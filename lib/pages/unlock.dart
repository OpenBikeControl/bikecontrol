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

    /*Future.delayed(Duration(seconds: 5), () {
      emulator.waiting.value = true;

      Future.delayed(Duration(seconds: 3), () {
        propPrefs.setZwiftClickV2LastUnlock(widget.device.device.deviceId, DateTime.now());
        emulator.isUnlocked.value = true;
      });
    });*/

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
              AppLocalizations.of(context).unlock_yourTrialPhaseHasExpired,
            )
          else if (_showManualSteps) ...[
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
            ),
            SizedBox(height: 32),
            Button.primary(
              child: Text(AppLocalizations.of(context).unlock_markAsUnlocked),
              onPressed: () {
                propPrefs.setZwiftClickV2LastUnlock(widget.device.scanResult.deviceId, DateTime.now());
                closeDrawer(context);
              },
            ),
          ] else if (!emulator.isConnected.value) ...[
            Text(AppLocalizations.of(context).unlock_openZwift).li,
            Text(AppLocalizations.of(context).unlock_connectToBikecontrol).li,
            SizedBox(height: 32),
            Text(AppLocalizations.of(context).unlock_bikecontrolAndZwiftNetwork).small,
          ] else if (emulator.alreadyUnlocked.value) ...[
            Text(AppLocalizations.of(context).unlock_yourZwiftClickMightBeUnlockedAlready),
            SizedBox(height: 8),
            Text(AppLocalizations.of(context).unlock_confirmByPressingAButtonOnYourDevice).small,
          ] else if (!emulator.isUnlocked.value)
            Text(AppLocalizations.of(context).unlock_waitingForZwift)
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
              Center(child: Text(AppLocalizations.of(context).unlock_notWorking).small),
            ],
            SizedBox(height: 6),
            Center(
              child: Button.secondary(
                onPressed: () {
                  setState(() {
                    _showManualSteps = !_showManualSteps;
                  });
                },
                child: Text(AppLocalizations.of(context).unlock_unlockManually),
              ),
            ),
          ],
          SizedBox(height: 20),
        ],
      ),
    );
  }

  void _close() {
    final title = AppLocalizations.of(context).unlock_isnowunlocked(widget.device.toString());

    final subtitle = AppLocalizations.of(context).unlock_youCanNowCloseZwift;
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
