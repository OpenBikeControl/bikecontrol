import 'dart:async';

import 'package:bike_control/bluetooth/ble.dart';
import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/openbikecontrol/openbikecontrol_device.dart';
import 'package:bike_control/bluetooth/devices/proxy/proxy_device.dart';
import 'package:bike_control/bluetooth/devices/shimano/shimano_di2.dart';
import 'package:bike_control/bluetooth/devices/sram/sram_axs.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_pro.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_bike_shift.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_climb.dart';
import 'package:bike_control/bluetooth/devices/wahoo/wahoo_kickr_headwind.dart';
import 'package:bike_control/bluetooth/devices/zwift/constants.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_click.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_left_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_clickv2_right_side.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_device.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_play_fw2.dart';
import 'package:bike_control/bluetooth/devices/zwift/zwift_ride.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/services/sensors/ble_sensor_source.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
// `SramAdvertisement` clashes with nothing here, but the prop package also
// exports a `SramAxs` constants class that collides with this file's `SramAxs`
// app device import above — pull in only what's needed to avoid the clash.
import 'package:prop/emulators/definitions/fitness_bike_definition.dart';
import 'package:prop/prop.dart' show LogLevel, SramAdvertisement;
import 'package:prop/utils/wahoo_climb.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'cycplus/cycplus_bc2.dart';
import 'elite/elite_rizer.dart';
import 'elite/elite_square.dart';
import 'elite/elite_sterzo.dart';
import 'ltwoo/ltwoo_erx.dart';
import 'sensors/ble_cadence_device.dart';
import 'sensors/ble_heart_rate_device.dart';
import 'sensors/ble_power_device.dart';
import 'thinkrider/thinkrider_vs200.dart';
import 'wheeltop/wheeltop_eds.dart';

abstract class BluetoothDevice extends BaseDevice {
  final BleDevice scanResult;

  BluetoothDevice(
    this.scanResult, {
    required List<ControllerButton> availableButtons,
    bool allowMultiple = false,
    bool isBeta = false,
    bool supportsLongPress = true,
    IconData icon = LucideIcons.gamepad,
    String? buttonPrefix,
  }) : super(
         scanResult.name,
         icon: icon,
         uniqueId: scanResult.deviceId,
         availableButtons: allowMultiple
             ? availableButtons.toList().map((b) => b.copyWith(sourceDeviceId: scanResult.deviceId)).toList()
             : availableButtons.toList(),
         isBeta: isBeta,
         supportsLongPress: supportsLongPress,
         buttonPrefix: buttonPrefix,
       ) {
    rssi = scanResult.rssi;
  }

  int? batteryLevel;
  String? firmwareVersion;
  String? hardwareRevision;
  String? manufacturerName;
  String? deviceName;
  int? rssi;

  static List<String> servicesToScan = [
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID,
    ZwiftConstants.ZWIFT_CUSTOM_SERVICE_SHORT_UUID,
    ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID,
    SquareConstants.SERVICE_UUID,
    WahooKickrBikeShiftConstants.SERVICE_UUID,
    WahooKickrHeadwindConstants.SERVICE_UUID,
    wahooClimbServiceUuid,
    SterzoConstants.SERVICE_UUID,
    CycplusBc2Constants.SERVICE_UUID,
    ShimanoDi2Constants.SERVICE_UUID,
    ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE,
    OpenBikeControlConstants.SERVICE_UUID,
    ThinkRiderVs200Constants.SERVICE_UUID,
    // Nordic UART Service — needed so L-TWOO derailleurs show up in filtered
    // scans; device matching itself stays name-gated (NUS is far too generic).
    LtwooErxConstants.SERVICE_UUID,
    // Heart Rate Service — so straps and armbands appear in filtered scans and
    // can be selected as an external source.
    BleSensorSource.heartRateServiceUuid,
    // Cycling Speed and Cadence Service — so cadence-only sensors appear in
    // filtered scans and can be selected as an external source.
    BleSensorSource.cscServiceUuid,
    // Cycling Power Service — so power meters appear in filtered scans and
    // can be selected as an external source.
    BleSensorSource.cyclingPowerServiceUuid,
  ];

