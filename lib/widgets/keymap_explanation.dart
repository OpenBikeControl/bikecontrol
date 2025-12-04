import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/pages/button_edit.dart';
import 'package:swift_control/pages/device.dart';
import 'package:swift_control/utils/core.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/keymap/apps/custom_app.dart';
import 'package:swift_control/utils/keymap/keymap.dart';
import 'package:swift_control/utils/keymap/manager.dart';
import 'package:swift_control/widgets/ui/button_widget.dart';
import 'package:swift_control/widgets/ui/toast.dart';

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
    final availableKeypairs = widget.keymap.keyPairs.whereNot(
      (keyPair) => keyPair.buttons.filter((b) => allAvailableButtons.contains(b)).isEmpty,
    );

    return ValueListenableBuilder(
      valueListenable: core.whooshLink.isConnected,
      builder: (c, _, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Table(
            columnWidths: {0: FlexTableSize(flex: 1), 1: FlexTableSize(flex: 3)},
            theme: TableTheme(
              cellTheme: TableCellTheme(
                border: WidgetStatePropertyAll(
                  Border.all(
                    color: Theme.of(context).colorScheme.border,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                ),
              ),
              // rounded border
              border: Border.all(
                color: Theme.of(context).colorScheme.border,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            rows: [
              TableHeader(
                cells: [
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        core.connection.devices.isEmpty
                            ? context.i18n.deviceButton('Device')
                            : context.i18n.deviceButton(
                                core.connection.devices.joinToString(transform: (d) => d.name.screenshot),
                              ),
                      ).small,
                    ),
                  ),
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(context.i18n.action).small,
                    ),
                  ),
                ],
              ),
              for (final keyPair in availableKeypairs) ...[
                TableRow(
                  cells: [
                    TableCell(
                      child: Container(
                        constraints: BoxConstraints(minHeight: 52),
                        padding: const EdgeInsets.all(8.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runAlignment: WrapAlignment.center,
                          children: [
                            if (core.actionHandler.supportedApp is! CustomApp)
                              for (final button in keyPair.buttons.filter((b) => allAvailableButtons.contains(b)))
                                IntrinsicWidth(child: ButtonWidget(button: button))
                            else
                              for (final button in keyPair.buttons) IntrinsicWidth(child: ButtonWidget(button: button)),
                          ],
                        ),
                      ),
                    ),
                    TableCell(
                      child: _ButtonEditor(keyPair: keyPair, onUpdate: widget.onUpdate),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ButtonEditor extends StatelessWidget {
  final KeyPair keyPair;
  final VoidCallback onUpdate;
  const _ButtonEditor({required this.onUpdate, super.key, required this.keyPair});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        if (core.actionHandler.supportedApp is! CustomApp) {
          final currentProfile = core.actionHandler.supportedApp!.name;
          final newName = await KeymapManager().duplicate(
            context,
            currentProfile,
            skipName: '$currentProfile (Copy)',
          );
          if (newName != null) {
            buildToast(context, title: context.i18n.createdNewCustomProfile(newName));
            final selectedKeyPair = core.actionHandler.supportedApp!.keymap.keyPairs.firstWhere(
              (e) => e == this.keyPair,
            );
            await openDrawer(
              context: context,
              builder: (c) => ButtonEditPage(
                keyPair: selectedKeyPair,
                onUpdate: () {},
              ),
              position: OverlayPosition.end,
            );
          }
          onUpdate();
        } else {
          await openDrawer(
            context: context,

            builder: (c) => ButtonEditPage(
              keyPair: keyPair,
              onUpdate: () {},
            ),
            position: OverlayPosition.end,
          );
          onUpdate();
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 6,
        children: [
          if (keyPair.buttons.isNotEmpty && keyPair.hasActiveAction)
            Expanded(
              child: KeypairExplanation(
                keyPair: keyPair,
              ),
            )
          else
            Expanded(
              child: Text(
                core.logic.hasNoConnectionMethod
                    ? context.i18n.pleaseSelectAConnectionMethodFirst
                    : context.i18n.noActionAssigned,
              ).muted.xSmall,
            ),
          Icon(Icons.edit, size: 14),
        ],
      ),
    );
  }
}

extension SplitByUppercase on String {
  String splitByUpperCase() {
    return replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}').capitalize();
  }
}
