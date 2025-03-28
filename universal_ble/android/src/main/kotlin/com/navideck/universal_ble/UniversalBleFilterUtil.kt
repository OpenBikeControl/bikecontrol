package com.navideck.universal_ble

import android.annotation.SuppressLint
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.os.ParcelUuid
import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import kotlin.experimental.and

private const val TAG = "UniversalBlePlugin"

@SuppressLint("MissingPermission")
class UniversalBleFilterUtil {
    var scanFilter: UniversalScanFilter? = null
    var serviceFilterUUIDS: List<UUID> = emptyList()

    fun filterDevice(
        name: String?,
        manufacturerDataList: List<UniversalManufacturerData>,
        serviceUuids: Array<UUID>,
    ): Boolean {
        val filter = scanFilter ?: return true

        val hasNamePrefixFilter = filter.withNamePrefix.isNotEmpty()
        val hasServiceFilter = filter.withServices.isNotEmpty()
        val hasManufacturerDataFilter = filter.withManufacturerData.isNotEmpty()

        // If there is no filter at all, then allow device
        if (!hasNamePrefixFilter &&
            !hasServiceFilter &&
            !hasManufacturerDataFilter
        ) {
            return true
        }

        // For not, we only have DeviceName filter
        return hasNamePrefixFilter && isNameMatchingFilters(filter, name) ||
                hasServiceFilter && isServicesMatchingFilters(serviceUuids) ||
                hasManufacturerDataFilter && isManufacturerDataMatchingFilters(
            filter,
            manufacturerDataList
        )
    }

    private fun isNameMatchingFilters(scanFilter: UniversalScanFilter, name: String?): Boolean {
        val namePrefixFilter = scanFilter.withNamePrefix.filterNotNull()
        if (namePrefixFilter.isEmpty()) {
            return true
        }
        if (name.isNullOrEmpty()) {
            return false
        }
        return namePrefixFilter.any { name.startsWith(it) }
    }

    private fun isServicesMatchingFilters(
        serviceUuids: Array<UUID>,
    ): Boolean {
        if (serviceFilterUUIDS.isEmpty()) {
            return true
        }
        if (serviceUuids.isEmpty()) {
            return false
        }
        return serviceFilterUUIDS.any {
            serviceUuids.contains(it)
        }
    }

    private fun isManufacturerDataMatchingFilters(
        scanFilter: UniversalScanFilter,
        manufacturerDataList: List<UniversalManufacturerData>,
    ): Boolean {
        val filters = scanFilter.withManufacturerData.filterNotNull()
        if (filters.isEmpty()) return true
        if (manufacturerDataList.isEmpty()) return false
        return manufacturerDataList.any { msd ->
            filters.any { filter ->
                msd.companyIdentifier == filter.companyIdentifier &&
                        isDataMatching(filter.data, msd.data, filter.mask)
            }
        }
    }

    private fun isDataMatching(
        filterData: ByteArray?,
        deviceData: ByteArray,
        filterMask: ByteArray?,
    ): Boolean {
        if (filterData == null) return true
        if (filterData.size > deviceData.size) return false

        val mask = filterMask ?: ByteArray(filterData.size) { 0xFF.toByte() }
        if (filterData.size != mask.size) return false

        return filterData.indices.all { i ->
            (filterData[i] and mask[i]) == (deviceData[i] and mask[i])
        }
    }
}

fun UniversalScanFilter.usesCustomFilters(): Boolean {
    // NamePrefix Filtering is not supported in native filters
    return withNamePrefix.isNotEmpty()
}

// Convert UniversalScanFilter to ScanFilter
fun UniversalScanFilter.toScanFilters(serviceUuids: List<UUID>): List<ScanFilter> {
    val scanFilters: ArrayList<ScanFilter> = arrayListOf()

    // Add withServices Filter
    for (service in serviceUuids) {
        try {
            service.let {
                scanFilters.add(
                    ScanFilter.Builder().setServiceUuid(ParcelUuid(it)).build()
                )
                Log.e(TAG, "scanFilters: $it")
            }
        } catch (e: Exception) {
            Log.e(TAG, e.toString())
            throw FlutterError(
                "illegalIllegalArgument",
                "Invalid serviceId: $service",
                e.toString()
            )
        }
    }

    // Add ManufacturerData Filter
    for (manufacturerData in this.withManufacturerData) {
        try {
            manufacturerData?.companyIdentifier?.let {
                val data: ByteArray = manufacturerData.data ?: ByteArray(0)
                val mask: ByteArray? = manufacturerData.mask
                if (mask == null) {
                    scanFilters.add(
                        ScanFilter.Builder().setManufacturerData(
                            it.toInt(), data
                        ).build()
                    )
                } else {
                    scanFilters.add(
                        ScanFilter.Builder().setManufacturerData(
                            it.toInt(), data, mask
                        ).build()
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, e.toString())
            throw FlutterError(
                "illegalIllegalArgument",
                "Invalid manufacturerData: ${manufacturerData?.companyIdentifier} ${manufacturerData?.data} ${manufacturerData?.mask}",
                e.toString()
            )
        }
    }

    return scanFilters.toList()
}