  /// Every power-meter name prefix BikeControl recognises for classification.
  /// Used by the narrow `BlePowerDevice` rules in [fromScanResult] (both
  /// platform branches) so a bare Cycling Power advertiser with one of these
  /// names is claimed as a power meter rather than falling through to
  /// [ProxyDevice] — see [_advertisesTrainerService] for the guard that
  /// still protects an actual trainer sold under one of these brands (e.g.
  /// Stages' SB20 smart bike, SRM's indoor trainer).
  static final List<String> _powerMeterNames = [
    'ASSIOMA', // Favero Assioma
    'QUARQ',
    'POWERCRANK',
    'STAGES',
    '4IIII',
    'SRM',
    'RALLY', // Garmin Rally
    'ROTOR',
    'POWER2MAX',
    'POWRLINK', // Wahoo POWRLINK
  ];

  /// Whether [name] matches one of the power-meter families BikeControl
  /// recognises for classification ([_powerMeterNames]) — the narrow
  /// `BlePowerDevice` rules in [fromScanResult] use this.
  static bool _isKnownPowerMeterName(String name) =>
      _powerMeterNames.any((knownName) => name.toUpperCase().startsWith(knownName));

  /// Whether [scanResult] advertises a trainer service — FTMS or
  /// FE-C-over-BLE — the same two services [ProxyDevice.isSmartTrainer]
  /// checks to decide a device is a smart trainer. Deliberately reuses those
  /// exact UUIDs rather than redefining them, so the two notions of
  /// "trainer" cannot drift apart.
  ///
  /// Used to exclude such a device from the narrow `BlePowerDevice` rules in
  /// [fromScanResult] (both platform branches): [_powerMeterNames]
  /// recognises brands like Stages, SRM, and Rotor that do not only sell
  /// crank/pedal power meters — Stages also makes the SB20 smart bike, SRM
  /// also makes an indoor trainer — and either can advertise bare Cycling
  /// Power alongside FTMS/FE-C. A device advertising a trainer service is a
  /// TRAINER that also reports power, not a power meter, and trainer control
  /// must always win: without this guard, a rider with one of those would
  /// have the narrow rule claim it as a bare [BlePowerDevice], losing
  /// resistance, ERG, and virtual shifting entirely.
  static bool _advertisesTrainerService(BleDevice scanResult) => scanResult.services.containsAny([
    FitnessBikeDefinition.FITNESS_MACHINE_SERVICE_UUID,
    FitnessBikeDefinition.FEC_BLE_SERVICE_UUID,
  ]);

  /// Test seam: overrides the effective [kIsWeb] check so `fromScanResult`'s
  /// web-specific classification branch can be exercised from a normal
  /// (Dart VM) test run, where the real compile-time [kIsWeb] is always
  /// false. Mirrors `ObpMdnsEmulator.debugIsWindows`. Reset to null once the
  /// test that set it is done, or it silently pins every later test in the
  /// same run to that platform.
  @visibleForTesting
  static bool Function()? debugIsWeb;

  static bool get _effectiveIsWeb => (debugIsWeb ?? (() => kIsWeb))();

  List<BleService>? services;

  /// §2.1: BikeControl should only connect to the SRAM AXS rear derailleur —
  /// bare shifters/blips/pods also advertise service 0xFE51 but aren't
  /// connectable targets. Uses the advertised device-type record to tell them
  /// apart; when it's absent or unparsable, falls back to the previous
  /// behavior (connect).
  static bool _sramIsConnectable(BleDevice scanResult) {
    Uint8List? record;
    for (final e in scanResult.serviceData.entries) {
      if (e.key.toLowerCase().contains('fe51')) {
        record = e.value;
        break;
      }
    }
    if (record == null) return true; // no service data → can't tell; keep current behavior
    final info = SramAdvertisement.parse(record);
    if (info == null) return true;
    return info.isRearDerailleur; // connect only to the rear derailleur
  }

