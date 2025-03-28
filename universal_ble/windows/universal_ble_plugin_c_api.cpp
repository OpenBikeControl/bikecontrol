#include "include/universal_ble/universal_ble_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "src/universal_ble_plugin.h"

void UniversalBlePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
    universal_ble::UniversalBlePlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
