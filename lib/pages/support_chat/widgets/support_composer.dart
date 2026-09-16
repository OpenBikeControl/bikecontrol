import 'dart:async' show unawaited;
import 'dart:io' show File;

import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// A staged attachment ready to be uploaded — wraps the platform file plus
/// a lightweight thumbnail for image previews.
class StagedAttachment {
  final PlatformFile file;
  StagedAttachment(this.file);

  String get name => file.name;
  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}

class SupportComposer extends StatefulWidget {
  final bool sending;
  final Future<void> Function(String body, StagedAttachment? attachment) onSend;

  /// When non-empty, a collapsible chip is rendered above the composer
  /// showing the diagnostic payload that will be attached to the next
  /// outgoing message. Right-aligned so it doesn't span the full width.
  final String? diagnosticPreview;

  /// Optional text to prefill the composer with on first build. The text
  /// field is auto-focused when this is non-empty so the user can start
  /// typing immediately.
  final String? initialText;

  /// Optional attachment to pre-stage on first build (e.g. an
  /// OverviewPage screenshot captured before navigating to the chat).
  /// The user can still remove it via the chip's X button before sending.
  final StagedAttachment? initialAttachment;

  /// A diagnostic line (e.g. `Network self-test: …`) that rides along with
  /// the first message instead of being prefilled into the input. Unlike
  /// [initialText] the rider cannot edit or delete it, and send stays
  /// disabled until they have typed a short description of their own: a
  /// bare test result used to be the whole message in a third of all chats
  /// and every one of those cost support a "what actually isn't working?"
  /// round trip. Consumed by the first successful send, like [initialText].
  final String? pinnedContext;

  /// What [pinnedContext] is, in the rider's language (e.g. "network check
  /// result"), for the "Attached: …" chip above the input. Required when
  /// [pinnedContext] is set.
  final String? pinnedContextLabel;

  const SupportComposer({
    super.key,
    required this.sending,
    required this.onSend,
    this.diagnosticPreview,
    this.initialText,
    this.initialAttachment,
    this.pinnedContext,
    this.pinnedContextLabel,
  }) : assert(pinnedContext == null || pinnedContextLabel != null, 'pinnedContext needs a pinnedContextLabel');

  /// The shortest description that unlocks send while a [pinnedContext] is
  /// attached. Trimmed length, so whitespace alone counts as nothing.
  static const int minDescriptionLength = 12;

  @override
  State<SupportComposer> createState() => _SupportComposerState();
}

