#include "keypress_simulator_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

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

  int keyIndex = static_cast<int>(modifiers.size());
  input[keyIndex].ki.wVk = static_cast<WORD>(keyCode);
  input[keyIndex].ki.dwFlags = keyDown ? 0 : KEYEVENTF_KEYUP;
  input[keyIndex].type = INPUT_KEYBOARD;

  // Send key sequence to system
  SendInput(static_cast<UINT>(std::size(input)), input, sizeof(INPUT));

  result->Success(flutter::EncodableValue(true));
}

void KeypressSimulatorWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("simulateKeyPress") == 0) {
    SimulateKeyPress(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace keypress_simulator_windows