  /// Whether a scan result points at a Zwift Ride on genuinely old,
  /// third-party-incompatible firmware — the only case the "update the
  /// firmware" toast should fire for.
  ///
  /// A modern Ride advertises two manufacturer-data types: `RIDE_LEFT_SIDE`
  /// (which builds a [ZwiftRide]) and `RIDE_RIGHT_SIDE` (deliberately mapped to
  /// null — we only connect to the left half). The right-side advert therefore
  /// builds no device yet still exposes the Zwift custom service, so
  /// [hasZwiftCustomService] is what separates it from an old Ride that exposes
  /// no recognizable Zwift service at all (ticket ed826861, issue #2).
  @visibleForTesting
  static bool isLikelyOldRideFirmware({
    required String? name,
    required bool deviceRecognized,
    required bool hasZwiftCustomService,
  }) => name == 'Zwift Ride' && !deviceRecognized && !hasZwiftCustomService;

  /// Whether a device [fromScanResult] just produced should be kept when it
  /// came from `UniversalBle.getSystemDevices` — devices the OS already
  /// considers connected/bonded, not ones seen in a live advertisement (see
  /// `Connection.performScanning`'s system-devices branch, the only caller).
  /// `getSystemDevices` has to filter by service UUID to return anything at
  /// all on Apple, so once Cycling Power (`BleSensorSource.
  /// cyclingPowerServiceUuid`) became one of the queried services — needed so
  /// a power meter or a cadence sensor can be found this way too — every
  /// power meter the OS has ever bonded can come back, including one
  /// currently held by another app.
  ///
  /// [ProxyDevice.proxyServiceUUIDs] matches bare Cycling Power with no
  /// FTMS/FE-C requirement, which is correct for a *live* scan result:
  /// nothing else distinguishes a power-only trainer from an unrecognised
  /// power meter there, so defaulting to "trainer" is the existing, accepted
  /// behaviour (see the "CPS advertiser with a non-power-meter name" test).
  /// It is wrong here: it would also catch every unrecognised-name power
  /// meter the system-devices query surfaces and add it to `proxyDevices` as
  /// if it were a trainer. A recognised power meter never reaches
  /// this check at all — the narrow, name-gated `BlePowerDevice` rule in
  /// [fromScanResult] claims it first — so this only ever excludes a
  /// [ProxyDevice] that has nothing beyond bare Cycling Power to justify the
  /// classification.
  static bool isEligibleSystemDevice(BluetoothDevice device) => device is! ProxyDevice || device.isSmartTrainer;

