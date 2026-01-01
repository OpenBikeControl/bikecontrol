import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/requirements/platform.dart';
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
            Button.outline(
              child: Text('Skip'),
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
            padding: EdgeInsets.symmetric(vertical: !_isMobile ? 42 : 22.0, horizontal: 16),
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
                      _currentStep = _OnboardingStep.finish;
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
                    ColoredTitle(text: 'Setup Complete!'),
                    Text(
                      "As a final step you'll choose how to connect to ${core.settings.getTrainerApp()?.name}.",
                      textAlign: TextAlign.center,
                    ).small.muted,

                    SizedBox(height: 30),
                    PrimaryButton(
                      leading: Icon(Icons.check),
                      onPressed: () {
                        core.settings.setShowOnboarding(false);
                        widget.onComplete();
                      },
                      child: Text('Continue'),
                    ),
                  ],
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
        Text('Let\'s get you set up!').h3,
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
        ColoredTitle(text: 'Controller Setup'),
        if (core.connection.controllerDevices.isEmpty) ...[
          ScanWidget(),

          OutlineButton(
            onPressed: () {
              launchUrlString(
                'https://github.com/jonasbark/swiftcontrol/?tab=readme-ov-file#supported-devices',
              );
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
          if (core.connection.controllerDevices.any((d) => d.isConnected))
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
                    'Great! Your controller is connected. Click a button on your controller to continue.',
                  ).small,
                );
              },
            ),
          SizedBox(),
          ...core.connection.controllerDevices.map(
            (device) => device.showInformation(context),
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
            child: Text('Continue'),
          ),
      ],
    );
  }
}
