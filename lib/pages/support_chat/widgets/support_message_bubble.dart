import 'package:bike_control/pages/support_chat/widgets/support_attachment_view.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SupportMessageBubble extends StatelessWidget {
  final SupportMessage message;
  final SupportChatService service;
  final int replyCount;
  final VoidCallback? onReply;
  final bool pending;

  const SupportMessageBubble({
    super.key,
    required this.message,
    required this.service,
    this.replyCount = 0,
    this.onReply,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.senderRole == SupportMessageSenderRole.user;

    final alignment = isUser ? AxisAlignmentDirectional.end : AxisAlignmentDirectional.start;
    final bubbleColor = isUser ? cs.primary.withAlpha(38) : cs.card;

    final bubble = ChatBubble(
      alignment: alignment,
      color: bubbleColor,
      widthFactor: 0.85,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: cs.foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUser ? context.i18n.senderYou : context.i18n.senderAdmin,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isUser ? cs.primary : cs.mutedForeground,
              ),
            ),
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 4),
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
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatGroup(
            avatarPrefix: isUser
                ? null
                : const Avatar(
                    initials: 'OB',
                    size: 38,
                    provider: AssetImage('openbikecontrol.png'),
                  ),
            children: [bubble],
          ),
          if (onReply != null)
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                right: 4,
                left: isUser ? 4 : 46,
              ),
              child: Button.ghost(
                onPressed: onReply,
                leading: const Icon(LucideIcons.cornerUpLeft, size: 12),
                child: Text(
                  replyCount > 0 ? context.i18n.replyCount(replyCount) : context.i18n.viewThread,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
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
