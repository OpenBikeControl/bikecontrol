#include "include/nsd_windows/nsd_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "nsd_windows_plugin.h"

void NsdWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  nsd_windows::NsdWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
