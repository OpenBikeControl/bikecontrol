package com.navideck.universal_ble

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothDevice.BOND_BONDED
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Context.RECEIVER_EXPORTED
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit


private const val TAG = "UniversalBlePlugin"

@SuppressLint("MissingPermission")
class UniversalBlePlugin : UniversalBlePlatformChannel, BluetoothGattCallback(), FlutterPlugin,
    ActivityAware, PluginRegistry.ActivityResultListener {
    private val bluetoothEnableRequestCode = 2342313
    private val bluetoothDisableRequestCode = 2342414
    private var callbackChannel: UniversalBleCallbackChannel? = null
    private var mainThreadHandler: Handler? = null
    private lateinit var context: Context
    private var activity: Activity? = null
    private lateinit var bluetoothManager: BluetoothManager
    private lateinit var safeScanner: SafeScanner
    private val cachedServicesMap = mutableMapOf<String, List<String>>()
    private val universalBleFilterUtil = UniversalBleFilterUtil()

    // Flutter Futures
    private var bluetoothEnableRequestFuture: ((Result<Boolean>) -> Unit)? = null
    private var bluetoothDisableRequestFuture: ((Result<Boolean>) -> Unit)? = null
    private val discoverServicesFutureList = mutableListOf<DiscoverServicesFuture>()
    private val mtuResultFutureList = mutableListOf<MtuResultFuture>()
    private val readResultFutureList = mutableListOf<ReadResultFuture>()
    private val writeResultFutureList = mutableListOf<WriteResultFuture>()
    private val subscriptionResultFutureList = mutableListOf<SubscriptionResultFuture>()
    private val pairResultFutures = mutableMapOf<String, (Result<Boolean>) -> Unit>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        UniversalBlePlatformChannel.setUp(flutterPluginBinding.binaryMessenger, this)
        callbackChannel = UniversalBleCallbackChannel(flutterPluginBinding.binaryMessenger)
        context = flutterPluginBinding.applicationContext
        mainThreadHandler = Handler(Looper.getMainLooper())
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        safeScanner = SafeScanner(bluetoothManager)

        val intentFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        intentFilter.addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(broadcastReceiver, intentFilter, RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(broadcastReceiver, intentFilter)
        }
        cachedServicesMap.putAll(getCachedServicesMap())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        bluetoothManager.adapter.bluetoothLeScanner?.stopScan(scanCallback)
        context.unregisterReceiver(broadcastReceiver)
        callbackChannel = null
        mainThreadHandler = null
    }

    override fun getBluetoothAvailabilityState(callback: (Result<Long>) -> Unit) {
        callback(
            Result.success(
                bluetoothManager.adapter?.state?.toAvailabilityState()
                    ?: AvailabilityState.Unknown.value
            )
        )
    }

    override fun enableBluetooth(callback: (Result<Boolean>) -> Unit) {
        if (bluetoothManager.adapter.isEnabled) {
            callback(Result.success(true))
            return
        }
        if (bluetoothEnableRequestFuture != null) {
            callback(
                Result.failure(
                    FlutterError("Failed", "Bluetooth enable request in progress", null)
                )
            )
            return
        }
        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        activity?.startActivityForResult(enableBtIntent, bluetoothEnableRequestCode)
        bluetoothEnableRequestFuture = callback
    }

    override fun disableBluetooth(callback: (Result<Boolean>) -> Unit) {
        if (!bluetoothManager.adapter.isEnabled) {
            callback(Result.success(true))
            return
        }
        if (bluetoothDisableRequestFuture != null) {
            callback(
                Result.failure(
                    FlutterError("Failed", "Bluetooth disable request in progress", null)
                )
            )
            return
        }
        val disableBtIntent = Intent("android.bluetooth.adapter.action.REQUEST_DISABLE")
        activity?.startActivityForResult(disableBtIntent, bluetoothDisableRequestCode)
        bluetoothDisableRequestFuture = callback
    }

    override fun startScan(filter: UniversalScanFilter?) {
        if (!isBluetoothAvailable()) throw FlutterError(
            "BluetoothNotEnabled",
            "Bluetooth not enabled",
        )

        val builder = ScanSettings.Builder()
        if (Build.VERSION.SDK_INT >= 26) {
            builder.setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
            builder.setLegacy(false)
        }
        val settings = builder.build()

        val usesCustomFilters = filter?.usesCustomFilters() ?: false;

        try {
            val filterServices = filter?.withServices?.filterNotNull()?.toUUIDList() ?: emptyList()
            var scanFilters = emptyList<ScanFilter>()

            // Set custom scan filter only if required
            if (usesCustomFilters) {
                Log.e(TAG, "Using Custom Filters")
                universalBleFilterUtil.scanFilter = filter
                universalBleFilterUtil.serviceFilterUUIDS = filterServices
            } else {
                universalBleFilterUtil.scanFilter = null
                scanFilters = filter?.toScanFilters(filterServices) ?: emptyList<ScanFilter>()
            }

            safeScanner.startScan(
                scanFilters, settings, scanCallback
            )
        } catch (e: Exception) {
            throw FlutterError(
                "illegalIllegalArgument",
                "Failed to start Scan",
                e.toString()
            )
        }
    }

    override fun stopScan() {
        if (!isBluetoothAvailable()) throw FlutterError(
            "BluetoothNotEnabled",
            "Bluetooth not enabled",
        )
        // check if already scanning
        safeScanner.stopScan(scanCallback)
    }

    override fun connect(deviceId: String) {
        // If already connected, send connected message,
        // if connecting, do nothing
        deviceId.findGatt()?.let {
            val currentState = bluetoothManager.getConnectionState(it.device, BluetoothProfile.GATT)
            if (currentState == BluetoothGatt.STATE_CONNECTED) {
                Log.e(TAG, "$deviceId Already connected")
                mainThreadHandler?.post {
                    callbackChannel?.onConnectionChanged(deviceId, true, null) {}
                }
                return
            } else if (currentState == BluetoothGatt.STATE_CONNECTING) {
                throw FlutterError("Connecting", "Connection already in progress", null)
            }
        }


        val remoteDevice = bluetoothManager.adapter.getRemoteDevice(deviceId)
        val gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            remoteDevice.connectGatt(
                context,
                false,
                this,
                BluetoothDevice.TRANSPORT_LE
            )
        } else {
            remoteDevice.connectGatt(context, false, this)
        }
        gatt.saveCacheIfNeeded()
    }

    override fun disconnect(deviceId: String) {
        cleanConnection(deviceId.toBluetoothGatt())
    }

    override fun getConnectionState(deviceId: String): Long {
        val connectionState = bluetoothManager.getConnectionState(
            bluetoothManager.adapter.getRemoteDevice(deviceId),
            BluetoothProfile.GATT
        )

        return if (deviceId.isKnownGatt() || connectionState == BluetoothGatt.STATE_DISCONNECTED || connectionState == BluetoothGatt.STATE_DISCONNECTING) {
            connectionState.toBleConnectionState().value
        } else {
            // Might be connected with device, but not with app
            Log.e(TAG, "Device might be connected but not known to this app")
            BleConnectionState.Disconnected.value
        }
    }

    override fun discoverServices(
        deviceId: String,
        callback: (Result<List<UniversalBleService>>) -> Unit,
    ) {
        try {
            val gatt = deviceId.toBluetoothGatt()
            if (gatt.discoverServices()) {
                discoverServicesFutureList.add(DiscoverServicesFuture(deviceId, callback))
            } else {
                callback(
                    Result.failure(FlutterError("Failed", "Failed to discover services", null))
                )
            }
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        }
    }

    override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
        if (status != BluetoothGatt.GATT_SUCCESS) {
            discoverServicesFutureList.filter { it.deviceId == gatt.device.address }.forEach {
                discoverServicesFutureList.remove(it)
                it.result(
                    Result.failure(FlutterError("Failed", "Failed to discover services", null))
                )
            }
            return
        }
        setCachedServices(gatt.device.address, gatt.services.map { it.uuid.toString() })
        val universalBleServices = gatt.services.map { service ->
            UniversalBleService(
                uuid = service.uuid.toString(),
                characteristics = service.characteristics.map {
                    UniversalBleCharacteristic(
                        uuid = it.uuid.toString(),
                        properties = it.getPropertiesList()
                    )
                }
            )
        }
        discoverServicesFutureList.filter { it.deviceId == gatt.device.address }.forEach {
            discoverServicesFutureList.remove(it)
            it.result(Result.success(universalBleServices))
        }
    }


    override fun setNotifiable(
        deviceId: String,
        service: String,
        characteristic: String,
        bleInputProperty: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            val gatt = deviceId.toBluetoothGatt()
            val gattCharacteristic: BluetoothGattCharacteristic? =
                gatt.getCharacteristic(service, characteristic)

            if (gattCharacteristic == null) {
                callback(subscriptionFailedError("characteristic not found"))
                return
            }

            val descriptor: BluetoothGattDescriptor? =
                gattCharacteristic.getDescriptor(ccdCharacteristic)

            val bleInputPropertyEnum: BleInputProperty =
                BleInputProperty.values().first { it.value == bleInputProperty }

            val (value, enable) = when (bleInputPropertyEnum) {
                BleInputProperty.Notification -> BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE to true
                BleInputProperty.Indication -> BluetoothGattDescriptor.ENABLE_INDICATION_VALUE to true
                else -> BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE to false
            }

            if (descriptor != null) {
                // Some devices do not need CCCD to update
                @Suppress("DEPRECATION")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (gatt.writeDescriptor(descriptor, value) != BluetoothStatusCodes.SUCCESS) {
                        callback(subscriptionFailedError("Failed to update descriptor"))
                        return
                    }
                } else {
                    descriptor.value = value
                    if (!gatt.writeDescriptor(descriptor)) {
                        callback(subscriptionFailedError("Failed to update descriptor"))
                        return
                    }
                }
            } else {
                Log.d("UniversalBle", "CCCD Descriptor not found")
            }

            if (gatt.setCharacteristicNotification(gattCharacteristic, enable)) {
                if (descriptor != null) {
                    subscriptionResultFutureList.add(
                        SubscriptionResultFuture(
                            gatt.device.address,
                            gattCharacteristic.uuid.toString(),
                            gattCharacteristic.service.uuid.toString(),
                            callback
                        )
                    )
                } else {
                    callback(Result.success(Unit))
                }
            } else {
                callback(subscriptionFailedError())
            }
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(subscriptionFailedError(e.toString()))
        }
    }

    override fun readValue(
        deviceId: String,
        service: String,
        characteristic: String,
        callback: (Result<ByteArray>) -> Unit,
    ) {
        try {
            val gatt = deviceId.toBluetoothGatt()
            val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
            if (gattCharacteristic == null) {
                callback(
                    Result.failure(FlutterError("IllegalArgument", "Unknown characteristic", null))
                )
                return
            }
            if (!gatt.readCharacteristic(gattCharacteristic)) {
                callback(
                    Result.failure(unknownCharacteristicError(characteristic))
                )
                return
            }

            readResultFutureList.add(
                ReadResultFuture(
                    gatt.device.address,
                    gattCharacteristic.uuid.toString(),
                    gattCharacteristic.service.uuid.toString(),
                    callback
                )
            )
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        } catch (e: Exception) {
            callback(
                Result.failure(
                    FlutterError(
                        "Failed",
                        "Failed to read value",
                        e.toString()
                    )
                )
            )
        }
    }

    override fun onCharacteristicRead(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        status: Int,
    ) {
        readResultFutureList.filter {
            it.deviceId == gatt.device.address &&
                    it.characteristicId == characteristic.uuid.toString() &&
                    it.serviceId == characteristic.service.uuid.toString()
        }.forEach {
            readResultFutureList.remove(it)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                it.result(Result.success(value))
            } else {
                it.result(
                    Result.failure(
                        FlutterError(
                            status.toString(),
                            "Failed to read: (${status.parseGattErrorCode()})",
                            null,
                        )
                    )
                )
            }

        }
    }

    override fun writeValue(
        deviceId: String,
        service: String,
        characteristic: String,
        value: ByteArray,
        bleOutputProperty: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        try {
            val gatt = deviceId.toBluetoothGatt()
            val gattCharacteristic = gatt.getCharacteristic(service, characteristic)
            if (gattCharacteristic == null) {
                callback(Result.failure(unknownCharacteristicError(characteristic)))
                return
            }

            var writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            if (bleOutputProperty == BleOutputProperty.withResponse.value) {
                if (gattCharacteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE == 0) {
                    callback(
                        Result.failure(
                            FlutterError(
                                "IllegalArgument",
                                "Characteristic does not support write withResponse",
                                null
                            )
                        )
                    )
                    return
                }
                writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            } else if (bleOutputProperty == BleOutputProperty.withoutResponse.value) {
                if (gattCharacteristic.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE == 0) {
                    callback(
                        Result.failure(
                            FlutterError(
                                "IllegalArgument",
                                "Characteristic does not support write withoutResponse",
                                null
                            )
                        )
                    )
                    return
                }
                writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            }

            val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val writeResult = gatt.writeCharacteristic(gattCharacteristic, value, writeType)
                writeResult == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                gattCharacteristic.value = value
                gattCharacteristic.writeType = writeType
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(gattCharacteristic)
            }

            if (!result) {
                callback(Result.failure(FlutterError("Failed", "Failed to write", null)))
                return
            }

            if (writeType == BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) {
                // wait for the result
                writeResultFutureList.add(
                    WriteResultFuture(
                        gatt.device.address,
                        gattCharacteristic.uuid.toString(),
                        gattCharacteristic.service.uuid.toString(),
                        callback
                    )
                )
            } else {
                callback(Result.success(Unit))
            }
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        }
    }

    override fun onCharacteristicWrite(
        gatt: BluetoothGatt?,
        characteristic: BluetoothGattCharacteristic,
        status: Int,
    ) {
        writeResultFutureList.filter {
            it.deviceId == gatt?.device?.address &&
                    it.characteristicId == characteristic.uuid.toString() &&
                    it.serviceId == characteristic.service.uuid.toString()
        }.forEach {
            writeResultFutureList.remove(it)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                it.result(Result.success(Unit))
            } else {
                it.result(
                    Result.failure(
                        FlutterError(
                            status.toString(),
                            "Failed to write: (${status.parseGattErrorCode()})",
                            null,
                        )
                    )
                )
            }
        }
    }


    override fun requestMtu(deviceId: String, expectedMtu: Long, callback: (Result<Long>) -> Unit) {
        try {
            val gatt = deviceId.toBluetoothGatt()
            gatt.requestMtu(expectedMtu.toInt())
            mtuResultFutureList.add(MtuResultFuture(deviceId, callback))
        } catch (e: FlutterError) {
            callback(Result.failure(e))
        }
    }

    override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
        val deviceId = gatt?.device?.address ?: return
        mtuResultFutureList.filter { it.deviceId == deviceId }.forEach {
            mtuResultFutureList.remove(it)
            if (status == BluetoothGatt.GATT_SUCCESS) {
                it.result(Result.success(mtu.toLong()))
            } else {
                it.result(Result.failure(FlutterError("Failed to change MTU", null, null)))
            }
        }
    }

    override fun isPaired(deviceId: String, callback: (Result<Boolean>) -> Unit) {
        val remoteDevice: BluetoothDevice =
            bluetoothManager.adapter.getRemoteDevice(deviceId)
        callback(Result.success(remoteDevice.bondState == BOND_BONDED))
    }

    override fun pair(deviceId: String, callback: (Result<Boolean>) -> Unit) {
        try {
            val remoteDevice = bluetoothManager.adapter.getRemoteDevice(deviceId)
            val pendingFuture = pairResultFutures.remove(deviceId)

            // If already paired, return and complete pending futures
            if (remoteDevice.bondState == BOND_BONDED) {
                pendingFuture?.let { it(Result.success(true)) }
                callback(Result.success(true))
                return
            }

            // throw error if we already have a pending future
            if (pendingFuture != null) {
                callback(
                    Result.failure(
                        FlutterError(
                            "InProgress",
                            "Pairing already in progress",
                            null
                        )
                    )
                )
                return
            }

            // Make a Pair request and complete future from Pair Update intent
            if (remoteDevice.createBond()) {
                pairResultFutures[deviceId] = callback
            } else {
                callback(Result.failure(FlutterError("Failed", "Failed to pair", null)))
            }
        } catch (e: Exception) {
            callback(
                Result.failure(
                    FlutterError("Failed", e.toString(), null)
                )
            )
        }

    }

    override fun unPair(deviceId: String) {
        val remoteDevice: BluetoothDevice =
            bluetoothManager.adapter.getRemoteDevice(deviceId)
        if (remoteDevice.bondState == BOND_BONDED) {
            remoteDevice.removeBond()
        }
    }

    override fun getSystemDevices(
        withServices: List<String>,
        callback: (Result<List<UniversalBleScanResult>>) -> Unit,
    ) {
        var devices: List<BluetoothDevice> =
            bluetoothManager.getConnectedDevices(BluetoothProfile.GATT)
        if (withServices.isNotEmpty()) {
            devices = filterDevicesByServices(devices, withServices)
        }
        callback(
            Result.success(
                devices.map {
                    UniversalBleScanResult(
                        name = it.name,
                        deviceId = it.address,
                        isPaired = it.bondState == BOND_BONDED,
                        manufacturerDataList = null,
                        rssi = null,
                    )
                }
            )
        )
    }

    private fun filterDevicesByServices(
        devices: List<BluetoothDevice>,
        withServices: List<String>,
    ): List<BluetoothDevice> {
        // If all devices have cached services
        if (devices.all { cachedServicesMap[it.address] != null }) {
            return devices.filter { device ->
                cachedServicesMap[device.address]?.any { uuid -> withServices.contains(uuid) } == true
            }
        }

        // Else discover services off already connected devices
        val latch = CountDownLatch(devices.size)
        val resultMap = mutableMapOf<String, Boolean>()

        devices.forEach { device ->
            discoverServicesOffAlreadyConnectedDevice(device) { uuids ->
                resultMap[device.address] =
                    uuids?.any { uuid -> withServices.contains(uuid) } == true
                latch.countDown()
            }
        }

        try {
            val timeout = (devices.size * 2).toLong()
            latch.await(timeout, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }

        return devices.filter { resultMap[it.address] == true }
    }

    private fun discoverServicesOffAlreadyConnectedDevice(
        device: BluetoothDevice,
        callback: (List<String>?) -> Unit,
    ) {
        // Check if already cached
        cachedServicesMap[device.address]?.let {
            callback(it)
            return
        }

        // To avoid duplicate callback
        var isUpdated = false
        fun updateCallback(uuids: List<String>?) {
            if (isUpdated) return
            callback(uuids)
            isUpdated = true
        }

        // If its a known gatt, just discover services
        device.address.findGatt()?.let { gatt ->
            gatt.services?.let { services ->
                updateCallback(services.map { service -> service.uuid.toString() })
                return
            }

            if (gatt.discoverServices()) {
                discoverServicesFutureList.add(
                    DiscoverServicesFuture(device.address) { uuids: Result<List<UniversalBleService>> ->
                        if (uuids.isSuccess) {
                            updateCallback(uuids.getOrNull()?.map { it.uuid })
                        } else {
                            updateCallback(null)
                        }
                    }
                )
                return
            }
        }

        // Else connect to Gatt, discover services, then disconnect
        val callbackHandler = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothGatt.STATE_CONNECTED) {
                    if (gatt?.discoverServices() != true) {
                        updateCallback(null)
                        if (!device.address.isKnownGatt()) {
                            gatt?.disconnect()
                        }
                    }
                } else {
                    updateCallback(null)
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    val uuids = gatt?.services?.map { it.uuid.toString() }
                    if (uuids != null) {
                        setCachedServices(device.address, uuids)
                    }
                    updateCallback(uuids)
                }
                if (!device.address.isKnownGatt()) {
                    gatt?.disconnect()
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(context, false, callbackHandler, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(context, false, callbackHandler)
        }
    }

    private fun cleanConnection(gatt: BluetoothGatt) {
        gatt.removeCache()
        gatt.disconnect()

        readResultFutureList.removeAll {
            if (it.deviceId == gatt.device.address) {
                it.result(Result.failure(DeviceDisconnectedError))
                true
            } else {
                false
            }
        }
        writeResultFutureList.removeAll {
            if (it.deviceId == gatt.device.address) {
                it.result(Result.failure(DeviceDisconnectedError))
                true
            } else {
                false
            }
        }
        subscriptionResultFutureList.removeAll {
            if (it.deviceId == gatt.device.address) {
                it.result(Result.failure(DeviceDisconnectedError))
                true
            } else {
                false
            }
        }
        mtuResultFutureList.removeAll {
            if (it.deviceId == gatt.device.address) {
                it.result(Result.failure(DeviceDisconnectedError))
                true
            } else {
                false
            }
        }
        discoverServicesFutureList.removeAll {
            if (it.deviceId == gatt.device.address) {
                it.result(Result.failure(DeviceDisconnectedError))
                true
            } else {
                false
            }
        }
    }

    private fun onBondStateUpdate(deviceId: String, bonded: Boolean, error: String? = null) {
        val future = pairResultFutures.remove(deviceId)
        future?.let { it(Result.success(bonded)) }
        mainThreadHandler?.post {
            callbackChannel?.onPairStateChange(deviceId, bonded, error) {}
        }
    }

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                mainThreadHandler?.post {
                    callbackChannel?.onAvailabilityChanged(
                        bluetoothManager.adapter?.state?.toAvailabilityState()
                            ?: AvailabilityState.Unknown.value
                    ) {}
                }
            } else if (intent.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                val device: BluetoothDevice? =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(
                            BluetoothDevice.EXTRA_DEVICE,
                            BluetoothDevice::class.java
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                if (device == null) {
                    Log.e(TAG, "No device found in ACTION_BOND_STATE_CHANGED intent")
                    return
                }
                // get pairing failed error
                when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.ERROR)) {
                    BluetoothDevice.BOND_BONDING -> {
                        Log.v(TAG, "${device.address} BOND_BONDING")
                    }

                    BluetoothDevice.BOND_BONDED -> {
                        onBondStateUpdate(device.address, true)
                    }

                    BluetoothDevice.ERROR -> {
                        onBondStateUpdate(device.address, false, "Failed to Pair")
                    }

                    BluetoothDevice.BOND_NONE -> {
                        Log.e(TAG, "${device.address} BOND_NONE")
                        onBondStateUpdate(device.address, false)
                    }
                }
            }
        }
    }


    private val scanCallback = object : ScanCallback() {
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "OnScanFailed: ${errorCode.parseScanErrorMessage()}")
        }

        override fun onScanResult(callbackType: Int, result: ScanResult) {

            // Log.v(TAG, "onScanResult: $result")
            var serviceUuids: Array<UUID> = arrayOf()
            result.device.uuids?.forEach {
                serviceUuids += it.uuid
            }
            result.scanRecord?.serviceUuids?.forEach {
                if (!serviceUuids.contains(it.uuid)) {
                    serviceUuids += it.uuid
                }
            }

            val name = result.device.name
            val manufacturerDataList = result.manufacturerDataList

            if (!universalBleFilterUtil.filterDevice(
                    name,
                    manufacturerDataList,
                    serviceUuids
                )
            ) return


            mainThreadHandler?.post {
                callbackChannel?.onScanResult(
                    UniversalBleScanResult(
                        name = result.device.name,
                        deviceId = result.device.address,
                        isPaired = result.device.bondState == BOND_BONDED,
                        manufacturerDataList = manufacturerDataList,
                        rssi = result.rssi.toLong(),
                        services = serviceUuids.map { it.toString() }.toList()
                    )
                ) {}
            }
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>?) {
            Log.v(TAG, "onBatchScanResults: $results")
        }
    }


    override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
        Log.d(
            TAG,
            "onConnectionStateChange-> Status: $status ${status.parseHciErrorCode()}, NewState: $newState"
        )

        if (newState == BluetoothGatt.STATE_CONNECTED) {
            mainThreadHandler?.post {
                callbackChannel?.onConnectionChanged(
                    gatt.device.address, true, status.parseHciErrorCode()
                ) {}
            }
        } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
            cleanConnection(gatt)
            mainThreadHandler?.post {
                callbackChannel?.onConnectionChanged(
                    gatt.device.address, false, status.parseHciErrorCode()
                ) {}
            }
            Log.d(TAG, "Closing gatt for ${gatt.device.name}")
            gatt.close()
        }
    }

    override fun onCharacteristicChanged(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
    ) {
        mainThreadHandler?.post {
            callbackChannel?.onValueChanged(
                deviceIdArg = gatt.device.address,
                characteristicIdArg = characteristic.uuid.toString(),
                valueArg = value
            ) {}
        }
    }

    override fun onDescriptorWrite(
        gatt: BluetoothGatt?,
        descriptor: BluetoothGattDescriptor?,
        status: Int,
    ) {
        super.onDescriptorWrite(gatt, descriptor, status)
        if (descriptor?.uuid.toString() == ccdCharacteristic.toString()) {
            val char: String? = descriptor?.characteristic?.uuid?.toString()
            val service: String? = descriptor?.characteristic?.service?.uuid?.toString()
            val deviceId: String? = gatt?.device?.address;
            if (deviceId != null && char != null && service != null) {
                updateSubscriptionState(deviceId, char, service, status)
            }
        }
    }

    private fun updateSubscriptionState(
        deviceId: String,
        characteristic: String,
        service: String,
        status: Int,
    ) {
        subscriptionResultFutureList.filter {
            it.deviceId == deviceId &&
                    it.characteristicId == characteristic &&
                    it.serviceId == service
        }.forEach {
            subscriptionResultFutureList.remove(it)
            val error: String? = status.parseGattErrorCode()
            if (error != null) {
                it.result(
                    Result.failure(
                        FlutterError(
                            status.toString(),
                            "Failed to update subscription state: $error",
                            null,
                        )
                    )
                )
            } else {
                it.result(Result.success(Unit))
            }
        }
    }

    private fun isBluetoothAvailable(): Boolean {
        return bluetoothManager.adapter.isEnabled
    }

    private fun setCachedServices(deviceId: String, services: List<String>) {
        val cachedServicesSharedPref = context.getSharedPreferences(
            "com.navideck.universal_ble.services",
            Context.MODE_PRIVATE
        )
        cachedServicesSharedPref.edit().putStringSet(deviceId, services.toSet()).apply()
        cachedServicesMap[deviceId] = services
    }

    private fun getCachedServicesMap(): Map<String, List<String>> {
        val cachedServicesSharedPref = context.getSharedPreferences(
            "com.navideck.universal_ble.services",
            Context.MODE_PRIVATE
        )
        return cachedServicesSharedPref.all.mapValues { (_, value) ->
            (value as? Set<*>)?.map { it.toString() } ?: emptyList()
        }
    }

    /// Depreciated Members, ( Requires to support older android devices )
    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCharacteristicRead(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        status: Int,
    ) {
        onCharacteristicRead(gatt, characteristic, characteristic.value, status)
    }

    @Suppress("OVERRIDE_DEPRECATION", "DEPRECATION")
    override fun onCharacteristicChanged(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
    ) {
        onCharacteristicChanged(gatt, characteristic, characteristic.value)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == bluetoothEnableRequestCode) {
            val future = bluetoothEnableRequestFuture ?: return false
            future(Result.success(resultCode == Activity.RESULT_OK))
            bluetoothEnableRequestFuture = null
            return true
        } else if (requestCode == bluetoothDisableRequestCode) {
            val future = bluetoothDisableRequestFuture ?: return false
            future(Result.success(resultCode == Activity.RESULT_OK))
            bluetoothDisableRequestFuture = null
            return true
        }
        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
}