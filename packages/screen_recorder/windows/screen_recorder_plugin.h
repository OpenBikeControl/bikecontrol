#ifndef FLUTTER_PLUGIN_SCREEN_RECORDER_PLUGIN_H_
#define FLUTTER_PLUGIN_SCREEN_RECORDER_PLUGIN_H_
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>
#include "capture_recorder.h"

namespace screen_recorder {
class ScreenRecorderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);
  ScreenRecorderPlugin();
  virtual ~ScreenRecorderPlugin();
 private:
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  std::unique_ptr<CaptureRecorder> recorder_;
};
}  // namespace screen_recorder
#endif
