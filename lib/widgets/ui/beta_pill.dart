import 'package:shadcn_flutter/shadcn_flutter.dart';

class BetaPill extends StatelessWidget {
  final String text;
  const BetaPill({super.key, this.text = 'BETA'});

  @override
  Widget build(BuildContext context) {
    return DestructiveBadge(child: Text(text));
  }
}
