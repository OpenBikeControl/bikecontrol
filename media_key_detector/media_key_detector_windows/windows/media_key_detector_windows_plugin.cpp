#include "include/media_key_detector_windows/media_key_detector_windows.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>

#include <map>
#include <memory>
#include <atomic>

namespace {

using flutter::EncodableValue;

// Hotkey IDs for media keys
constexpr int HOTKEY_PLAY_PAUSE = 1;
constexpr int HOTKEY_NEXT_TRACK = 2;
constexpr int HOTKEY_PREV_TRACK = 3;

class MediaKeyDetectorWindows : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MediaKeyDetectorWindows(flutter::PluginRegistrarWindows *registrar);

  virtual ~MediaKeyDetectorWindows();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  
  // Register global hotkeys for media keys
  void RegisterHotkeys();
  
  // Unregister global hotkeys
  void UnregisterHotkeys();
  
  // Handle Windows messages
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  
  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::EventSink<>> event_sink_;
  std::atomic<bool> is_playing_{false};
  int window_proc_id_ = -1;
  bool hotkeys_registered_ = false;
};

// static
void MediaKeyDetectorWindows::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "media_key_detector_windows",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<MediaKeyDetectorWindows>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Set up event channel for media key events
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "media_key_detector_windows_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_handler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        plugin_pointer->event_sink_ = std::move(events);
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        plugin_pointer->event_sink_ = nullptr;
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(event_handler));

  registrar->AddPlugin(std::move(plugin));
}

MediaKeyDetectorWindows::MediaKeyDetectorWindows(flutter::PluginRegistrarWindows *registrar) 
    : registrar_(registrar) {
  // Register a window procedure to handle hotkey messages
  window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}

MediaKeyDetectorWindows::~MediaKeyDetectorWindows() {
  UnregisterHotkeys();
  if (window_proc_id_ != -1) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

void MediaKeyDetectorWindows::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformName") == 0) {
    result->Success(EncodableValue("Windows"));
  } else if (method_call.method_name().compare("getIsPlaying") == 0) {
    result->Success(EncodableValue(is_playing_.load()));
  } else if (method_call.method_name().compare("setIsPlaying") == 0) {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto is_playing_it = arguments->find(EncodableValue("isPlaying"));
      if (is_playing_it != arguments->end()) {
        if (auto* is_playing = std::get_if<bool>(&is_playing_it->second)) {
          is_playing_.store(*is_playing);
          if (*is_playing) {
            RegisterHotkeys();
          } else {
            UnregisterHotkeys();
          }
          result->Success();
          return;
        }
      }
    }
    result->Error("INVALID_ARGUMENT", "isPlaying argument is required");
  } else {
    result->NotImplemented();
  }
}

void MediaKeyDetectorWindows::RegisterHotkeys() {
  if (hotkeys_registered_) {
    return;
  }

  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  
  // Register global hotkeys for media keys
  // MOD_NOREPEAT prevents the hotkey from repeating when held down
  bool play_pause_ok = RegisterHotKey(hwnd, HOTKEY_PLAY_PAUSE, MOD_NOREPEAT, VK_MEDIA_PLAY_PAUSE);
  bool next_ok = RegisterHotKey(hwnd, HOTKEY_NEXT_TRACK, MOD_NOREPEAT, VK_MEDIA_NEXT_TRACK);
  bool prev_ok = RegisterHotKey(hwnd, HOTKEY_PREV_TRACK, MOD_NOREPEAT, VK_MEDIA_PREV_TRACK);
  
  // If all registrations succeeded, mark as registered
  // If any failed, unregister the successful ones to maintain consistent state
  if (play_pause_ok && next_ok && prev_ok) {
    hotkeys_registered_ = true;
  } else {
    // Clean up any successful registrations
    if (play_pause_ok) UnregisterHotKey(hwnd, HOTKEY_PLAY_PAUSE);
    if (next_ok) UnregisterHotKey(hwnd, HOTKEY_NEXT_TRACK);
    if (prev_ok) UnregisterHotKey(hwnd, HOTKEY_PREV_TRACK);
  }
}

void MediaKeyDetectorWindows::UnregisterHotkeys() {
  if (!hotkeys_registered_) {
    return;
  }

  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  
  UnregisterHotKey(hwnd, HOTKEY_PLAY_PAUSE);
  UnregisterHotKey(hwnd, HOTKEY_NEXT_TRACK);
  UnregisterHotKey(hwnd, HOTKEY_PREV_TRACK);
  
  hotkeys_registered_ = false;
}

std::optional<LRESULT> MediaKeyDetectorWindows::HandleWindowProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_HOTKEY && event_sink_) {
    int key_index = -1;
    
    // Map hotkey ID to media key index
    switch (wparam) {
      case HOTKEY_PLAY_PAUSE:
        key_index = 0;  // MediaKey.playPause
        break;
      case HOTKEY_PREV_TRACK:
        key_index = 1;  // MediaKey.rewind
        break;
      case HOTKEY_NEXT_TRACK:
        key_index = 2;  // MediaKey.fastForward
        break;
    }
    
    if (key_index >= 0) {
      event_sink_->Success(EncodableValue(key_index));
    }
    
    return 0;
  }
  
  return std::nullopt;
}

}  // namespace

void MediaKeyDetectorWindowsRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MediaKeyDetectorWindows::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
