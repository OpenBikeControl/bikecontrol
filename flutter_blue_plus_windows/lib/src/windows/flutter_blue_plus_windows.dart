part of 'windows.dart';

class FlutterBluePlusWindows {
  static bool _initialized = false;

  static BluetoothAdapterState _state = BluetoothAdapterState.unknown;

  // stream used for the isScanning public api
  static final _isScanning = _StreamController(initialValue: false);

  // we always keep track of these device variables
  static final _platformNames = <DeviceIdentifier, String>{};
  static final _advNames = <DeviceIdentifier, String>{};
  static final _rssiMap = <DeviceIdentifier, int?>{};
  static final _knownServices = <DeviceIdentifier, List<BluetoothServiceWindows>>{};
  static final Map<DeviceIdentifier, Map<String, List<int>>> _lastChrs = {};
  static final Map<DeviceIdentifier, Map<String, bool>> _isNotifying = {};
  static final Map<DeviceIdentifier, Map<String, List<BluetoothCharacteristic>>> _characteristicCache = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _deviceSubscriptions = {};
  static final Map<DeviceIdentifier, List<StreamSubscription>> _delayedSubscriptions = {};
  static final List<StreamSubscription> _scanSubscriptions = [];

  // stream used for the scanResults public api
  static final _scanResultsList = _StreamController(initialValue: <ScanResult>[]);

  // the subscription to the scan results stream
  static StreamSubscription<BleDevice?>? _scanSubscription;

  // timeout for scanning that can be cancelled by stopScan
  static Timer? _scanTimeout;

  static List<BluetoothDeviceWindows> get _devices => [..._deviceSet];

  static final _deviceSet = <BluetoothDeviceWindows>{};
  static final _removedDeviceTracer = <BluetoothDeviceWindows, StreamSubscription>{};

  // static final _unhandledDeviceSet = <BluetoothDeviceWindows>{};

  /// Flutter blue plus windows
  static final _charReadWriteStreamController = StreamController<(String, List<int>)>();
  static final _charReadStreamController = StreamController<(String, List<int>)>();

  static final _charReadWriteStream = _charReadWriteStreamController.stream.asBroadcastStream();
  static final _charReadStream = _charReadStreamController.stream.asBroadcastStream();

  /// Flutter blue plus windows
  static final _connectionStream = _StreamController(initialValue: <String, bool>{});

  static Future<void> _initialize() async {
    if (_initialized) return;
    await WinBle.initialize(
      serverPath: await WinServer.path(),
      enableLog: false,
    );

    WinBle.connectionStream.listen(
      (event) {
        log('$event - event');
        if (event['device'] == null) return;
        if (event['connected'] == null) return;

        final map = _connectionStream.latestValue;
        map[event['device']] = event['connected'];

        log('$map - map');
        _connectionStream.add(map);

        if (!event['connected']) {
          final removingDevices = [
            ..._deviceSet.where(
              (device) => device._address == event['device'],
            ),
          ];
          for (final device in removingDevices) {
            _deviceSet.remove(device);
            if (!_removedDeviceTracer.keys.contains(device)) {
              _removedDeviceTracer[device] = Stream.periodic(const Duration(seconds: 10), (_) => device).listen(
                (event) {
                  if(event.isConnected) {
                    _removedDeviceTracer[device]?.cancel();
                    _removedDeviceTracer.remove(device);
                    return;
                  }
                  event.connect();
                },
              );
            }

            _deviceSubscriptions[device.remoteId]?.forEach((s) => s.cancel());
            _deviceSubscriptions.remove(device.remoteId);
            // use delayed to update the stream before we cancel it
            Future.delayed(Duration.zero).then((_) {
              _delayedSubscriptions[device.remoteId]?.forEach((s) => s.cancel());
              _delayedSubscriptions.remove(device.remoteId);
            });

            _lastChrs[device.remoteId]?.clear();
            _isNotifying[device.remoteId]?.clear();
          }
        }
      },
    );
    _initialized = true;
  }

  static Future<bool> get isSupported async {
    return true;
  }

  static Future<String> get adapterName async {
    return 'Windows';
  }

  static Stream<bool> get isScanning => _isScanning.stream;

  static bool get isScanningNow => _isScanning.latestValue;

  static Future<void> turnOn({int timeout = 10}) async {
    await _initialize();
    await WinBle.updateBluetoothState(true);
  }

  // TODO: compare with original lib
  static Stream<List<ScanResult>> get scanResults => _scanResultsList.stream;

