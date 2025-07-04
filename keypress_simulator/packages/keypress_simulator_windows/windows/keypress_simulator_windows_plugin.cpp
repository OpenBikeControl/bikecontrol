#include "keypress_simulator_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <psapi.h>
#include <string.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace keypress_simulator_windows {

// static
void KeypressSimulatorWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.leanflutter.plugins/keypress_simulator",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<KeypressSimulatorWindowsPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

KeypressSimulatorWindowsPlugin::KeypressSimulatorWindowsPlugin() {}

KeypressSimulatorWindowsPlugin::~KeypressSimulatorWindowsPlugin() {}

void KeypressSimulatorWindowsPlugin::SimulateKeyPress(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const EncodableMap& args = std::get<EncodableMap>(*method_call.arguments());

  UINT keyCode = std::get<int>(args.at(EncodableValue("keyCode")));
  std::vector<std::string> modifiers;
  bool keyDown = std::get<bool>(args.at(EncodableValue("keyDown")));

  EncodableList key_modifier_list =
      std::get<EncodableList>(args.at(EncodableValue("modifiers")));
  for (flutter::EncodableValue key_modifier_value : key_modifier_list) {
    std::string key_modifier = std::get<std::string>(key_modifier_value);
    modifiers.push_back(key_modifier);
  }

  // List of compatible training apps to look for
  std::vector<std::string> compatibleApps = {
    "MyWhooshHD.exe",
    "indieVelo.exe", 
    "biketerra.exe"
  };

  // Try to find and focus a compatible app
  HWND targetWindow = NULL;
  for (const std::string& processName : compatibleApps) {
    targetWindow = FindTargetWindow(processName, "");
    if (targetWindow != NULL) {
      // Only focus the window if it's not already in the foreground
      if (GetForegroundWindow() != targetWindow) {
        SetForegroundWindow(targetWindow);
        Sleep(50); // Brief delay to ensure window is focused
      }
      break;
    }
  }

  INPUT input[6];

  for (int32_t i = 0; i < modifiers.size(); i++) {
    if (modifiers[i].compare("shiftModifier") == 0) {
      input[i].ki.wVk = VK_SHIFT;
    } else if (modifiers[i].compare("controlModifier") == 0) {
      input[i].ki.wVk = VK_CONTROL;
    } else if (modifiers[i].compare("altModifier") == 0) {
      input[i].ki.wVk = VK_MENU;
    } else if (modifiers[i].compare("metaModifier") == 0) {
      input[i].ki.wVk = VK_LWIN;
    }

    input[i].ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
    input[i].type = INPUT_KEYBOARD;
  }

  /*int keyIndex = static_cast<int>(modifiers.size());
  input[keyIndex].ki.wVk = static_cast<WORD>(keyCode);
  input[keyIndex].ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
  input[keyIndex].type = INPUT_KEYBOARD;*/

  // Send key sequence to system
  //SendInput(static_cast<UINT>(std::size(input)), input, sizeof(INPUT));

  BYTE byteValue = static_cast<BYTE>(keyCode);
  keybd_event(byteValue, 0x45, keyDown ? 0 : KEYEVENTF_KEYUP, 0);

  result->Success(flutter::EncodableValue(true));
}

void KeypressSimulatorWindowsPlugin::SimulateMouseClick(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const EncodableMap& args = std::get<EncodableMap>(*method_call.arguments());
  double x = 0;
  double y = 0;

  auto it_x = args.find(EncodableValue("x"));
  if (it_x != args.end() && std::holds_alternative<double>(it_x->second)) {
      x = std::get<double>(it_x->second);
  }

  auto it_y = args.find(EncodableValue("y"));
  if (it_y != args.end() && std::holds_alternative<double>(it_y->second)) {
      y = std::get<double>(it_y->second);
  }

  // Move the mouse to the specified coordinates
  SetCursorPos(static_cast<int>(x), static_cast<int>(y));

  // Prepare input for mouse down and up
  INPUT input = {0};
  input.type = INPUT_MOUSE;

  // Mouse left button down
  input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
  SendInput(1, &input, sizeof(INPUT));

  // Mouse left button up
  input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
  SendInput(1, &input, sizeof(INPUT));

  result->Success(flutter::EncodableValue(true));
}

// Helper function to find window by process name or window title
struct FindWindowData {
  std::string targetProcessName;
  std::string targetWindowTitle;
  HWND foundWindow;
};

BOOL CALLBACK EnumWindowsCallback(HWND hwnd, LPARAM lParam) {
  FindWindowData* data = reinterpret_cast<FindWindowData*>(lParam);
  
  // Check if window is visible and not minimized
  if (!IsWindowVisible(hwnd) || IsIconic(hwnd)) {
    return TRUE; // Continue enumeration
  }
  
  // Get window title
  char windowTitle[256];
  GetWindowTextA(hwnd, windowTitle, sizeof(windowTitle));
  
  // Get process name
  DWORD processId;
  GetWindowThreadProcessId(hwnd, &processId);
  HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
  char processName[MAX_PATH];
  if (hProcess) {
    DWORD size = sizeof(processName);
    if (QueryFullProcessImageNameA(hProcess, 0, processName, &size)) {
      // Extract just the filename from the full path
      char* filename = strrchr(processName, '\\');
      if (filename) {
        filename++; // Skip the backslash
      } else {
        filename = processName;
      }
      
      // Check if this matches our target
      if (!data->targetProcessName.empty() && 
          _stricmp(filename, data->targetProcessName.c_str()) == 0) {
        data->foundWindow = hwnd;
        return FALSE; // Stop enumeration
      }
    }
    CloseHandle(hProcess);
  }
  
  // Check window title if process name didn't match
  if (!data->targetWindowTitle.empty() && 
      _stricmp(windowTitle, data->targetWindowTitle.c_str()) == 0) {
    data->foundWindow = hwnd;
    return FALSE; // Stop enumeration
  }
  
  return TRUE; // Continue enumeration
}

HWND FindTargetWindow(const std::string& processName, const std::string& windowTitle) {
  FindWindowData data;
  data.targetProcessName = processName;
  data.targetWindowTitle = windowTitle;
  data.foundWindow = NULL;
  
  EnumWindows(EnumWindowsCallback, reinterpret_cast<LPARAM>(&data));
  return data.foundWindow;
}



void KeypressSimulatorWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("simulateKeyPress") == 0) {
    SimulateKeyPress(method_call, std::move(result));
  } else if (method_call.method_name().compare("simulateMouseClick") == 0) {
    SimulateMouseClick(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace keypress_simulator_windows
