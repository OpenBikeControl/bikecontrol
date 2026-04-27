import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Renders one attachment. Lazily resolves a signed URL via the service and
/// caches it across rebuilds; image MIMEs render an inline preview, others
/// render a chip that opens the file in an external viewer.
class SupportAttachmentView extends StatefulWidget {
  final SupportAttachment attachment;
  final SupportChatService service;
  final double? maxImageHeight;

  const SupportAttachmentView({
    super.key,
    required this.attachment,
    required this.service,
    this.maxImageHeight = 220,
  });

  @override
  State<SupportAttachmentView> createState() => _SupportAttachmentViewState();
}

class _SupportAttachmentViewState extends State<SupportAttachmentView> {
  static final Map<String, _CachedSignedUrl> _cache = {};
  static const Duration _safetyMargin = Duration(seconds: 30);
  static const Duration _ttl = Duration(seconds: 300);

  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _urlFuture = _resolveUrl();
  }

  Future<String> _resolveUrl() async {
    final cached = _cache[widget.attachment.storagePath];
    final now = DateTime.now();
    if (cached != null && cached.expiresAt.isAfter(now.add(_safetyMargin))) {
      return cached.url;
    }
    final url = await widget.service.signedAttachmentUrl(widget.attachment.storagePath);
    _cache[widget.attachment.storagePath] = _CachedSignedUrl(
      url: url,
      expiresAt: now.add(_ttl),
    );
    return url;
  }

  bool get _isImage => widget.attachment.mimeType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SmallProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _chip(context, onTap: null, error: true);
        }
        final url = snapshot.data!;
        if (_isImage) {
          return GestureDetector(
            onTap: () => launchUrlString(url),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxImageHeight ?? 220),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _chip(context, onTap: () => launchUrlString(url)),
                ),
              ),
            ),
          );
        }
        return _chip(context, onTap: () => launchUrlString(url));
      },
    );
  }

  Widget _chip(BuildContext context, {VoidCallback? onTap, bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.muted.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error ? LucideIcons.fileWarning : LucideIcons.paperclip,
              size: 14,
              color: cs.mutedForeground,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.attachment.fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedSignedUrl {
  final String url;
  final DateTime expiresAt;
  const _CachedSignedUrl({required this.url, required this.expiresAt});
}
