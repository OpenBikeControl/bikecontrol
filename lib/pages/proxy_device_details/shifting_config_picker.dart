import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/shifting_config.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/bk_icon_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ShiftingConfigPicker extends StatefulWidget {
  final String trainerKey;
  const ShiftingConfigPicker({super.key, required this.trainerKey});

  @override
  State<ShiftingConfigPicker> createState() => _ShiftingConfigPickerState();
}

class _ShiftingConfigPickerState extends State<ShiftingConfigPicker> {
  /// Below this width the New / Manage buttons stack beside the dropdown
  /// instead of sharing its row. Tuned for the row inside the settings
  /// section on 360–390 dp phones (~330–360 dp of usable width once the page
  /// and card paddings are off): side by side, the two labelled buttons left
  /// the dropdown — the part the rider actually reads — a few characters
  /// wide.
  static const double _stackButtonsBelowWidth = 400;

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

  Future<String?> _promptName({required String title, String initial = ''}) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          placeholder: Text(l10n.nameHint),
          onSubmitted: (value) => Navigator.of(c).pop(value.trim()),
        ),
        actions: [
          Button.outline(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text(l10n.cancel),
          ),
          Button.primary(
            onPressed: () => Navigator.of(c).pop(controller.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
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
    await showDialog<void>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setLocal) {
            final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
            return AlertDialog(
              title: Text(l10n.manageShiftingConfigs),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    for (final cfg in configs)
                      _manageRow(
                        cfg,
                        canDelete: configs.length > 1,
                        onChanged: () => setLocal(() {}),
                      ),
                  ],
                ),
              ),
              actions: [
                Button.outline(
                  onPressed: () => Navigator.of(c).pop(),
                  child: Text(l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// One profile in the Manage dialog: its name (and whether it is the
  /// active one), then duplicate / rename / delete.
  Widget _manageRow(ShiftingConfig cfg, {required bool canDelete, required VoidCallback onChanged}) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: ValueKey('shifting-config-${cfg.name}'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cfg.name).semiBold,
              if (cfg.isActive) Text(l10n.active).xSmall.muted,
            ],
          ),
        ),
        BkIconButton.ghost(
          icon: const Icon(LucideIcons.copy, size: 18),
          label: l10n.duplicate,
          onPressed: () async {
            final name = await _promptName(title: l10n.duplicate, initial: l10n.configCopySuffix(cfg.name));
            if (name == null || name.isEmpty) return;
            await core.shiftingConfigs.duplicate(trainerKey: widget.trainerKey, sourceName: cfg.name, newName: name);
            onChanged();
          },
        ),
        BkIconButton.ghost(
          icon: const Icon(LucideIcons.pencil, size: 18),
          label: l10n.rename,
          onPressed: () async {
            final name = await _promptName(title: l10n.rename, initial: cfg.name);
            if (name == null || name.isEmpty || name == cfg.name) return;
            await core.shiftingConfigs.rename(trainerKey: widget.trainerKey, from: cfg.name, to: name);
            onChanged();
          },
        ),
        if (canDelete)
          BkIconButton.ghost(
            icon: const Icon(LucideIcons.trash2, size: 18),
            label: l10n.delete,
            onPressed: () async {
              await core.shiftingConfigs.remove(trainerKey: widget.trainerKey, name: cfg.name);
              onChanged();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _stackButtonsBelowWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _select(context)),
              const Gap(8),
              // IntrinsicWidth sizes the column to its wider button so both
              // stretch to the same width instead of each hugging its label.
              IntrinsicWidth(
                child: Column(
                  // min: the Row hands its children whatever height the page
                  // allows, and an expanding column would drag the dropdown
                  // down to the middle of that instead of the button stack.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [_newButton(context), _manageButton(context)],
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: _select(context)),
            const Gap(8),
            _newButton(context),
            const Gap(8),
            _manageButton(context),
          ],
        );
      },
    );
  }

  Widget _select(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final configs = core.shiftingConfigs.configsFor(widget.trainerKey);
    final active = core.shiftingConfigs.activeFor(widget.trainerKey);
    final selected = configs.any((c) => c.name == active.name) ? active : null;
    return Select<ShiftingConfig>(
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
    );
  }

  Widget _newButton(BuildContext context) {
    return Button.outline(
      onPressed: _createNew,
      leading: const Icon(LucideIcons.plus, size: 16),
      child: Text(AppLocalizations.of(context).newAction),
    );
  }

  Widget _manageButton(BuildContext context) {
    return Button.outline(
      onPressed: _manage,
      leading: const Icon(LucideIcons.settings, size: 16),
      child: Text(AppLocalizations.of(context).manageAction),
    );
  }
}
