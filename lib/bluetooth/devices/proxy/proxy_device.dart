import 'dart:async';

import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:flutter/foundation.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/utils/actions/base_actions.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart' show TrainerConnectionType;
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/units.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/emulators/definitions/proxy_bike_definition.dart';
import 'package:prop/prop.dart' hide TrainerMode;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';

class ProxyDevice extends BluetoothDevice {
  static final List<String> proxyServiceUUIDs = [
    FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID, // Heart Rate
    FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID, // Heart Rate
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID, // Fitness Machine
  ];

  /// Per-instance emulator used exclusively in proxy mode. Each proxy-mode
  /// trainer needs its own mDNS identity / peripheral so they are independent.
  final DirconEmulator _proxyEmulator = DirconEmulator();

  /// Active emulator for this device. In proxy mode → own per-instance
  /// emulator; in VS modes → shared global [ftmsEmulator].
  DirconEmulator get emulator =>
      _retrofitModeN.value == RetrofitMode.proxy ? _proxyEmulator : ftmsEmulator;

  final ValueChangeNotifier<String> onChange = ValueChangeNotifier('');

  /// True while the initial BLE connect + service discovery for this proxy is
  /// in flight. The emulator's `isStarted` only flips once startServer runs
  /// (after services are discovered); UI that needs to render a "Connecting…"
  /// state between tap and first successful start should watch this instead.
  final ValueNotifier<bool> isStarting = ValueNotifier(false);

  // ── Stable state wrappers ─────────────────────────────────────────────────
  // These mirror whichever emulator is currently active. Because the active
  // emulator can change on a mode swap, the UI should bind to these
  // ProxyDevice-level listenables instead of directly to emulator.X, so
  // bindings survive mode transitions.

  final ValueNotifier<RetrofitMode> _retrofitModeN = ValueNotifier(RetrofitMode.proxy);

  /// The current retrofit mode. Stays stable across emulator swaps.
  ValueListenable<RetrofitMode> get retrofitMode => _retrofitModeN;

  final ValueNotifier<bool> _isStartedN = ValueNotifier(false);

  /// Whether the active emulator has started. Stable across mode swaps.
  ValueListenable<bool> get isStartedListenable => _isStartedN;

  final ValueNotifier<bool> _isConnectedN = ValueNotifier(false);

  /// Whether a trainer app is connected via the active emulator. Stable across
  /// mode swaps.
  ValueListenable<bool> get isConnectedListenable => _isConnectedN;

  final ValueNotifier<String?> _localAddressN = ValueNotifier(null);

  /// Local IPv4 address currently advertised, if any. Stable across mode swaps.
  ValueListenable<String?> get localAddress => _localAddressN;

  /// The [FitnessBikeDefinition] for this trainer while in VS mode. Attached
  /// to [ftmsEmulator]'s composite while VS is active; null in proxy mode.
  FitnessBikeDefinition? _fbd;
  FitnessBikeDefinition? get fitnessBike => _fbd;

  /// Services captured at [handleServices] time — needed to reconstruct the
  /// [FitnessBikeDefinition] when entering VS mode.
  List<BleService>? _services;

  /// Which emulator we currently have listeners registered on. Used by
  /// [_bindToActiveEmulator] to remove stale listeners.
  DirconEmulator? _currentlyListening;

  StreamSubscription<void>? _bridgeBudgetSub;

  /// Latest [FitnessBikeDefinition] handed to us via
  /// [DirconEmulator.onFitnessBikeDefinitionCreated]. In VS mode this is the
  /// same as [_fbd]. Kept separate so the bridge-usage tracker can read live
  /// trainer activity via [_isTrainerActive].
  FitnessBikeDefinition? _currentFbd;

  ProxyDevice(super.scanResult)
    : super(
        availableButtons: const [],
        icon: _iconFor(scanResult),
        isBeta: true,
      ) {
    _configureProxyEmulator();
    _bindToActiveEmulator();
  }

  void _configureProxyEmulator() {
    _proxyEmulator.onFitnessBikeDefinitionCreated = _seedFitnessBikeDefinition;
    _proxyEmulator.isTrial = () => !IAPManager.instance.isProEnabledForCurrentDevice;
    _proxyEmulator.shouldAdvertise = () => !_isBridgeTrialOver;
    _proxyEmulator.trainerName = () => core.settings.getTrainerApp()?.name ?? 'BikeControl';
  }

