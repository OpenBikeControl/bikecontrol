import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/utils/actions/android.dart';
import 'package:swift_control/utils/actions/desktop.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/buttons.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/widgets/ui/gradient_text.dart';
import 'package:swift_control/widgets/ui/warning.dart';

class ButtonSimulator extends StatelessWidget {
  const ButtonSimulator({super.key});

  @override
  Widget build(BuildContext context) {
    final connectedTrainers = core.logic.connectedTrainerConnections;

    return Scaffold(
      headers: [
        AppBar(
          leading: [BackButton()],
          title: Text(context.i18n.simulateButtons),
        ),
      ],
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              if (connectedTrainers.isEmpty)
                Warning(
                  children: [
                    Text('No connected trainers found. Connect a trainer to simulate button presses.'),
                  ],
                ),
              ...connectedTrainers.map(
                (connection) {
                  final supportedActions = connection.supportedActions;

                  final actionGroups = {
                    if (supportedActions.contains(InGameAction.shiftUp) &&
                        supportedActions.contains(InGameAction.shiftDown))
                      'Shifting': [InGameAction.shiftUp, InGameAction.shiftDown],
                    'Other': supportedActions
                        .where((action) => action != InGameAction.shiftUp && action != InGameAction.shiftDown)
                        .toList(),
                  };

                  return [
                    GradientText(connection.title).bold.large,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        for (final group in actionGroups.entries) ...[
                          Text(group.key).bold,
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: group.value
                                .map(
                                  (action) => PrimaryButton(
                                    size: ButtonSize(1.6),
                                    child: Text(action.title),
                                    onPressed: () async {
                                      if (action.possibleValues != null) {
                                        showDropdown(
                                          context: context,
                                          builder: (context) => DropdownMenu(
                                            children: action.possibleValues!
                                                .map(
                                                  (e) => MenuButton(
                                                    child: Text(e.toString()),
                                                    onPressed: (c) async {
                                                      await connection.sendAction(
                                                        KeyPair(
                                                          buttons: [],
                                                          physicalKey: null,
                                                          logicalKey: null,
                                                          inGameAction: action,
                                                          inGameActionValue: e,
                                                        ),
                                                        isKeyDown: true,
                                                        isKeyUp: false,
                                                      );
                                                      await connection.sendAction(
                                                        KeyPair(
                                                          buttons: [],
                                                          physicalKey: null,
                                                          logicalKey: null,
                                                          inGameAction: action,
                                                          inGameActionValue: e,
                                                        ),
                                                        isKeyDown: false,
                                                        isKeyUp: true,
                                                      );
                                                    },
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        );
                                        return;
                                      } else {
                                        await connection.sendAction(
                                          KeyPair(
                                            buttons: [],
                                            physicalKey: null,
                                            logicalKey: null,
                                            inGameAction: action,
                                          ),
                                          isKeyDown: true,
                                          isKeyUp: false,
                                        );
                                        await connection.sendAction(
                                          KeyPair(
                                            buttons: [],
                                            physicalKey: null,
                                            logicalKey: null,
                                            inGameAction: action,
                                          ),
                                          isKeyDown: false,
                                          isKeyUp: true,
                                        );
                                      }
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ];
                },
              ).flatten(),
              // local control doesn't make much sense - it would send the key events to BikeControl itself
              if (false &&
                  core.logic.showLocalControl &&
                  core.settings.getLocalEnabled() &&
                  core.actionHandler.supportedApp != null) ...[
                GradientText('Local Control'),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: core.actionHandler.supportedApp!.keymap.keyPairs
                      .map(
                        (keyPair) => PrimaryButton(
                          child: Text(keyPair.toString()),
                          onPressed: () async {
                            if (core.actionHandler is AndroidActions) {
                              await (core.actionHandler as AndroidActions).performAction(
                                keyPair.buttons.first,
                                isKeyDown: true,
                                isKeyUp: false,
                              );
                              await (core.actionHandler as AndroidActions).performAction(
                                keyPair.buttons.first,
                                isKeyDown: false,
                                isKeyUp: true,
                              );
                            } else {
                              await (core.actionHandler as DesktopActions).performAction(
                                keyPair.buttons.first,
                                isKeyDown: true,
                                isKeyUp: false,
                              );
                              await (core.actionHandler as DesktopActions).performAction(
                                keyPair.buttons.first,
                                isKeyDown: false,
                                isKeyUp: true,
                              );
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
