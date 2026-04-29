import 'dart:io' show Platform;

import 'package:bike_control/pages/support_chat/widgets/support_attachment_view.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_review/in_app_review.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Magic admin-message body that the backend sends to nudge a happy user
/// toward leaving a store rating. The bubble swaps it for a localised
/// thank-you sentence + an in-app rating button instead of rendering the
/// raw token.
const String _kSuccessRatingToken = 'success_rating';

/// Renders a single chat message as a shadcn [ChatBubble]. Designed to be
/// nested inside a [ChatGroup] (see [SupportMessageGroup]) so that runs of
/// consecutive same-sender messages share one avatar.
class SupportMessageBubble extends StatelessWidget {
  final SupportMessage message;
  final SupportChatService service;
  final int replyCount;
  final VoidCallback? onReply;
  final bool pending;

  /// Hide the per-message sender label. Set on every bubble after the first
  /// in a [ChatGroup] so we don't repeat "You" / "Support" on each line.
  final bool showSenderLabel;

  const SupportMessageBubble({
    super.key,
    required this.message,
    required this.service,
    this.replyCount = 0,
    this.onReply,
    this.pending = false,
    this.showSenderLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.senderRole == SupportMessageSenderRole.user;
    final alignment = isUser ? AxisAlignmentDirectional.end : AxisAlignmentDirectional.start;
    final bubbleColor = isUser ? cs.primary.withAlpha(38) : cs.secondary;
    final isRatingPrompt = !isUser && message.body == _kSuccessRatingToken;
    final renderedBody = isRatingPrompt
        ? context.i18n.successRatingMessage(_storeName())
        : message.body;

    return ChatBubble(
      alignment: alignment,
      color: bubbleColor,
      widthFactor: 0.85,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: cs.foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSenderLabel)
              Text(
                isUser ? context.i18n.senderYou : 'Jonas @ BikeControl',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isUser ? cs.primary : cs.mutedForeground,
                ),
              ),
            if (renderedBody.isNotEmpty) ...[
              if (showSenderLabel) const SizedBox(height: 4),
              Text(renderedBody, style: const TextStyle(fontSize: 14)),
            ],
            if (isRatingPrompt) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                onPressed: _openRating,
                leading: const Icon(LucideIcons.star, size: 14),
                child: Text(context.i18n.rateBikeControl),
              ),
            ],
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final att in message.attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SupportAttachmentView(attachment: att, service: service),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(message.createdAt),
                  style: TextStyle(fontSize: 10, color: cs.mutedForeground),
                ),
                if (pending) ...[
                  const SizedBox(width: 6),
                  Icon(LucideIcons.clock, size: 10, color: cs.mutedForeground),
                ],
              ],
            ),
            if (onReply != null && !isRatingPrompt) ...[
              const SizedBox(height: 4),
              Button.ghost(
                onPressed: onReply,
                leading: const Icon(LucideIcons.cornerUpLeft, size: 12),
                child: Text(
                  replyCount > 0 ? context.i18n.replyCount(replyCount) : context.i18n.viewThread,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Platform-specific store name shown in the rating prompt copy. Web and
  /// Linux fall back to "App Store" since they don't have a native store flow.
  String _storeName() {
    if (kIsWeb) return 'App Store';
    if (Platform.isIOS || Platform.isMacOS) return 'App Store';
    if (Platform.isAndroid) return 'Play Store';
    if (Platform.isWindows) return 'Microsoft Store';
    return 'App Store';
  }

  /// Triggers the platform's in-app review sheet, falling back to the store
  /// listing when the in-app sheet isn't available (e.g. simulator, browser).
  Future<void> _openRating() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    } else {
      await review.openStoreListing(
        appStoreId: 'id6753721284',
        microsoftStoreId: '9NP42GS03Z26',
      );
    }
  }

  String _formatTimestamp(DateTime utc) {
    final local = utc.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (isToday) return '$hh:$mm';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}
