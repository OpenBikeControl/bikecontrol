package com.navideck.universal_ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothStatusCodes
import android.bluetooth.le.ScanCallback.SCAN_FAILED_ALREADY_STARTED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED
import android.bluetooth.le.ScanCallback.SCAN_FAILED_INTERNAL_ERROR
import android.bluetooth.le.ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES
import android.bluetooth.le.ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY
import android.bluetooth.le.ScanResult
import android.util.Log
import android.util.SparseArray
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

private const val TAG = "UniversalBlePlugin"

private val knownGatts = mutableMapOf<String, BluetoothGatt>()
val ccdCharacteristic: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

enum class BleConnectionState(val value: Long) {
    Connected(0),
    Disconnected(1),
    Connecting(2),
    Disconnecting(3)
}

enum class AvailabilityState(val value: Long) {
    Unknown(0),
    Resetting(1),
    Unsupported(2),
    Unauthorized(3),
    PoweredOff(4),
    PoweredOn(5);
}

enum class BleInputProperty(val value: Long) {
    Disabled(0),
    Notification(1),
    Indication(2);
}

enum class BleOutputProperty(val value: Long) {
    withResponse(0),
    withoutResponse(1);
}


enum class CharacteristicProperty(val value: Long) {
    Broadcast(0),
    Read(1),
    WriteWithoutResponse(2),
    Write(3),
    Notify(4),
    Indicate(5),
    AuthenticatedSignedWrites(6),
    ExtendedProperties(7)
}


fun Int.toBleConnectionState(): BleConnectionState {
    return when (this) {
        BluetoothGatt.STATE_CONNECTED -> BleConnectionState.Connected
        BluetoothGatt.STATE_CONNECTING -> BleConnectionState.Connecting
        BluetoothGatt.STATE_DISCONNECTING -> BleConnectionState.Disconnecting
        BluetoothGatt.STATE_DISCONNECTED -> BleConnectionState.Disconnected
        else -> BleConnectionState.Disconnected
    }
}

fun List<String>.toUUIDList(): List<UUID> {
    return this.map { UUID.fromString(it) }
}


fun String.toBluetoothGatt(): BluetoothGatt {
    return this.findGatt()
        ?: throw FlutterError("IllegalArgument", "Unknown deviceId: $this", null)
}

fun String.isKnownGatt(): Boolean {
    return this.findGatt() != null
}

fun String.findGatt(): BluetoothGatt? {
    return knownGatts[this]
}

fun BluetoothGatt.saveCacheIfNeeded() {
    knownGatts[this.device.address] = this
}

fun BluetoothGatt.removeCache() {
    knownGatts.remove(this.device.address)
}


fun Int.toAvailabilityState(): Long {
    return when (this) {
        BluetoothAdapter.STATE_OFF -> AvailabilityState.PoweredOff.value
        BluetoothAdapter.STATE_ON -> AvailabilityState.PoweredOn.value
        BluetoothAdapter.STATE_TURNING_ON -> AvailabilityState.Resetting.value
        BluetoothAdapter.STATE_TURNING_OFF -> AvailabilityState.Resetting.value
        else -> AvailabilityState.Unknown.value
    }
}

fun Int.parseScanErrorMessage(): String {
    return when (this) {
        SCAN_FAILED_ALREADY_STARTED -> "SCAN_FAILED_ALREADY_STARTED"
        SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED"
        SCAN_FAILED_FEATURE_UNSUPPORTED -> "SCAN_FAILED_FEATURE_UNSUPPORTED"
        SCAN_FAILED_INTERNAL_ERROR -> "SCAN_FAILED_INTERNAL_ERROR"
        SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES -> "SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES"
        SCAN_FAILED_SCANNING_TOO_FREQUENTLY -> "SCAN_FAILED_SCANNING_TOO_FREQUENTLY"
        else -> "ErrorCode: $this"
    }
}

fun Int.parseBluetoothStatusCodeError(): String? {
    if (this == BluetoothStatusCodes.SUCCESS) return null
    return when (this) {
        BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ENABLED -> "ERROR_BLUETOOTH_NOT_ENABLED"
        BluetoothStatusCodes.ERROR_BLUETOOTH_NOT_ALLOWED -> "ERROR_BLUETOOTH_NOT_ALLOWED"
        BluetoothStatusCodes.ERROR_DEVICE_NOT_BONDED -> "ERROR_DEVICE_NOT_BONDED"
        BluetoothStatusCodes.ERROR_GATT_WRITE_NOT_ALLOWED -> "ERROR_GATT_WRITE_NOT_ALLOWED"
        BluetoothStatusCodes.ERROR_GATT_WRITE_REQUEST_BUSY -> "ERROR_GATT_WRITE_REQUEST_BUSY"
        BluetoothStatusCodes.ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION -> "ERROR_MISSING_BLUETOOTH_CONNECT_PERMISSION"
        BluetoothStatusCodes.ERROR_PROFILE_SERVICE_NOT_BOUND -> "ERROR_PROFILE_SERVICE_NOT_BOUND"
        BluetoothStatusCodes.ERROR_UNKNOWN -> "ERROR_UNKNOWN"
        BluetoothStatusCodes.FEATURE_NOT_CONFIGURED -> "FEATURE_NOT_CONFIGURED"
        BluetoothStatusCodes.FEATURE_NOT_SUPPORTED -> "FEATURE_NOT_SUPPORTED"
        BluetoothStatusCodes.FEATURE_SUPPORTED -> "FEATURE_SUPPORTED"
        else -> "ErrorCode: $this"
    }
}

