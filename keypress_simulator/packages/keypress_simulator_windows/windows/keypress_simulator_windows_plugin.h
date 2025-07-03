#ifndef FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_WINDOWS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace keypress_simulator_windows {

class KeypressSimulatorWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  KeypressSimulatorWindowsPlugin();

  virtual ~KeypressSimulatorWindowsPlugin();

  // Disallow copy and assign.
  KeypressSimulatorWindowsPlugin(const KeypressSimulatorWindowsPlugin&) =
      delete;
  KeypressSimulatorWindowsPlugin& operator=(
      const KeypressSimulatorWindowsPlugin&) = delete;

  void KeypressSimulatorWindowsPlugin::SimulateKeyPress(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void KeypressSimulatorWindowsPlugin::SimulateMouseClick(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);



  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace keypress_simulator_windows

#endif  // FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_WINDOWS_PLUGIN_H_
