import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/utils/auth/fresh_access_token.dart';
import 'package:bike_control/utils/core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What a [SupportChatService.deleteSupportData] call erases.
///
/// - [conversation] removes the support chat, its messages and every attached
///   screenshot/diagnostic, but keeps the account (and, with it, any Pro
///   entitlement) and the linked email.
/// - [account] additionally deletes the auth user, which removes the email and
///   the account itself (GDPR right to erasure).
enum SupportDeleteScope { conversation, account }

class SupportChatException implements Exception {
  final String message;
  const SupportChatException(this.message);

  @override
  String toString() => 'SupportChatException: $message';
}

class SupportAttachmentLimits {
  static const int maxBytes = 10 * 1024 * 1024;
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'text/plain',
    'application/pdf',
    'application/zip',
  };

  static String? mimeTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    // .log alongside .txt: app/trainer logs are the attachment a support
    // thread most often needs, and they are plain text under another name.
    if (lower.endsWith('.txt') || lower.endsWith('.log')) return 'text/plain';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    return null;
  }
}

class SupportChatService {
  static const _createOrGetFunction = 'create-or-get-support-chat';
  static const _getChatFunction = 'get-support-chat';
  static const _sendMessageFunction = 'send-support-message';
  static const _uploadAttachmentFunction = 'upload-support-attachment';
  static const _deleteFunction = 'delete-support-data';
  static const _attachmentBucket = 'support-attachments';
  static const _signedUrlTtlSeconds = 300;

  // Mirrors the values passed to Supabase.initialize() in
  // lib/utils/settings/settings.dart. The Supabase Dart client doesn't
  // expose these back through SupabaseClient, so we keep them here for the
  // raw multipart edge-function upload below.
  static const String _supabaseUrl = 'https://pikrcyynovdvogrldfnw.supabase.co';
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final SupabaseClient _supabase;
  final http.Client _httpClient;

  SupportChatService({SupabaseClient? supabase, http.Client? httpClient})
    : _supabase = supabase ?? core.supabase,
      _httpClient = httpClient ?? http.Client();

  /// The Supabase client this service talks to — exposed so callers that
  /// need auth state (e.g. [SupportChatPage] checking/observing the current
  /// session) share the exact same client instance rather than falling back
  /// to the ambient `core.supabase` singleton, which would break test
  /// injection.
  SupabaseClient get client => _supabase;

