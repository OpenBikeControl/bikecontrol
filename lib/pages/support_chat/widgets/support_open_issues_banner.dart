import 'package:bike_control/services/support_chat_models.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SupportOpenIssuesBanner extends StatelessWidget {
  final List<SupportIssue> issues;

  const SupportOpenIssuesBanner({super.key, required this.issues});

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(LucideIcons.triangleAlert, size: 14, color: cs.mutedForeground),
                const Gap(6),
                Text(
                  context.i18n.knownIssues,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.mutedForeground,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          for (final issue in issues)
            Button.ghost(
              onPressed: () => launchUrlString(
                'https://bikecontrol.app/issues/${issue.id}',
                mode: LaunchMode.externalApplication,
              ),
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        issue.title,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(8),
                    Icon(LucideIcons.externalLink, size: 12, color: cs.mutedForeground),
                  ],
                ),
              ),
            ),
          const Gap(6),
        ],
      ),
    );
  }
}
