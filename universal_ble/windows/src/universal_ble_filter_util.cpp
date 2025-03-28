#include <vector>
#include "helper/utils.h"
#include "generated/universal_ble.g.h"
#include <unordered_set>

namespace universal_ble
{
    std::vector<UniversalManufacturerDataFilter> manufacturerScanFilter = std::vector<UniversalManufacturerDataFilter>();
    std::vector<winrt::guid> serviceFilterUUIDS = std::vector<winrt::guid>();
    std::vector<std::string> namePrefixFilter = std::vector<std::string>();

    void setScanFilter(const UniversalScanFilter filter)
    {
        // Set ManufacturerData filter
        const auto &manufacturerData = filter.with_manufacturer_data();
        for (const flutter::EncodableValue &data : manufacturerData)
        {
            UniversalManufacturerDataFilter manufacturerDataFilter = std::any_cast<UniversalManufacturerDataFilter>(std::get<flutter::CustomEncodableValue>(data));
            manufacturerScanFilter.push_back(manufacturerDataFilter);
        }
        // Set Services Filter
        if (!filter.with_services().empty())
        {
            for (const auto &uuid : filter.with_services())
            {
                serviceFilterUUIDS.push_back(uuid_to_guid(std::get<std::string>(uuid)));
            }
        }
        // Set Names Filter
        if (!filter.with_name_prefix().empty())
        {
            for (const auto &name : filter.with_name_prefix())
            {
                namePrefixFilter.push_back(std::get<std::string>(name));
            }
        }
    }

    void resetScanFilter()
    {
        manufacturerScanFilter.clear();
        serviceFilterUUIDS.clear();
        namePrefixFilter.clear();
    }

    bool isNameMatchingFilters(const std::string *name)
    {
        if (namePrefixFilter.empty())
            return true;
        if (name == nullptr || name->empty())
            return false;
        return std::any_of(namePrefixFilter.begin(), namePrefixFilter.end(),
                           [&name](const flutter::EncodableValue &prefix)
                           {
                               return name->find(std::get<std::string>(prefix)) == 0;
                           });
    }

    bool isServicesMatchingFilters(const flutter::EncodableList *services)
    {
        if (serviceFilterUUIDS.empty())
            return true;
        if (services == nullptr || services->empty())
            return false;

        std::unordered_set<winrt::guid> serviceGUIDs;
        serviceGUIDs.reserve(services->size());
        for (const auto &service : *services)
        {
            if (const auto *str = std::get_if<std::string>(&service))
            {
                serviceGUIDs.insert(uuid_to_guid(*str));
            }
        }

        // Check if any of the filter UUIDs are in the set of service GUIDs
        return std::any_of(serviceFilterUUIDS.begin(), serviceFilterUUIDS.end(),
                           [&serviceGUIDs](const winrt::guid &filterUUID)
                           {
                               return serviceGUIDs.find(filterUUID) != serviceGUIDs.end();
                           });
    }

    bool isManufacturerDataMatchingFilters(const flutter::EncodableList *manufacturerDataList)
    {
        if (manufacturerScanFilter.empty())
            return true;
        if (manufacturerDataList == nullptr || manufacturerDataList->empty())
            return false;

        for (const auto &filter : manufacturerScanFilter)
        {
            const auto *data_filter = filter.data();
            const auto *mask = filter.mask();

            for (const auto &value : *manufacturerDataList)
            {
                const auto &deviceManufacturerData = std::any_cast<const UniversalManufacturerData &>(
                    std::get<flutter::CustomEncodableValue>(value));

                if (deviceManufacturerData.company_identifier() != filter.company_identifier())
                    continue;

                // If no data filter, all data matches
                if (data_filter == nullptr)
                    return true;

                const auto &deviceData = deviceManufacturerData.data();
                if (deviceData.size() < data_filter->size())
                    continue;

                bool isMatch = true;
                for (size_t i = 0; i < data_filter->size(); ++i)
                {
                    const bool hasMask = mask != nullptr && i < mask->size();
                    const uint8_t maskByte = hasMask ? (*mask)[i] : 0xFF;
                    if ((maskByte & (*data_filter)[i]) != (maskByte & deviceData[i]))
                    {
                        isMatch = false;
                        break;
                    }
                }

                if (isMatch)
                    return true;
            }
        }

        return false;
    }

    bool filterDevice(UniversalBleScanResult scanResult)
    {
        bool hasNamePrefixFilter = !namePrefixFilter.empty();
        bool hasServiceFilter = !serviceFilterUUIDS.empty();
        bool hasManufacturerDataFilter = !manufacturerScanFilter.empty();

        // If there is no filter at all, then allow device
        if (!hasNamePrefixFilter &&
            !hasServiceFilter &&
            !hasManufacturerDataFilter)
        {
            return true;
        }

        // Check each filter condition
        return (hasNamePrefixFilter && isNameMatchingFilters(scanResult.name())) ||
               (hasServiceFilter && isServicesMatchingFilters(scanResult.services())) ||
               (hasManufacturerDataFilter && isManufacturerDataMatchingFilters(scanResult.manufacturer_data_list()));
    }

} // namespace universal_ble
