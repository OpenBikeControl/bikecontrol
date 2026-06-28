#include "include/screen_recorder/screen_recorder_plugin_c_api.h"
#include "include/screen_recorder/screen_recorder_plugin.h"
#include <flutter/plugin_registrar_windows.h>
#include "screen_recorder_plugin.h"

// Called by Flutter's generated_plugin_registrant.cc (pluginClass without CApi suffix).
void ScreenRecorderPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  screen_recorder::ScreenRecorderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

// Legacy CApi-suffixed alias; kept for compatibility if pubspec pluginClass
// is ever changed to ScreenRecorderPluginCApi.
void ScreenRecorderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ScreenRecorderPluginRegisterWithRegistrar(registrar);
}
