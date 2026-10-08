import 'package:shadcn_flutter/shadcn_flutter.dart';

/// "BETA" (or "EXPER.") beside something not finished yet. Information, not
/// a warning: a neutral badge, so it never reads as an error.
class BetaPill extends StatelessWidget {
  final String text;
  const BetaPill({super.key, this.text = 'BETA'});

  @override
  Widget build(BuildContext context) {
    return SecondaryBadge(child: Text(text));
  }
}
