import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Opt-in switch for the WHEELTOP keepalive experiment (see WheeltopProbe).
///
/// English-only on purpose: a temporary beta diagnostic driven through
/// support, expected to disappear once the TX status-frame reply is known.
class WheeltopProbeToggle extends StatefulWidget {
  const WheeltopProbeToggle({super.key});

  @override
  State<WheeltopProbeToggle> createState() => _WheeltopProbeToggleState();
}

class _WheeltopProbeToggleState extends State<WheeltopProbeToggle> {
  late bool _enabled = core.settings.getWheeltopProbeEnabled();

  void _onChanged(bool value) {
    setState(() => _enabled = value);
    core.settings.setWheeltopProbeEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(AppLocalizations.of(context).wheeltopKeepaliveTitle).small.semiBold),
            Switch(value: _enabled, onChanged: _onChanged),
          ],
        ),
        Text(AppLocalizations.of(context).wheeltopKeepaliveBody).xSmall,
      ],
    );
  }
}
