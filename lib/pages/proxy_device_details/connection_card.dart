import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:bike_control/widgets/ui/loading_widget.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/emulators/dircon_emulator.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

enum _ConnectMode { proxy, virtualShifting }

_ConnectMode _connectModeOf(RetrofitMode mode) =>
    mode == RetrofitMode.proxy ? _ConnectMode.proxy : _ConnectMode.virtualShifting;

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
    } else {
      _pendingMode = _resolvedVirtualShiftingMode ?? RetrofitMode.wifi;
    }
    _useAccordion = saved != RetrofitMode.proxy;
  }

  List<_ConnectMode> get _connectModes => const [
        _ConnectMode.proxy,
        _ConnectMode.virtualShifting,
      ];

  /// Resolves which concrete [RetrofitMode] the Virtual Shifting radio will
  /// switch into when picked. Mirrors the active Trainer Connections — BT wins
  /// over WiFi. Returns `null` when neither transport is enabled, in which
  /// case the VS radio renders disabled and the missing-transport hint shows.
  RetrofitMode? get _resolvedVirtualShiftingMode {
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => null,
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
    final RetrofitMode? resolved = m == _ConnectMode.proxy
        ? RetrofitMode.proxy
        : _resolvedVirtualShiftingMode;
    final IconData iconData = resolved == null
        ? LucideIcons.cog
        : _modeIcon(resolved);
    final bool disabled = m == _ConnectMode.virtualShifting && resolved == null;

    return RadioCard<_ConnectMode>(
      value: m,
      enabled: !disabled,
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
        _ConnectMode.virtualShifting => AppLocalizations.of(context).virtualShifting,
      };

  String _connectModeHint(_ConnectMode m) => switch (m) {
        _ConnectMode.proxy => AppLocalizations.of(context).proxyModeHint,
        _ConnectMode.virtualShifting => switch (_resolvedVirtualShiftingMode) {
            RetrofitMode.bluetooth => AppLocalizations.of(context).virtualShiftingBluetoothHint,
            RetrofitMode.wifi => AppLocalizations.of(context).virtualShiftingWifiHint,
            _ => AppLocalizations.of(context).virtualShiftingTransportNeededHint,
          },
      };

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
              final RetrofitMode? next = m == _ConnectMode.proxy
                  ? RetrofitMode.proxy
                  : _resolvedVirtualShiftingMode;
              if (next == null) return;
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
              final connectMode = _connectModeOf(_pendingMode);
              final RetrofitMode? next = connectMode == _ConnectMode.proxy
                  ? RetrofitMode.proxy
                  : _resolvedVirtualShiftingMode;
              if (next == null) return;
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
    final cs = Theme.of(context).colorScheme;
    return ComponentTheme<DividerTheme>(
      data: DividerTheme(
        color: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 15.0),
        child: Accordion(
          items: [
            AccordionItem(
              trigger: AccordionTrigger(
                child: Row(
                  spacing: 10,
                  children: [
                    Icon(_modeIcon(mode), size: 16, color: cs.mutedForeground),
                    Text(
                      AppLocalizations.of(context).connectModeActive(mode.label),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              content: _modePickerCompact(mode),
            ),
          ],
        ),
      ),
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
              final RetrofitMode? next = m == _ConnectMode.proxy
                  ? RetrofitMode.proxy
                  : _resolvedVirtualShiftingMode;
              if (next == null) return;
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
