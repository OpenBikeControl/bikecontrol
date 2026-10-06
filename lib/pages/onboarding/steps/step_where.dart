import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_headline.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_note.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget _whereTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String desc,
  required String implies,
  required bool selected,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Button.ghost(
    style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
    onPressed: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: selected ? onboardingAccent(context) : const Color(0x00000000), width: 2),
        borderRadius: BorderRadius.circular(16),
        color: scheme.card,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? onboardingAccent(context) : scheme.muted,
          ),
          child: Icon(icon, size: 22, color: selected ? onboardingOnAccent(context) : null),
        ),
        Gap(13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title).semiBold),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? onboardingAccent(context) : null,
                  border: selected ? null : Border.all(color: scheme.border, width: 2),
                ),
                child: selected ? Icon(LucideIcons.check, size: 12, color: onboardingOnAccent(context)) : null,
              ),
            ]),
            Gap(5),
            Text(desc).xSmall.muted,
            Gap(10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: selected ? onboardingAccent(context).withValues(alpha: 0.09) : scheme.muted,
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(LucideIcons.arrowRight, size: 13, color: selected ? onboardingAccent(context) : scheme.mutedForeground),
                Gap(7),
                Expanded(child: Text(implies).xSmall),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  );
}

Widget onboardingWhereBody(BuildContext context,
    {required SupportedApp app, required Target? selected, required ValueChanged<Target> onSelect}) {
  String enables(Target t) =>
      onboardingWhereUsesLocal(t)
          ? context.i18n.onboardingWhereEnablesLocal(app.name)
          : context.i18n.onboardingWhereEnablesNetwork(app.name);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: onboardingReveal([
      OnboardingHeadline(context.i18n.onboardingWhereTitle(app.name)),
      Gap(6),
      Text(context.i18n.onboardingWhereSubtitle).small.muted,
      Gap(18),
      for (final target in Target.supportedFor(app)) ...[
        KeyedSubtree(
          key: ValueKey('onboarding-where-${target.name}'),
          child: _whereTile(
          context,
          icon: target.icon,
          title: target.getTitle(context),
          desc: target.getDescription(app),
          implies: enables(target),
          selected: selected == target,
          onTap: () => onSelect(target),
          ),
        ),
        Gap(10),
      ],
      Gap(4),
      OnboardingNote(context.i18n.onboardingWhereChangeLater, icon: LucideIcons.pencil),
    ]),
  );
}
