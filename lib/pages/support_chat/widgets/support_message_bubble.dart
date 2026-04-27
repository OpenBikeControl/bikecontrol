import 'package:bike_control/pages/support_chat/widgets/support_attachment_view.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
            if (message.body.isNotEmpty) ...[
              if (showSenderLabel) const SizedBox(height: 4),
              Text(message.body, style: const TextStyle(fontSize: 14)),
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
            if (onReply != null) ...[
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
