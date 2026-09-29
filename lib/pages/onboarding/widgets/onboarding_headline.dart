import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A wizard screen's headline: upper-case, in the display face
/// ("YOUR CONTROLLER IS READY"). Announced as a heading, in the words'
/// own case so screen readers don't spell it out.
class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Text(text.toUpperCase(), textAlign: textAlign, style: BkDisplay.headline(context)),
    );
  }
}

/// The accent line over a step's headline: which step this is and what it
/// is for ("Controller · Find and connect").
class OnboardingEyebrow extends StatelessWidget {
  const OnboardingEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.typography.small.copyWith(
        fontWeight: FontWeight.w600,
        color: bkAccentText(context),
      ),
    );
  }
}
