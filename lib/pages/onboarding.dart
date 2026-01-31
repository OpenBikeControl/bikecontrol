import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_ble_tile.dart';
import 'package:bike_control/widgets/apps/openbikecontrol_mdns_tile.dart';
import 'package:bike_control/widgets/scan.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:bike_control/widgets/ui/permissions_list.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../utils/i18n_extension.dart';
import '../widgets/ui/colored_title.dart';
import 'configuration.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _OnboardingStep {
  permissions,
  connect,
  trainer,
  openbikecontrol,
  finish,
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _currentStep = _OnboardingStep.permissions;

  bool _isMobile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _isMobile = MediaQuery.sizeOf(context).width < 600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      loadingProgress: _OnboardingStep.values.indexOf(_currentStep) / (_OnboardingStep.values.length - 1),
      headers: [
        AppBar(
          backgroundColor: Theme.of(context).colorScheme.primaryForeground,
          leading: [
            Image.asset('icon.png', height: 40),
            SizedBox(width: 10),
            AppTitle(),
          ],
          trailing: [
            Button(
              style: ButtonStyle.outline(size: ButtonSize.small),
              child: Text(AppLocalizations.of(context).skip),
              onPressed: () {
                core.settings.setShowOnboarding(false);
                widget.onComplete();
              },
            ),
          ],
        ),
        Divider(),
      ],
      floatingFooter: true,
      footers: [
        Center(
          child: HelpButton(
            isMobile: true,
          ),
        ),
      ],
      child: Center(
        child: Container(
          alignment: Alignment.topCenter,
          constraints: !_isMobile ? BoxConstraints(maxWidth: 500) : null,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: !_isMobile ? 42 : 22.0, bottom: !_isMobile ? 42 : 68.0, left: 16, right: 16),
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: 600),
              child: switch (_currentStep) {
                _OnboardingStep.permissions => _PermissionsOnboardingStep(
                  onComplete: () {
                    setState(() {
                      _currentStep = _OnboardingStep.connect;
                    });
                  },
                ),
                _OnboardingStep.connect => _ConnectOnboardingStep(
                  onComplete: () {
                    setState(() {
                      _currentStep = _OnboardingStep.trainer;
                    });
                  },
                ),
                _OnboardingStep.trainer => _TrainerOnboardingStep(
                  onComplete: () {
                    setState(() {
                      if (core.settings.getTrainerApp()?.supportsOpenBikeProtocol.contains(
                            OpenBikeProtocolSupport.network,
                          ) ??
                          false) {
                        _currentStep = _OnboardingStep.openbikecontrol;
                      } else {
                        _currentStep = _OnboardingStep.finish;
                      }
                    });
                  },
                ),
                _OnboardingStep.finish => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 12,
                  children: [
                    SizedBox(height: 30),
                    Icon(Icons.check_circle, size: 58, color: Colors.green),
                    ColoredTitle(text: AppLocalizations.of(context).setupComplete),
                    if (core.obpMdnsEmulator.connectedApp.value == null)
                      Text(
                        AppLocalizations.of(
                          context,
                        ).asAFinalStepYoullChooseHowToConnectTo(core.settings.getTrainerApp()?.name ?? 'your trainer'),
                        textAlign: TextAlign.center,
                      ).small.muted,

                    SizedBox(height: 30),
                    PrimaryButton(
                      leading: Icon(Icons.check),
                      onPressed: () {
                        core.settings.setShowOnboarding(false);
                        widget.onComplete();
                      },
                      child: Text(context.i18n.continueAction),
                    ),
                  ],
                ),
                _OnboardingStep.openbikecontrol => _OpenBikeControlConnectPage(
                  onComplete: () {
                    setState(() {
                      _currentStep = _OnboardingStep.finish;
                    });
                  },
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionsOnboardingStep extends StatefulWidget {
  final VoidCallback onComplete;
  const _PermissionsOnboardingStep({super.key, required this.onComplete});

  @override
  State<_PermissionsOnboardingStep> createState() => _PermissionsOnboardingStepState();
}

class _PermissionsOnboardingStepState extends State<_PermissionsOnboardingStep> {
  void _checkRequirements() {
    core.permissions.getScanRequirements().then((permissions) {
      if (!mounted) return;
      setState(() {
        _needsPermissions = permissions;
      });
      if (permissions.isEmpty) {
        widget.onComplete();
      }
    });
  }

  List<PlatformRequirement>? _needsPermissions;

  @override
  void initState() {
    super.initState();
    _checkRequirements();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 8),
        Text(AppLocalizations.of(context).letsGetYouSetUp).h3,
        if (_needsPermissions != null && _needsPermissions!.isNotEmpty)
          PermissionList(
            requirements: _needsPermissions!,
            onDone: () {
              widget.onComplete();
            },
          ),
      ],
    );
  }
}

