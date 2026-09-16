import 'dart:io';

import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show SupportedApp, TrainerConnectionType;
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/go_pro_dialog.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show openPermissionSheet;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:prop/prop.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Explains BikeControl's virtual shifting versus the trainer app's own, so
/// the user can pick a connect mode with the trade-offs in hand.
const _helpMeDecideUrl = 'https://bikecontrol.app/blog/virtual-shifting-with-and-without-bikecontrol';

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
  /// should start in: the last saved VS transport if there is one (already
  /// folded into WiFi on a same-device setup, see
  /// [ProxyDevice.savedRetrofitMode]), otherwise the transport mirrored from
  /// the active Trainer Connections (BT wins over WiFi, WiFi when nothing is
  /// enabled).
  RetrofitMode get _initialVsTransport {
    final saved = widget.device.savedRetrofitMode;
    if (saved == RetrofitMode.bluetooth || saved == RetrofitMode.wifi) {
      return _vsTransports.contains(saved) ? saved : _vsTransports.first;
    }
    return _resolvedVirtualShiftingMode;
  }

  /// Whether the trainer app runs on this same device. A Bluetooth bridge can
  /// never be found from the device advertising it — a BLE peripheral is
  /// invisible to a central on the same adapter — so Bluetooth is not a
  /// Virtual Shifting transport here. (Only WiFi loops back.)
  bool get _isSameDevice => core.settings.getLastTarget() == Target.thisDevice;

  /// Whether the rider's saved Bluetooth choice for this trainer is being
  /// overridden by [_isSameDevice]. Read fresh on every build: it clears the
  /// moment a WiFi connect persists WiFi, or the target moves off this device.
  bool get _sameDeviceOverridesBluetooth =>
      _isSameDevice &&
      core.settings.getRetrofitMode(widget.device.trainerKey, fallback: RetrofitMode.proxy) == RetrofitMode.bluetooth;

  /// The Virtual Shifting transports the selected trainer app can actually find
  /// our trainer on, in the order the toggle offers them. Both for nearly every
  /// app; a single entry hides the toggle rather than offering a dead end.
  List<RetrofitMode> get _vsTransports {
    final supported = core.settings.getTrainerApp()?.virtualShiftingTransports;
    final modes = [
      if (supported?.contains(TrainerConnectionType.wifi) ?? true) RetrofitMode.wifi,
      if (supported?.contains(TrainerConnectionType.bluetooth) ?? true) RetrofitMode.bluetooth,
    ];
    // An app declaring no transport at all would leave the rider with no way to
    // connect; offer both rather than render an empty toggle.
    if (modes.isEmpty) modes.addAll(const [RetrofitMode.wifi, RetrofitMode.bluetooth]);
    // Same device: Bluetooth is a dead end whatever the app declares — even an
    // app that only pairs over Bluetooth (FulGaz) leaves WiFi as the one
    // transport this card can honestly offer.
    if (_isSameDevice) modes.remove(RetrofitMode.bluetooth);
    return modes.isEmpty ? const [RetrofitMode.wifi] : modes;
  }

  /// Mirrors the active Trainer Connections — BT wins over WiFi, WiFi as the
  /// fallback when no transport is enabled — then falls back to whatever the
  /// trainer app can actually receive.
  RetrofitMode get _resolvedVirtualShiftingMode {
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    final mode = switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.wifi,
    };
    return _vsTransports.contains(mode) ? mode : _vsTransports.first;
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
  ///
  /// Reads this device's own state wrappers, not `emulator.*`: in the VS
  /// modes the emulator is the one shared bridge, and a twin entry (the same
  /// trainer over the other transport) released in a path switch keeps
  /// pointing at it — its page would light up with the live twin's bridge.
  Widget _bridgeStatusRow(RetrofitMode mode, _ConnectSelection selection, bool connecting) {
    final connected = widget.device.isConnectedListenable.value;
    final started = widget.device.isStartedListenable.value;
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
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).connectModeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: cs.mutedForeground,
                  ),
                ),
              ),
              // Links out to the blog post comparing BikeControl's virtual
              // shifting against the trainer app's own — the decision this
              // picker is asking the user to make.
              Button(
                style: const ButtonStyle.text(size: ButtonSize.small, density: ButtonDensity.compact),
                onPressed: () => launchUrlString(_helpMeDecideUrl, mode: LaunchMode.externalApplication),
                child: Text(AppLocalizations.of(context).helpMeDecide, style: const TextStyle(fontSize: 12)),
              ),
            ],
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
    // The rider chose Bluetooth for this trainer, but the toggle no longer
    // offers it: say why the row runs over WiFi instead of silently dropping
    // their choice. Plain muted text — nothing to dismiss, it goes away on its
    // own once WiFi is persisted or the app moves to another device. Not
    // while a Bluetooth bridge is actually live (see [_transportToggle]) —
    // "using WiFi" would be untrue.
    final bool liveOverBluetooth = active == _ConnectSelection.virtualShifting && mode == RetrofitMode.bluetooth;
    final bool showSameDeviceNote =
        s == _ConnectSelection.virtualShifting && _sameDeviceOverridesBluetooth && !liveOverBluetooth;
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
                if (showSameDeviceNote)
                  Text(
                    AppLocalizations.of(context).vsTransportSameDeviceNote,
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
  /// Collapses to a plain label when only one transport is on offer (an app
  /// that takes a single one, see [SupportedApp.virtualShiftingTransports], or
  /// a same-device setup) — there is nothing to pick.
  ///
  /// The transport actually running is always shown, even when it is not on
  /// offer (the target moved to this device while a Bluetooth bridge was
  /// live): the toggle never claims a transport the bridge is not on, and the
  /// offered one stays tappable as the way out.
  Widget _transportToggle(RetrofitMode active) {
    final l10n = AppLocalizations.of(context);
    final offered = _vsTransports;
    final shown = [
      for (final t in const [RetrofitMode.wifi, RetrofitMode.bluetooth])
        if (offered.contains(t) || t == active) t,
    ];
    Widget button(RetrofitMode t) => _transportButton(
      t,
      t == RetrofitMode.bluetooth ? LucideIcons.bluetooth : LucideIcons.wifi,
      t == RetrofitMode.bluetooth ? l10n.connectionBluetooth : l10n.connectionWifi,
      shown.length < 2 || t == active,
    );
    if (shown.length < 2) return button(shown.first);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [button(shown.first), const SizedBox(width: 6), button(shown.last)],
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
