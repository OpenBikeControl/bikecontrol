import 'package:bike_control/pages/support_chat/widgets/support_message_bubble.dart';
import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/services/support_chat_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Reply / pending metadata for a single [SupportMessage] within a group.
class SupportMessageMeta {
  final int replyCount;
  final VoidCallback? onReply;
  final bool pending;

  const SupportMessageMeta({
    this.replyCount = 0,
    this.onReply,
    this.pending = false,
  });
}

/// Renders a run of consecutive same-sender messages as one shadcn
/// [ChatGroup]. Support-side groups get the OpenBikeControl avatar prefix;
/// user-side groups omit the prefix and right-align their bubbles. The first
/// bubble in the group keeps its sender label ("You" / "Support"); the
/// remaining bubbles drop it so the run reads as one block.
class SupportMessageGroup extends StatelessWidget {
  final List<SupportMessage> messages;
  final SupportChatService service;
  final Map<String, SupportMessageMeta> meta;

  const SupportMessageGroup({
    super.key,
    required this.messages,
    required this.service,
    this.meta = const {},
  });

  @override
  Widget build(BuildContext context) {
    assert(messages.isNotEmpty, 'SupportMessageGroup needs at least one message');
    final isUser = messages.first.senderRole == SupportMessageSenderRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: ChatGroup(
        avatarPrefix: isUser
            ? null
            : const Avatar(
                initials: 'OB',
                size: 38,
                provider: AssetImage('openbikecontrol.png'),
              ),
        children: [
          for (var i = 0; i < messages.length; i++)
            SupportMessageBubble(
              message: messages[i],
              service: service,
              replyCount: meta[messages[i].id]?.replyCount ?? 0,
              onReply: meta[messages[i].id]?.onReply,
              pending: meta[messages[i].id]?.pending ?? false,
              showSenderLabel: i == 0,
            ),
        ],
      ),
    );
  }
}

/// Splits [messages] into runs of consecutive same-sender messages, preserving
/// order. Used by the chat / thread pages to feed [SupportMessageGroup].
List<List<SupportMessage>> groupConsecutiveBySender(List<SupportMessage> messages) {
  final groups = <List<SupportMessage>>[];
  for (final m in messages) {
    if (groups.isEmpty || groups.last.last.senderRole != m.senderRole) {
      groups.add([m]);
    } else {
      groups.last.add(m);
    }
  }
  return groups;
}
