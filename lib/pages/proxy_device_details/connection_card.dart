import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum _ConnectMode { proxy, virtualShiftingWifi, virtualShiftingBluetooth }

_ConnectMode _connectModeOf(RetrofitMode mode) => switch (mode) {
  RetrofitMode.proxy => _ConnectMode.proxy,
  RetrofitMode.bluetooth => _ConnectMode.virtualShiftingBluetooth,
  RetrofitMode.wifi => _ConnectMode.virtualShiftingWifi,
};

RetrofitMode _retrofitModeOf(_ConnectMode mode) => switch (mode) {
  _ConnectMode.proxy => RetrofitMode.proxy,
  _ConnectMode.virtualShiftingBluetooth => RetrofitMode.bluetooth,
  _ConnectMode.virtualShiftingWifi => RetrofitMode.wifi,
};

class ConnectionCard extends StatefulWidget {
  final ProxyDevice device;
  const ConnectionCard({super.key, required this.device});

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  late RetrofitMode _pendingMode;

  /// Decided once at mount based on the starting retrofit mode: Proxy stays
  /// expanded (it's the diagnostic-friendly default), anything else mounts
  /// collapsed. Live mode switches never flip this — the picker shouldn't
  /// suddenly collapse out from under the user while they're using it.
  late final bool _useAccordion;

  @override
  void initState() {
    super.initState();
    // Read directly from settings (with the device's smart-trainer-aware
    // fallback) — the emulator's value defaults to RetrofitMode.proxy at
    // construction time, which would otherwise hide the VS-default for users
    // landing on the details page before tap-to-connect runs.
    final saved = core.settings.getRetrofitMode(
      widget.device.trainerKey,
      fallback: widget.device.defaultRetrofitMode,
    );
    if (saved == RetrofitMode.proxy) {
      _pendingMode = RetrofitMode.proxy;
    } else if (saved == RetrofitMode.bluetooth) {
      _pendingMode = RetrofitMode.bluetooth;
    } else {
      _pendingMode = _resolvedVirtualShiftingMode;
    }
    _useAccordion = saved != RetrofitMode.proxy;
  }

  /// Radio rows shown for the current setup. When the user has picked
  /// [Target.otherDevice], we expose both Bluetooth and WiFi as separate VS
  /// transports — `preferredBridgeTransport` only sees Trainer Connections,
  /// and apps like MyWhoosh that have no Bluetooth controller channel would
  /// otherwise never get a Bluetooth VS option, even though they happily pair
  /// with a BLE-advertised smart trainer. For [Target.thisDevice] / no target,
  /// keep the auto-resolved single VS row.
  List<_ConnectMode> get _connectModes {
    if (core.settings.getLastTarget() == Target.otherDevice) {
      return const [
        _ConnectMode.virtualShiftingWifi,
        _ConnectMode.virtualShiftingBluetooth,
        _ConnectMode.proxy,
      ];
    }
    return [
      switch (_resolvedVirtualShiftingMode) {
        RetrofitMode.bluetooth => _ConnectMode.virtualShiftingBluetooth,
        _ => _ConnectMode.virtualShiftingWifi,
      },
      _ConnectMode.proxy,
    ];
  }

