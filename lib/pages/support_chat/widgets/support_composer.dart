import 'dart:io' show File;

import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

  const SupportComposer({
    super.key,
    required this.sending,
    required this.onSend,
    this.diagnosticPreview,
  });

  @override
  State<SupportComposer> createState() => _SupportComposerState();
}

class _SupportComposerState extends State<SupportComposer> {
  final TextEditingController _controller = TextEditingController();
  StagedAttachment? _attachment;
  bool _diagnosticExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (widget.sending) return false;
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
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt'],
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _attachment = StagedAttachment(result.files.single);
    });
  }

  void _showAttachSheet() {
    showDropdown(
      context: context,
      builder: (c) => DropdownMenu(
        children: [
          MenuButton(
            leading: const Icon(LucideIcons.image),
            onPressed: (_) async {
              await _pickImage();
            },
            child: Text(context.i18n.attachImage),
          ),
          MenuButton(
            leading: const Icon(LucideIcons.fileText),
            onPressed: (_) async {
              await _pickFile();
            },
            child: Text(context.i18n.attachDocument),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final body = _controller.text.trim();
    final attachment = _attachment;
    final preservedText = body;
    final preservedAttachment = attachment;
    setState(() {
      _controller.clear();
      _attachment = null;
      _diagnosticExpanded = false;
    });
    try {
      await widget.onSend(body, attachment);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller.text = preservedText;
        _attachment = preservedAttachment;
      });
      rethrow;
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
          if (hasDiagnostic) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _diagnosticPreview(cs),
            ),
            const SizedBox(height: 8),
          ],
          if (_attachment != null) _stagedAttachmentChip(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Builder(
                builder: (context) {
                  return IconButton.ghost(
                    icon: const Icon(LucideIcons.paperclip, size: 20),
                    onPressed: widget.sending ? null : _showAttachSheet,
                  );
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextArea(
                  controller: _controller,
                  placeholder: Text(context.i18n.messageComposerPlaceholder),
                  expandableHeight: true,
                  initialHeight: 56,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.primary(
                icon: widget.sending ? const SmallProgressIndicator() : const Icon(LucideIcons.send, size: 18),
                onPressed: _canSend ? _submit : null,
              ),
            ],
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Button.outline(
            onPressed: () => setState(() => _diagnosticExpanded = !_diagnosticExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.fileText, size: 14, color: cs.mutedForeground),
                  const SizedBox(width: 8),
                  Text(
                    context.i18n.diagnosticInfoAttached,
                    style: TextStyle(fontSize: 12, color: cs.mutedForeground, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _diagnosticExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 14,
                    color: cs.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (_diagnosticExpanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SelectableText(
                  widget.diagnosticPreview!,
                  style: TextStyle(fontSize: 11, color: cs.mutedForeground, fontFamily: 'monospace'),
                ),
              ),
            ),
        ],
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
