import 'dart:async';

import 'package:bike_control/pages/support_chat/support_chat_page.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:bike_control/pages/support_chat/widgets/support_message_group.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/material.dart' show RefreshIndicator;
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SupportThreadPage extends StatefulWidget {
  final SupportChat chat;
  final SupportMessage parent;
  final TelemetryBuilder telemetryBuilder;

  const SupportThreadPage({
    super.key,
    required this.chat,
    required this.parent,
    required this.telemetryBuilder,
  });

  @override
  State<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends State<SupportThreadPage> {
  final SupportChatService _service = SupportChatService();
  late SupportMessage _parent;
  List<SupportMessage> _replies = const [];
  final List<SupportMessage> _pendingReplies = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _parent = widget.parent;
    _refresh(initial: true);
  }

  Future<void> _refresh({bool initial = false}) async {
    if (initial) setState(() => _loading = true);
    try {
      final fetched = await _service.fetchChat(skipLastSeen: false);
      final all = fetched.messages;
      final updatedParent = all.firstWhere(
        (m) => m.id == widget.parent.id,
        orElse: () => _parent,
      );
      final replies = all.where((m) => m.parentMessageId == widget.parent.id).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      setState(() {
        _parent = updatedParent;
        _replies = replies;
        _loading = false;
      });
    } on SupportChatException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
    }
  }

  Future<void> _send(String body, StagedAttachment? staged) async {
    final telemetry = await widget.telemetryBuilder();
    final placeholderId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final session = core.supabase.auth.currentSession;
    final placeholder = SupportMessage(
      id: placeholderId,
      chatId: widget.chat.id,
      senderId: session?.user.id ?? '',
      senderRole: SupportMessageSenderRole.user,
      body: body,
      parentMessageId: widget.parent.id,
      createdAt: DateTime.now().toUtc(),
      attachments: const [],
    );
    setState(() {
      _sending = true;
      _pendingReplies.add(placeholder);
    });
    try {
      final attachments = <SupportAttachmentUpload>[];
      if (staged != null) {
        final upload = await _service.uploadAttachment(
          chatId: widget.chat.id,
          file: staged.file,
          attachmentTooLargeMessage: context.i18n.attachmentTooLarge,
          unsupportedMimeMessage: context.i18n.attachmentMimeUnsupported,
        );
        attachments.add(upload);
      }
      final sent = await _service.sendMessage(
        chatId: widget.chat.id,
        body: body,
        parentMessageId: widget.parent.id,
        attachments: attachments,
        telemetry: telemetry.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _pendingReplies.removeWhere((m) => m.id == placeholderId);
        _replies = [..._replies, sent];
        _sending = false;
      });
    } on SupportChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingReplies.removeWhere((m) => m.id == placeholderId);
        _sending = false;
      });
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
      rethrow;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingReplies.removeWhere((m) => m.id == placeholderId);
        _sending = false;
      });
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: context.i18n.failedToSendMessage);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          leading: [
            IconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft, size: 24),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          title: Text(
            context.i18n.threadTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          ),
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading && _replies.isEmpty) {
      return const Center(child: SmallProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                SupportMessageGroup(messages: [_parent], service: _service),
                if (_replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                for (final group in groupConsecutiveBySender([..._replies, ..._pendingReplies]))
                  SupportMessageGroup(
                    messages: group,
                    service: _service,
                    meta: {
                      for (final p in _pendingReplies) p.id: const SupportMessageMeta(pending: true),
                    },
                  ),
              ],
            ),
          ),
        ),
        SupportComposer(sending: _sending, onSend: _send),
      ],
    );
  }
}
