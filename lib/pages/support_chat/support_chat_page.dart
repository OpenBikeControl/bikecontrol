import 'dart:async';

import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/pages/support_chat/support_thread_page.dart';
import 'package:bike_control/pages/support_chat/widgets/support_account_link_card.dart';
import 'package:bike_control/pages/support_chat/widgets/support_composer.dart';
import 'package:bike_control/pages/support_chat/widgets/support_intake_form.dart';
import 'package:bike_control/pages/support_chat/widgets/support_message_group.dart';
import 'package:bike_control/services/feedback_submission_service.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/services/telemetry_snapshot.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/support/intake_options.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:flutter/material.dart' show RefreshIndicator;
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TelemetryBuilder = Future<TelemetrySnapshot> Function();

class SupportChatPage extends StatefulWidget {
  final TelemetryBuilder telemetryBuilder;

  /// Resolves to the diagnostic-payload preview shown in the composer. Awaited
  /// lazily (in [initState]) so opening the chat is instant while the
  /// diagnostics gather in the background.
  final Future<String>? diagnosticPreviewFuture;
  final String? initialText;

  /// Optional attachment to pre-stage in the composer on first build
  /// (e.g. an OverviewPage screenshot captured by the caller before
  /// pushing this page). The user can still remove it before sending.
  final StagedAttachment? initialAttachment;

  /// Pre-fills the intake summary (skipping the form) for callers that already
  /// know the answer — e.g. the self-test card's verdict CTAs, which map
  /// directly onto a smart-trainer intake branch.
  final IntakeAnswers? initialIntake;

  /// Test-only injection point for the chat's Supabase-backed service.
  /// Production call sites never pass this and get the default
  /// `SupportChatService()`, which talks to `core.supabase`.
  final SupportChatService? service;

  /// Test-only injection point for the anonymous-session + email-link-up
  /// helper. When null, defaults to a [FeedbackSubmissionService] sharing
  /// [service]'s client so both always agree on the current auth state.
  final FeedbackSubmissionService? accountService;

