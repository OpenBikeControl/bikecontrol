import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/proxy_device_details.dart';
import 'package:bike_control/pages/proxy_device_details/overlay_settings_section.dart';
import 'package:bike_control/services/overlay/overlay_state.dart';
import 'package:bike_control/services/overlay/trainer_overlay_service.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/widgets/overlay/trainer_overlay_view.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:bike_control/widgets/ui/bk_page_column.dart';

/// Where "show me the overlay setup" lands for [proxy]: the Overlay page while
/// the trainer is in a virtual shifting session (the only time there is a
/// gear to draw), else the trainer's own page, where that session starts.
Widget overlaySettingsDestination(ProxyDevice proxy) => switch (proxy.fitnessBike) {
  final definition? => OverlaySettingsPage(device: proxy, definition: definition),
  null => ProxyDeviceDetailsPage(device: proxy),
};

/// Settings → Overlay: a live preview of the gear overlay on top, then its
/// settings. The preview is the real pill, driven by the trainer's live gear
/// and following the field switches, so riders see what they are switching on
/// before they start a ride.
class OverlaySettingsPage extends StatefulWidget {
  const OverlaySettingsPage({super.key, required this.device, required this.definition});

  final ProxyDevice device;
  final FitnessBikeDefinition definition;

  @override
  State<OverlaySettingsPage> createState() => _OverlaySettingsPageState();
}

class _OverlaySettingsPageState extends State<OverlaySettingsPage> {
  late Set<OverlayField> _fields = core.settings.getOverlayFields();
  late bool _enabled = TrainerOverlayService.forCurrentPlatform().isShowing.value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      headers: [BkPageHeader(title: l10n.overlaySection)],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: BkPageColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OverlayPreview(definition: widget.definition, fields: _fields, enabled: _enabled),
              const Gap(16),
              OverlaySettingsSection(
                definition: widget.definition,
                device: widget.device,
                onFieldsChanged: (fields) => setState(() => _fields = fields),
                onEnabledChanged: (enabled) => setState(() => _enabled = enabled),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The overlay pill over a quiet stand-in for the trainer app's screen,
/// showing [definition]'s live gear with [fields]. Faded while the overlay is
/// off. The −/+ work, as they do on the real overlay.
class OverlayPreview extends StatefulWidget {
  const OverlayPreview({super.key, required this.definition, required this.fields, required this.enabled});

  final FitnessBikeDefinition definition;
  final Set<OverlayField> fields;
  final bool enabled;

  @override
  State<OverlayPreview> createState() => _OverlayPreviewState();
}

class _OverlayPreviewState extends State<OverlayPreview> {
  late final ValueNotifier<TrainerOverlayState> _state = ValueNotifier(_read());
  late Listenable _live;

  FitnessBikeDefinition get _def => widget.definition;

  Listenable _listenTo(FitnessBikeDefinition d) => Listenable.merge([
    d.currentGear,
    d.gearRatio,
    d.gearRatios,
    d.trainerMode,
    d.ergTargetPower,
    d.frontRing,
  ]);

  @override
  void initState() {
    super.initState();
    _live = _listenTo(_def)..addListener(_refresh);
  }

  @override
  void didUpdateWidget(OverlayPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      _live.removeListener(_refresh);
      _live = _listenTo(_def)..addListener(_refresh);
    }
    _refresh();
  }

  @override
  void dispose() {
    _live.removeListener(_refresh);
    _state.dispose();
    super.dispose();
  }

  /// What the real overlay would be sent right now; never watts or rpm.
  TrainerOverlayState _read() => TrainerOverlayState(
    gear: _def.currentGear.value,
    maxGear: _def.maxGear,
    gearRatio: _def.gearRatio.value,
    mode: _def.trainerMode.value,
    powerW: null,
    cadenceRpm: null,
    ergTargetW: _def.ergTargetPower.value,
    fields: widget.fields,
    frontShiftEnabled: _def.frontShiftEnabled,
    frontRingLarge: _def.frontRing.value == FrontRing.large,
  );

  void _refresh() => _state.value = _read();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // The desktop window fits what it shows (and follows the mode); Android's
    // keeps room for everything.
    Size sizeFor(TrainerOverlayState s) => defaultTargetPlatform == TargetPlatform.android
        ? TrainerOverlayView.windowSize(
            MediaQuery.textScalerOf(context),
            controls: widget.fields.contains(OverlayField.controls),
          )
        : TrainerOverlayView.fitWindowSizeOf(context, s);
    return Container(
      key: const ValueKey('overlay-preview'),
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
        // A stand-in for the trainer app behind the overlay, in the theme's
        // own greys.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.muted, cs.card, cs.muted],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ValueListenableBuilder<TrainerOverlayState>(
            valueListenable: _state,
            builder: (context, s, child) => SizedBox(width: sizeFor(s).width, child: child),
            child: TrainerOverlayView(
              state: _state,
              pill: true,
              onPrimaryDecrement: _def.shiftDown,
              onPrimaryIncrement: _def.shiftUp,
            ),
          ),
        ),
      ),
    );
  }
}