  void _configureSharedEmulator() {
    ftmsEmulator.onFitnessBikeDefinitionCreated = _seedFitnessBikeDefinition;
    ftmsEmulator.isTrial = () => !IAPManager.instance.isProEnabledForCurrentDevice;
    ftmsEmulator.shouldAdvertise = () => !_isBridgeTrialOver;
    ftmsEmulator.trainerName = () => core.settings.getTrainerApp()?.name ?? 'BikeControl';
  }

  /// Mirror the active emulator's state notifiers into our stable wrappers.
  /// Removes listeners from the previous emulator (if any) before re-binding.
  void _bindToActiveEmulator() {
    final prev = _currentlyListening;
    if (prev != null) {
      prev.isStarted.removeListener(_mirrorIsStarted);
      prev.isConnected.removeListener(_mirrorIsConnected);
      prev.localAddress.removeListener(_mirrorLocalAddress);
      prev.retrofitMode.removeListener(_mirrorRetrofitMode);
      prev.isConnected.removeListener(_syncBridgeTracking);
      prev.retrofitMode.removeListener(_syncBridgeTracking);
    }

    final active = emulator;
    _currentlyListening = active;
    active.isStarted.addListener(_mirrorIsStarted);
    active.isConnected.addListener(_mirrorIsConnected);
    active.localAddress.addListener(_mirrorLocalAddress);
    active.retrofitMode.addListener(_mirrorRetrofitMode);
    active.isConnected.addListener(_syncBridgeTracking);
    active.retrofitMode.addListener(_syncBridgeTracking);

    // Immediately mirror current values.
    _mirrorIsStarted();
    _mirrorIsConnected();
    _mirrorLocalAddress();
    _mirrorRetrofitMode();
  }

  void _mirrorIsStarted() => _isStartedN.value = emulator.isStarted.value;
  void _mirrorIsConnected() => _isConnectedN.value = emulator.isConnected.value;
  void _mirrorLocalAddress() => _localAddressN.value = emulator.localAddress.value;
  void _mirrorRetrofitMode() => _retrofitModeN.value = emulator.retrofitMode.value;

  void _syncBridgeTracking() {
    final isBridgeSession =
        _isConnectedN.value && _retrofitModeN.value != RetrofitMode.proxy;
    final isPro = IAPManager.instance.isProEnabledForCurrentDevice;
    if (isBridgeSession && !isPro) {
      if (core.bridgeUsageTracker.isExhausted) {
        // Already at the daily limit — pause advertising so no new clients can
        // discover us, but keep the transport pipeline + upstream BLE alive.
        scheduleMicrotask(() => unawaited(emulator.pauseAdvertising()));
        return;
      }
      core.bridgeUsageTracker.startSession(isActive: _isTrainerActive);
      _bridgeBudgetSub ??= core.bridgeUsageTracker.onBudgetExhausted.listen((_) {
        scheduleMicrotask(() => unawaited(emulator.pauseAdvertising()));
        _announceBridgeTrialOver();
      });
    } else {
      core.bridgeUsageTracker.stopSession();
    }
  }

  /// True when the current retrofit mode needs a Bridge transport (wifi /
  /// bluetooth) but the non-Pro user has already burned today's 20-minute
  /// budget. Proxy mode is unaffected.
  bool get _isBridgeTrialOver {
    if (_retrofitModeN.value == RetrofitMode.proxy) return false;
    if (IAPManager.instance.isProEnabledForCurrentDevice) return false;
    return core.bridgeUsageTracker.isExhausted;
  }