class _SupportComposerState extends State<SupportComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  StagedAttachment? _attachment;

  /// The pending [SupportComposer.pinnedContext]; null once it has gone out
  /// with a message, so a follow-up "yes, still happening" is neither gated
  /// nor carries the (multi-line) result a second time.
  String? _pinnedContext;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      _controller.selection = TextSelection.collapsed(offset: initial.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    _attachment = widget.initialAttachment;
    _pinnedContext = widget.pinnedContext;
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// True while a pinned result is waiting on a description the rider has
  /// not typed yet — the one case where send is disabled despite there
  /// being something to send.
  bool get _needsDescription =>
      _pinnedContext != null && _controller.text.trim().length < SupportComposer.minDescriptionLength;

  bool get _canSend {
    if (widget.sending) return false;
    // A staged screenshot does not stand in for the description: a picture
    // plus a test result still doesn't say what the rider expected to happen.
    if (_pinnedContext != null) return !_needsDescription;
    if (_attachment != null) return true;
    return _controller.text.trim().isNotEmpty;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _attachment = StagedAttachment(
        PlatformFile(
          name: picked.name,
          size: bytes.length,
          bytes: bytes,
          path: kIsWeb ? null : picked.path,
        ),
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt', 'log', 'zip'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _attachment = StagedAttachment(result.files.single);
    });
  }

  void _showAttachSheet(BuildContext context) {
    // Resolve the strings NOW: the dropdown lives in the app overlay and can
    // rebuild after this widget's context is defunct (e.g. the file-picker
    // round trip). Localizations.of on a dead context returns null in release
    // builds, which broke the attach menu with a null-check error.
    final i18n = context.i18n;
    showDropdown(
      context: context,
      builder: (c) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.image),
            onPressed: (_) async {
              await _pickImage();
            },
            child: Text(i18n.attachImage),
          ),
          MenuButton(
            leading: const Icon(LucideIcons.fileText),
            onPressed: (_) async {
              await _pickFile();
            },
            child: Text(i18n.attachDocument),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final userText = _controller.text.trim();
    final attachment = _attachment;
    final pinned = _pinnedContext;
    // The rider's words first, the machine-readable result last: support
    // reads the top of a chat, and the bundle line is what gets grepped.
    final body = pinned == null ? userText : '$userText\n\n$pinned';
    final preservedText = userText;
    final preservedAttachment = attachment;
    setState(() {
      _controller.clear();
      _attachment = null;
      _pinnedContext = null;
    });
    try {
      await widget.onSend(body, attachment);
    } catch (_) {
      // Terminal on purpose: the page-level handlers already reported and
      // toasted this failure; their rethrow only exists so we know to restore
      // the composer. Rethrowing again would escape into the zone as an
      // unhandled error (the button drops the returned Future) and get logged
      // as an app crash.
      if (!mounted) return;
      setState(() {
        _controller.text = preservedText;
        _attachment = preservedAttachment;
        _pinnedContext = pinned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDiagnostic = (widget.diagnosticPreview ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(top: BorderSide(color: cs.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GDPR transparency: telemetry is attached to every support message
          // and a screenshot is pre-staged on the first one. Say so here rather
          // than sending it silently — the ⓘ button and the attachment chip
          // both let the user inspect/remove before sending.
          if (hasDiagnostic) _diagnosticsNotice(cs),
          if (_pinnedContext != null) _pinnedContextChip(cs),
          if (_attachment != null) _stagedAttachmentChip(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Builder(
                builder: (context) {
                  return IconButton.ghost(
                    icon: const Icon(LucideIcons.paperclip, size: 20),
                    onPressed: widget.sending ? null : () => _showAttachSheet(context),
                  );
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextArea(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: Text(
                    _pinnedContext != null
                        ? context.i18n.supportDescribeProblemPlaceholder
                        : context.i18n.messageComposerPlaceholder,
                  ),
                  expandableHeight: true,
                  initialHeight: 56,
                ),
              ),
              const SizedBox(width: 8),
              if (hasDiagnostic) ...[
                _diagnosticPreview(cs),
                const SizedBox(width: 8),
              ],
              IconButton.primary(
                icon: widget.sending ? const SmallProgressIndicator() : const Icon(LucideIcons.send, size: 18),
                onPressed: _canSend ? () => unawaited(_submit()) : null,
              ),
            ],
          ),
          // Only while the description is what's holding the send back: once
          // it is long enough the hint would just be nagging.
          if (!widget.sending && _needsDescription)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.i18n.supportDescribeProblemHint,
                style: TextStyle(fontSize: 11, color: cs.mutedForeground, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  /// Display-only: the pinned result cannot be removed, that is the point.
  /// Same muted styling as the attachment chip so the two read as one row
  /// of "things going out with this message".
  Widget _pinnedContextChip(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.muted.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.clipboardCheck, size: 16, color: cs.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.i18n.supportPinnedContextChip(widget.pinnedContextLabel!),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.mutedForeground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnosticsNotice(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, size: 13, color: cs.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.i18n.supportDiagnosticsNotice,
                  style: TextStyle(fontSize: 11, color: cs.mutedForeground, height: 1.3),
                ),
                Button.text(
                  onPressed: () => launchUrlString('https://bikecontrol.app/privacy-policy'),
                  child: Text(context.i18n.privacyPolicy).xSmall.muted.underline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticPreview(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.muted.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Button.outline(
        style: ButtonStyle.outlineIcon(),
        child: Icon(LucideIcons.info),
        // The payload includes the full log buffer, so it can be far taller
        // than the screen: cap the sheet height (keeps the dismiss barrier
        // reachable) and scroll the payload instead of overflowing.
        onPressed: () => openSheet(
          context: context,
          draggable: true,
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          builder: (c) => Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text("${context.i18n.diagnosticInfoAttached}:")),
                    IconButton.ghost(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => closeSheet(c),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      widget.diagnosticPreview!,
                      style: TextStyle(fontSize: 11, color: cs.mutedForeground, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          position: OverlayPosition.bottom,
        ),
      ),
    );
  }

  Widget _stagedAttachmentChip() {
    final att = _attachment!;
    final cs = Theme.of(context).colorScheme;
    Widget? preview;
    if (att.isImage) {
      if (att.file.bytes != null) {
        preview = Image.memory(att.file.bytes!, height: 36, width: 36, fit: BoxFit.cover);
      } else if (att.file.path != null) {
        preview = Image.file(File(att.file.path!), height: 36, width: 36, fit: BoxFit.cover);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.muted.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        child: Row(
          children: [
            if (preview != null) ...[
              ClipRRect(borderRadius: BorderRadius.circular(4), child: preview),
              const SizedBox(width: 8),
            ] else ...[
              Icon(LucideIcons.fileText, size: 16, color: cs.mutedForeground),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                att.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            IconButton.ghost(
              icon: const Icon(LucideIcons.x, size: 14),
              onPressed: widget.sending ? null : () => setState(() => _attachment = null),
            ),
          ],
        ),
      ),
    );
  }
}
