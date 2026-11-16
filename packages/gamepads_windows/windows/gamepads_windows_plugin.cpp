#include "gamepads_windows_plugin.h"

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>

namespace gamepads_windows {
namespace {

constexpr wchar_t kMessageWindowClass[] = L"GamepadsWindowsPluginMessageWindow";
constexpr UINT kChannelMessage = WM_APP + 1;

// A channel call posted from another thread, owned by the message queue
// until the platform thread sends it.
struct PendingCall {
  const char* method;
  flutter::EncodableMap arguments;
};

const flutter::EncodableValue* FindArgument(const flutter::EncodableMap& args,
                                            const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  return it == args.end() ? nullptr : &it->second;
}

std::optional<double> DoubleArgument(const flutter::EncodableMap& args,
                                     const char* key) {
  const auto* value = FindArgument(args, key);
  if (value != nullptr && std::holds_alternative<double>(*value)) {
    return std::get<double>(*value);
  }
  return std::nullopt;
}

std::optional<int64_t> IntArgument(const flutter::EncodableMap& args,
                                   const char* key) {
  const auto* value = FindArgument(args, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (std::holds_alternative<int32_t>(*value)) {
    return std::get<int32_t>(*value);
  }
  if (std::holds_alternative<int64_t>(*value)) {
    return std::get<int64_t>(*value);
  }
  return std::nullopt;
}

}  // namespace

void GamepadsWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<GamepadsWindowsPlugin>(registrar));
}

GamepadsWindowsPlugin::GamepadsWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "xyz.luan/gamepads",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = MessageWindowProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.lpszClassName = kMessageWindowClass;
  RegisterClassExW(&window_class);  // Fails harmlessly if already registered.
  message_window_ =
      CreateWindowExW(0, kMessageWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                      nullptr, GetModuleHandle(nullptr), nullptr);
  if (message_window_ != nullptr) {
    SetWindowLongPtr(message_window_, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(this));
  }

  gamepads_.init(
      [this](const GamepadInfo& gamepad, const Event& event) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("gamepadId")] =
            flutter::EncodableValue(gamepad.id);
        map[flutter::EncodableValue("time")] =
            flutter::EncodableValue(event.time);
        map[flutter::EncodableValue("type")] =
            flutter::EncodableValue(event.type);
        map[flutter::EncodableValue("key")] =
            flutter::EncodableValue(event.key);
        map[flutter::EncodableValue("value")] =
            flutter::EncodableValue(event.value);
        map[flutter::EncodableValue("vendorId")] =
            flutter::EncodableValue(gamepad.vendor_id);
        map[flutter::EncodableValue("productId")] =
            flutter::EncodableValue(gamepad.product_id);
        PostToChannel("onGamepadEvent", std::move(map));
      },
      [this](const GamepadInfo& gamepad, bool connected) {
        flutter::EncodableMap map;
        map[flutter::EncodableValue("gamepadId")] =
            flutter::EncodableValue(gamepad.id);
        map[flutter::EncodableValue("name")] =
            flutter::EncodableValue(gamepad.name);
        map[flutter::EncodableValue("type")] =
            flutter::EncodableValue(connected ? "connected" : "disconnected");
        PostToChannel("onGamepadConnectionEvent", std::move(map));
      });
}

GamepadsWindowsPlugin::~GamepadsWindowsPlugin() {
  // Joins every GameInput callback and reader thread: nothing posts after it.
  gamepads_.stop();
  // Don't unregister the method call handler here. Plugins are destroyed from
  // ~FlutterWindowsEngine, after it has already cleared the messenger's
  // engine, so SetMethodCallHandler(nullptr) dereferences a null engine
  // (FlutterDesktopMessengerSetCallback) and every app close crashed. The
  // dispatcher goes away with the engine, and nothing dispatches during
  // teardown.
  if (message_window_ != nullptr) {
    SetWindowLongPtr(message_window_, GWLP_USERDATA, 0);
    MSG message;
    while (PeekMessage(&message, message_window_, kChannelMessage,
                       kChannelMessage, PM_REMOVE)) {
      delete reinterpret_cast<PendingCall*>(message.lParam);
    }
    DestroyWindow(message_window_);
    message_window_ = nullptr;
  }
}

void GamepadsWindowsPlugin::PostToChannel(const char* method,
                                          flutter::EncodableMap arguments) {
  if (message_window_ == nullptr) {
    return;
  }
  auto* call = new PendingCall{method, std::move(arguments)};
  if (!PostMessage(message_window_, kChannelMessage, 0,
                   reinterpret_cast<LPARAM>(call))) {
    delete call;
  }
}

LRESULT CALLBACK GamepadsWindowsPlugin::MessageWindowProc(HWND hwnd,
                                                          UINT message,
                                                          WPARAM wparam,
                                                          LPARAM lparam) {
  if (message == kChannelMessage) {
    std::unique_ptr<PendingCall> call(reinterpret_cast<PendingCall*>(lparam));
    auto* plugin = reinterpret_cast<GamepadsWindowsPlugin*>(
        GetWindowLongPtr(hwnd, GWLP_USERDATA));
    if (plugin != nullptr) {
      plugin->channel_->InvokeMethod(
          call->method, std::make_unique<flutter::EncodableValue>(
                            std::move(call->arguments)));
    }
    return 0;
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

void GamepadsWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = method_call.method_name();
  if (method == "listGamepads") {
    flutter::EncodableList list;
    for (const auto& gamepad : gamepads_.get_gamepads()) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("id")] = flutter::EncodableValue(gamepad.id);
      map[flutter::EncodableValue("name")] =
          flutter::EncodableValue(gamepad.name);
      map[flutter::EncodableValue("vendorId")] =
          flutter::EncodableValue(gamepad.vendor_id);
      map[flutter::EncodableValue("productId")] =
          flutter::EncodableValue(gamepad.product_id);
      list.push_back(flutter::EncodableValue(map));
    }
    result->Success(flutter::EncodableValue(list));
    return;
  }
  if (method == "hasRumble" || method == "rumble" || method == "stopRumble") {
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    const auto* id = args == nullptr ? nullptr : FindArgument(*args, "gamepadId");
    if (id == nullptr || !std::holds_alternative<std::string>(*id)) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    const auto& gamepad_id = std::get<std::string>(*id);
    bool accepted = false;
    if (method == "hasRumble") {
      accepted = gamepads_.has_rumble(gamepad_id);
    } else if (method == "stopRumble") {
      accepted = gamepads_.set_rumble(gamepad_id, 0, 0, 0);
    } else {
      const auto low = DoubleArgument(*args, "lowFrequency");
      const auto high = DoubleArgument(*args, "highFrequency");
      const auto duration = IntArgument(*args, "durationMillis");
      if (low && high && duration && *duration >= 0 && *duration <= 30000) {
        accepted = gamepads_.set_rumble(gamepad_id, *low, *high,
                                        static_cast<int>(*duration));
      }
    }
    result->Success(flutter::EncodableValue(accepted));
    return;
  }
  result->NotImplemented();
}

}  // namespace gamepads_windows