  static Stream<BluetoothAdapterState> get adapterState async* {
    await _initialize();
    yield _state;
    yield* WinBle.bleState.asBroadcastStream().map(
      (s) {
        _state = s.toAdapterState();
        return _state;
      },
    );
  }

  /// Start a scan, and return a stream of results
  /// Note: scan filters use an "or" behavior. i.e. if you set `withServices` & `withNames` we
  /// return all the advertisments that match any of the specified services *or* any of the specified names.
  ///   - [withServices] filter by advertised services
  ///   - [withRemoteIds] filter for known remoteIds (iOS: 128-bit guid, android: 48-bit mac address)
  ///   - [withNames] filter by advertised names (exact match)
  ///   - [withKeywords] filter by advertised names (matches any substring)
  ///   - [withMsd] filter by manfacture specific data
  ///   - [withServiceData] filter by service data
  ///   - [timeout] calls stopScan after a specified duration
  ///   - [removeIfGone] if true, remove devices after they've stopped advertising for X duration
  ///   - [continuousUpdates] If `true`, we continually update 'lastSeen' & 'rssi' by processing
  ///        duplicate advertisements. This takes more power. You typically should not use this option.
  ///   - [continuousDivisor] Useful to help performance. If divisor is 3, then two-thirds of advertisements are
  ///        ignored, and one-third are processed. This reduces main-thread usage caused by the platform channel.
  ///        The scan counting is per-device so you always get the 1st advertisement from each device.
  ///        If divisor is 1, all advertisements are returned. This argument only matters for `continuousUpdates` mode.
  ///   - [oneByOne] if `true`, we will stream every advertistment one by one, possibly including duplicates.
  ///        If `false`, we deduplicate the advertisements, and return a list of devices.
  ///   - [androidLegacy] Android only. If `true`, scan on 1M phy only.
  ///        If `false`, scan on all supported phys. How the radio cycles through all the supported phys is purely
  ///        dependent on the your Bluetooth stack implementation.
  ///   - [androidScanMode] choose the android scan mode to use when scanning
  ///   - [androidUsesFineLocation] request `ACCESS_FINE_LOCATION` permission at runtime
  static Future<void> startScan({
    List<Guid> withServices = const [],
    List<String> withRemoteIds = const [],
    List<String> withNames = const [],
    //TODO: implementation missing
    List<String> withKeywords = const [],
    //TODO: implementation missing
    List<MsdFilter> withMsd = const [],
    List<ServiceDataFilter> withServiceData = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool continuousUpdates = false,
    int continuousDivisor = 1,
    bool oneByOne = false,
    bool androidLegacy = false,
    AndroidScanMode androidScanMode = AndroidScanMode.lowLatency,
    bool androidUsesFineLocation = false,
  }) async {
    await _initialize();

    // stop existing scan
    if (_isScanning.latestValue == true) {
      await stopScan();
    }

    // push to stream
    _isScanning.add(true);

    // Start timer *after* stream is being listened to, to make sure the
    // timeout does not fire before _buffer is set
    if (timeout != null) {
      _scanTimeout = Timer(timeout, stopScan);
    }

    /// remove connection by OS.
    /// The reason why we add this logic is
    /// to avoid uncontrollable devices and to make consistency.

    /// add WinBle scanning
    WinBle.startScanning();

    // check every 250ms for gone devices?
    late Stream<BleDevice?> outputStream;
    if (removeIfGone != null) {
      outputStream = _mergeStreams([WinBle.scanStream, Stream.periodic(Duration(milliseconds: 250))]);
    } else {
      outputStream = WinBle.scanStream;
    }

    final output = <ScanResult>[];

    // listen & push to `scanResults` stream
    _scanSubscription = outputStream.listen(
      (BleDevice? winBleDevice) {
        // print(winBleDevice?.serviceUuids);
        if (winBleDevice == null) {
          // if null, this is just a periodic update for removing old results
          output.removeWhere((elm) => DateTime.now().difference(elm.timeStamp) > removeIfGone!);

          // push to stream
          _scanResultsList.add(List.from(output));
        } else {
          final remoteId = DeviceIdentifier(winBleDevice.address.toUpperCase());
          final scanResult = output.where((sr) => sr.device.remoteId == remoteId).firstOrNull;
          final deviceName = winBleDevice.name.isNotEmpty ? winBleDevice.name : scanResult?.device.platformName ?? '';
          final serviceUuids = winBleDevice.serviceUuids.isNotEmpty
              ? [...winBleDevice.serviceUuids.map((e) => Guid((e as String).replaceAll(RegExp(r'[{}]'), '')))]
              : scanResult?.advertisementData.serviceUuids ?? [];

          final manufacturerData = winBleDevice.manufacturerData.isNotEmpty
              ? {
                  if (winBleDevice.manufacturerData.length >= 2)
                    winBleDevice.manufacturerData[0] + (winBleDevice.manufacturerData[1] << 8):
                        winBleDevice.manufacturerData.sublist(2),
                }
              : scanResult?.advertisementData.manufacturerData ?? {};

          final rssi = int.tryParse(winBleDevice.rssi) ?? -100;

          FlutterBluePlusWindows._platformNames[remoteId] = deviceName;
          FlutterBluePlusWindows._advNames[remoteId] = deviceName;
          FlutterBluePlusWindows._rssiMap[remoteId] = rssi;

          final device = BluetoothDeviceWindows(remoteId: remoteId);

          String hex(int value) => value.toRadixString(16).padLeft(2, '0');
          String hexToId(Iterable<int> values) => values.map((e) => hex(e)).join();

          final sr = ScanResult(
            device: device,
            advertisementData: AdvertisementData(
              advName: deviceName,
              txPowerLevel: winBleDevice.adStructures?.where((e) => e.type == 10).singleOrNull?.data.firstOrNull,
              //TODO: Should verify
              connectable: !winBleDevice.advType.contains('Non'),
              manufacturerData: manufacturerData,
              serviceData: {
                for (final advStructures in winBleDevice.adStructures ?? <AdStructure>[])
                  if (advStructures.type == 0x16 && advStructures.data.length >= 2)
                    Guid(hexToId(advStructures.data.sublist(0, 2).reversed)): advStructures.data.sublist(2),
                for (final advStructures in winBleDevice.adStructures ?? <AdStructure>[])
                  if (advStructures.type == 0x20 && advStructures.data.length >= 4)
                    Guid(hexToId(advStructures.data.sublist(0, 4).reversed)): advStructures.data.sublist(4),
                for (final advStructures in winBleDevice.adStructures ?? <AdStructure>[])
                  if (advStructures.type == 0x21 && advStructures.data.length >= 16)
                    Guid(hexToId(advStructures.data.sublist(0, 16).reversed)): advStructures.data.sublist(16),
              },
              serviceUuids: serviceUuids,
              appearance: null,
            ),
            rssi: rssi,
            timeStamp: DateTime.now(),
          );

          // filter with services
          final isFilteredWithServices =
              withServices.isNotEmpty && serviceUuids.where((service) => withServices.contains(service)).isEmpty;

          // filter with remote ids
          final isFilteredWithRemoteIds = withRemoteIds.isNotEmpty && !withRemoteIds.contains(remoteId);

          // filter with names
          final isFilteredWithNames = withNames.isNotEmpty && !withNames.contains(deviceName);

          if (isFilteredWithServices || isFilteredWithRemoteIds || isFilteredWithNames) {
            _scanResultsList.add(List.from(output));
            return;
          }

          // add result to output
          if (oneByOne) {
            output
              ..clear()
              ..add(sr);
          } else {
            output.addOrUpdate(sr);
          }

          // push to stream
          _scanResultsList.add(List.from(output));
        }
      },
    );
  }