  void _announceBridgeTrialOver() {
    final title = AppLocalizations.current.bridgeTrialTimeOverTitle;
    final body = AppLocalizations.current.bridgeTrialTimeOverBody;
    core.connection.signalNotification(
      AlertNotification(LogLevel.LOGLEVEL_WARNING, '$title — $body'),
    );
    core.flutterLocalNotificationsPlugin.show(
      1340,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('BridgeTrial', 'Bridge Trial Status'),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  void _seedFitnessBikeDefinition(FitnessBikeDefinition def) {
    _currentFbd = def;
    // Also update _fbd when in VS mode (the shared emulator creates the FBD).
    if (_retrofitModeN.value != RetrofitMode.proxy) {
      _fbd = def;
    }
    final cfg = core.shiftingConfigs.activeFor(trainerKey);
    def.setMaxGear(cfg.maxGear);
    def.setBicycleWeightKg(cfg.bikeWeightKg);
    def.setRiderWeightKg(cfg.riderWeightKg);
    def.setGradeSmoothingEnabled(cfg.gradeSmoothing);
    def.setCadenceFilterEnabled(cfg.cadenceFilterEnabled);
    def.setVirtualShiftingMode(cfg.mode);
    if (cfg.gearRatios != null) {
      def.setGearRatios(cfg.gearRatios!);
    }
  }

  /// Is the connected trainer reporting any sign of riding right now? Used to
  /// gate the bridge-usage tracker so coast / paused minutes don't burn the
  /// non-Pro daily budget. Any of cadence, speed or power being non-zero is
  /// enough; null values (no trainer notification yet) count as idle.
  bool _isTrainerActive() {
    final fbd = _currentFbd;
    if (fbd == null) return false;
    if ((fbd.cadenceRpm.value ?? 0) > 0) return true;
    if ((fbd.speedKph.value ?? 0) > 0) return true;
    if ((fbd.powerW.value ?? 0) > 0) return true;
    return false;
  }

  static IconData _iconFor(BleDevice scanResult) {
    final services = scanResult.services.map((s) => s.toLowerCase()).toSet();

    if (services.contains(FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase())) {
      return LucideIcons.bike;
    }
    if (services.contains(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase())) {
      return LucideIcons.zap;
    }
    if (services.contains(FitnessBikeDefinition.HEART_RATE_MEASUREMENT_UUID.toLowerCase())) {
      return LucideIcons.heart;
    }
    return LucideIcons.bike;
  }

  @override
  Future<void> handleServices(List<BleService> services) async {
    _services = services;
    final mode = _retrofitModeN.value;

    try {
      if (mode == RetrofitMode.proxy) {
        _proxyEmulator.setScanResult(scanResult);
        _proxyEmulator.handleServices(services);
        await _proxyEmulator.startServer();
      } else {
        // VS modes (wifi / bluetooth): the FBD lives in the shared
        // ftmsEmulator. setScanResult / handleServices on the shared one
        // give it this trainer's identity for mDNS advertising.
        _configureSharedEmulator();
        ftmsEmulator.setScanResult(scanResult);
        ftmsEmulator.handleServices(services);
        ftmsEmulator.setRetrofitMode(mode);
        if (!ftmsEmulator.isStarted.value) {
          await ftmsEmulator.startServer();
        } else if (ftmsEmulator.retrofitMode.value != mode) {
          await ftmsEmulator.switchRetrofitMode(mode);
        }
        _fbd = ftmsEmulator.fitnessBike;
      }

      applyTrainerSettings();
      // Read the trainer's FTMS Feature map proactively so the UI can gate
      // virtual-shifting options and the feedback payload can report it. Runs
      // off the critical path — failures just leave trainerFeature null.
      final def = emulator.fitnessBike;
      if (def != null) unawaited(def.probeTrainerFeatures());
      onChange.value = 'Connected to ${scanResult.name}';

      if (_isBridgeTrialOver) {
        _announceBridgeTrialOver();
      }
    } catch (e) {
      core.connection.signalNotification(
        AlertNotification(LogLevel.LOGLEVEL_ERROR, 'Failed to start emulator: $e'),
      );
      onChange.value = 'Failed to start emulator: $e';
      if (mode == RetrofitMode.proxy) {
        _proxyEmulator.stop();
      } else if (_fbd != null) {
        await ftmsEmulator.detachDefinition(_fbd!).catchError((_) {});
        _fbd = null;
        if (ftmsEmulator.composite.children.isEmpty && ftmsEmulator.isStarted.value) {
          ftmsEmulator.stop();
        }
      }
      disconnect();
    }
  }

  /// Push persisted user settings (bike/rider weight, grade smoothing, VS mode)
  /// onto the active FitnessBikeDefinition so the physics calc uses them even
  /// when the user never opens the details page. No-op for ProxyBikeDefinition
  /// (those settings don't apply) and for WiFi modes whose definition is
  /// created lazily per TCP client — the details page rehydrates on mount.
  String get trainerKey => scanResult.name ?? scanResult.deviceId;

  /// Whether the underlying device looks like a smart trainer (FTMS-capable
  /// or FE-C-over-BLE). Power-meter-only or HR-only devices have no trainer
  /// commands to drive, so Virtual Shifting is meaningless for them — they
  /// stay on Proxy.
  bool get isSmartTrainer => scanResult.services.any((s) {
    final lower = s.toLowerCase();
    return lower == FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID.toLowerCase() ||
        lower == FitnessBikeDefinition.FEC_BLE_SERVICE_UUID.toLowerCase();
  });

  /// Default connect mode when the user hasn't explicitly picked one. Smart
  /// trainers default to Virtual Shifting (transport resolved from the
  /// active Trainer Connection Settings); other devices fall back to Proxy.
  /// When VS is the conceptual default but no transport is enabled in
  /// Connection Settings, falls through to Proxy so the device still works.
  RetrofitMode get defaultRetrofitMode {
    if (!isSmartTrainer) return RetrofitMode.proxy;
    final transport = core.logic.preferredBridgeTransport(core.logic.enabledTrainerConnections);
    return switch (transport) {
      TrainerConnectionType.bluetooth => RetrofitMode.bluetooth,
      TrainerConnectionType.wifi => RetrofitMode.wifi,
      null => RetrofitMode.wifi,
    };
  }

  void applyTrainerSettings() {
    final def = emulator.fitnessBike;
    if (def == null) return;
    _seedFitnessBikeDefinition(def);
  }

  @override
  Future<void> processCharacteristic(String characteristic, Uint8List bytes) async {
    emulator.processCharacteristic(characteristic, bytes);
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    if (isConnected) {
      final units = unitSystemOf(context);
      if (screenshotMode) {
        final parts = <Widget>[];
        _addMetric(parts, context, 250, 'W', LucideIcons.zap);
        _addMetric(parts, context, 133, 'bpm', LucideIcons.heart);
        _addMetric(parts, context, 90, 'rpm', LucideIcons.rotateCw);
        _addMetric(parts, context, units.fromKph(40).round(), units.speedSymbol, LucideIcons.gauge);
        return parts;
      }
      return [
        ValueListenableBuilder<String>(
          valueListenable: emulator.data,
          builder: (context, value, _) {
            if (value.isEmpty) return Text('Waiting for connection...').xSmall.muted;
            final proxyDef = emulator.composite.firstOfType<ProxyBikeDefinition>();
            final fitnessDef = emulator.fitnessBike;
            final parts = <Widget>[];
            if (proxyDef != null) {
              _addMetric(parts, context, proxyDef.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, proxyDef.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, proxyDef.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = proxyDef.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, units.fromKph(speed).round(), units.speedSymbol, LucideIcons.gauge);
              }
            } else if (fitnessDef != null) {
              _addMetric(parts, context, fitnessDef.powerW.value, 'W', LucideIcons.zap);
              _addMetric(parts, context, fitnessDef.heartRateBpm.value, 'bpm', LucideIcons.heart);
              _addMetric(parts, context, fitnessDef.cadenceRpm.value, 'rpm', LucideIcons.rotateCw);
              final speed = fitnessDef.speedKph.value;
              if (speed != null) {
                _addMetric(parts, context, units.fromKph(speed).round(), units.speedSymbol, LucideIcons.gauge);
              }
              // Gear (sim / VS mode) or ERG target wattage (erg mode).
              if (fitnessDef.trainerMode.value == TrainerMode.ergMode) {
                final watts = fitnessDef.ergTargetPower.value;
                if (watts != null) {
                  _addTextMetric(parts, context, 'ERG $watts W', LucideIcons.target);
                }
              } else {
                _addTextMetric(
                  parts,
                  context,
                  'Gear ${fitnessDef.currentGear.value}/${fitnessDef.maxGear}',
                  LucideIcons.settings2,
                );
              }
            }
            if (parts.isEmpty) return const SizedBox.shrink();
            return Wrap(
              spacing: 12,
              runSpacing: 4,
              children: parts,
            );
          },
        ),
      ];
    }
    return [_buildFeatureList(context)];
  }

  Widget _buildFeatureList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 11, color: cs.mutedForeground);