  const SupportChatPage({
    super.key,
    required this.telemetryBuilder,
    this.diagnosticPreviewFuture,
    this.initialText,
    this.initialAttachment,
    this.initialIntake,
    this.service,
    this.accountService,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> with WidgetsBindingObserver {
  late final SupportChatService _service = widget.service ?? SupportChatService();

  /// Handles anonymous sign-in-on-demand and the email link-up flow. Reused
  /// from the feedback prompt rather than reinvented — the logic isn't
  /// feedback-specific, it always shares [_service]'s client so a session
  /// created here (e.g. by [_send]) is immediately visible to [_service].
  late final FeedbackSubmissionService _accountService =
      widget.accountService ?? FeedbackSubmissionService(client: _service.client);

  SupabaseClient get _client => _service.client;

  StreamSubscription<AuthState>? _authSub;

  bool _loading = false;
  String? _loadError;
  SupportChat? _chat;
  List<SupportMessage> _messages = [];
  final List<SupportMessage> _pendingMessages = [];
  bool _sending = false;

  /// Attachments already uploaded to storage but whose message send failed.
  /// Keyed by the staged attachment the composer restores, so retrying re-uses
  /// the blob instead of orphaning it (there is no client-side delete).
  final Map<StagedAttachment, SupportAttachmentUpload> _retainedUploads = {};
  IntakeAnswers? _intakeAnswers;
  bool _intakeSent = false;
  bool _editingIntake = false;
  String? _diagnosticPreview;

  /// True once either entry point (the post-send prompt or the header's
  /// "Sign In" button) has revealed [SupportAccountLinkCard]. Both entry
  /// points converge on the same card instance/state machine, so this only
  /// ever flips false → true.
  bool _showAccountLink = false;

  @override
  void initState() {
    super.initState();
    // Lets a caller that already knows the answer (e.g. the self-test card's
    // verdict CTAs) skip straight past the intake form; the existing send
    // path already attaches whatever is in _intakeAnswers to the next
    // outgoing message.
    _intakeAnswers = widget.initialIntake ?? _intakeAnswers;
    WidgetsBinding.instance.addObserver(this);
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      if (!mounted) return;
      setState(() {});
      // Catches a session appearing from outside this page's own _send()
      // flow (e.g. the rider signs in elsewhere while the chat is open).
      // _sending guards against the race _send() would otherwise cause with
      // itself: ensureSession() signing in anonymously fires this same
      // event, and without the guard both this listener and _send() would
      // call openChat() concurrently.
      if (_client.auth.currentSession != null && _chat == null && !_loading && !_sending) {
        _bootstrap();
      }
    });
    // A session (anonymous or otherwise) may already exist from a previous
    // visit — bootstrap eagerly so returning riders see their history. A
    // brand-new rider has no session yet; _send() creates one (and the chat)
    // lazily on the first message instead of forcing that here just to view
    // the empty composer.
    if (_client.auth.currentSession != null) {
      _bootstrap();
    }
    widget.diagnosticPreviewFuture?.then((preview) {
      if (mounted) setState(() => _diagnosticPreview = preview);
    });
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
      // Get-only: opening the page must never create a chat by itself (that
      // was 135 of 444 chat rows in 30 days — someone merely looked, then
      // left). A brand-new rider with a session but no messages yet gets
      // chat: null here and stays that way until _send()'s lazy create
      // (openChat()) runs on the first message.
      final fetched = await _service.fetchChat(skipLastSeen: false);
      if (!mounted) return;
      setState(() {
        _chat = fetched.chat;
        _messages = fetched.messages;
        _loading = false;
      });
      // A returning rider's chat already exists server-side — flip the sticky
      // "has a support chat" flag now, same as openChat() does for the
      // lazy-create-on-send path, so HelpButton's unread-reply poll picks it
      // up without waiting for another message. This gets its own try/catch:
      // the chat and its messages already loaded successfully above, so a
      // failure writing this local flag must not turn that into a full-page
      // "failed to open chat" screen.
      if (fetched.chat != null) {
        try {
          await core.settings.setSupportChatActive(true);
        } catch (e, s) {
          recordError(e, s, context: 'support.chat.bootstrap.setActive');
        }
      }
    } on SupportChatException catch (e, s) {
      recordError(e, s, context: 'support.chat.bootstrap');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    } catch (e, s) {
      recordError(e, s, context: 'support.chat.bootstrap');
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
    setState(() => _sending = true);

    // Write-first, sign-in-afterwards: a rider with no session at all gets
    // one created silently right here, the same anonymous-session-on-demand
    // pattern the feedback flow already uses. SupportChatService's calls
    // below are otherwise unchanged — they just now always find a session.
    try {
      await _accountService.ensureSession();
    } catch (e, s) {
      recordError(e, s, context: 'support.chat.send.ensureSession');
      if (!mounted) return;
      setState(() => _sending = false);
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: context.i18n.failedToSendMessage);
      // Same contract as the catch blocks below: the composer restores the
      // typed text and staged attachment on any rethrow.
      rethrow;
    }

    // A brand-new anonymous rider has no chat yet — open one now that a
    // session exists. Returning riders (session already existed at
    // initState) already have _chat from _bootstrap().
    var chat = _chat;
    if (chat == null) {
      try {
        chat = await _service.openChat();
        if (!mounted) return;
        setState(() => _chat = chat);
      } on SupportChatException catch (e, s) {
        recordError(e, s, context: 'support.chat.send.openChat');
        if (!mounted) return;
        setState(() => _sending = false);
        buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
        rethrow;
      } catch (e, s) {
        recordError(e, s, context: 'support.chat.send.openChat');
        if (!mounted) return;
        setState(() => _sending = false);
        buildToast(level: LogLevel.LOGLEVEL_ERROR, title: context.i18n.failedToSendMessage);
        rethrow;
      }
    }

    final telemetry = await widget.telemetryBuilder();

    final placeholderId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final session = _client.auth.currentSession;
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
      _pendingMessages.add(placeholder);
    });

    try {
      final attachments = <SupportAttachmentUpload>[];
      if (staged != null) {
        // The blob is uploaded before the message send, so a failed send would
        // otherwise leak it: there is no client-side delete for the bucket.
        // Instead we remember the successful upload against the staged file the
        // composer hands back, so a retry re-uses that blob instead of
        // orphaning it and uploading a second copy.
        final upload =
            _retainedUploads[staged] ??
            await _service.uploadAttachment(
              chatId: chat.id,
              file: staged.file,
              attachmentTooLargeMessage: context.i18n.attachmentTooLarge,
              unsupportedMimeMessage: context.i18n.attachmentMimeUnsupported,
            );
        _retainedUploads[staged] = upload;
        attachments.add(upload);
      }
      final intakePayload = (!_intakeSent && _intakeAnswers != null) ? _intakeAnswers!.toJson() : null;
      final sent = await _service.sendMessage(
        chatId: chat.id,
        body: body,
        attachments: attachments,
        telemetry: telemetry.toJson(),
        intakeAnswers: intakePayload,
      );
      if (staged != null) _retainedUploads.remove(staged);
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == placeholderId);
        _messages = [..._messages, sent];
        _sending = false;
        if (intakePayload != null) _intakeSent = true;
        // The incentive to link an email: the message is already with
        // support, but nothing comes back to an anonymous rider until they
        // do. Shown once per chat session — _showAccountLink only goes
        // false → true.
        if (_accountService.isAnonymous) _showAccountLink = true;
      });
    } on SupportChatException catch (e, s) {
      recordError(e, s, context: 'support.chat.send');
      if (!mounted) return;
      setState(() {
        _pendingMessages.removeWhere((m) => m.id == placeholderId);
        _sending = false;
      });
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: e.message);
      // The composer relies on this to know it must restore the text and the
      // staged attachment; it swallows it there rather than passing it on.
      rethrow;
    } catch (e, s) {
      recordError(e, s, context: 'support.chat.send');
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
    final cs = Theme.of(context).colorScheme;
    final signedIn = !_accountService.isAnonymous;
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
          // Standing sign-in affordance: works no matter whether the rider
          // has sent anything yet — it starts the exact same email-link flow
          // as the post-send prompt (SupportAccountLinkCard), just revealed
          // from a different trigger.
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: signedIn ? Colors.green : cs.mutedForeground,
                ),
              ),
              const Gap(5),
              Text(
                key: const ValueKey('support-account-status-text'),
                signedIn ? context.i18n.supportAccountStatusSignedIn : context.i18n.supportAccountStatusAnonymous,
                style: TextStyle(fontSize: 11, color: cs.mutedForeground),
              ),
            ],
          ),
          trailing: [
            if (!signedIn)
              Button(
                key: const ValueKey('support-header-sign-in'),
                style: ButtonStyle.outline(size: ButtonSize.small),
                onPressed: _openAccountLink,
                child: Text(context.i18n.signIn),
              ),
            // Self-serve data deletion — only meaningful once a chat (and thus
            // data) exists. "Delete account" is gated to signed-in riders; an
            // anonymous rider's data is fully covered by "Delete conversation".
            if (_chat != null)
              IconButton.ghost(
                key: const ValueKey('support-overflow-menu'),
                icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
                onPressed: () => _showDeleteMenu(context, signedIn),
              ),
          ],
          backgroundColor: Theme.of(context).colorScheme.background,
        ),
        const Divider(),
      ],
      // The known-issues banner used to sit here — it's gone (usage-fix
      // round 3): known issues belong to the Help Center now, and showing
      // them again in the chat was noise. `_body()` fills the whole content
      // area directly; it no longer needs an Expanded+Column to share space
      // with a banner above it.
      child: _body(),
    );
  }

  /// Reveals [SupportAccountLinkCard] — the same instance/state machine the
  /// post-send prompt uses — from the header's "Sign In" button. Idempotent:
  /// tapping it again once the card is already showing is a no-op.
  void _openAccountLink() {
    if (_showAccountLink) return;
    setState(() => _showAccountLink = true);
  }

  void _showDeleteMenu(BuildContext anchorContext, bool signedIn) {
    final i18n = anchorContext.i18n;
    showDropdown(
      context: anchorContext,
      builder: (c) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.trash2),
            onPressed: (_) => _confirmAndDelete(SupportDeleteScope.conversation),
            child: Text(i18n.supportDeleteConversation),
          ),
          if (signedIn)
            MenuButton(
              leading: const Icon(LucideIcons.userX),
              onPressed: (_) => _confirmAndDelete(SupportDeleteScope.account),
              child: Text(i18n.supportDeleteAccount),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(SupportDeleteScope scope) async {
    final i18n = context.i18n;
    final isAccount = scope == SupportDeleteScope.account;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(isAccount ? i18n.supportDeleteAccountTitle : i18n.supportDeleteConversationTitle),
        content: Text(isAccount ? i18n.supportDeleteAccountBody : i18n.supportDeleteConversationBody),
        actions: [
          Button.ghost(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(i18n.cancel),
          ),
          Button.destructive(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(i18n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.deleteSupportData(scope);
      if (!mounted) return;
      if (isAccount) {
        // The auth user no longer exists server-side, so clear the local
        // session only — a global sign-out would just round-trip to a user
        // that is already gone.
        await _client.auth.signOut(scope: SignOutScope.local);
        if (!mounted) return;
      }
      setState(() {
        _messages = [];
        _pendingMessages.clear();
        _chat = null;
        _intakeSent = false;
        _intakeAnswers = null;
        _editingIntake = false;
        _showAccountLink = false;
        _retainedUploads.clear();
      });
      buildToast(level: LogLevel.LOGLEVEL_INFO, title: i18n.supportDeleteSuccess);
    } catch (e, s) {
      recordError(e, s, context: 'support.chat.delete');
      if (!mounted) return;
      buildToast(level: LogLevel.LOGLEVEL_ERROR, title: i18n.supportDeleteFailed);
    }
  }

  Widget _body() {
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
    final hasMessages = _messages.isNotEmpty || _pendingMessages.isNotEmpty;
    // Gate the composer on a NEW chat (no messages yet) until the intake form
    // is submitted. Once any message exists, the composer is always shown so
    // existing conversations remain unaffected.
    final showComposer = hasMessages || _intakeAnswers != null;
    return Column(
      children: [
        Expanded(child: _messageList()),
        // Inline, not a modal — sits right above the composer regardless of
        // which entry point (post-send prompt or header button) revealed it.
        if (_showAccountLink)
          SupportAccountLinkCard(
            accountService: _accountService,
            onLinked: () => setState(() {}),
          ),
        if (showComposer && !_intakeSent && _intakeAnswers != null && !_editingIntake)
          SupportIntakeSummaryChip(
            answers: _intakeAnswers!,
            onEdit: () => setState(() => _editingIntake = true),
          ),
        if (showComposer)
          SupportComposer(
            sending: _sending,
            onSend: _send,
            diagnosticPreview: _diagnosticPreview,
            initialText: widget.initialText,
            initialAttachment: widget.initialAttachment,
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
      final showForm = _intakeAnswers == null || _editingIntake;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.i18n.supportChatIntro,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.i18n.supportChatIntroFatherNote,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: cs.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (showForm)
              SupportIntakeForm(
                service: _service,
                initial: _intakeAnswers,
                onContinue: (answers) {
                  setState(() {
                    _intakeAnswers = answers;
                    _editingIntake = false;
                  });
                },
              )
            else
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
}