fun Int.parseGattErrorCode(): String? {
    return when (this) {
        BluetoothGatt.GATT_SUCCESS -> null
        BluetoothGatt.GATT_READ_NOT_PERMITTED -> "GATT_READ_NOT_PERMITTED"
        BluetoothGatt.GATT_WRITE_NOT_PERMITTED -> "GATT_WRITE_NOT_PERMITTED"
        BluetoothGatt.GATT_INSUFFICIENT_AUTHENTICATION -> "GATT_INSUFFICIENT_AUTHENTICATION"
        BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED -> "GATT_REQUEST_NOT_SUPPORTED"
        BluetoothGatt.GATT_INVALID_OFFSET -> "GATT_INVALID_OFFSET"
        BluetoothGatt.GATT_INSUFFICIENT_AUTHORIZATION -> "GATT_INSUFFICIENT_AUTHORIZATION"
        BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH -> "GATT_INVALID_ATTRIBUTE_LENGTH"
        BluetoothGatt.GATT_INSUFFICIENT_ENCRYPTION -> "GATT_INSUFFICIENT_ENCRYPTION"
        BluetoothGatt.GATT_CONNECTION_CONGESTED -> "GATT_CONNECTION_CONGESTED"
        BluetoothGatt.GATT_FAILURE -> "GATT_FAILURE"
        0x01 -> "GATT_INVALID_HANDLE"
        0x04 -> "GATT_INVALID_PDU"
        0x09 -> "GATT_PREPARE_QUEUE_FULL"
        0x0a -> "GATT_ATTR_NOT_FOUND"
        0x0b -> "GATT_ATTR_NOT_LONG"
        0x0c -> "GATT_INSUFFICIENT_KEY_SIZE"
        0x0e -> "GATT_UNLIKELY"
        0x10 -> "GATT_UNSUPPORTED_GROUP"
        0x11 -> "GATT_INSUFFICIENT_RESOURCES"
        else -> "Unknown Error: $this"
    }
}

val ScanResult.manufacturerDataList: List<UniversalManufacturerData>
    get() {
        return scanRecord?.manufacturerSpecificData?.toList()?.map { (key, value) ->
            UniversalManufacturerData(key.toLong(), value)
        } ?: emptyList()
    }

fun <T> SparseArray<T>.toList(): List<Pair<Int, T>> {
    return (0 until size()).map { index ->
        keyAt(index) to valueAt(index)
    }
}

fun BluetoothGatt.getCharacteristic(
    service: String,
    characteristic: String,
): BluetoothGattCharacteristic? {
    return getService(UUID.fromString(service))?.getCharacteristic(UUID.fromString(characteristic))
}

fun subscriptionFailedError(error: String? = null): Result<Unit> {
    return Result.failure(
        FlutterError(
            "Failed",
            "Failed to update subscription state",
            error
        )
    )
}

fun BluetoothDevice.removeBond() {
    try {
        javaClass.getMethod("removeBond").invoke(this)
    } catch (e: Exception) {
        Log.e(TAG, "Removing bond failed. ${e.message}")
    }
}