    final services = scanResult.services.map((s) => s.toLowerCase()).toSet();
    final hasZwiftAdv = services.contains(ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase());
    final controller = core.connection.controllerDevices.firstOrNull;
    final supportsWifiProxy = services.contains(FitnessBikeDefinition.CYCLING_POWER_SERVICE_UUID.toLowerCase());

    final l10n = AppLocalizations.of(context);
    final features = <(IconData, String)>[
      if (!hasZwiftAdv) (LucideIcons.sparkles, l10n.proxyFeatureAddVirtualShifting),
      (LucideIcons.slidersHorizontal, l10n.proxyFeatureAdjustGears),
      if (controller != null) (LucideIcons.gamepad2, l10n.proxyFeatureDirectControl(controller.name)),
      (LucideIcons.dumbbell, l10n.proxyFeatureMiniWorkout),
      if (supportsWifiProxy) (LucideIcons.wifi, l10n.proxyFeatureWifiProxy),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.proxyConnectFor(name), style: muted),
        const Gap(2),
        for (final (icon, label) in features)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 11, color: cs.mutedForeground),
                ),
                const Gap(6),
                Flexible(child: Text(label, style: muted)),
              ],
            ),
          ),
      ],
    );
  }

  void _addMetric(List<Widget> parts, BuildContext context, int? value, String unit, IconData icon) {
    if (value == null) return;
    _addTextMetric(parts, context, '$value $unit', icon);
  }

  void _addTextMetric(List<Widget> parts, BuildContext context, String text, IconData icon) {
    parts.add(
      Container(
        constraints: const BoxConstraints(minWidth: 42),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.mutedForeground),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ActionResult handleTrainerAction(InGameAction action) {
    final l10n = AppLocalizations.current;
    final def = emulator.fitnessBike;
    if (def == null) {
      // Internal-only diagnostic; not user-visible toast copy.
      return NotHandled('No active FitnessBikeDefinition');
    }
    switch (action) {
      case InGameAction.shiftUp:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current + 10);
          return Success(l10n.trainerErgTarget(def.ergTargetPower.value ?? current));
        } else {
          final didChange = def.shiftUp();
          return didChange
              ? Ignored(l10n.trainerShiftedUp(def.currentGear.value))
              : Ignored(l10n.trainerAlreadyHighestGear);
        }
      case InGameAction.shiftDown:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current - 10);
          return Success(l10n.trainerErgTarget(def.ergTargetPower.value ?? current));
        } else {
          final didChange = def.shiftDown();
          return didChange
              ? Ignored(l10n.trainerShiftedDown(def.currentGear.value))
              : Ignored(l10n.trainerAlreadyLowestGear);
        }
      case InGameAction.trainerSwitchMode:
        if (def.trainerMode.value == TrainerMode.ergMode) {
          def.exitErgMode();
          return Success(l10n.trainerSwitchedToSim);
        } else {
          final current = def.ergTargetPower.value ?? 150;
          def.setManualErgPower(current);
          return Success(l10n.trainerSwitchedToErg(current));
        }
      case InGameAction.trainerIntensityUp:
        def.adjustIntensity(0.05);
        return Success(l10n.trainerIntensityIncreased);
      case InGameAction.trainerIntensityDown:
        def.adjustIntensity(-0.05);
        return Success(l10n.trainerIntensityDecreased);
      default:
        return NotHandled('');
    }
  }

  /// Whether the auto-connect path is allowed to start this device on its own
  /// (scan-time / app-launch). Requires an explicit prior connect intent
  /// (`getAutoConnect`) and, for smart trainers, the one-time takeover-consent
  /// flag set via the consent dialog.
  bool get shouldAutoConnect {
    if (!core.settings.getAutoConnect(trainerKey)) return false;
    if (isSmartTrainer && !core.settings.getSmartTrainerConsent(trainerKey)) return false;
    return true;
  }

  @override
  Future<void> connect() async {
    // ProxyDevice intentionally skips the upstream auto-connect — BLE is only
    // opened once the user explicitly starts the emulator via startProxy().
    // If they connected previously and haven't since tapped Disconnect,
    // honour that intent by kicking off startProxy() here (fire-and-forget).
    if (isStarting.value || _proxyEmulator.isStarted.value) return;
    if (!shouldAutoConnect) return;
    final savedMode = core.settings.getRetrofitMode(trainerKey, fallback: defaultRetrofitMode);
    setRetrofitMode(savedMode);
    await startProxy();
  }

  Future<void> startProxy() async {
    if (IAPManager.instance.isTrialExpired) {
      // 5-day trial over, user hasn't purchased — silently refuse the connect.
      // The UI Connect buttons surface a Go Pro dialog before ever reaching
      // here; this branch exists as a defensive funnel for the auto-connect
      // path. Clear auto-connect so the scanner doesn't keep re-firing.
      await core.settings.setAutoConnect(trainerKey, false);
      return;
    }
    isStarting.value = true;
    try {
      await super.connect();
    } finally {
      isStarting.value = false;
    }
  }

  /// Set the retrofit mode for this device. Updates the internal mode notifier
  /// and configures the proxy emulator accordingly, but does NOT start the
  /// emulator — call [startProxy] or [handleServices] to do that.
  ///
  /// For mode switches on an already-running emulator (e.g. swapping proxy ↔ VS
  /// while connected) use [switchRetrofitMode] instead.
  void setRetrofitMode(RetrofitMode mode) {
    _retrofitModeN.value = mode;
    _proxyEmulator.setRetrofitMode(mode);
  }

  /// Swap the retrofit transport without tearing down the upstream BLE
  /// connection. Delegates to the appropriate emulator's [switchRetrofitMode].
  /// For proxy ↔ VS transitions, migrates the FBD between emulators.
  Future<void> switchRetrofitMode(RetrofitMode next) async {
    final old = _retrofitModeN.value;
    if (old == next) return;

    if (old == RetrofitMode.proxy && next != RetrofitMode.proxy) {
      // proxy → VS: stop per-instance emulator, attach FBD to shared
      _proxyEmulator.stop();
      _configureSharedEmulator();

      if (_services != null) {
        ftmsEmulator.setScanResult(scanResult);
        ftmsEmulator.handleServices(_services!);
      }

      ftmsEmulator.setRetrofitMode(next);
      _retrofitModeN.value = next;
      _bindToActiveEmulator();

      if (!ftmsEmulator.isStarted.value) {
        await ftmsEmulator.startServer();
      } else {
        await ftmsEmulator.switchRetrofitMode(next);
      }
      // Capture the FBD that was created during startServer / mode switch
      _fbd = ftmsEmulator.fitnessBike;
    } else if (old != RetrofitMode.proxy && next == RetrofitMode.proxy) {
      // VS → proxy: detach from shared, start per-instance
      if (_fbd != null) {
        await ftmsEmulator.detachDefinition(_fbd!).catchError((_) {});
        _fbd = null;
      }
      if (ftmsEmulator.composite.children.isEmpty && ftmsEmulator.isStarted.value) {
        ftmsEmulator.stop();
      }

      if (_services != null) {
        _proxyEmulator.setScanResult(scanResult);
        _proxyEmulator.handleServices(_services!);
      }
      _proxyEmulator.setRetrofitMode(next);
      _retrofitModeN.value = next;
      _bindToActiveEmulator();

      await _proxyEmulator.startServer();
    } else {
      // VS wifi ↔ VS bluetooth: just switch the shared emulator's mode
      _retrofitModeN.value = next;
      await ftmsEmulator.switchRetrofitMode(next);
    }
  }

  @override
  Future<void> disconnect() async {
    // Remove listeners from the active emulator before teardown.
    final active = _currentlyListening;
    if (active != null) {
      active.isStarted.removeListener(_mirrorIsStarted);
      active.isConnected.removeListener(_mirrorIsConnected);
      active.localAddress.removeListener(_mirrorLocalAddress);
      active.retrofitMode.removeListener(_mirrorRetrofitMode);
      active.isConnected.removeListener(_syncBridgeTracking);
      active.retrofitMode.removeListener(_syncBridgeTracking);
      _currentlyListening = null;
    }

    _bridgeBudgetSub?.cancel();
    _bridgeBudgetSub = null;
    core.bridgeUsageTracker.stopSession();

    // Detach FBD from shared emulator if we contributed one.
    if (_fbd != null) {
      await ftmsEmulator.detachDefinition(_fbd!).catchError((_) {});
      _fbd = null;
    }
    if (ftmsEmulator.composite.children.isEmpty && ftmsEmulator.isStarted.value) {
      ftmsEmulator.stop();
    }

    _proxyEmulator.stop();
    return super.disconnect();
  }
}
