import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../bluetooth/messages/notification.dart';
import '../pages/touch_area.dart';

class KeymapExplanation extends StatefulWidget {
  final Keymap keymap;
  final VoidCallback onUpdate;
  const KeymapExplanation({super.key, required this.keymap, required this.onUpdate});

  @override
  State<KeymapExplanation> createState() => _KeymapExplanationState();
}

class _KeymapExplanationState extends State<KeymapExplanation> {
  late StreamSubscription<void> _updateStreamListener;

  late StreamSubscription<BaseNotification> _actionSubscription;

  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      setState(() {});
    });
    _actionSubscription = core.connection.actionStream.listen((data) async {
      if (!mounted) {
        return;
      }
      if (data is ButtonNotification && data.buttonsClicked.length == 1) {
        final clickedButton = data.buttonsClicked.first;
        final keyPair = widget.keymap.keyPairs.firstOrNullWhere(
          (kp) => kp.buttons.contains(clickedButton),
        );
        if (keyPair != null && !_isDrawerOpen) {
          await _openKeyPairEditor(keyPair);
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _updateStreamListener.cancel();
    _actionSubscription.cancel();
  }

  @override
  void didUpdateWidget(KeymapExplanation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keymap != widget.keymap) {
      _updateStreamListener.cancel();
      _updateStreamListener = widget.keymap.updateStream.listen((_) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyButtonMap = core.connection.devices.associateWith((d) {
      final allButtons = d.availableButtons;
      return widget.keymap.keyPairs
          .whereNot(
            (keyPair) => keyPair.buttons.filter((b) => allButtons.contains(b)).isEmpty,
          )
          .sortedBy(
            (k) => k.buttons.first.color != null
                ? '0${(k.buttons.first.icon?.codePoint ?? 0 * -1)}'
                : '1${(k.buttons.first.icon?.codePoint ?? 0 * -1)}',
          );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (core.connection.controllerDevices.isNotEmpty)
          Text(
            AppLocalizations.of(context).clickAButtonOnYourController,
            style: TextStyle(fontSize: 12),
          ).muted,

        for (final devicePair in keyButtonMap.entries) ...[
          SizedBox(height: 12),
          ColoredTitle(text: devicePair.key.toString()),
          if (devicePair.value.isEmpty && devicePair.key.buttonExplanation != null)
            Text(
              devicePair.key.buttonExplanation!,
              style: TextStyle(height: 1),
            ).muted,
          for (final keyPair in devicePair.value) ...[
            Button.card(
              style: ButtonStyle.card().withBackgroundColor(color: Theme.of(context).colorScheme.background),
              onPressed: () async {
                if (core.actionHandler.supportedApp is! CustomApp) {
                  final currentProfile = core.actionHandler.supportedApp!.name;
                  final newName = await KeymapManager().duplicate(
                    context,
                    currentProfile,
                    skipName: '$currentProfile (Copy)',
                  );
                  if (newName != null && context.mounted) {
                    buildToast(context, title: context.i18n.createdNewCustomProfile(newName));
                    final selectedKeyPair = core.actionHandler.supportedApp!.keymap.keyPairs.firstWhere(
                      (e) => e == keyPair,
                    );
                    _openKeyPairEditor(selectedKeyPair);
                  }
                } else {
                  _openKeyPairEditor(keyPair);
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: Basic(
                      leading: SizedBox(
                        width: 68,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runAlignment: WrapAlignment.center,
                          children: [
                            if (core.actionHandler.supportedApp is! CustomApp)
                              for (final button in keyPair.buttons)
                                IntrinsicWidth(
                                  child: ButtonWidget(
                                    button: button,
                                    big: true,
                                  ),
                                )
                            else
                              for (final button in keyPair.buttons)
                                IntrinsicWidth(
                                  child: ButtonWidget(
                                    button: button,
                                    big: true,
                                  ),
                                ),
                          ],
                        ),
                      ),
                      content: (keyPair.buttons.isNotEmpty && keyPair.hasActiveAction)
                          ? KeypairExplanation(
                              keyPair: keyPair,
                            )
                          : Text(
                              core.logic.hasNoConnectionMethod
                                  ? AppLocalizations.of(context).noConnectionMethodSelected
                                  : context.i18n.noActionAssigned,
                              style: TextStyle(height: 1),
                            ).muted,
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 26),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _openKeyPairEditor(KeyPair selectedKeyPair) async {
    _isDrawerOpen = true;
    await openDrawer(
      context: context,
      builder: (c) => ButtonEditPage(
        keyPair: selectedKeyPair,
        keymap: widget.keymap,
        onUpdate: () {
          widget.keymap.signalUpdate();
          widget.onUpdate();
        },
      ),
      position: OverlayPosition.end,
    );
    widget.onUpdate();
    _isDrawerOpen = false;
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
