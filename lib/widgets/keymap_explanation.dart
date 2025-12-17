import 'dart:async';

import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/custom_app.dart';
import 'package:bike_control/utils/keymap/keymap.dart';
import 'package:bike_control/utils/keymap/manager.dart';
import 'package:bike_control/widgets/ui/button_widget.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _updateStreamListener = widget.keymap.updateStream.listen((_) {
      setState(() {});
    });
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
  void dispose() {
    super.dispose();
    _updateStreamListener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final allAvailableButtons = IterableFlatMap(core.connection.devices).flatMap((d) => d.availableButtons);
    final availableKeypairs = widget.keymap.keyPairs
        .whereNot(
          (keyPair) => keyPair.buttons.filter((b) => allAvailableButtons.contains(b)).isEmpty,
        )
        .sortedBy((k) => k.buttons.first.color != null ? 0 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final keyPair in availableKeypairs) ...[
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
                  await openDrawer(
                    context: context,
                    builder: (c) => ButtonEditPage(
                      keyPair: selectedKeyPair,
                      onUpdate: () {
                        widget.onUpdate();
                      },
                    ),
                    position: OverlayPosition.end,
                  );
                }
                widget.onUpdate();
              } else {
                await openDrawer(
                  context: context,

                  builder: (c) => ButtonEditPage(
                    keyPair: keyPair,
                    onUpdate: () {
                      widget.onUpdate();
                    },
                  ),
                  position: OverlayPosition.end,
                );
                widget.onUpdate();
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
                            for (final button in keyPair.buttons.filter((b) => allAvailableButtons.contains(b)))
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
    );
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
