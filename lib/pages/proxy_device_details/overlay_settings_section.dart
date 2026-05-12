import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/ui/setting_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class OverlaySettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;
  const OverlaySettingsSection({
    super.key,
    required this.definition,
    required this.device,
  });

  @override
  State<OverlaySettingsSection> createState() => _OverlaySettingsSectionState();
}

class _OverlaySettingsSectionState extends State<OverlaySettingsSection> {
  late TrainerOverlayController _controller;
  late bool _enabled;
  late Set<OverlayField> _fields;
  bool _androidPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _controller = TrainerOverlayService.forCurrentPlatform();
    // Use the controller's live state as source of truth — the persisted flag
    // may be stale after a cold start where no overlay is actually showing.
    _enabled = _controller.isShowing.value;
    _fields = core.settings.getOverlayFields();
    _controller.isShowing.addListener(_syncFromController);
    _refreshAndroidPermission();
  }

  Future<void> _refreshAndroidPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!mounted) return;
    setState(() => _androidPermissionGranted = granted);
  }

  @override
  void dispose() {
    _controller.isShowing.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    if (!mounted) return;
    setState(() => _enabled = _controller.isShowing.value);
  }

  Future<void> _toggle(bool v) async {
    if (kIsWeb) return;
    if (v) {
      final res = await _controller.show(
        widget.definition,
        _fields,
        liveDef: () {
          final live = widget.device.emulator.activeDefinition;
          return live is FitnessBikeDefinition ? live : null;
        },
      );
      if (!mounted) return;
      // Permission state may have changed during show().
      _refreshAndroidPermission();
      if (res.ok) {
        await core.settings.setOverlayEnabled(true);
        setState(() => _enabled = true);
      } else {
        // Stay off and surface message.
        showToast(
          context: context,
          builder: (c, _) => SurfaceCard(
            child: Text(res.message ?? AppLocalizations.of(context).overlayLowPowerMode),
          ),
        );
        setState(() => _enabled = false);
      }
    } else {
      await _controller.hide();
      await core.settings.setOverlayEnabled(false);
      if (mounted) setState(() => _enabled = false);
    }
  }

  Future<void> _toggleField(OverlayField f, bool on) async {
    final next = {..._fields};
    if (on) {
      next.add(f);
    } else {
      next.remove(f);
    }
    await core.settings.setOverlayFields(next);
    _controller.updateFields(next);
    if (mounted) setState(() => _fields = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIos = !kIsWeb && Platform.isIOS;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text(
          l10n.overlaySection,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        SettingTile(
          icon: LucideIcons.layers,
          title: l10n.overlayEnabled,
          subtitle: isIos ? l10n.overlayDisabledIos : l10n.overlaySectionSubtitle,
          trailing: Switch(value: _enabled, onChanged: _toggle),
        ),
        if (_enabled) _fieldsCard(l10n),
        if (!kIsWeb && Platform.isWindows && _enabled) _tipCard(l10n.overlayWindowsTip),
        if (isAndroid && !_androidPermissionGranted) _androidPermissionTile(l10n),
      ],
    );
  }

  Widget _fieldsCard(AppLocalizations l10n) {
    Widget row(OverlayField f, String label) {
      return Row(
        children: [
          Expanded(child: Text(label)),
          Switch(
            value: _fields.contains(f),
            onChanged: (v) => _toggleField(f, v),
          ),
        ],
      );
    }
    return SettingTile(
      icon: LucideIcons.eye,
      title: l10n.overlayFieldsLabel,
      subtitle: l10n.overlaySectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          row(OverlayField.power, l10n.overlayFieldPower),
          row(OverlayField.cadence, l10n.overlayFieldCadence),
          row(OverlayField.ergTarget, l10n.overlayFieldErgTarget),
          row(OverlayField.gearRatio, l10n.overlayFieldGearRatio),
          row(OverlayField.controls, l10n.overlayFieldControls),
        ],
      ),
    );
  }

  Widget _tipCard(String text) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 16, color: cs.mutedForeground),
          const Gap(8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: cs.mutedForeground)),
          ),
        ],
      ),
    );
  }

  Widget _androidPermissionTile(AppLocalizations l10n) {
    return SettingTile(
      icon: LucideIcons.shieldCheck,
      title: l10n.overlayGrantAndroidPermission,
      subtitle: l10n.overlayPermissionExplain,
      trailing: Button.ghost(
        onPressed: () async {
          // Re-trigger via show(): the controller asks for permission first.
          await _toggle(true);
        },
        child: Text(l10n.overlayGrantAndroidPermission),
      ),
    );
  }
}
