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
#include <string>
#include <vector>
#include <sstream>
#include <iomanip>

namespace {

using flutter::EncodableValue;

// Hotkey IDs for media keys
constexpr int HOTKEY_PLAY_PAUSE = 1;
constexpr int HOTKEY_NEXT_TRACK = 2;
constexpr int HOTKEY_PREV_TRACK = 3;
constexpr int HOTKEY_VOLUME_UP = 4;
constexpr int HOTKEY_VOLUME_DOWN = 5;

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
  
  // Register for raw input from keyboard devices
  void RegisterRawInput(HWND hwnd);
  
  // Unregister raw input
  void UnregisterRawInput(HWND hwnd);
  
  // Get device identifier from device handle
  std::string GetDeviceIdentifier(HANDLE hDevice);
  
  // Handle Windows messages
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  
  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::EventSink<>> event_sink_;
  std::atomic<bool> is_playing_{false};
  int window_proc_id_ = -1;
  bool hotkeys_registered_ = false;
  bool raw_input_registered_ = false;
  
  // Cache for device identifiers
  std::map<HANDLE, std::string> device_cache_;
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
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  UnregisterRawInput(hwnd);
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
          HWND hwnd = registrar_->GetView()->GetNativeWindow();
          if (*is_playing) {
            RegisterHotkeys();
            RegisterRawInput(hwnd);
          } else {
            UnregisterHotkeys();
            UnregisterRawInput(hwnd);
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
  bool vol_up_ok = RegisterHotKey(hwnd, HOTKEY_VOLUME_UP, MOD_NOREPEAT, VK_VOLUME_UP);
  bool vol_down_ok = RegisterHotKey(hwnd, HOTKEY_VOLUME_DOWN, MOD_NOREPEAT, VK_VOLUME_DOWN);
  
  // If all registrations succeeded, mark as registered
  // If any failed, unregister the successful ones to maintain consistent state
  if (play_pause_ok && next_ok && prev_ok && vol_up_ok && vol_down_ok) {
    hotkeys_registered_ = true;
  } else {
    // Clean up any successful registrations
    if (play_pause_ok) UnregisterHotKey(hwnd, HOTKEY_PLAY_PAUSE);
    if (next_ok) UnregisterHotKey(hwnd, HOTKEY_NEXT_TRACK);
    if (prev_ok) UnregisterHotKey(hwnd, HOTKEY_PREV_TRACK);
    if (vol_up_ok) UnregisterHotKey(hwnd, HOTKEY_VOLUME_UP);
    if (vol_down_ok) UnregisterHotKey(hwnd, HOTKEY_VOLUME_DOWN);
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
  UnregisterHotKey(hwnd, HOTKEY_VOLUME_UP);
  UnregisterHotKey(hwnd, HOTKEY_VOLUME_DOWN);
  
  hotkeys_registered_ = false;
}

void MediaKeyDetectorWindows::RegisterRawInput(HWND hwnd) {
  if (raw_input_registered_) {
    return;
  }

  // Register for raw input from keyboard devices
  RAWINPUTDEVICE rid[1];
  
  // Keyboard devices
  rid[0].usUsagePage = 0x01;  // Generic Desktop Controls
  rid[0].usUsage = 0x06;      // Keyboard
  rid[0].dwFlags = RIDEV_INPUTSINK;  // Receive input even when not in foreground
  rid[0].hwndTarget = hwnd;
  
  if (RegisterRawInputDevices(rid, 1, sizeof(rid[0]))) {
    raw_input_registered_ = true;
  }
}

void MediaKeyDetectorWindows::UnregisterRawInput(HWND hwnd) {
  if (!raw_input_registered_) {
    return;
  }

  // Unregister raw input
  RAWINPUTDEVICE rid[1];
  
  rid[0].usUsagePage = 0x01;
  rid[0].usUsage = 0x06;
  rid[0].dwFlags = RIDEV_REMOVE;
  rid[0].hwndTarget = nullptr;
  
  RegisterRawInputDevices(rid, 1, sizeof(rid[0]));
  raw_input_registered_ = false;
  device_cache_.clear();
}

std::string MediaKeyDetectorWindows::GetDeviceIdentifier(HANDLE hDevice) {
  // Check cache first
  auto it = device_cache_.find(hDevice);
  if (it != device_cache_.end()) {
    return it->second;
  }

  // Get device name
  UINT size = 0;
  GetRawInputDeviceInfoA(hDevice, RIDI_DEVICENAME, nullptr, &size);
  
  if (size == 0) {
    return "Unknown Device";
  }

  std::vector<char> name(size);
  if (GetRawInputDeviceInfoA(hDevice, RIDI_DEVICENAME, name.data(), &size) == static_cast<UINT>(-1)) {
    return "Unknown Device";
  }

  std::string deviceName(name.data());
  
  // Cache the result
  device_cache_[hDevice] = deviceName;
  
  return deviceName;
}

std::optional<LRESULT> MediaKeyDetectorWindows::HandleWindowProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  
  // Handle raw input messages for device-specific detection
  if (message == WM_INPUT && event_sink_) {
    UINT dwSize;
    GetRawInputData((HRAWINPUT)lparam, RID_INPUT, nullptr, &dwSize, sizeof(RAWINPUTHEADER));
    
    std::vector<BYTE> buffer(dwSize);
    if (GetRawInputData((HRAWINPUT)lparam, RID_INPUT, buffer.data(), &dwSize, sizeof(RAWINPUTHEADER)) != dwSize) {
      return std::nullopt;
    }
    
    RAWINPUT* raw = (RAWINPUT*)buffer.data();
    
    if (raw->header.dwType == RIM_TYPEKEYBOARD) {
      RAWKEYBOARD& keyboard = raw->data.keyboard;
      
      // Check for media keys
      int key_index = -1;
      
      // Media keys have VKey codes
      // Check for key down event (RI_KEY_MAKE is defined as 0, so we check both explicitly)
      if (keyboard.Flags == RI_KEY_MAKE) {  // Key down event
        switch (keyboard.VKey) {
          case VK_MEDIA_PLAY_PAUSE:
            key_index = 0;  // MediaKey.playPause
            break;
          case VK_MEDIA_PREV_TRACK:
            key_index = 1;  // MediaKey.rewind
            break;
          case VK_MEDIA_NEXT_TRACK:
            key_index = 2;  // MediaKey.fastForward
            break;
          case VK_VOLUME_UP:
            key_index = 3;  // MediaKey.volumeUp
            break;
          case VK_VOLUME_DOWN:
            key_index = 4;  // MediaKey.volumeDown
            break;
        }
        
        if (key_index >= 0) {
          // Get device identifier
          std::string deviceId = GetDeviceIdentifier(raw->header.hDevice);
          
          // Send event with both key index and device identifier
          flutter::EncodableMap event_data;
          event_data[EncodableValue("key")] = EncodableValue(key_index);
          event_data[EncodableValue("device")] = EncodableValue(deviceId);
          
          event_sink_->Success(EncodableValue(event_data));
          
          return 0;
        }
      }
    }
  }
  
  // Fallback to hotkey messages (for compatibility)
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
      case HOTKEY_VOLUME_UP:
        key_index = 3;  // MediaKey.volumeUp
        break;
      case HOTKEY_VOLUME_DOWN:
        key_index = 4;  // MediaKey.volumeDown
        break;
    }
    
    if (key_index >= 0) {
      // Send event with key index only (no device info for hotkey)
      flutter::EncodableMap event_data;
      event_data[EncodableValue("key")] = EncodableValue(key_index);
      event_data[EncodableValue("device")] = EncodableValue("HID Device");
      
      event_sink_->Success(EncodableValue(event_data));
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
