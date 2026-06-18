import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/smart_trainer_consent_dialog.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The selectable connection entries in the picker. Virtual Shifting is a single
/// consolidated row whose WiFi/Bluetooth transport is switched via an inline
/// toggle; [none] disconnects and lets the trainer app drive shifting itself.
enum _ConnectSelection { virtualShifting, proxy, none }

class ConnectionCard extends StatefulWidget {
  final ProxyDevice device;
  const ConnectionCard({super.key, required this.device});

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  static const List<_ConnectSelection> _selections = [
    _ConnectSelection.virtualShifting,
    _ConnectSelection.proxy,
    _ConnectSelection.none,
  ];

  /// Whether the picker accordion is open. Starts expanded when the user lands
  /// disconnected (options visible), collapsed when they arrive already
  /// connected. A user-initiated connect keeps it open across the brief
  /// "connecting" teardown so it doesn't collapse out from under them; after
  /// that the accordion's own trigger drives expand/collapse.
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !(widget.device.isConnected || widget.device.isStartedListenable.value);
  }

  /// Resolves which concrete Virtual Shifting [RetrofitMode] a fresh connect
  /// should start in: the last saved VS transport if there is one, otherwise the
  /// transport mirrored from the active Trainer Connections (BT wins over WiFi,
  /// WiFi when nothing is enabled).
  RetrofitMode get _initialVsTransport {
    final saved = core.settings.getRetrofitMode(
      widget.device.trainerKey,
      fallback: widget.device.defaultRetrofitMode,
    );
    if (saved == RetrofitMode.bluetooth || saved == RetrofitMode.wifi) return saved;
    return _resolvedVirtualShiftingMode;
  }

  /// Mirrors the active Trainer Connections — BT wins over WiFi, WiFi as the
  /// fallback when no transport is enabled.
  RetrofitMode get _resolvedVirtualShiftingMode {
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.wifi,
    };
  }

  /// `true` when at least one Trainer Connection is enabled, OR the user has
  /// picked [Target.otherDevice] — in the latter case BikeControl can always
  /// advertise itself via BT/WiFi for the remote app, regardless of any
  /// Trainer Connection toggles.
  bool get _hasUsableTransport {
    if (core.settings.getLastTarget() == Target.otherDevice) return true;
    return core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections) != null;
  }

  String get _trainerAppName => core.settings.getTrainerApp()?.name ?? AppLocalizations.of(context).yourTrainerApp;

  /// Permissions that must be granted before the Bluetooth retrofit mode can
  /// start advertising. Empty list on platforms that don't gate BLE peripheral
  /// advertising behind a runtime permission (e.g. iOS).
  List<PlatformRequirement> get _bluetoothAdvertiseRequirements => [
    if (!kIsWeb && Platform.isAndroid) BluetoothAdvertiseRequirement(),
  ];

  /// Verify the Bluetooth-advertise permission before switching into or starting
  /// the Bluetooth retrofit mode. Returns true if all requirements are satisfied
  /// (already granted, or granted after prompting). False if the user declined.
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

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Handles a radio selection. Selecting "No connection" disconnects the
  /// device (staying on the page); selecting any other entry connects — gated,
  /// for smart trainers, behind the trial + one-time takeover-consent dialog.
  Future<void> _onSelect(_ConnectSelection selection) async {
    final device = widget.device;
    final bool connected = device.isConnected || device.isStartedListenable.value;

    if (selection == _ConnectSelection.none) {
      if (connected) {
        await core.settings.setAutoConnect(device.trainerKey, false);
        // Disconnect in place: keep this device registered (and on the page) so
        // the user can pick Virtual Shifting / Proxy again on the same object.
        await core.connection.disconnect(device, forget: false, persistForget: false, keepInList: true);
      }
      return;
    }

    // Keep the picker open through the connect and its brief "connecting"
    // teardown so the accordion doesn't collapse out from under the user.
    if (!_expanded) setState(() => _expanded = true);

    if (IAPManager.instance.isTrialExpired) {
      await showGoProDialog(context);
      return;
    }

    if (device.isSmartTrainer && !core.settings.getSmartTrainerConsent(device.trainerKey)) {
      final confirmed = await showSmartTrainerConsentDialog(
        context,
        trainerName: device.trainerKey,
        appName: _trainerAppName,
      );
      if (!confirmed) return;
      await core.settings.setSmartTrainerConsent(device.trainerKey, true);
      if (!mounted) return;
    }

    final RetrofitMode next = selection == _ConnectSelection.proxy ? RetrofitMode.proxy : _initialVsTransport;
    if (next == RetrofitMode.bluetooth) {
      final ok = await _ensureBluetoothAdvertisePermissions();
      if (!ok) return;
    }

    if (connected) {
      if (device.retrofitMode.value == next) return;
      await core.settings.setRetrofitMode(device.trainerKey, next);
      try {
        await device.switchRetrofitMode(next);
      } catch (e, s) {
        core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Error: ${e.toString()}'));
        recordError(e, s, context: 'Retrofit Switch');
      }
    } else {
      device.setRetrofitMode(next);
      await core.settings.setRetrofitMode(device.trainerKey, next);
      await core.settings.setAutoConnect(device.trainerKey, true);
      // Route through the connection manager (not device.startProxy directly) so
      // the action / connection-state listeners are re-attached. After an
      // in-place "No connection" disconnect those listeners are gone, and a bare
      // startProxy reconnects BLE but never flips isConnected — the connect
      // appears to hang.
      await core.connection.connectDevice(device);
    }
  }

  /// Switches the live Virtual Shifting transport via the inline WiFi/BT toggle.
  /// Only reachable while VS is the active (connected) mode.
  Future<void> _onVsTransport(RetrofitMode transport) async {
    final device = widget.device;
    if (device.retrofitMode.value == transport) return;
    if (transport == RetrofitMode.bluetooth) {
      final ok = await _ensureBluetoothAdvertisePermissions();
      if (!ok) return;
    }
    await core.settings.setRetrofitMode(device.trainerKey, transport);
    try {
      await device.switchRetrofitMode(transport);
    } catch (e, s) {
      core.connection.signalNotification(AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Error: ${e.toString()}'));
      recordError(e, s, context: 'Retrofit Switch');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.device.isStarting,
      builder: (context, starting, _) {
        return ValueListenableBuilder<bool>(
          // Use the stable ProxyDevice wrapper so this stays live across
          // proxy ↔ VS emulator swaps.
          valueListenable: widget.device.isStartedListenable,
          builder: (context, started, _) {
            return ValueListenableBuilder<RetrofitMode>(
              valueListenable: widget.device.retrofitMode,
              builder: (context, mode, _) {
                // While connecting/switching we keep the bridge accordion mounted
                // and surface progress inline (a spinner in the status icon),
                // rather than swapping the whole card for a placeholder.
                final bool connecting = starting && !started;
                final bool connected = widget.device.isConnected || started;
                final _ConnectSelection selection = (!connected && !connecting)
                    ? _ConnectSelection.none
                    : switch (mode) {
                        RetrofitMode.proxy => _ConnectSelection.proxy,
                        RetrofitMode.wifi || RetrofitMode.bluetooth => _ConnectSelection.virtualShifting,
                      };
                return _modePickerAccordion(selection, mode, connecting: connecting, expanded: _expanded);
              },
            );
          },
        );
      },
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

  Widget _modePickerAccordion(
    _ConnectSelection selection,
    RetrofitMode mode, {
    required bool connecting,
    required bool expanded,
  }) {
    return ComponentTheme<DividerTheme>(
      data: DividerTheme(color: Colors.transparent),
      child: Accordion(
        items: [
          AccordionItem(
            expanded: expanded,
            trigger: AccordionTrigger(child: _bridgeStatusRow(mode, selection, connecting)),
            content: _modePicker(selection, mode),
          ),
        ],
      ),
    );
  }

  /// Bridge (trainer-app-side) connection status used as the accordion trigger.
  /// Green dot when the trainer app has connected to our advertised bridge,
  /// a spinner while connecting/switching, muted otherwise.
  Widget _bridgeStatusRow(RetrofitMode mode, _ConnectSelection selection, bool connecting) {
    final emulator = widget.device.emulator;
    final connected = emulator.isConnected.value;
    final started = emulator.isStarted.value;
    final IconData icon = switch (mode) {
      RetrofitMode.bluetooth => LucideIcons.bluetooth,
      RetrofitMode.wifi => LucideIcons.wifi,
      RetrofitMode.proxy => LucideIcons.radioTower,
    };
    final l10n = AppLocalizations.of(context);
    // "No connection" selected → nothing is advertising, so the
    // "Choose BikeControl …" instruction doesn't apply; say "Not connected".
    final String subtitle = selection == _ConnectSelection.none
        ? l10n.notConnected
        : l10n.chooseBikeControlInConnectionScreen.replaceAll(
            screenshotMode ? '1337' : 'BikeControl',
            widget.device.advertisementName,
          );
    final title = 'Bridge (${widget.device.toString()})';
    return Basic(
      leading: StatusIcon(icon: icon, status: connected, started: started || connecting),
      title: connected ? Text(title).small.semiBold : Text(title).small.muted,
      subtitle: Text(subtitle).xSmall.textMuted,
    );
  }

  Widget _modePicker(_ConnectSelection selection, RetrofitMode mode) {
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: cs.mutedForeground,
            ),
          ),
          RadioGroup<_ConnectSelection>(
            value: selection,
            onChanged: (s) => _onSelect(s),
            child: Column(
              spacing: 8,
              children: [
                for (final s in _selections) _radioCard(s, selection, mode, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radioCard(
    _ConnectSelection s,
    _ConnectSelection active,
    RetrofitMode mode,
    ColorScheme cs,
  ) {
    final bool showToggle = s == _ConnectSelection.virtualShifting && active == _ConnectSelection.virtualShifting;
    return RadioCard<_ConnectSelection>(
      value: s,
      child: Row(
        spacing: 12,
        children: [
          Icon(_selectionIcon(s), size: 20, color: cs.mutedForeground),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  _selectionLabel(s),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  _selectionHint(s),
                  style: TextStyle(fontSize: 11, color: cs.mutedForeground),
                ),
              ],
            ),
          ),
          if (showToggle) _transportToggle(mode),
        ],
      ),
    );
  }

  /// Inline WiFi/Bluetooth toggle shown inside the active Virtual Shifting row.
  Widget _transportToggle(RetrofitMode active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _transportButton(RetrofitMode.wifi, LucideIcons.wifi, 'WiFi', active == RetrofitMode.wifi),
        const SizedBox(width: 6),
        _transportButton(
          RetrofitMode.bluetooth,
          LucideIcons.bluetooth,
          'BT',
          active == RetrofitMode.bluetooth,
        ),
      ],
    );
  }

  Widget _transportButton(RetrofitMode transport, IconData icon, String label, bool active) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(icon, size: 13),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    if (active) {
      return Button(
        style: ButtonStyle.primary(size: ButtonSize.small),
        onPressed: () {},
        child: child,
      );
    }
    return Button(
      style: ButtonStyle.outline(size: ButtonSize.small),
      onPressed: () => _onVsTransport(transport),
      child: child,
    );
  }

  String _selectionLabel(_ConnectSelection s) => switch (s) {
    _ConnectSelection.virtualShifting => AppLocalizations.of(context).virtualShifting,
    _ConnectSelection.proxy => AppLocalizations.of(context).proxyMode,
    _ConnectSelection.none => AppLocalizations.of(context).noConnection,
  };

  String _selectionHint(_ConnectSelection s) {
    final l10n = AppLocalizations.of(context);
    return switch (s) {
      _ConnectSelection.virtualShifting =>
        _hasUsableTransport ? l10n.virtualShiftingHint : l10n.virtualShiftingTransportNeededHint,
      _ConnectSelection.proxy => l10n.proxyModeHint,
      _ConnectSelection.none => l10n.noConnectionHint(_trainerAppName),
    };
  }

  IconData _selectionIcon(_ConnectSelection s) => switch (s) {
    _ConnectSelection.virtualShifting => LucideIcons.arrowLeftRight,
    _ConnectSelection.proxy => LucideIcons.radioTower,
    _ConnectSelection.none => LucideIcons.unplug,
  };
}
