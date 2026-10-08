import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A [BkGroupedRow] with a switch: the whole row flips it. A Pro-only switch
/// wears the PRO badge until Pro is on, and asks for Pro before it flips.
class BkSwitchRow extends StatelessWidget {
  const BkSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onToggle,
    this.subtitle,
    this.proOnly = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;

  /// Flips the setting. Only called once Pro is granted, for [proOnly].
  final VoidCallback onToggle;

  final bool proOnly;

  Future<void> _press(BuildContext context) async {
    if (proOnly && !await IAPManager.instance.ensureProForFeature(context)) return;
    onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return BkGroupedRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      badge: proOnly && !IAPManager.instance.isProEnabled ? const ProBadge() : null,
      trailing: Switch(value: value, onChanged: (_) => _press(context)),
      onPressed: () => _press(context),
    );
  }
}
