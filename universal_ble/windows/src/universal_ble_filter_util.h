#pragma once

#include <cstdint>
#include <exception>
#include <string>

#include "helper/universal_ble_base.h"
#include "generated/universal_ble.g.h"

namespace universal_ble
{
    void setScanFilter(const UniversalScanFilter filter);
    void resetScanFilter();
    bool filterDevice(UniversalBleScanResult scanResult);
} // namespace universal_ble