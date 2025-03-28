//
//  UniversalBleFilterUtil.swift
//  universal_ble
//
//  Created by Rohit Sangwan on 23/08/24.
//

import CoreBluetooth
import Foundation

public class UniversalBleFilterUtil {
    var scanFilter: UniversalScanFilter?
    var scanFilterServicesUUID: [CBUUID] = []

    func filterDevice(name: String?, manufacturerData: UniversalManufacturerData?, services: [CBUUID]?) -> Bool {
        guard let filter = scanFilter else {
            return true
        }

        let hasNamePrefixFilter = !filter.withNamePrefix.isEmpty
        let hasServiceFilter = !filter.withServices.isEmpty
        let hasManufacturerDataFilter = !filter.withManufacturerData.isEmpty

        // If there is no filter at all, then allow device
        if !hasNamePrefixFilter && !hasServiceFilter && !hasManufacturerDataFilter {
            return true
        }

        // Else check one of the filter passes
        return hasNamePrefixFilter && isNameMatchingFilters(filter: filter, name: name) ||
            hasServiceFilter && isServicesMatchingFilters(services: services) ||
            hasManufacturerDataFilter && isManufacturerDataMatchingFilters(scanFilter: filter, msd: manufacturerData)
    }

    func isNameMatchingFilters(filter: UniversalScanFilter, name: String?) -> Bool {
        let prefixFilters = filter.withNamePrefix.compactMap { $0 }.filter { !$0.isEmpty }

        guard !prefixFilters.isEmpty else {
            return true
        }

        guard let name = name, !name.isEmpty else {
            return false
        }

        return prefixFilters.contains { name.hasPrefix($0) }
    }

    func isServicesMatchingFilters(services: [CBUUID]?) -> Bool {
        let serviceFilters = Set(scanFilterServicesUUID.compactMap { $0 })

        guard !serviceFilters.isEmpty else {
            return true
        }

        guard let services = services, !services.isEmpty else {
            return false
        }

        return !Set(services).isDisjoint(with: serviceFilters)
    }

    func isManufacturerDataMatchingFilters(scanFilter: UniversalScanFilter, msd: UniversalManufacturerData?) -> Bool {
        let filters = scanFilter.withManufacturerData.compactMap { $0 }
        if filters.isEmpty {
            return true
        }

        guard let msd = msd else {
            return false
        }

        for filter in filters {
            let companyIdentifier: Int64 = filter.companyIdentifier
            if msd.companyIdentifier == companyIdentifier && findData(find: filter.data?.toData(), inData: msd.data.toData(), usingMask: filter.mask?.toData()) {
                return true
            }
        }
        return false
    }

    func findData(find: Data?, inData data: Data, usingMask mask: Data?) -> Bool {
        if let find = find {
            // If mask is null, use a default mask of all 1s
            let mask = mask ?? Data(repeating: 0xFF, count: find.count)

            // Ensure find & mask are same length
            guard find.count == mask.count else {
                return false
            }

            for i in 0 ..< find.count {
                // Perform bitwise AND with mask and then compare
                if (find[i] & mask[i]) != (data[i] & mask[i]) {
                    return false
                }
            }
        }
        return true
    }
}

extension UniversalScanFilter {
    var usesCustomFilters: Bool {
        return !withManufacturerData.isEmpty || !withNamePrefix.isEmpty
    }
}
