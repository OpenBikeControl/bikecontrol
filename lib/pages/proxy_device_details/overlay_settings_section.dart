import 'dart:io' show Platform;

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/overlay/ios_pip_controller.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_controller.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/settings/settings.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The overlay's settings — the body of Settings → Overlay: the switch and,
/// while the overlay is on, the fields it shows; then what only some
/// platforms have (opacity on desktop, Picture-in-Picture on iOS, Android's
/// draw-over permission, the Windows fullscreen tip).
class OverlaySettingsSection extends StatefulWidget {
  final FitnessBikeDefinition definition;
  final ProxyDevice device;

  /// Told about every field switch, so a preview can follow them.
  final ValueChanged<Set<OverlayField>>? onFieldsChanged;

  /// Told when the overlay goes on or off.
  final ValueChanged<bool>? onEnabledChanged;

  const OverlaySettingsSection({
    super.key,
    required this.definition,
    required this.device,
    this.onFieldsChanged,
    this.onEnabledChanged,
  });

  @override
  State<OverlaySettingsSection> createState() => _OverlaySettingsSectionState();
}

class _OverlaySettingsSectionState extends State<OverlaySettingsSection> {
  late TrainerOverlayController _controller;
  late bool _enabled;
  late Set<OverlayField> _fields;
  late double _opacity;
  bool _androidPermissionGranted = false;
  bool _pipCapable = false;
  bool _pipAutoDefault = false;
  bool? _pipPref;

  @override
  void initState() {
    super.initState();
    _controller = TrainerOverlayService.forCurrentPlatform();
    // Use the controller's live state as source of truth — the persisted flag
    // may be stale after a cold start where no overlay is actually showing.
    _enabled = _controller.isShowing.value;
    _fields = core.settings.getOverlayFields();
    _opacity = core.settings.getOverlayOpacity();
    _controller.isShowing.addListener(_syncFromController);
    _refreshAndroidPermission();
    _pipPref = core.settings.getOverlayUsePip();
    _loadPipCapability();
  }

  Future<void> _loadPipCapability() async {
    if (kIsWeb || !Platform.isIOS) return;
    final pip = IosPipController();
    final capable = await pip.isCapable();
    final auto = await pip.isSupported();
    if (!mounted) return;
    setState(() {
      _pipCapable = capable;
      _pipAutoDefault = auto;
    });
  }

  Future<void> _togglePip(bool v) async {
    await core.settings.setOverlayUsePip(v);
    if (mounted) setState(() => _pipPref = v);
    // Re-apply immediately if the overlay is already showing.
    if (_enabled) {
      await _controller.hide();
      final res = await _controller.show(
        widget.definition,
        _fields,
        liveDef: () => widget.device.fitnessBike,
      );
      if (mounted) setState(() => _enabled = res.ok);
    }
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
    widget.onEnabledChanged?.call(_enabled);
  }

  Future<void> _toggle(bool v) async {
    if (kIsWeb) return;
    if (v) {
      final res = await enableTrainerOverlay(widget.device);
      if (!mounted) return;
      // Permission state may have changed during show().
      _refreshAndroidPermission();
      if (res.ok) {
        setState(() => _enabled = true);
      } else {
        // Stay off and surface message.
        showToast(
          context: context,
          builder: (c, _) => SurfaceCard(
            child: Text(res.riderMessage(AppLocalizations.of(context))),
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

  /// Live-preview as the user drags: update the on-screen % and fade the
  /// overlay window in real time. Persistence happens once on release
  /// ([_commitOpacity]) to avoid a disk write per drag tick.
  void _previewOpacity(double v) {
    setState(() => _opacity = v);
    _controller.updateOpacity(v);
  }

  Future<void> _commitOpacity(double v) async {
    await core.settings.setOverlayOpacity(v);
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
    widget.onFieldsChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIos = !kIsWeb && Platform.isIOS;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows);

    final platformRows = <Widget>[
      if (isIos && _pipCapable)
        BkGroupedRow(
          icon: LucideIcons.appWindow,
          title: l10n.overlayUsePip,
          subtitle: l10n.overlayUsePipSubtitle,
          trailing: Switch(value: _pipPref ?? _pipAutoDefault, onChanged: _togglePip),
          onPressed: () => _togglePip(!(_pipPref ?? _pipAutoDefault)),
        ),
      if (isDesktop && _enabled)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BkGroupedRow(icon: LucideIcons.blend, title: l10n.overlayOpacity, subtitle: l10n.overlayOpacitySubtitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BkGroupedSection.inset + BkIconTile.size + BkGroupedRow.gap,
                0,
                BkGroupedSection.inset,
                12,
              ),
              child: _opacitySlider(),
            ),
          ],
        ),
      if (isAndroid && !_androidPermissionGranted) _androidPermissionRow(l10n),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        BkGroupedSection(
          key: const ValueKey('overlay-main'),
          children: [
            BkGroupedRow(
              icon: LucideIcons.layers,
              title: l10n.overlayEnabled,
              subtitle: isIos ? l10n.overlayDisabledIos : l10n.overlaySectionSubtitle,
              trailing: Switch(value: _enabled, onChanged: _toggle),
              onPressed: () => _toggle(!_enabled),
            ),
            // The fields only matter while there is an overlay to show them.
            if (_enabled) ...[
              _fieldRow(OverlayField.ergTarget, l10n.overlayFieldErgTarget),
              _fieldRow(OverlayField.gearRatio, l10n.overlayFieldGearRatio),
              _fieldRow(OverlayField.controls, l10n.overlayFieldControls),
            ],
          ],
        ),
        if (platformRows.isNotEmpty) BkGroupedSection(key: const ValueKey('overlay-platform'), children: platformRows),
        if (!kIsWeb && Platform.isWindows && _enabled) _tipCard(l10n.overlayWindowsTip),
      ],
    );
  }

  /// One field of the overlay, indented under the switch it belongs to.
  Widget _fieldRow(OverlayField f, String label) {
    final on = _fields.contains(f);
    return BkGroupedRow(
      leading: const SizedBox(width: BkIconTile.size),
      title: label,
      trailing: Switch(value: on, onChanged: (v) => _toggleField(f, v)),
      onPressed: () => _toggleField(f, !on),
    );
  }

  Widget _opacitySlider() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: SliderValue.single(_opacity),
            min: Settings.minOverlayOpacity,
            max: 1.0,
            // 5% steps across the 20–100% range.
            divisions: 16,
            onChanged: (v) => _previewOpacity(v.value),
            onChangeEnd: (v) => _commitOpacity(v.value),
          ),
        ),
        const Gap(12),
        SizedBox(
          width: 40,
          child: Text(
            '${(_opacity * 100).round()}%',
            textAlign: TextAlign.end,
            style: context.typography.xSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.mutedForeground,
            ),
          ),
        ),
      ],
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
            child: Text(text, style: context.typography.xSmall.copyWith(color: cs.mutedForeground)),
          ),
        ],
      ),
    );
  }

  Widget _androidPermissionRow(AppLocalizations l10n) {
    return BkGroupedRow(
      icon: LucideIcons.shieldCheck,
      title: l10n.overlayGrantAndroidPermission,
      subtitle: l10n.overlayPermissionExplain,
      // Re-trigger via show(): the controller asks for permission first.
      onPressed: () => _toggle(true),
      chevron: true,
    );
  }
}
