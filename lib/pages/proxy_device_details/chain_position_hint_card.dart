import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:intl/intl.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// "Move your chain to a middle gear": shown while [definition] says the
/// rider's real chain on the trainer has sat on a very big or very small gear
/// (see [FitnessBikeDefinition.chainPositionHint]). The grade physics assume a
/// middle gear (or the real chain the rider set), so with the chain far off it
/// every virtual gear feels wrong and nothing else on screen says why. Renders
/// nothing otherwise.
class ChainPositionHintCard extends StatelessWidget {
  const ChainPositionHintCard({super.key, required this.definition, required this.chainSet});

  final FitnessBikeDefinition definition;

  /// Whether the rider set their real chain ([ShiftingConfig.hasRealChain]).
  /// Not read off the definition's ratio: a chain set to 36/18 is 2:1 like
  /// the default.
  final bool chainSet;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([definition.chainPositionHint, definition.estimatedChainRatio]),
      builder: (context, _) {
        final hint = definition.chainPositionHint.value;
        final ratio = definition.estimatedChainRatio.value;
        if (hint == ChainPositionHint.none || ratio == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final format = NumberFormat('0.0', Localizations.localeOf(context).toString());
        final ratioText = format.format(ratio);
        // A rider who set their real chain gets told it moved off that, not
        // to go to a middle gear: the band is around their chain.
        final title = chainSet ? l10n.chainHintSetTitle : l10n.chainHintTitle;
        final body = chainSet
            ? l10n.chainHintSetBody(ratioText, format.format(definition.realChainRatio))
            : switch (hint) {
                ChainPositionHint.veryBigGear => l10n.chainHintVeryBigGear(ratioText),
                ChainPositionHint.verySmallGear => l10n.chainHintVerySmallGear(ratioText),
                ChainPositionHint.none => '',
              };
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.muted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Icon(LucideIcons.triangleAlert, color: BkStatusColors.of(context).warning, size: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(title, style: context.typography.small.copyWith(fontWeight: FontWeight.w600)),
                      Text(body, style: context.typography.xSmall.copyWith(color: cs.foreground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
