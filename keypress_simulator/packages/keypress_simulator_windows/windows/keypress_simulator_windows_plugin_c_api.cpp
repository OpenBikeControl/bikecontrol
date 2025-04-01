#include "include/keypress_simulator_windows/keypress_simulator_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "keypress_simulator_windows_plugin.h"

void KeypressSimulatorWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  keypress_simulator_windows::KeypressSimulatorWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
