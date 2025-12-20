#include "include/windows_iap/windows_iap_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "windows_iap_plugin.h"

void WindowsIapPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  windows_iap::WindowsIapPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
