import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/core.dart';
import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ShiftingConfigPicker extends StatefulWidget {
  final String trainerKey;
  const ShiftingConfigPicker({super.key, required this.trainerKey});

  @override
  State<ShiftingConfigPicker> createState() => _ShiftingConfigPickerState();
}

class _ShiftingConfigPickerState extends State<ShiftingConfigPicker> {
  @override
  void initState() {
    super.initState();
    core.shiftingConfigs.addListener(_onChanged);
  }

  @override
  void dispose() {
    core.shiftingConfigs.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<String?> _promptName({required String title, String initial = ''}) {
    final l10n = AppLocalizations.of(context);
    final controller = material.TextEditingController(text: initial);
    return material.showDialog<String>(
      context: context,
      builder: (c) => material.AlertDialog(
        title: material.Text(title),
        content: material.TextField(
          controller: controller,
          autofocus: true,
          decoration: material.InputDecoration(hintText: l10n.nameHint),
        ),
        actions: [
          material.TextButton(
            onPressed: () => material.Navigator.of(c).pop(null),
            child: material.Text(l10n.cancel),
          ),
          material.TextButton(
            onPressed: () => material.Navigator.of(c).pop(controller.text.trim()),
            child: material.Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _createNew() async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(title: l10n.newShiftingConfig);
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    final app = core.settings.getTrainerApp();
    await core.shiftingConfigs.upsert(
      ShiftingConfig.defaults(
        trainerKey: widget.trainerKey,
        name: name,
        maxGear: app?.virtualGearAmount ?? ShiftingConfig.maxGearDefault,
      ),
    );
  }

  Future<void> _manage() async {
    final l10n = AppLocalizations.of(context);
    await material.showDialog<void>(
      context: context,
      builder: (c) {
        return material.StatefulBuilder(
          builder: (c, setLocal) {
            final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
            return material.AlertDialog(
              title: material.Text(l10n.manageShiftingConfigs),
              content: material.SizedBox(
                width: 360,
                child: material.Column(
                  mainAxisSize: material.MainAxisSize.min,
                  children: [
                    for (final cfg in configs)
                      material.ListTile(
                        title: material.Text(cfg.name),
                        subtitle: cfg.isActive ? material.Text(l10n.active) : null,
                        trailing: material.Row(
                          mainAxisSize: material.MainAxisSize.min,
                          children: [
                            material.IconButton(
                              tooltip: l10n.duplicate,
                              icon: const material.Icon(material.Icons.copy, size: 18),
                              onPressed: () async {
                                final name = await _promptName(
                                  title: l10n.duplicate,
                                  initial: l10n.configCopySuffix(cfg.name),
                                );
                                if (name == null || name.isEmpty) return;
                                await core.shiftingConfigs.duplicate(
                                  trainerKey: widget.trainerKey,
                                  sourceName: cfg.name,
                                  newName: name,
                                );
                                setLocal(() {});
                              },
                            ),
                            material.IconButton(
                              tooltip: l10n.rename,
                              icon: const material.Icon(material.Icons.edit_outlined, size: 18),
                              onPressed: () async {
                                final name = await _promptName(
                                  title: l10n.rename,
                                  initial: cfg.name,
                                );
                                if (name == null || name.isEmpty || name == cfg.name) return;
                                await core.shiftingConfigs.rename(
                                  trainerKey: widget.trainerKey,
                                  from: cfg.name,
                                  to: name,
                                );
                                setLocal(() {});
                              },
                            ),
                            if (configs.length > 1)
                              material.IconButton(
                                tooltip: l10n.delete,
                                icon: const material.Icon(material.Icons.delete_outline, size: 18),
                                onPressed: () async {
                                  await core.shiftingConfigs.remove(
                                    trainerKey: widget.trainerKey,
                                    name: cfg.name,
                                  );
                                  setLocal(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                material.TextButton(
                  onPressed: () => material.Navigator.of(c).pop(),
                  child: material.Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
    final active = core.shiftingConfigs.activeFor(widget.trainerKey);
    final selected = configs.any((c) => c.name == active.name) ? active : null;

    return Row(
      children: [
        Expanded(
          child: Select<ShiftingConfig>(
            value: selected,
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final cfg in configs)
                    SelectItemButton(
                      value: cfg,
                      child: Text(cfg.name),
                    ),
                ],
              ),
            ).call,
            itemBuilder: (c, cfg) => Text(cfg.name),
            placeholder: Text(l10n.defaultName),
            onChanged: (cfg) async {
              if (cfg == null) return;
              await core.shiftingConfigs.setActive(trainerKey: widget.trainerKey, name: cfg.name);
            },
          ),
        ),
        const Gap(8),
        Button.outline(
          onPressed: _createNew,
          leading: const Icon(LucideIcons.plus, size: 16),
          child: Text(l10n.newAction),
        ),
        const Gap(8),
        Button.outline(
          onPressed: _manage,
          leading: const Icon(LucideIcons.settings, size: 16),
          child: Text(l10n.manageAction),
        ),
      ],
    );
  }
}