  /// Resolves which concrete [RetrofitMode] the Virtual Shifting radio will
  /// switch into when picked. Mirrors the active Trainer Connections — BT wins
  /// over WiFi. Falls back to WiFi when no transport is enabled; the
  /// missing-transport hint is driven separately via [_hasUsableTransport].
  RetrofitMode get _resolvedVirtualShiftingMode {
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.wifi,
    };
  }

  /// Permissions that must be granted before the Bluetooth retrofit mode can
  /// start advertising. Empty list on platforms that don't gate BLE peripheral
  /// advertising behind a runtime permission (e.g. iOS).
  List<PlatformRequirement> get _bluetoothAdvertiseRequirements => [
    if (!kIsWeb && Platform.isAndroid) BluetoothAdvertiseRequirement(),
  ];

  /// Verify the Bluetooth-advertise permission before switching into or
  /// starting the Bluetooth retrofit mode. Returns true if all requirements
  /// are satisfied (granted already, or granted after prompting the user via
  /// the permission sheet). Returns false if the user declined.
  Future<bool> _ensureBluetoothAdvertisePermissions() async {
    final reqs = _bluetoothAdvertiseRequirements;
    if (reqs.isEmpty) return true;
    await Future.wait(reqs.map((r) => r.getStatus()));
    final notDone = reqs.filter((r) => !r.status).toList();
    if (notDone.isEmpty) return true;
    if (!mounted) return false;
    await openPermissionSheet(context, notDone);
    await Future.wait(reqs.map((r) => r.getStatus()));
    return reqs.every((r) => r.status);
  }

  Widget _radioCard(_ConnectMode m, ColorScheme cs) {
    final IconData iconData = _modeIcon(_retrofitModeOf(m));

    return RadioCard<_ConnectMode>(
      value: m,
      child: Row(
        spacing: 12,
        children: [
          Icon(iconData, size: 20, color: cs.mutedForeground),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  _connectModeLabel(m),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  _connectModeHint(m),
                  style: TextStyle(fontSize: 11, color: cs.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _connectModeLabel(_ConnectMode m) => switch (m) {
    _ConnectMode.proxy => AppLocalizations.of(context).proxyMode,
    _ConnectMode.virtualShiftingBluetooth ||
    _ConnectMode.virtualShiftingWifi => AppLocalizations.of(context).virtualShifting,
  };

  /// `true` when at least one Trainer Connection is enabled, OR the user has
  /// picked [Target.otherDevice] — in the latter case BikeControl can always
  /// advertise itself via BT/WiFi for the remote app, regardless of any
  /// Trainer Connection toggles.
  bool get _hasUsableTransport {
    if (core.settings.getLastTarget() == Target.otherDevice) return true;
    return core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections) != null;
  }

  String _connectModeHint(_ConnectMode m) {
    final hasTransport = _hasUsableTransport;
    return switch (m) {
      _ConnectMode.proxy => AppLocalizations.of(context).proxyModeHint,
      _ConnectMode.virtualShiftingBluetooth =>
        hasTransport
            ? AppLocalizations.of(context).virtualShiftingBluetoothHint
            : AppLocalizations.of(context).virtualShiftingTransportNeededHint,
      _ConnectMode.virtualShiftingWifi =>
        hasTransport
            ? AppLocalizations.of(context).virtualShiftingWifiHint
            : AppLocalizations.of(context).virtualShiftingTransportNeededHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final emulator = widget.device.emulator;
    return ValueListenableBuilder<bool>(
      valueListenable: widget.device.isStarting,
      builder: (context, starting, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: emulator.isStarted,
          builder: (context, started, _) {
            if (starting && !started) {
              return _connectingCard(emulator);
            }
            if (!widget.device.isConnected && !started) {
              return _disconnectedCard(emulator);
            }
            return _connectedCard(emulator);
          },
        );
      },
    );
  }

  Widget _connectingCard(DirconEmulator emulator) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Row(
        spacing: 12,
        children: [
          const SmallProgressIndicator(),
          Expanded(
            child: Text(
              AppLocalizations.of(context).connectingInMode(emulator.retrofitMode.value.label),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Color bg, required Color border, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _disconnectedCard(DirconEmulator emulator) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Text(
            AppLocalizations.of(context).connectModeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: cs.mutedForeground,
            ),
          ),
          RadioGroup<_ConnectMode>(
            value: _connectModeOf(_pendingMode),
            onChanged: (m) async {
              final RetrofitMode next = _retrofitModeOf(m);
              setState(() => _pendingMode = next);
              await core.settings.setRetrofitMode(widget.device.trainerKey, next);
            },
            child: Column(
              spacing: 8,
              children: [
                for (final m in _connectModes) _radioCard(m, cs),
              ],
            ),
          ),
          LoadingWidget(
            futureCallback: () async {
              if (IAPManager.instance.isTrialExpired) {
                await showGoProDialog(context);
                return;
              }
              final RetrofitMode next = _pendingMode;
              if (next == RetrofitMode.bluetooth) {
                final ok = await _ensureBluetoothAdvertisePermissions();
                if (!ok) return;
              }
              emulator.setRetrofitMode(next);
              await core.settings.setRetrofitMode(widget.device.trainerKey, next);
              await core.settings.setAutoConnect(widget.device.trainerKey, true);
              await widget.device.startProxy();
            },
            renderChild: (isLoading, tap) => Button.primary(
              onPressed: tap,
              child: isLoading ? SmallProgressIndicator() : Text(AppLocalizations.of(context).connect),
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectedCard(DirconEmulator emulator) {
    return ValueListenableBuilder<RetrofitMode>(
      valueListenable: emulator.retrofitMode,
      builder: (context, mode, _) {
        if (_useAccordion) {
          return _modePickerAccordion(mode);
        }
        return _modePickerCompact(mode);
      },
    );
  }

  Widget _modePickerAccordion(RetrofitMode mode) {
    return ComponentTheme<DividerTheme>(
      data: DividerTheme(
        color: Colors.transparent,
      ),
      child: Accordion(
        items: [
          AccordionItem(
            trigger: AccordionTrigger(
              child: _bridgeStatusRow(mode),
            ),
            content: _modePickerCompact(mode),
          ),
        ],
      ),
    );
  }

  /// Bridge (trainer-app-side) connection status used as the accordion trigger.
  /// Green dot when the trainer app has connected to our advertised bridge,
  /// muted otherwise — same data the Overview row surfaces, just inlined here
  /// so the collapsed accordion still tells the user whether something is
  /// listening on the wire.
  Widget _bridgeStatusRow(RetrofitMode mode) {
    final emulator = widget.device.emulator;
    final connected = emulator.isConnected.value;
    final started = emulator.isStarted.value;
    final IconData icon = switch (mode) {
      RetrofitMode.bluetooth => LucideIcons.bluetooth,
      RetrofitMode.wifi => LucideIcons.wifi,
      RetrofitMode.proxy => LucideIcons.radioTower,
    };
    final advertisement = emulator.advertisementName;
    final subtitle = AppLocalizations.of(context).chooseBikeControlInConnectionScreen.replaceAll(
      screenshotMode ? '1337' : 'BikeControl',
      advertisement,
    );
    final title = 'Bridge (${widget.device.toString()})';
    return Basic(
      leading: StatusIcon(icon: icon, status: connected, started: started),
      title: connected ? Text(title).small.semiBold : Text(title).small.muted,
      subtitle: Text(subtitle).xSmall.textMuted,
    );
  }

  Widget _modePickerCompact(RetrofitMode active) {
    final cs = Theme.of(context).colorScheme;
    return _card(
      bg: cs.card,
      border: cs.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            AppLocalizations.of(context).connectModeLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: cs.mutedForeground),
          ),
          RadioGroup<_ConnectMode>(
            value: _connectModeOf(active),
            onChanged: (m) async {
              final RetrofitMode next = _retrofitModeOf(m);
              if (next == active) return;
              if (next == RetrofitMode.bluetooth) {
                final ok = await _ensureBluetoothAdvertisePermissions();
                if (!ok) return;
              }
              await core.settings.setRetrofitMode(widget.device.trainerKey, next);
              setState(() => _pendingMode = next);
              try {
                // The emulator seeds any freshly-created FitnessBikeDefinition
                // synchronously via ProxyDevice.onFitnessBikeDefinitionCreated,
                // so by the time switchRetrofitMode returns the new transport
                // is already running against the user's active ShiftingConfig.
                await widget.device.emulator.switchRetrofitMode(next);
              } catch (e) {
                if (kDebugMode) print('switchRetrofitMode failed: $e');
              }
            },
            child: Column(
              spacing: 8,
              children: [
                for (final m in _connectModes) _radioCard(m, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(RetrofitMode mode) => switch (mode) {
    RetrofitMode.proxy => LucideIcons.radioTower,
    RetrofitMode.wifi => LucideIcons.wifi,
    RetrofitMode.bluetooth => LucideIcons.bluetooth,
  };
}
