#ifndef FLUTTER_PLUGIN_WINDOWS_IAP_PLUGIN_H_
#define FLUTTER_PLUGIN_WINDOWS_IAP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace windows_iap {

class WindowsIapPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  WindowsIapPlugin();

  virtual ~WindowsIapPlugin();

  // Disallow copy and assign.
  WindowsIapPlugin(const WindowsIapPlugin&) = delete;
  WindowsIapPlugin& operator=(const WindowsIapPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace windows_iap

#endif  // FLUTTER_PLUGIN_WINDOWS_IAP_PLUGIN_H_