  static List<FBP.BluetoothDevice> get connectedDevices {
    return _devices;
  }

  static Future<List<BluetoothDeviceWindows>> get bondedDevices async {
    return _devices;
  }

  /// Stops a scan for Bluetooth Low Energy devices
  static Future<void> stopScan() async {
    await _initialize();
    WinBle.stopScanning();
    _scanSubscription?.cancel();
    _scanTimeout?.cancel();
    _isScanning.add(false);

    for (var subscription in _scanSubscriptions) {
      subscription.cancel();
    }

    _scanResultsList.latestValue = [];
  }

  /// Register a subscription to be canceled when scanning is complete.
  /// This function simplifies cleanup, so you can prevent creating duplicate stream subscriptions.
  ///   - this is an optional convenience function
  ///   - prevents accidentally creating duplicate subscriptions before each scan
  static void cancelWhenScanComplete(StreamSubscription subscription) {
    _scanSubscriptions.add(subscription);
  }

  /// Sets the internal FlutterBlue log level
  static Future<void> setLogLevel(LogLevel level, {color = true}) async {
    // Nothing to implement
    return;
  }

  static Future<void> turnOff({int timeout = 10}) async {
    await _initialize();
    await WinBle.updateBluetoothState(false);
  }

  // TODO: need to test
  static Future<bool> get isOn async {
    await _initialize();
    return await WinBle.bleState.asBroadcastStream().first == BleState.On;
  }
}
