import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/utils/core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  };

  static String? mimeTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return null;
  }
}

class SupportChatService {
  static const _createOrGetFunction = 'create-or-get-support-chat';
  static const _getChatFunction = 'get-support-chat';
  static const _sendMessageFunction = 'send-support-message';
  static const _uploadAttachmentFunction = 'upload-support-attachment';
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

  Future<SupportChat> openChat() async {
    final session = _requireSession();
    try {
      final response = await _supabase.functions.invoke(
        _createOrGetFunction,
        method: HttpMethod.post,
        headers: _authHeaders(session),
        body: const <String, dynamic>{},
      );
      final data = _asMap(response.data);
      final chatJson = _asMap(data['chat']);
      // Persist the sticky "user has a support chat" flag so HelpButton can
      // poll for unread replies on subsequent app launches.
      await core.settings.setSupportChatActive(true);
      return SupportChat.fromJson(chatJson);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? 'Failed to open support chat');
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw const SupportChatException('Failed to open support chat');
    }
  }

  Future<({SupportChat? chat, List<SupportMessage> messages})> fetchChat() async {
    final session = _requireSession();
    try {
      final response = await _supabase.functions.invoke(
        _getChatFunction,
        method: HttpMethod.get,
        headers: _authHeaders(session),
      );
      final data = _asMap(response.data);
      final rawChat = data['chat'];
      final chat = rawChat is Map ? SupportChat.fromJson(Map<String, dynamic>.from(rawChat)) : null;
      final rawMessages = data['messages'];
      final messages = rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : <SupportMessage>[];
      return (chat: chat, messages: messages);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? 'Failed to load support chat');
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw const SupportChatException('Failed to load support chat');
    }
  }

  Future<SupportMessage> sendMessage({
    required String chatId,
    required String body,
    String? parentMessageId,
    List<SupportAttachmentUpload> attachments = const [],
    Map<String, dynamic> telemetry = const {},
  }) async {
    final session = _requireSession();
    final payload = <String, dynamic>{
      'chat_id': chatId,
      'body': body.trim(),
      if (parentMessageId != null) 'parent_message_id': parentMessageId,
      if (attachments.isNotEmpty)
        'attachment_paths': attachments.map((a) => a.toJson()).toList(growable: false),
      ...telemetry,
    };

    try {
      final response = await _supabase.functions.invoke(
        _sendMessageFunction,
        method: HttpMethod.post,
        headers: _authHeaders(session),
        body: payload,
      );
      final data = _asMap(response.data);
      final messageJson = _asMap(data['message']);
      // Echo attachments client-side; the API doesn't return them inline.
      messageJson['attachments'] ??= attachments.map((a) {
        return {
          'id': a.storagePath,
          'message_id': messageJson['id'],
          'storage_path': a.storagePath,
          'file_name': a.fileName,
          'mime_type': a.mimeType,
          'created_at': messageJson['created_at'],
        };
      }).toList(growable: false);
      return SupportMessage.fromJson(messageJson);
    } on FunctionException catch (e) {
      throw SupportChatException(_extractError(e.details) ?? 'Failed to send message');
    } on SupportChatException {
      rethrow;
    } catch (_) {
      throw const SupportChatException('Failed to send message');
    }
  }

  Future<SupportAttachmentUpload> uploadAttachment({
    required String chatId,
    required PlatformFile file,
    String? attachmentTooLargeMessage,
    String? unsupportedMimeMessage,
  }) async {
    final session = _requireSession();
    final fileName = file.name;
    final fileBytes = file.bytes;
    final filePath = file.path;

    final mimeType = SupportAttachmentLimits.mimeTypeForName(fileName);
    if (mimeType == null || !SupportAttachmentLimits.allowedMimeTypes.contains(mimeType)) {
      throw SupportChatException(unsupportedMimeMessage ?? 'Unsupported file type');
    }

    final size = file.size;
    if (size > SupportAttachmentLimits.maxBytes) {
      throw SupportChatException(attachmentTooLargeMessage ?? 'Attachment exceeds 10 MB');
    }

    final uri = Uri.parse('$_supabaseUrl/functions/v1/$_uploadAttachmentFunction');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.headers['apikey'] = _supabaseAnonKey;
    request.fields['chat_id'] = chatId;

    final mediaType = MediaType.parse(mimeType);
    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: mediaType,
      ));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
        contentType: mediaType,
      ));
    } else {
      throw const SupportChatException('Selected file has no readable content');
    }

    try {
      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SupportChatException(_extractErrorFromBody(response.body) ?? 'Failed to upload attachment');
      }
      final json = jsonDecode(response.body);
      if (json is! Map) {
        throw const SupportChatException('Failed to upload attachment');
      }
      return SupportAttachmentUpload.fromJson(Map<String, dynamic>.from(json));
    } on SupportChatException {
      rethrow;
    } on SocketException {
      throw const SupportChatException('Failed to upload attachment');
    } catch (_) {
      throw const SupportChatException('Failed to upload attachment');
    }
  }

  Future<String> signedAttachmentUrl(String storagePath) async {
    return _supabase.storage.from(_attachmentBucket).createSignedUrl(storagePath, _signedUrlTtlSeconds);
  }

  Session _requireSession() {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw const SupportChatException('Not signed in');
    }
    return session;
  }

  Map<String, String> _authHeaders(Session session) {
    return {'Authorization': 'Bearer ${session.accessToken}'};
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
