#include "multi_window_native_plugin.h"

std::vector<flutter::BinaryMessenger*> MultiWindowNativePlugin::messengers_;
std::function<void(std::vector<std::string>)> MultiWindowNativePlugin::on_create_window_;
std::function<void(bool isMainWindow, const std::string& windowId)> MultiWindowNativePlugin::on_close_window_;
std::function<void(const std::string& windowId)> MultiWindowNativePlugin::_set_window_id_;

void MultiWindowNativePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.coditas.multi_window_native/pluginChannel",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MultiWindowNativePlugin>(registrar);

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "createWindow") {
          if (MultiWindowNativePlugin::on_create_window_) {
            const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (!args) {
            result->Error("INVALID_ARGS", "Expected map");
            return;
            }
            std::vector<std::string> str_args;
            if (args) {
              for (const auto& pair : *args) {
                if (auto p = std::get_if<std::string>(&pair.second)) {
                  str_args.push_back(*p);
                }
              }
            }
            MultiWindowNativePlugin::on_create_window_(str_args);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "closeWindow") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (!args) {
            result->Error("INVALID_ARGS", "Expected map");
            return;
            }
          auto isMainWindowIt = args->find(flutter::EncodableValue("isMainWindow"));
          auto windowIdIt = args->find(flutter::EncodableValue("windowId"));
          
          if (isMainWindowIt != args->end() && windowIdIt != args->end()) {
            if (auto isMainWindowPtr = std::get_if<bool>(&isMainWindowIt->second)) {
              if (auto windowIdPtr = std::get_if<std::string>(&windowIdIt->second)) {
                if (MultiWindowNativePlugin::on_close_window_) {
                  MultiWindowNativePlugin::on_close_window_(*isMainWindowPtr, *windowIdPtr);
                }
              }
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "getMessengerCount") {
          result->Success(flutter::EncodableValue(
                    static_cast<int>(MultiWindowNativePlugin::messengers_.size())));                    
        } else if (call.method_name() == "setWindowId") {
           const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
            if (!args) {
            result->Error("INVALID_ARGS", "Expected map");
            return;
            }
          auto windowIdIt = args->find(flutter::EncodableValue("windowId"));
          if (windowIdIt != args->end()) {
            if (auto windowIdPtr = std::get_if<std::string>(&windowIdIt->second)) {
              if (MultiWindowNativePlugin::_set_window_id_) {
                MultiWindowNativePlugin::_set_window_id_(*windowIdPtr);
              }
            }
          }
          result->Success(flutter::EncodableValue(
                  static_cast<int>(MultiWindowNativePlugin::messengers_.size())));
        }  else if (call.method_name() == "notifyUiReady"){
          // no-op for now
          result->Success(flutter::EncodableValue(true));
        }
        else {
          // broadcast
          BroadcastToAll(call.method_name(), *call.arguments());
          result->Success(flutter::EncodableValue(true));
        }
      });

  registrar->AddPlugin(std::move(plugin));
}

void MultiWindowNativePlugin::RegisterMessenger(flutter::BinaryMessenger* messenger) {
      for (auto* m : messengers_)
        if (m == messenger) return;
  messengers_.push_back(messenger);
}

void MultiWindowNativePlugin::SetCreateWindowCallback(
    std::function<void(std::vector<std::string>)> callback) {
  on_create_window_ = std::move(callback);
}

void MultiWindowNativePlugin::SetCloseWindowCallback(std::function<void(bool isMainWindow, const std::string& windowId)> callback) {
  on_close_window_ = std::move(callback);
}

void MultiWindowNativePlugin::SetWindowIdCallback(std::function<void(const std::string& windowId)> callback) {
  _set_window_id_ = std::move(callback);
}

void MultiWindowNativePlugin::UnregisterMessenger(flutter::BinaryMessenger* messenger) {
    messengers_.erase(
        std::remove(messengers_.begin(), messengers_.end(), messenger),
        messengers_.end()
    );
}

void MultiWindowNativePlugin::ClearMessengers() {
  messengers_.clear();
}

void MultiWindowNativePlugin::BroadcastToAll(const std::string& method,
                                             const flutter::EncodableValue& args) {
  for (auto* messenger : messengers_) {
    flutter::MethodChannel<flutter::EncodableValue> channel(
        messenger, "com.coditas.multi_window_native/pluginChannel",
        &flutter::StandardMethodCodec::GetInstance());
    channel.InvokeMethod(method, std::make_unique<flutter::EncodableValue>(args));
  }
}

MultiWindowNativePlugin::MultiWindowNativePlugin(flutter::PluginRegistrarWindows* registrar) {}



