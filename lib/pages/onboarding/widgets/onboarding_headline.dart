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