  static BluetoothDevice? fromScanResult(BleDevice scanResult) {
    // Use the name first as the "System Devices" and Web (android sometimes Windows) don't have manufacturer data
    BluetoothDevice? device;
    if (_effectiveIsWeb) {
      device = switch (scanResult.name) {
        'Zwift Ride' => ZwiftRide(scanResult),
        'Zwift Play' => ZwiftPlay(scanResult, deviceType: ZwiftDeviceType.playLeft),
        'Zwift Click' => ZwiftClickV2(scanResult),
        'SQUARE' => EliteSquare(scanResult),
        'OpenBike' => OpenBikeControlDevice(scanResult),
        null => null,
        _ when scanResult.name!.toUpperCase().startsWith('KICKR CLIMB') && IAPManager.instance.isBetaTester =>
          WahooKickrClimb(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('HEADWIND') => WahooKickrHeadwind(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('RIZER') && IAPManager.instance.isBetaTester => EliteRizer(
          scanResult,
        ),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE PRO') => WahooKickrBikePro(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('THINK VS') => ThinkRiderVs200(scanResult),
        _ when LtwooErxConstants.matchesName(scanResult.name) => LtwooErx(scanResult),
        // Windows' universal_ble surfaces the Tacx Neo with an empty
        // advertisement (no services/serviceData), so match on name alone.
        _ when scanResult.name!.toUpperCase().startsWith('TACX NEO') => ProxyDevice(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('RDR') => ShimanoDi2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('SRAM') && _sramIsConnectable(scanResult) => SramAxs(
          scanResult,
        ),
        // Heart rate straps are matched by advertised service, never by name
        // (TICKR, H10, HRM-Dual, Rhythm24, ... vary too widely) — and this
        // rule MUST stay last: trainers routinely relay a paired strap and
        // advertise 0x180D themselves, so matching it earlier would steal a
        // trainer away from its own device class.
        _ when scanResult.services.contains(BleSensorSource.heartRateServiceUuid) => BleHeartRateDevice(scanResult),
        // Cadence sensors and power meters, matched by advertised service
        // for the same reason heart rate is above — and these rules MUST
        // also stay last: trainers advertise CSC (0x1816) and Cycling Power
        // (0x1818) far more readily than they advertise heart rate, so
        // matching either earlier would misclassify a trainer as a plain
        // sensor and break bridging entirely. This branch has no
        // ProxyDevice case to protect against (web never builds one), so
        // today this narrow, name-gated rule produces exactly the same
        // BlePowerDevice the broad rule below it does — the name check
        // does not change the outcome there. Kept anyway so the two switch
        // branches have the same shape and do not silently diverge if a
        // ProxyDevice-equivalent is ever added here, which would need the
        // ordering the non-web branch already relies on. See that branch's
        // version of this rule for why the narrow form is the one that
        // matters there today.
        //
        // Also excludes a device advertising FTMS/FE-C (_advertisesTrainerService)
        // — see that method's doc comment for why a recognised power-meter
        // NAME is not enough by itself once brands like Stages (SB20 smart
        // bike) and SRM (indoor trainer) are in [_powerMeterNames].
        _
            when scanResult.name != null &&
                _isKnownPowerMeterName(scanResult.name!) &&
                scanResult.services.contains(BleSensorSource.cyclingPowerServiceUuid) &&
                !_advertisesTrainerService(scanResult) =>
          BlePowerDevice(scanResult),
        // Power is checked before cadence so a combo device advertising both
        // services (common — many power meters also expose CSC) resolves to
        // the richer BlePowerDevice rather than being downgraded to
        // cadence-only.
        //
        // Deliberately broader than the narrow rule above on name, since
        // BikeControl cannot enumerate every power meter brand that exists
        // — picking a source in the Sensors UI is the rider's consent (see
        // `SensorQuantitySelector`), so there is no separate opt-in left to
        // gate this on. Unconditional on web specifically because there is
        // no ProxyDevice branch here to protect (see the narrow rule's
        // comment above) — an unrecognised-name bare-CPS advertiser simply
        // becomes a selectable power meter rather than nothing at all.
        _ when scanResult.services.contains(BleSensorSource.cyclingPowerServiceUuid) => BlePowerDevice(scanResult),
        _ when scanResult.services.contains(BleSensorSource.cscServiceUuid) => BleCadenceDevice(scanResult),
        _ => null,
      };
    } else {
      device = switch (scanResult.name) {
        null => null,
        //'Zwift Ride' => ZwiftRide(scanResult), special case for Zwift Ride: we must only connect to the left controller
        // https://www.makinolo.com/blog/2024/07/26/zwift-ride-protocol/
        //'Zwift Play' => ZwiftPlay(scanResult),
        //'Zwift Click' => ZwiftClick(scanResult), special case for Zwift Click v2: we must only connect to the left controller
        _ when scanResult.name!.toUpperCase().startsWith('KICKR CLIMB') && IAPManager.instance.isBetaTester =>
          WahooKickrClimb(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('HEADWIND') => WahooKickrHeadwind(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('SQUARE') => EliteSquare(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('STERZO') => EliteSterzo(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('RIZER') && IAPManager.instance.isBetaTester => EliteRizer(
          scanResult,
        ),
        _ when scanResult.name!.toUpperCase().contains('KICKR BIKE SHIFT') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE PRO') => WahooKickrBikePro(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('KICKR BIKE') => WahooKickrBikeShift(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('CYCPLUS') && scanResult.name!.toUpperCase().contains('BC2') =>
          CycplusBc2(scanResult),
        _ when scanResult.name!.toUpperCase().startsWith('THINK VS') => ThinkRiderVs200(scanResult),
        _ when LtwooErxConstants.matchesName(scanResult.name) => LtwooErx(scanResult),
        // Windows' universal_ble surfaces the Tacx Neo with an empty
        // advertisement (no services/serviceData) — only the name is usable, so
        // match on it and build a ProxyDevice (real services discovered on
        // connect). Must win over the services-based ProxyDevice branch below.
        _ when scanResult.name!.toUpperCase().startsWith('TACX NEO') => ProxyDevice(scanResult),
        //_ when scanResult.services.contains(CycplusBc2Constants.SERVICE_UUID.toLowerCase()) => CycplusBc2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID.toLowerCase()) => ShimanoDi2(scanResult),
        _ when scanResult.services.contains(ShimanoDi2Constants.SERVICE_UUID_ALTERNATIVE.toLowerCase()) => ShimanoDi2(
          scanResult,
        ),
        // Before the ProxyDevice branch below, which claims Cycling Power
        // (0x1818) unconditionally via containsAny — including for a
        // legitimately-named power meter, which is wrong. This rule is
        // deliberately narrow to avoid the opposite mistake: it only fires
        // for a device whose name we already recognise as a power meter
        // (_isKnownPowerMeterName, built from _powerMeterNames). A
        // power-only TRAINER with an unrecognised name is untouched by this
        // rule and keeps resolving to ProxyDevice below. A recognised name is
        // NOT enough on its own, though: _powerMeterNames includes brands
        // like Stages and SRM that also sell a smart bike (SB20) or an
        // indoor trainer, not just crank/pedal power meters, so the
        // _advertisesTrainerService exclusion below is what keeps one of
        // those from being claimed here instead of by ProxyDevice — a device
        // advertising a trainer service is a TRAINER that also reports
        // power, not a power meter, and trainer control must always win.
        _
            when scanResult.name != null &&
                _isKnownPowerMeterName(scanResult.name!) &&
                scanResult.services.contains(BleSensorSource.cyclingPowerServiceUuid) &&
                !_advertisesTrainerService(scanResult) =>
          BlePowerDevice(scanResult),
        _
            when scanResult.services.containsAny(ProxyDevice.proxyServiceUUIDs) ||
                scanResult.serviceData.keys.containsAny(ProxyDevice.proxyServiceUUIDs) =>
          ProxyDevice(scanResult),
        _
            when scanResult.services.contains(SramAxsConstants.SERVICE_UUID.toLowerCase()) &&
                _sramIsConnectable(scanResult) =>
          SramAxs(scanResult),
        _ when scanResult.services.contains(OpenBikeControlConstants.SERVICE_UUID.toLowerCase()) =>
          OpenBikeControlDevice(scanResult),
        _ when scanResult.services.contains(WahooKickrHeadwindConstants.SERVICE_UUID.toLowerCase()) =>
          WahooKickrHeadwind(scanResult),
        _ when scanResult.services.contains(wahooClimbServiceUuid.toLowerCase()) => WahooKickrClimb(scanResult),
        // Heart rate straps are matched by advertised service, never by name
        // (TICKR, H10, HRM-Dual, Rhythm24, ... vary too widely) — and this
        // rule MUST stay last: trainers routinely relay a paired strap and
        // advertise 0x180D themselves, so matching it earlier (including
        // ahead of the ProxyDevice.proxyServiceUUIDs branch above) would
        // steal a trainer away from its own device class.
        _ when scanResult.services.contains(BleSensorSource.heartRateServiceUuid) => BleHeartRateDevice(scanResult),
        // Cadence sensors, matched by advertised service for the same reason
        // heart rate is above — and this rule MUST also stay last, including
        // after the ProxyDevice.proxyServiceUUIDs branch: trainers advertise
        // CSC (0x1816) far more readily than they advertise heart rate, so
        // matching it earlier would misclassify a trainer as a plain cadence
        // sensor and break bridging entirely. CSC has no overlap with
        // ProxyDevice.proxyServiceUUIDs, so, unlike the power rule above,
        // there is nothing narrower needed here.
        _ when scanResult.services.contains(BleSensorSource.cscServiceUuid) => BleCadenceDevice(scanResult),
        // Kept as a fallback for symmetry with the web branch below, but
        // unreachable here in practice: ProxyDevice.proxyServiceUUIDs already
        // contains this exact Cycling Power UUID with no name gate, so
        // anything that would satisfy this condition was already claimed by
        // the ProxyDevice branch above. The narrow, name-gated rule before
        // ProxyDevice is what actually classifies a rider's power
        // meter on this branch — see its comment for why a broader
        // (name-unaware) rule can't safely sit ahead of ProxyDevice.
        _ when scanResult.services.contains(BleSensorSource.cyclingPowerServiceUuid) => BlePowerDevice(scanResult),
        // otherwise the service UUIDs will be used
        _ => null,
      };
    }

    final hasZwiftCustomService = scanResult.services.containsAny([
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_UUID.toLowerCase(),
      ZwiftConstants.ZWIFT_CUSTOM_SERVICE_SHORT_UUID.toLowerCase(),
      ZwiftConstants.ZWIFT_RIDE_CUSTOM_SERVICE_UUID.toLowerCase(),
    ]);

    if (device != null) {
      return device;
    } else if (hasZwiftCustomService) {
      // otherwise use the manufacturer data to identify the device
      final manufacturerData = scanResult.manufacturerDataList;
      final data = manufacturerData
          .firstOrNullWhere((e) => e.companyId == ZwiftConstants.ZWIFT_MANUFACTURER_ID)
          ?.payload;

      if (data == null || data.isEmpty) {
      } else {
        final type = ZwiftDeviceType.fromManufacturerData(data.first);
        // The split left/right controllers (with the new unlock handling) are
        // available to everyone now; a single toggle picks them over the
        // legacy unified [ZwiftClickV2]. Defaults on.
        final useNewUnlock = core.settings.getUseNewUnlockMethod();
        device = switch (type) {
          ZwiftDeviceType.click => ZwiftClick(scanResult),
          ZwiftDeviceType.playRight => ZwiftPlay(scanResult, deviceType: type!),
          ZwiftDeviceType.playLeft => ZwiftPlay(scanResult, deviceType: type!),
          ZwiftDeviceType.rideLeft => ZwiftRide(scanResult),
          ZwiftDeviceType.playFw2 => ZwiftPlayFw2(scanResult),
          //DeviceType.rideRight => ZwiftRide(scanResult), // see comment above
          ZwiftDeviceType.clickV2Left => useNewUnlock ? ZwiftClickV2LeftSide(scanResult) : ZwiftClickV2(scanResult),
          ZwiftDeviceType.clickV2Right => useNewUnlock ? ZwiftClickV2RightSide(scanResult) : null,
          _ => null,
        };
      }
    }

    // WHEELTOP EDS shifters advertise no usable name and no service UUIDs —
    // they are recognized by their manufacturer-data prefix alone.
    device ??= WheeltopEds.tryFrom(scanResult);

    if (isLikelyOldRideFirmware(
          name: scanResult.name,
          deviceRecognized: device != null,
          hasZwiftCustomService: hasZwiftCustomService,
        ) &&
        core.connection.controllerDevices.none((d) => d is ZwiftRide)) {
      // Fallback for Zwift Ride if nothing else matched => old firmware.
      // Naming the Companion app isn't enough — riders don't know firmware
      // updates live there, so the toast's action opens it directly.
      buildToast(
        level: LogLevel.LOGLEVEL_WARNING,
        title: AppLocalizations.current.firmwareUpdateRequired(scanResult.name!),
        closeTitle: AppLocalizations.current.zwiftCompanionApp,
        onClose: () => launchUrlString(ZwiftConstants.ZWIFT_COMPANION_URL, mode: LaunchMode.externalApplication),
        duration: Duration(seconds: 6),
      );
    }
    return device;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice && runtimeType == other.runtimeType && scanResult.deviceId == other.scanResult.deviceId;

  @override
  int get hashCode => scanResult.deviceId.hashCode;

  BleDevice get device => scanResult;

  /// Consecutive failed auto-connect attempts before [Connection] stops
  /// retrying this device and surfaces [connectionGuidance]. 0 = retry forever.
  int get maxAutoConnectAttempts => 0;

  /// Actionable hint shown when auto-connect gives up (see
  /// [maxAutoConnectAttempts]); null when there is no device-specific guidance.
  String? get connectionGuidance => null;

  /// When true, [Connection] leaves this device in the reconnect loop even if
  /// it keeps dropping within seconds of connecting — i.e. it opts out of the
  /// quick-drop backoff. Default false. WheeltopEds returns true while its
  /// keepalive experiment runs, so each reconnect can try the next candidate.
  bool get keepsReconnectingWhileDropping => false;

  @override
  Future<void> connect() async {
    try {
      await connectUpstream();
    } catch (e) {
      isConnected = false;
      rethrow;
    }

    services = await discoverUpstreamServices();

    final deviceInformationService = services!.firstOrNullWhere(
      (service) => service.uuid == BleUuid.DEVICE_INFORMATION_SERVICE_UUID.toLowerCase(),
    );
    Future<String?> readStringChar(BleService? service, String charUuid) async {
      final characteristic = service?.characteristics.firstOrNullWhere(
        (c) => c.uuid == charUuid.toLowerCase(),
      );
      if (characteristic == null) return null;
      try {
        final data = await readUpstream(service!.uuid, characteristic.uuid);
        final decoded = String.fromCharCodes(data).trim();
        return decoded.isEmpty ? null : decoded;
      } catch (_) {
        return null;
      }
    }

    firmwareVersion = await readStringChar(
      deviceInformationService,
      BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_FIRMWARE_REVISION,
    );
    hardwareRevision = await readStringChar(
      deviceInformationService,
      BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_HARDWARE_REVISION,
    );
    manufacturerName = await readStringChar(
      deviceInformationService,
      BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_MANUFACTURER_NAME,
    );

    final genericAccessService = services!.firstOrNullWhere(
      (service) => service.uuid == BleUuid.GENERIC_ACCESS_SERVICE_UUID.toLowerCase(),
    );
    deviceName =
        await readStringChar(
          genericAccessService,
          BleUuid.GENERIC_ACCESS_CHARACTERISTIC_DEVICE_NAME,
        ) ??
        device.name;

    if (firmwareVersion != null || hardwareRevision != null || manufacturerName != null || deviceName != null) {
      core.connection.signalChange(this);
    }

    final batteryService = services!.firstOrNullWhere(
      (service) => service.uuid == BleUuid.DEVICE_BATTERY_SERVICE_UUID.toLowerCase(),
    );

    final batteryCharacteristic = batteryService?.characteristics.firstOrNullWhere(
      (c) => c.uuid == BleUuid.DEVICE_INFORMATION_CHARACTERISTIC_BATTERY_LEVEL.toLowerCase(),
    );
    if (batteryCharacteristic != null) {
      final batteryData = await readUpstream(batteryService!.uuid, batteryCharacteristic.uuid);
      if (batteryData.isNotEmpty) {
        batteryLevel = batteryData.first;
        core.connection.signalChange(this);
      }
    }

    await handleServices(services!);
  }

  Future<void> handleServices(List<BleService> services);
  Future<void> processCharacteristic(String characteristic, Uint8List bytes);

  // ── Upstream I/O seams ────────────────────────────────────────────────
  // ProxyDevice overrides these to route through its TrainerTransport so a
  // WiFi (DirCon) trainer reuses this whole connect flow. The defaults are
  // verbatim the previous inline UniversalBle calls.

  @protected
  Future<void> connectUpstream() async {
    await UniversalBle.connect(device.deviceId);
    if (!kIsWeb) {
      try {
        await UniversalBle.requestMtu(device.deviceId, 517);
      } catch (e) {
        // not critical, just log it
        debugPrint('Failed to request MTU: $e');
      }
    }
  }

  @protected
  Future<List<BleService>> discoverUpstreamServices() => UniversalBle.discoverServices(device.deviceId);

  @protected
  Future<Uint8List> readUpstream(String serviceUuid, String characteristicUuid) =>
      UniversalBle.read(device.deviceId, serviceUuid, characteristicUuid);

  @protected
  Future<void> disconnectUpstream() => UniversalBle.disconnect(device.deviceId);

  @override
  Future<void> disconnect() async {
    services?.clear();
    await disconnectUpstream();
    super.disconnect();
  }

  String? serviceUuidForCharacteristic(String characteristicUuid) {
    return services
        ?.firstOrNullWhere((service) => service.characteristics.any((c) => c.uuid == characteristicUuid.toLowerCase()))
        ?.uuid;
  }

  @override
  List<Widget> showMetaInformation(BuildContext context, {required bool showFull}) {
    final foregroundColor = Theme.of(context).colorScheme.mutedForeground;
    const fontSize = 11.0;
    return [
      // metaRow: battery + signal
      if (batteryLevel != null || rssi != null) ...[
        if (batteryLevel != null) ...[
          Icon(
            switch (batteryLevel!) {
              >= 80 => LucideIcons.batteryFull,
              >= 60 => LucideIcons.batteryFull,
              >= 50 => LucideIcons.batteryMedium,
              >= 25 => LucideIcons.batteryLow,
              >= 10 => LucideIcons.batteryLow,
              _ => LucideIcons.batteryWarning,
            },
            size: 14,
            color: batteryLevel! < 20 ? Theme.of(context).colorScheme.destructive : foregroundColor,
          ),
          Text(
            '$batteryLevel%',
            style: TextStyle(
              fontSize: fontSize,
              color: foregroundColor,
            ),
          ),
          // SizedBox (not Gap) because this lives in a `Wrap`, and Gap looks
          // up a Flex/Scrollable ancestor for direction — which is absent
          // when the parent device-header Row flies through a Hero overlay.
          if (firmwareVersion != null || rssi != null) const SizedBox(width: 16),
        ],
        if (firmwareVersion != null &&
            (showFull || (this is ZwiftDevice && (this as ZwiftDevice).hasNewerFirmwareVersion))) ...[
          if (this is ZwiftDevice && (this as ZwiftDevice).hasNewerFirmwareVersion)
            Icon(
              Icons.warning,
              size: fontSize,
            )
          else
            Text('FW', style: TextStyle(fontSize: 10, color: foregroundColor)).inlineCode,
          Text(
            firmwareVersion!,
            style: TextStyle(
              fontSize: fontSize,
              color: foregroundColor,
            ),
          ),
          if (this is ZwiftDevice && (this as ZwiftDevice).hasNewerFirmwareVersion)
            Text(
              ' (${context.i18n.latestVersion((this as ZwiftDevice).latestFirmwareVersion!)})',
              style: TextStyle(color: foregroundColor, fontSize: fontSize),
            ),
          if (rssi != null) const SizedBox(width: 16),
        ],
        if (rssi != null)
          StreamBuilder(
            stream: core.connection.rssiConnectionStream.where((device) => device == this).map((event) => event.rssi),
            builder: (context, rssiValue) {
              final currentRssi = rssiValue.data ?? rssi!;
              if (showFull || currentRssi < -70) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.signal, size: 14, color: foregroundColor),
                    const Gap(4),
                    Text(
                      switch (currentRssi) {
                        >= -50 => 'Strong',
                        >= -70 => 'Good',
                        >= -85 => 'Fair',
                        _ => 'Weak',
                      },
                      style: TextStyle(fontSize: fontSize, color: foregroundColor),
                    ),
                  ],
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
      ],
    ];
  }

  void debugSubscribeToAll(List<BleService> services) {
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.contains(CharacteristicProperty.indicate)) {
          debugPrint('Subscribing to indications for ${service.uuid} / ${characteristic.uuid}');
          UniversalBle.subscribeIndications(device.deviceId, service.uuid, characteristic.uuid);
        }
        if (characteristic.properties.contains(CharacteristicProperty.notify)) {
          debugPrint('Subscribing to notifications for ${service.uuid} / ${characteristic.uuid}');
          UniversalBle.subscribeNotifications(device.deviceId, service.uuid, characteristic.uuid);
        }
      }
    }
  }
}

/// Marker for devices that react to trainer/game state rather than acting as a
/// controller (e.g. Headwind fan, KICKR Climb). Excluded from [controllerDevices].
mixin Accessory on BluetoothDevice {}
