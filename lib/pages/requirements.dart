import 'dart:io';

import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stepper, Card, Step, StepState;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Scaffold, AppBar, Theme;
import 'package:swift_control/bluetooth/messages/notification.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/utils/requirements/multi.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/menu.dart';
import 'package:swift_control/widgets/title.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';

import 'device.dart';

class RequirementsPage extends StatefulWidget {
  const RequirementsPage({super.key});

  @override
  State<RequirementsPage> createState() => _RequirementsPageState();
}

class _RequirementsPageState extends State<RequirementsPage> with WidgetsBindingObserver {
  List<PlatformRequirement> _requirements = [];
  final StepperController _controller = StepperController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // call after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && Platform.isMacOS) {
        // add more delay due to CBManagerStateUnknown
        Future.delayed(const Duration(seconds: 2), () {
          _reloadRequirements();
        });
      } else {
        _reloadRequirements();
      }
    });
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadRequirements();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppTitle(),
        actions: buildMenuButtons(),
        backgroundColor: Theme.brightnessOf(context) == Brightness.light
            ? Theme.of(context).colorScheme.inversePrimary
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          spacing: 12,
          children: [
            SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Image.asset('icon.png', width: 64, height: 64),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome to BikeControl!', style: Theme.of(context).textTheme.titleMedium),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 140),

                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Need help? Click on the '),
                            WidgetSpan(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Icon(Icons.help_outline),
                              ),
                            ),
                            TextSpan(text: ' button on top and don\'t hesitate to contact us.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _requirements.isEmpty
                ? Center(child: SmallProgressIndicator())
                : Card(
                    child: Stepper(
                      controller: _controller,
                      direction: Axis.vertical,
                      key: ObjectKey(_requirements.length),

                      /*onStepContinue: _currentStep < _requirements.length
                          ? () {
                              setState(() {
                                _currentStep += 1;
                              });
                            }
                          : null,
                      onStepTapped: (step) {
                        if (_requirements[step].status && _requirements[step] is! TargetRequirement) {
                          return;
                        }
                        final hasEarlierIncomplete =
                            _requirements.indexWhere((req) => !req.status) != -1 &&
                            _requirements.indexWhere((req) => !req.status) < step;
                        if (hasEarlierIncomplete) {
                          return;
                        }
                        setState(() {
                          _currentStep = step;
                        });
                      },*/
                      steps: _requirements
                          .mapIndexed(
                            (index, req) => Step(
                              title: Text(req.name, style: TextStyle(fontWeight: FontWeight.w600)),
                              icon: StepNumber(
                                icon: Icon(
                                  req.status
                                      ? Icons.check
                                      : (index == _controller.value.currentStep
                                            ? Icons.info
                                            : Icons.radio_button_unchecked),
                                  size: 18,
                                ),
                              ),
                              /*subtitle:
                                  req.buildDescription() ?? (req.description != null ? Text(req.description!) : null),*/
                              contentBuilder: (context) => Container(
                                padding: const EdgeInsets.only(top: 16.0),
                                alignment: Alignment.centerLeft,
                                child:
                                    (index == _controller.value.currentStep
                                        ? req.build(context, () {
                                            _reloadRequirements();
                                          })
                                        : null) ??
                                    ElevatedButton(
                                      onPressed: req.status
                                          ? null
                                          : () => _callRequirement(req, context, () {
                                              _reloadRequirements();
                                            }),
                                      child: Text(req.name),
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _callRequirement(PlatformRequirement req, BuildContext context, VoidCallback onUpdate) {
    req
        .call(context, onUpdate)
        .then((_) {
          return _reloadRequirements();
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error handling requirement "${req.name}": $e'),
            ),
          );
        });
  }

  void _reloadRequirements() async {
    try {
      final req = await getRequirements(
        settings.getLastTarget()?.connectionType ?? ConnectionType.unknown,
      );
      _requirements = req;
      _controller.jumpToStep(_controller.value.currentStep >= _requirements.length ? 0 : _controller.value.currentStep);

      setState(() {});
      final unresolvedIndex = req.indexWhere((req) => !req.status);
      if (unresolvedIndex != -1) {
        _controller.jumpToStep(unresolvedIndex);
      } else if (mounted) {
        String? currentPath;
        navigatorKey.currentState?.popUntil((route) {
          currentPath = route.settings.name;
          return true;
        });
        if (currentPath == '/') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => DevicePage(),
              settings: RouteSettings(name: '/device'),
            ),
          );
        }
      }
    } catch (e) {
      connection.signalNotification(LogNotification('Error loading requirements: $e'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading requirements: $e'),
        ),
      );
      _controller.jumpToStep(0);
      _requirements = [ErrorRequirement('Error loading requirements: $e')];
      setState(() {});
    }
  }
}
