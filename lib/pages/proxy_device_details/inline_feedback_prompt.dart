import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/trainer_feedback.dart';
import 'package:bike_control/services/trainer_feedback_service.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class InlineFeedbackPrompt extends StatefulWidget {
  final ProxyDevice device;
  const InlineFeedbackPrompt({super.key, required this.device});

  @override
  State<InlineFeedbackPrompt> createState() => _InlineFeedbackPromptState();
}

class _InlineFeedbackPromptState extends State<InlineFeedbackPrompt> {
  bool _dismissed = false;

  Future<void> _openForm(TrainerFeedbackRating rating) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerFeedbackPage(
          device: widget.device,
          initialRating: rating,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageSquare, size: 16),
              const Gap(8),
              Text(l10n.feedbackQuestion).semiBold,
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Button.outline(
                  onPressed: () => _openForm(TrainerFeedbackRating.works),
                  leading: const Icon(LucideIcons.thumbsUp, size: 14),
                  child: Text(l10n.yes),
                ),
              ),
              Expanded(
                child: Button.ghost(
                  onPressed: () => setState(() => _dismissed = true),
                  child: Text(l10n.feedbackNoDifference).muted,
                ),
              ),
              Expanded(
                child: Button.outline(
                  onPressed: () => _openForm(TrainerFeedbackRating.doesNotWork),
                  leading: const Icon(LucideIcons.thumbsDown, size: 14),
                  child: Text(l10n.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
