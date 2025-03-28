#pragma once

#include <cstdint>
#include <exception>
#include <string>

#include "winrt/Windows.Foundation.h"
#include "winrt/Windows.Storage.Streams.h"
#include "winrt/base.h"
#include "universal_ble_base.h"

constexpr uint32_t TEN_SECONDS_IN_MSECS = 10000;

namespace universal_ble
{

    std::string mac_address_to_str(uint64_t mac_address);
    uint64_t str_to_mac_address(const std::string& mac_str);

    guid uuid_to_guid(const std::string &uuid);
    std::string guid_to_uuid(const guid &guid);

    std::vector<uint8_t> to_bytevc(const IBuffer& buffer);
    IBuffer from_bytevc(std::vector<uint8_t> bytes);
    std::string to_hexstring(const std::vector<uint8_t>& bytes);

    std::string to_uuidstr(guid guid);
    bool is_little_endian();
    bool is_windows11_or_greater();

    /// To call async functions synchronously
    template <typename AsyncT>
    static auto async_get(AsyncT const &async)
    {
        if (async.Status() == AsyncStatus::Started)
        {
            wait_for_completed(async, TEN_SECONDS_IN_MSECS);
        }
        try
        {
            return async.GetResults();
        }
        catch (const hresult_error &err)
        {
            throw FlutterError("Failed", to_string(err.message()));
        }
        catch (...)
        {
            throw FlutterError("Failed", "Unknown error");
        }
    }

} // namespace universal_ble