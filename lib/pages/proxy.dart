import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ProxyPage extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onUpdate;
  const ProxyPage({
    super.key,
    required this.onUpdate,
    required this.isMobile,
  });

  @override
  State<ProxyPage> createState() => _DevicePageState();
}

class _DevicePageState extends State<ProxyPage> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = core.connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...core.connection.proxyDevices
            .sortedBy((e) => e.isConnected ? 0 : 1)
            .mapIndexed(
              (index, device) => [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    bottom: index == core.connection.proxyDevices.length - 1 ? 8 : 12.0,
                    top: index == 0 ? 8 : 0,
                  ),
                  child: Button.ghost(
                    onPressed: () async {
                      if (!device.emulator.isStarted.value && !device.isStarting.value) {
                        if (IAPManager.instance.isTrialExpired) {
                          await showGoProDialog(context);
                          return;
                        }
                        final savedMode = core.settings.getRetrofitMode(
                          device.trainerKey,
                          fallback: device.defaultRetrofitMode,
                        );
                        device.emulator.setRetrofitMode(savedMode);
                        await core.settings.setAutoConnect(device.trainerKey, true);
                        // Fire-and-forget — details page opens immediately and
                        // renders a "Connecting…" state via device.isStarting.
                        unawaited(device.startProxy().catchError((_) {}));
                      }
                      if (!context.mounted) return;
                      await context.push(ProxyDeviceDetailsPage(device: device));
                      widget.onUpdate();
                    },
                    child: device.showInformation(context, showFull: false),
                  ),
                ),
                if (index != core.connection.proxyDevices.length - 1)
                  Divider(
                    thickness: 0.5,
                  ),
              ],
            )
            .flatten(),
        ValueListenableBuilder<bool>(
          valueListenable: core.connection.isScanning,
          builder: (context, scanning, _) {
            if (!scanning || core.connection.proxyDevices.isNotEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Text(
                    context.i18n.lookingForSmartTrainers,
                    style: TextStyle(fontSize: 12, color: cs.mutedForeground),
                  ),
                  SizedBox(width: 10, height: 10, child: SmallProgressIndicator(color: cs.mutedForeground)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
