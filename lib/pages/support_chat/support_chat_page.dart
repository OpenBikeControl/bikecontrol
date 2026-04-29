import 'dart:async';

import 'package:bike_control/pages/subscriptions/login.dart';
import 'package:bike_control/pages/support_chat/support_thread_page.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:bike_control/pages/support_chat/widgets/support_message_group.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/material.dart' show BackButton, RefreshIndicator;
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TelemetryBuilder = Future<TelemetrySnapshot> Function();

class SupportChatPage extends StatefulWidget {
  final TelemetryBuilder telemetryBuilder;
  final String? diagnosticPreview;

  const SupportChatPage({
    super.key,
    required this.telemetryBuilder,
    this.diagnosticPreview,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> with WidgetsBindingObserver {
  final SupportChatService _service = SupportChatService();
  StreamSubscription<AuthState>? _authSub;

  bool _loading = false;
  String? _loadError;
  SupportChat? _chat;
  List<SupportMessage> _messages = [];
  final List<SupportMessage> _pendingMessages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = core.supabase.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() {});
      if (core.supabase.auth.currentSession != null && _chat == null && !_loading) {
        _bootstrap();
      }
    });
    if (core.supabase.auth.currentSession != null) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _chat != null && !_loading) {
      _refresh();
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final chat = await _service.openChat();
      final fetched = await _service.fetchChat(skipLastSeen: false);
      if (!mounted) return;
      setState(() {
        _chat = fetched.chat ?? chat;
        _messages = fetched.messages;
        _loading = false;
      });
    } on SupportChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = context.i18n.failedToOpenChat;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final fetched = await _service.fetchChat(skipLastSeen: false);
      if (!mounted) return;
      setState(() {
        if (fetched.chat != null) _chat = fetched.chat;
        _messages = fetched.messages;
      });
    } on SupportChatException catch (e) {
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
    }
  }

  Future<void> _send(String body, StagedAttachment? staged) async {
    final chat = _chat;
    if (chat == null) return;

    final telemetry = await widget.telemetryBuilder();

    final placeholderId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final session = core.supabase.auth.currentSession;
    final placeholder = SupportMessage(
      id: placeholderId,
      chatId: chat.id,
      senderId: session?.user.id ?? '',
      senderRole: SupportMessageSenderRole.user,
      body: body,
      parentMessageId: null,
      createdAt: DateTime.now().toUtc(),
      attachments: const [],
    );
    setState(() {
      _sending = true;
      _pendingMessages.add(placeholder);
    });

    try {
      final attachments = <SupportAttachmentUpload>[];
      if (staged != null) {
        final upload = await _service.uploadAttachment(
          chatId: chat.id,
          file: staged.file,
          attachmentTooLargeMessage: context.i18n.attachmentTooLarge,
          unsupportedMimeMessage: context.i18n.attachmentMimeUnsupported,
        );
        attachments.add(upload);
      }
      final sent = await _service.sendMessage(
        chatId: chat.id,
        body: body,
        attachments: attachments,
        telemetry: telemetry.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == placeholderId);
        _messages = [..._messages, sent];
        _sending = false;
      });
    } on SupportChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == placeholderId);
        _sending = false;
      });
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
      rethrow;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == placeholderId);
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
            context.i18n.supportChat,
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
    if (core.supabase.auth.currentSession == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _signInGate(),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: SmallProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            const SizedBox(height: 12),
            Button.secondary(
              onPressed: _bootstrap,
              child: Text(context.i18n.retry),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(child: _messageList()),
        SupportComposer(
          sending: _sending,
          onSend: _send,
          diagnosticPreview: widget.diagnosticPreview,
        ),
      ],
    );
  }

  Widget _messageList() {
    final rootMessages = _messages.where((m) => m.parentMessageId == null).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final replyCounts = <String, int>{};
    for (final m in _messages) {
      final parent = m.parentMessageId;
      if (parent != null) {
        replyCounts[parent] = (replyCounts[parent] ?? 0) + 1;
      }
    }

    if (rootMessages.isEmpty && _pendingMessages.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Avatar(
                    initials: 'JB',
                    size: 52,
                    provider: AssetImage('jonas.jpg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.i18n.supportChatIntro,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                context.i18n.supportChatEmpty,
                style: TextStyle(color: cs.mutedForeground),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final timeline = [...rootMessages, ..._pendingMessages];
    final meta = <String, SupportMessageMeta>{
      for (final m in rootMessages)
        m.id: SupportMessageMeta(
          replyCount: replyCounts[m.id] ?? 0,
          onReply: () => _openThread(m),
        ),
      for (final p in _pendingMessages) p.id: const SupportMessageMeta(pending: true),
    };
    final groups = groupConsecutiveBySender(timeline);

    // reverse: true anchors the list at its bottom, so the newest message is
    // always in view on first build and stays pinned when new messages arrive.
    // Children are reversed so visually they still read top-to-bottom oldest
    // → newest.
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final group in groups.reversed) SupportMessageGroup(messages: group, service: _service, meta: meta),
        ],
      ),
    );
  }

  void _openThread(SupportMessage parent) {
    final chat = _chat;
    if (chat == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => SupportThreadPage(
              chat: chat,
              parent: parent,
              telemetryBuilder: widget.telemetryBuilder,
            ),
          ),
        )
        .then((_) {
          if (mounted) _refresh();
        });
  }

  Widget _signInGate() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.logIn, size: 20, color: cs.mutedForeground),
              const Gap(10),
              Text(
                context.i18n.signInToChatWithSupport,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Gap(8),
          Text(
            context.i18n.signInToChatExplanation,
            style: TextStyle(fontSize: 13, color: cs.mutedForeground),
          ),
          const Gap(16),
          Button.primary(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    headers: [
                      AppBar(
                        leading: [BackButton()],
                      ),
                    ],
                    child: const LoginPage(pushed: true),
                  ),
                ),
              );
            },
            child: Text(context.i18n.signIn),
          ),
        ],
      ),
    );
  }
}
