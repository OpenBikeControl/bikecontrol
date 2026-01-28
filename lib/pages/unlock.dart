import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/ui/warning.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/src/scheduler/ticker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../widgets/ui/small_progress_indicator.dart';

class UnlockPage extends StatefulWidget {
  final ZwiftClickV2 device;
  const UnlockPage({super.key, required this.device});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> with SingleTickerProviderStateMixin {
  late final bool _wasZwiftMdnsEmulatorActive;
  late final bool _wasObpMdnsEmulatorActive;
  bool _showManualSteps = false;

  late final bool _isInTrialPhase;

  late final Ticker _ticker;

  int _secondsRemaining = 60;

  void _isConnectedUpdate() {
    setState(() {});
    if (emulator.isUnlocked.value) {
      _close();
    }
  }

  @override
  void initState() {
    super.initState();
    _isInTrialPhase = !IAPManager.instance.isPurchased.value && IAPManager.instance.isTrialExpired;

    _ticker = createTicker((_) {
      if (emulator.waiting.value) {
        final waitUntil = emulator.connectionDate!.add(Duration(minutes: 1));
        final secondsUntil = waitUntil.difference(DateTime.now()).inSeconds;

        if (mounted) {
          _secondsRemaining = secondsUntil;
          setState(() {});
        }
      }
    })..start();

    _wasZwiftMdnsEmulatorActive = core.zwiftMdnsEmulator.isStarted.value;
    _wasObpMdnsEmulatorActive = core.obpMdnsEmulator.isStarted.value;
    if (!_isInTrialPhase) {
      if (_wasZwiftMdnsEmulatorActive) {
        core.zwiftMdnsEmulator.stop();
        core.settings.setZwiftMdnsEmulatorEnabled(false);
      }
      if (_wasObpMdnsEmulatorActive) {
        core.obpMdnsEmulator.stopServer();
        core.settings.setObpMdnsEnabled(false);
      }

      emulator.isUnlocked.value = false;
      emulator.alreadyUnlocked.value = false;
      emulator.waiting.value = false;
      emulator.isConnected.addListener(_isConnectedUpdate);
      emulator.isUnlocked.addListener(_isConnectedUpdate);
      emulator.alreadyUnlocked.addListener(_isConnectedUpdate);
      emulator.startServer().then((_) {}).catchError((e, s) {
        recordError(e, s, context: 'Emulator');
        core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, e.toString()));
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (!_isInTrialPhase) {
      emulator.isConnected.removeListener(_isConnectedUpdate);
      emulator.isUnlocked.removeListener(_isConnectedUpdate);
      emulator.alreadyUnlocked.removeListener(_isConnectedUpdate);
      emulator.stop();

      if (_wasZwiftMdnsEmulatorActive) {
        core.zwiftMdnsEmulator.startServer();
        core.settings.setZwiftMdnsEmulatorEnabled(true);
      }
      if (_wasObpMdnsEmulatorActive) {
        core.obpMdnsEmulator.startServer();
        core.settings.setObpMdnsEnabled(true);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isInTrialPhase && !_showManualSteps)
            Text(
              'Your trial phase has expired. Please purchase the full version to unlock the comfortable unlocking feature :)',
            )
          else if (_showManualSteps)
            Warning(
              children: [
                Text(
                  'Important Setup Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                ).small,
                Text(
                  AppLocalizations.of(context).clickV2Instructions,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.destructive,
                  ),
                ).xSmall,
                if (kDebugMode)
                  GhostButton(
                    onPressed: () {
                      widget.device.sendCommand(Opcode.RESET, null);
                    },
                    child: Text('Reset now'),
                  ),

                Button.secondary(
                  onPressed: () {
                    openDrawer(
                      context: context,
                      position: OverlayPosition.bottom,
                      builder: (_) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                    );
                  },
                  leading: const Icon(Icons.help_outline_outlined),
                  child: Text(context.i18n.instructions),
                ),
              ],
            )
          else if (!emulator.isConnected.value) ...[
            Text('Open Zwift (not the Companion) on this or another device').li,
            Text('Connect to "BikeControl" as Power Source.').li,
            SizedBox(height: 32),
            Text('BikeControl and Zwift need to be on the same network. It may take a few seconds to appear.').small,
          ] else if (emulator.alreadyUnlocked.value) ...[
            Text('Your Zwift Click might be unlocked already.'),
            SizedBox(height: 8),
            Text('Confirm by pressing a button on your device.').small,
          ] else if (!emulator.isUnlocked.value)
            Text('Waiting for Zwift to unlock your device...')
          else
            Text('Zwift Click is unlocked! You can now close this page.'),
          SizedBox(height: 32),
          if (!_showManualSteps && !_isInTrialPhase) ...[
            if (emulator.waiting.value && _secondsRemaining >= 0)
              Center(child: CircularProgressIndicator(value: 1 - (_secondsRemaining / 60), size: 20))
            else if (emulator.alreadyUnlocked.value)
              Center(child: Icon(Icons.lock_clock))
            else
              SmallProgressIndicator(),
            SizedBox(height: 20),
          ],
          if (!emulator.isUnlocked.value && !_showManualSteps) ...[
            if (!_isInTrialPhase) ...[
              SizedBox(height: 32),
              Center(child: Text('Not working?').small),
            ],
            SizedBox(height: 6),
            Center(
              child: Button.secondary(
                onPressed: () {
                  setState(() {
                    _showManualSteps = !_showManualSteps;
                  });
                },
                child: Text('Unlock manually'),
              ),
            ),
          ],
          SizedBox(height: 20),
        ],
      ),
    );
  }

  void _close() {
    final title = '${widget.device.toString()} is now unlocked';

    final subtitle = 'You can now close Zwift and return to BikeControl.';
    core.connection.signalNotification(
      AlertNotification(LogLevel.LOGLEVEL_INFO, title),
    );

    core.flutterLocalNotificationsPlugin.show(
      1339,
      title,
      subtitle,
      NotificationDetails(
        android: AndroidNotificationDetails('Unlocked', 'Device unlocked notification'),
        iOS: DarwinNotificationDetails(presentAlert: true),
      ),
    );
    closeDrawer(context);
  }
}
