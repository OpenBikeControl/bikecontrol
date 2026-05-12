#include "include/multi_window_native/multi_window_native_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "multi_window_native_plugin.h"

void MultiWindowNativePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MultiWindowNativePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
