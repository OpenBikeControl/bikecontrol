#ifndef FLUTTER_PLUGIN_UNIVERSAL_BLE_PLUGIN_H_
#define FLUTTER_PLUGIN_UNIVERSAL_BLE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <windows.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>

#include <memory>
#include "helper/utils.h"
#include "helper/universal_enum.h"
#include "helper/universal_ble_base.h"
#include "generated/universal_ble.g.h"
#include "ui_thread_handler.hpp"
#include "universal_ble_thread_safe.h"

namespace universal_ble
{
    struct GattCharacteristicObject
    {
        GattCharacteristic obj = nullptr;
        std::optional<event_token> subscription_token; 
    };

    struct GattServiceObject
    {
        GattDeviceService obj = nullptr;
        std::unordered_map<std::string, GattCharacteristicObject> characteristics;
    };

    struct BluetoothDeviceAgent
    {
        BluetoothLEDevice device;
        event_token connection_status_changed_token;
        std::unordered_map<std::string, GattServiceObject> gatt_map;

        BluetoothDeviceAgent(const BluetoothLEDevice &device, const event_token connection_status_changed_token,
                             const std::unordered_map<std::string, GattServiceObject> &gatt_map)
            : device(device),
              connection_status_changed_token(connection_status_changed_token),
              gatt_map(gatt_map)
        {
        }

        ~BluetoothDeviceAgent()
        {
            device = nullptr;
        }

        GattCharacteristicObject &FetchCharacteristic(const std::string &service_uuid,
                                                       const std::string &characteristic_uuid)
        {
            if (gatt_map.count(service_uuid) == 0)
            {
                throw FlutterError("IllegalArgument", "Service not found");
            }
            if (gatt_map[service_uuid].characteristics.count(characteristic_uuid) == 0)
            {
                throw FlutterError("IllegalArgument", "Characteristic not found");
            }
            return gatt_map[service_uuid].characteristics.at(characteristic_uuid);
        }
    };

    class UniversalBlePlugin : public flutter::Plugin, public UniversalBlePlatformChannel
    {
    public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

        UniversalBlePlugin(flutter::PluginRegistrarWindows *registrar);

        ~UniversalBlePlugin();

        // Disallow copy and assign.
        UniversalBlePlugin(const UniversalBlePlugin&) = delete;
        UniversalBlePlugin& operator=(const UniversalBlePlugin&) = delete;


    private:
        static void SuccessCallback() {}
        static void ErrorCallback(const FlutterError &error)
        {
            // Ignore ChannelConnection Error, This might occur because of HotReload
            if (error.code() != "channel-error")
            {
                std::cout << "ErrorCode: " << error.code() << " Message: " << error.message() << std::endl;
            }
        }

        flutter::PluginRegistrarWindows *registrar_;
        bool initialized_ = false;

        UniversalBleUiThreadHandler ui_thread_handler_;
        Radio bluetooth_radio_{nullptr};
        RadioState old_radio_state_ = RadioState::Unknown;
        BluetoothLEAdvertisementWatcher bluetooth_le_watcher_{nullptr};
        DeviceWatcher device_watcher_{nullptr};

        std::unordered_map<uint64_t, std::unique_ptr<BluetoothDeviceAgent>> connected_devices_{};
        ThreadSafeMap<std::string, DeviceInformation> device_watcher_devices_{};
        ThreadSafeMap<std::string, UniversalBleScanResult> scan_results_{};

        event_token bluetooth_le_watcher_received_token_;
        event_token device_watcher_added_token_;
        event_token device_watcher_updated_token_;
        event_token device_watcher_removed_token_;
        event_token device_watcher_enumeration_completed_token_;
        event_token device_watcher_stopped_token_;
        event_revoker<IRadio> radio_state_changed_revoker_;