  Future<SupportChat> openChat() async {
    _requireSession();
    try {
      final response = await _supabase.functions.invoke(
        _createOrGetFunction,
        method: HttpMethod.post,
        body: const <String, dynamic>{},
      );
      final data = _asMap(response.data);
      final chatJson = _asMap(data['chat']);
      // Persist the sticky "user has a support chat" flag so HelpButton can
      // poll for unread replies on subsequent app launches.
      await core.settings.setSupportChatActive(true);
      return SupportChat.fromJson(chatJson);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? AppLocalizations.current.supportChatOpenFailed);
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatOpenFailed);
    }
  }

  Future<List<SupportIssue>> fetchOpenIssues({
    String? problemCategory,
    Iterable<String> problemSubcategories = const [],
  }) async {
    try {
      final trainerApp = core.settings.getTrainerApp();
      var query = _supabase
          .from('issues')
          .select('id, title, description, help_blog_slug, help_video_url')
          .eq('is_public', true)
          .eq('status', 'open');
      // trainer_apps is the per-issue scoping array; an empty array = applies to everyone.
      if (trainerApp != null) {
        query = query.or('trainer_apps.eq.{},trainer_apps.cs.{${trainerApp.name}}');
      } else {
        query = query.eq('trainer_apps', '{}');
      }
      if (problemCategory != null) {
        query = query.or('problem_categories.eq.{},problem_categories.cs.{$problemCategory}');
      }
      final subs = problemSubcategories.where((s) => s.isNotEmpty).toList(growable: false);
      if (subs.isNotEmpty) {
        // Build `{a,b}` literal carefully — slugs are snake_case ASCII, no quoting needed.
        final subsList = subs.join(',');
        query = query.or('problem_subcategories.eq.{},problem_subcategories.cs.{$subsList}');
      }
      final response = await query.order('created_at', ascending: false);
      return response
          .whereType<Map>()
          .map((e) => SupportIssue.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatIssuesFailed);
    }
  }

  Future<({SupportChat? chat, List<SupportMessage> messages})> fetchChat({required bool skipLastSeen}) async {
    _requireSession();
    try {
      final response = await _supabase.functions.invoke(
        _getChatFunction,
        method: HttpMethod.get,
        queryParameters: {'skipLastSeen': skipLastSeen.toString()},
      );
      final data = _asMap(response.data);
      final rawChat = data['chat'];
      final chat = rawChat is Map ? SupportChat.fromJson(Map<String, dynamic>.from(rawChat)) : null;
      final rawMessages = data['messages'];
      final messages = rawMessages is List
          ? rawMessages.whereType<Map>().map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e))).toList()
          : <SupportMessage>[];
      return (chat: chat, messages: messages);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? AppLocalizations.current.supportChatLoadFailed);
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatLoadFailed);
    }
  }

  Future<SupportMessage> sendMessage({
    required String chatId,
    required String body,
    String? parentMessageId,
    List<SupportAttachmentUpload> attachments = const [],
    Map<String, dynamic> telemetry = const {},
    Map<String, dynamic>? intakeAnswers,
  }) async {
    _requireSession();
    // An image-only message is legitimate, but the send-support-message edge
    // function rejects an empty body. Substitute a minimal placeholder so the
    // screenshot goes through; remove this once the function accepts empty
    // bodies with attachments.
    final trimmedBody = body.trim();
    final effectiveBody = (trimmedBody.isEmpty && attachments.isNotEmpty)
        ? AppLocalizations.current.attachmentOnlyMessageBody
        : trimmedBody;
    final payload = <String, dynamic>{
      'chat_id': chatId,
      'body': effectiveBody,
      if (parentMessageId != null) 'parent_message_id': parentMessageId,
      if (attachments.isNotEmpty) 'attachment_paths': attachments.map((a) => a.toJson()).toList(growable: false),
      if (intakeAnswers != null) 'intake_answers': intakeAnswers,
      ...telemetry,
    };

    try {
      final response = await _supabase.functions.invoke(
        _sendMessageFunction,
        method: HttpMethod.post,
        body: payload,
      );
      final data = _asMap(response.data);
      final messageJson = _asMap(data['message']);
      // Echo attachments client-side; the API doesn't return them inline.
      messageJson['attachments'] ??= attachments
          .map((a) {
            return {
              'id': a.storagePath,
              'message_id': messageJson['id'],
              'storage_path': a.storagePath,
              'file_name': a.fileName,
              'mime_type': a.mimeType,
              'created_at': messageJson['created_at'],
            };
          })
          .toList(growable: false);
      return SupportMessage.fromJson(messageJson);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? AppLocalizations.current.supportChatSendFailed);
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatSendFailed);
    }
  }

  Future<SupportAttachmentUpload> uploadAttachment({
    required String chatId,
    required PlatformFile file,
    String? attachmentTooLargeMessage,
    String? unsupportedMimeMessage,
  }) async {
    _requireSession();
    final fileName = file.name;
    final fileBytes = file.bytes;
    final filePath = file.path;

    final mimeType = SupportAttachmentLimits.mimeTypeForName(fileName);
    if (mimeType == null || !SupportAttachmentLimits.allowedMimeTypes.contains(mimeType)) {
      throw SupportChatException(unsupportedMimeMessage ?? AppLocalizations.current.supportChatUnsupportedFile);
    }

    final size = file.size;
    if (size > SupportAttachmentLimits.maxBytes) {
      throw SupportChatException(attachmentTooLargeMessage ?? 'Attachment exceeds 10 MB');
    }

    final uri = Uri.parse('$_supabaseUrl/functions/v1/$_uploadAttachmentFunction');
    final request = http.MultipartRequest('POST', uri);
    // Raw request: the Supabase client's AuthHttpClient doesn't refresh for us.
    request.headers['Authorization'] = 'Bearer ${await freshAccessToken(_supabase.auth)}';
    request.headers['apikey'] = _supabaseAnonKey;
    request.fields['chat_id'] = chatId;

    final mediaType = MediaType.parse(mimeType);
    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else {
      throw const SupportChatException('Selected file has no readable content');
    }

    try {
      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SupportChatException(
          _extractErrorFromBody(response.body) ?? AppLocalizations.current.supportChatUploadFailed,
        );
      }
      final json = jsonDecode(response.body);
      if (json is! Map) {
        throw SupportChatException(AppLocalizations.current.supportChatUploadFailed);
      }
      return SupportAttachmentUpload.fromJson(Map<String, dynamic>.from(json));
    } on SupportChatException {
      rethrow;
    } on SocketException {
      throw SupportChatException(AppLocalizations.current.supportChatUploadFailed);
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatUploadFailed);
    }
  }

  Future<String> signedAttachmentUrl(String storagePath) async {
    return _supabase.storage.from(_attachmentBucket).createSignedUrl(storagePath, _signedUrlTtlSeconds);
  }

  /// Erases the caller's support data. The heavy lifting runs server-side in
  /// the [_deleteFunction] edge function (service role): a client can neither
  /// delete objects in the attachments bucket — there is no DELETE storage
  /// policy — nor delete its own auth user, so this cannot be done over RLS
  /// alone. See [SupportDeleteScope] for what each scope removes.
  ///
  /// Whichever scope, the local "user has a support chat" flag is cleared on
  /// success so [HelpButton] stops polling for replies to a thread that no
  /// longer exists. Sign-out / RevenueCat teardown for [SupportDeleteScope.account]
  /// is the caller's responsibility — the session's own user is gone.
  Future<void> deleteSupportData(SupportDeleteScope scope) async {
    _requireSession();
    try {
      await _supabase.functions.invoke(
        _deleteFunction,
        method: HttpMethod.post,
        body: {'scope': scope.name},
      );
      await core.settings.setSupportChatActive(false);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? AppLocalizations.current.supportChatDeleteFailed);
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw SupportChatException(AppLocalizations.current.supportChatDeleteFailed);
    }
  }

  Session _requireSession() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const SupportChatException('Not signed in');
    }
    return session;
  }

  String? _extractError(dynamic details) {
    if (details is Map && details['error'] is String) return details['error'] as String;
    return null;
  }

  String? _extractErrorFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) return decoded['error'] as String;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}
