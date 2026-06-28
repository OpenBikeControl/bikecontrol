#include "screen_recorder_plugin.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>

namespace screen_recorder {

void ScreenRecorderPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "screen_recorder",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<ScreenRecorderPlugin>();
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

ScreenRecorderPlugin::ScreenRecorderPlugin() {}
ScreenRecorderPlugin::~ScreenRecorderPlugin() {}

void ScreenRecorderPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "isSupported") {
    result->Success(flutter::EncodableValue(CaptureRecorder::IsSupported()));
  } else if (method == "hasPermission" || method == "requestPermission") {
    result->Success(flutter::EncodableValue(true));  // WGC needs no prompt
  } else if (method == "start") {
    recorder_ = std::make_unique<CaptureRecorder>();
    bool ok = recorder_->Start();
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "stop") {
    if (recorder_) {
      std::string path = recorder_->Stop();
      recorder_.reset();
      if (path.empty()) result->Success(flutter::EncodableValue());
      else result->Success(flutter::EncodableValue(path));
    } else {
      result->Success(flutter::EncodableValue());
    }
  } else {
    result->NotImplemented();
  }
}
}  // namespace screen_recorder