        fire_and_forget InitializeAsync();
        fire_and_forget ConnectAsync(uint64_t bluetooth_address);
        fire_and_forget SetNotifiableAsync(
            const std::string& device_id,
            const std::string& service,
            const std::string& characteristic,
            int64_t ble_input_property,
            std::function<void(std::optional<FlutterError> reply)> result);
        fire_and_forget PairAsync(const std::string& device_id, std::function<void(ErrorOr<bool> reply)> result);
        fire_and_forget CustomPairAsync(const std::string& device_id, std::function<void(ErrorOr<bool> reply)> result);
        static fire_and_forget GetSystemDevicesAsync(
            std::vector<std::string> with_services,
            std::function<void(ErrorOr<flutter::EncodableList> reply)> result);
        static fire_and_forget IsPairedAsync(const std::string& device_id, std::function<void(ErrorOr<bool> reply)> result);

        static void DiscoverServicesAsync(BluetoothDeviceAgent& bluetooth_device_agent, const std::function<void(ErrorOr<flutter::EncodableList> reply)>&);
        void PairingRequestedHandler(DeviceInformationCustomPairing sender, const DevicePairingRequestedEventArgs& event_args);

        void RadioStateChanged(const Radio& sender, const IInspectable&);
        void SetupDeviceWatcher();
        void DisposeDeviceWatcher();
        void PushUniversalScanResult(UniversalBleScanResult scan_result, bool is_connectable);
        void BluetoothLeWatcherReceived(const BluetoothLEAdvertisementWatcher& sender, const
                                        BluetoothLEAdvertisementReceivedEventArgs& args);
        void OnDeviceInfoReceived(const DeviceInformation& device_info);
        void BluetoothLeDeviceConnectionStatusChanged(const BluetoothLEDevice& sender, const IInspectable& args);
        void CleanConnection(uint64_t bluetooth_address);
 

    	void GattCharacteristicValueChanged(const GattCharacteristic& sender, const GattValueChangedEventArgs& args);

        // UniversalBlePlatformChannel implementation.
        void GetBluetoothAvailabilityState(std::function<void(ErrorOr<int64_t> reply)> result) override;
        void EnableBluetooth(std::function<void(ErrorOr<bool> reply)> result) override;
        void DisableBluetooth(std::function<void(ErrorOr<bool> reply)> result) override;
        ErrorOr<int64_t> GetConnectionState(const std::string &device_id) override;
        std::optional<FlutterError> StartScan(const UniversalScanFilter *filter) override;
        std::optional<FlutterError> StopScan() override;
        std::optional<FlutterError> Connect(const std::string &device_id) override;
        std::optional<FlutterError> Disconnect(const std::string &device_id) override;
        void DiscoverServices(
            const std::string &device_id,
            std::function<void(ErrorOr<flutter::EncodableList> reply)> result) override;
        void SetNotifiable(
            const std::string &device_id,
            const std::string &service,
            const std::string &characteristic,
            int64_t ble_input_property,
            std::function<void(std::optional<FlutterError> reply)> result) override;
        void ReadValue(
            const std::string &device_id,
            const std::string &service,
            const std::string &characteristic,
            std::function<void(ErrorOr<std::vector<uint8_t>> reply)> result) override;
        void WriteValue(
            const std::string &device_id,
            const std::string &service,
            const std::string &characteristic,
            const std::vector<uint8_t> &value,
            int64_t ble_output_property,
            std::function<void(std::optional<FlutterError> reply)> result) override;
        void RequestMtu(
            const std::string &device_id,
            int64_t expected_mtu,
            std::function<void(ErrorOr<int64_t> reply)> result) override;
        void IsPaired(
            const std::string &device_id,
            std::function<void(ErrorOr<bool> reply)> result) override;
        void Pair(
            const std::string &device_id,
            std::function<void(ErrorOr<bool> reply)> result) override;
        std::optional<FlutterError> UnPair(const std::string &device_id) override;
        void GetSystemDevices(
            const flutter::EncodableList &with_services,
            std::function<void(ErrorOr<flutter::EncodableList> reply)> result) override;
    };

} // namespace universal_ble

#endif // FLUTTER_PLUGIN_UNIVERSAL_BLE_PLUGIN_H_