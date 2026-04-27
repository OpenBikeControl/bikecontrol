import 'package:flutter/foundation.dart';

@immutable
class SupportChat {
  final String id;
  final String userId;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final DateTime? lastSeenAt;

  const SupportChat({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.lastMessageAt,
    this.lastSeenAt,
  });

  factory SupportChat.fromJson(Map<String, dynamic> json) {
    return SupportChat(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageAt: _parseDate(json['last_message_at']),
      lastSeenAt: _parseDate(json['last_seen_at']),
    );
  }
}

enum SupportMessageSenderRole { user, admin }

@immutable
class SupportMessage {
  final String id;
  final String chatId;
  final String senderId;
  final SupportMessageSenderRole senderRole;
  final String body;
  final String? parentMessageId;
  final DateTime createdAt;
  final List<SupportAttachment> attachments;

  const SupportMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.parentMessageId,
    required this.createdAt,
    required this.attachments,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
              .whereType<Map>()
              .map((e) => SupportAttachment.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
        : const <SupportAttachment>[];
    return SupportMessage(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] == 'admin'
          ? SupportMessageSenderRole.admin
          : SupportMessageSenderRole.user,
      body: (json['body'] as String?) ?? '',
      parentMessageId: json['parent_message_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      attachments: attachments,
    );
  }
}

@immutable
class SupportAttachment {
  final String id;
  final String messageId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final DateTime createdAt;

  const SupportAttachment({
    required this.id,
    required this.messageId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.createdAt,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: (json['file_name'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// The object returned by the upload-support-attachment endpoint, ready to be
/// included in the send-support-message body's `attachment_paths` array.
@immutable
class SupportAttachmentUpload {
  final String storagePath;
  final String fileName;
  final String mimeType;

  const SupportAttachmentUpload({
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
  });

  factory SupportAttachmentUpload.fromJson(Map<String, dynamic> json) {
    return SupportAttachmentUpload(
      storagePath: json['storage_path'] as String,
      fileName: (json['file_name'] as String?) ?? 'attachment',
      mimeType: (json['mime_type'] as String?) ?? 'application/octet-stream',
    );
  }

  Map<String, dynamic> toJson() => {
    'storage_path': storagePath,
    'file_name': fileName,
    'mime_type': mimeType,
  };
}

DateTime? _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