class _ConnectOnboardingStep extends StatefulWidget {
  final VoidCallback onComplete;
  const _ConnectOnboardingStep({super.key, required this.onComplete});

  @override
  State<_ConnectOnboardingStep> createState() => _ConnectOnboardingStepState();
}

class _ConnectOnboardingStepState extends State<_ConnectOnboardingStep> {
  late StreamSubscription<BaseDevice> _connectionStateSubscription;
  late StreamSubscription<BaseNotification> _actionSubscription;

  @override
  void initState() {
    super.initState();

    _actionSubscription = core.connection.actionStream.listen((data) async {
      setState(() {});
      if (data is ButtonNotification) {
        widget.onComplete();
      }
    });
    _connectionStateSubscription = core.connection.connectionStream.listen((state) async {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _actionSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        ColoredTitle(text: context.i18n.connectControllers),
        if (core.connection.controllerDevices.isEmpty) ...[
          ScanWidget(),

          OutlineButton(
            onPressed: () {
              launchUrlString('https://github.com/OpenBikeControl/bikecontrol/?tab=readme-ov-file#supported-devices');
            },
            leading: Icon(Icons.gamepad_outlined),
            child: Text(context.i18n.showSupportedControllers),
          ),
          PrimaryButton(
            leading: Icon(Icons.computer_outlined),
            onPressed: () {
              widget.onComplete();
            },
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: "${AppLocalizations.of(context).noControllerUseCompanionMode.split("?").first}?\n"),
                  TextSpan(
                    text: AppLocalizations.of(context).noControllerUseCompanionMode.split("? ").last,
                    style: TextStyle(color: Theme.of(context).colorScheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          if (core.connection.controllerDevices.any((d) => d.isConnected && d is ZwiftDevice))
            RepeatedAnimationBuilder<double>(
              duration: Duration(seconds: 1),
              start: 0.5,
              end: 1.0,
              curve: Curves.easeInOut,
              mode: LoopingMode.pingPong,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    AppLocalizations.of(context).controllerConnectedClickButton,
                  ).small,
                );
              },
            ),
          SizedBox(),
          ...core.connection.controllerDevices.map(
            (device) => device.showInformation(context),
          ),
          if (core.connection.controllerDevices.any((d) => d.isConnected))
            PrimaryButton(
              leading: Icon(Icons.check),
              onPressed: () {
                widget.onComplete();
              },
              child: Text(context.i18n.continueAction),
            ),
          SizedBox(),
        ],
      ],
    );
  }
}

class _TrainerOnboardingStep extends StatefulWidget {
  final VoidCallback onComplete;
  const _TrainerOnboardingStep({super.key, required this.onComplete});

  @override
  State<_TrainerOnboardingStep> createState() => _TrainerOnboardingStepState();
}

class _TrainerOnboardingStepState extends State<_TrainerOnboardingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        SizedBox(),
        ConfigurationPage(
          onboardingMode: true,
          onUpdate: () {
            setState(() {});
          },
        ),
        if (core.settings.getTrainerApp() != null) SizedBox(height: 20),
        if (core.settings.getTrainerApp() != null)
          PrimaryButton(
            leading: Icon(Icons.check),
            onPressed: () {
              widget.onComplete();
            },
            child: Text(context.i18n.continueAction),
          ),
      ],
    );
  }
}

class _OpenBikeControlConnectPage extends StatefulWidget {
  final VoidCallback onComplete;
  const _OpenBikeControlConnectPage({super.key, required this.onComplete});

  @override
  State<_OpenBikeControlConnectPage> createState() => _OpenBikeControlConnectPageState();
}

class _OpenBikeControlConnectPageState extends State<_OpenBikeControlConnectPage> {
  @override
  void initState() {
    super.initState();
    if (!core.obpMdnsEmulator.isStarted.value) {
      if (!core.logic.isObpMdnsEnabled) {
        core.settings.setObpMdnsEnabled(true);
      }
      core.logic.startEnabledConnectionMethod();
    }
    core.obpMdnsEmulator.connectedApp.addListener(() {
      if (core.obpMdnsEmulator.connectedApp.value != null) {
        widget.onComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 22,
      children: [
        Text(
          AppLocalizations.of(context).openBikeControlAnnouncement(core.settings.getTrainerApp()!.name),
        ).small,
        OpenBikeControlMdnsTile(),

        if (core.settings.getLastTarget() == Target.otherDevice &&
            core.settings.getTrainerApp()?.supportsOpenBikeProtocol.contains(OpenBikeProtocolSupport.ble) == true) ...[
          SizedBox(height: 20),
          Text('If you have issues with your network connection, you can also connect via Bluetooth.').small.muted,
          OpenBikeControlBluetoothTile(),
        ],
      ],
    );
  }
}
