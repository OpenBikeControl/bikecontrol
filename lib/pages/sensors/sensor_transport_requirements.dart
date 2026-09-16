import 'dart:io';

import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/connection_method.dart' show satisfyRequirements;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:prop/emulators/dircon_emulator.dart';

/// The platform grants the standalone sensor transport needs before it can
/// advertise at all — the same ones the bridge pre-flights for the same
/// transport: `BLUETOOTH_ADVERTISE` on Android (`ConnectionCard`'s
/// `_ensureBluetoothAdvertisePermissions`) and Apple's Local Network for
/// the network listener (`ensureLocalNetworkAccess`). Launch only asks for
/// scan/connect, so a first Broadcast on Android would otherwise fail
/// inside the emulator with nothing to tell the rider.
List<PlatformRequirement> sensorTransportRequirements(RetrofitMode transport) => switch (transport) {
  RetrofitMode.bluetooth => [if (!kIsWeb && Platform.isAndroid) BluetoothAdvertiseRequirement()],
  RetrofitMode.wifi => localNetworkRequirements(),
  RetrofitMode.proxy => throw ArgumentError('proxy is not a sensor transport'),
};

/// Prompts for whatever [sensorTransportRequirements] is still missing and
/// reports whether the transport may start. Same prompt-then-recheck flow as
/// the bridge's (`satisfyRequirements`), deliberately NOT
/// `ensureLocalNetworkAccess`: that one also brings the trainer connection
/// methods up, which the no-trainer path has no use for.
Future<bool> ensureSensorTransportReady(BuildContext context, RetrofitMode transport) =>
    satisfyRequirements(context, sensorTransportRequirements(transport));