fun BluetoothGattCharacteristic.getPropertiesList(): ArrayList<Long> {
    val propertiesList = arrayListOf<Long>()
    if (properties and BluetoothGattCharacteristic.PROPERTY_BROADCAST > 0) {
        propertiesList.add(CharacteristicProperty.Broadcast.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_READ > 0) {
        propertiesList.add(CharacteristicProperty.Read.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE > 0) {
        propertiesList.add(CharacteristicProperty.WriteWithoutResponse.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE > 0) {
        propertiesList.add(CharacteristicProperty.Write.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY > 0) {
        propertiesList.add(CharacteristicProperty.Notify.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE > 0) {
        propertiesList.add(CharacteristicProperty.Indicate.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE > 0) {
        propertiesList.add(CharacteristicProperty.AuthenticatedSignedWrites.value)
    }
    if (properties and BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS > 0) {
        propertiesList.add(CharacteristicProperty.ExtendedProperties.value)
    }
    return propertiesList
}


fun Short.toByteArray(byteOrder: ByteOrder = ByteOrder.LITTLE_ENDIAN): ByteArray =
    ByteBuffer.allocate(2 /*Short.SIZE_BYTES*/).order(byteOrder).putShort(this).array()

// Errors
fun unknownCharacteristicError(char: String) =
    FlutterError("IllegalArgument", "Unknown error", null)


val DeviceDisconnectedError: FlutterError = FlutterError(
    "DeviceDisconnected",
    "Device Disconnected",
    null
)

fun Int.parseHciErrorCode(): String? {
    return when (this) {
        BluetoothGatt.GATT_SUCCESS -> null
        0x01 -> "Unknown HCI Command"
        0x02 -> "Unknown Connection Identifier"
        0x03 -> "Hardware Failure"
        0x04 -> "Page Timeout"
        0x05 -> "Authentication Failure"
        0x06 -> "PIN or Key Missing"
        0x07 -> "Memory Capacity Exceeded"
        0x08 -> "Connection Timeout"
        0x09 -> "Connection Limit Exceeded"
        0x0A -> "Synchronous Connection Limit To A Device Exceeded"
        0x0B -> "Connection Already Exists"
        0x0C -> "Command Disallowed"
        0x0D -> "Connection Rejected due to Limited Resources"
        0x0E -> "Connection Rejected Due To Security Reasons"
        0x0F -> "Connection Rejected due to Unacceptable BD_ADDR"
        0x10 -> "Connection Accept Timeout Exceeded"
        0x11 -> "Unsupported Feature or Parameter Value"
        0x12 -> "Invalid HCI Command Parameters"
        0x13 -> "Remote User Terminated Connection"
        0x14 -> "Remote Device Terminated Connection due to Low Resources"
        0x15 -> "Remote Device Terminated Connection due to Power Off"
        0x16 -> "Connection Terminated By Local Host"
        0x17 -> "Repeated Attempts"
        0x18 -> "Pairing Not Allowed"
        0x19 -> "Unknown LMP PDU"
        0x1A -> "Unsupported Remote Feature / Unsupported LMP Feature"
        0x1B -> "SCO Offset Rejected"
        0x1C -> "SCO Interval Rejected"
        0x1D -> "SCO Air Mode Rejected"
        0x1E -> "Invalid LMP Parameters / Invalid LL Parameters"
        0x1F -> "Unspecified Error"
        0x20 -> "Unsupported LMP Parameter Value / Unsupported LL Parameter Value"
        0x21 -> "Role Change Not Allowed"
        0x22 -> "LMP Response Timeout / LL Response Timeout"
        0x23 -> "LMP Error Transaction Collision / LL Procedure Collision"
        0x24 -> "LMP PDU Not Allowed"
        0x25 -> "Encryption Mode Not Acceptable"
        0x26 -> "Link Key cannot be Changed"
        0x27 -> "Requested QoS Not Supported"
        0x28 -> "Instant Passed"
        0x29 -> "Pairing With Unit Key Not Supported"
        0x2A -> "Different Transaction Collision"
        0x2B -> "Reserved for future use"
        0x2C -> "QoS Unacceptable Parameter"
        0x2D -> "QoS Rejected"
        0x2E -> "Channel Classification Not Supported"
        0x2F -> "Insufficient Security"
        0x30 -> "Parameter Out Of Mandatory Range"
        0x31 -> "Reserved for future use"
        0x32 -> "Role Switch Pending"
        0x33 -> "Reserved for future use"
        0x34 -> "Reserved Slot Violation"
        0x35 -> "Role Switch Failed"
        0x36 -> "Extended Inquiry Response Too Large"
        0x37 -> "Secure Simple Pairing Not Supported By Host"
        0x38 -> "Host Busy - Pairing"
        0x39 -> "Connection Rejected due to No Suitable Channel Found"
        0x3A -> "Controller Busy"
        0x3B -> "Unacceptable Connection Parameters"
        0x3C -> "Advertising Timeout"
        0x3D -> "Connection Terminated due to MIC Failure"
        0x3E -> "Connection Failed to be Established / Synchronization Timeout"
        0x3F -> "MAC Connection Failed"
        0x40 -> "Coarse Clock Adjustment Rejected but Will Try to Adjust Using Clock Dragging"
        0x41 -> "Type0 Submap Not Defined"
        0x42 -> "Unknown Advertising Identifier"
        0x43 -> "Limit Reached"
        0x44 -> "Operation Cancelled by Host"
        0x45 -> "Packet Too Long"
        else -> "Unknown Error $this"
    }
}

// Future result classes
class DiscoverServicesFuture(
    val deviceId: String,
    val result: (Result<List<UniversalBleService>>) -> Unit,
)

class MtuResultFuture(
    val deviceId: String,
    val result: (Result<Long>) -> Unit,
)

class ReadResultFuture(
    val deviceId: String,
    val characteristicId: String,
    val serviceId: String,
    val result: (Result<ByteArray>) -> Unit,
)

class WriteResultFuture(
    val deviceId: String,
    val characteristicId: String,
    val serviceId: String,
    val result: (Result<Unit>) -> Unit,
)

class SubscriptionResultFuture(
    val deviceId: String,
    val characteristicId: String,
    val serviceId: String,
    val result: (Result<Unit>) -> Unit,
)