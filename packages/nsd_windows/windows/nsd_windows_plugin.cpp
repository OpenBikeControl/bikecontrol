#include "nsd_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace nsd_windows {

	void NsdWindowsPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
		auto methodChannel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
			registrar->messenger(), "com.haberey/nsd", &flutter::StandardMethodCodec::GetInstance());
		auto nsdWindows = std::make_unique<NsdWindowsPlugin>(std::move(methodChannel));
		registrar->AddPlugin(std::move(nsdWindows));
	}

	NsdWindowsPlugin::NsdWindowsPlugin(std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methodChannel) : nsdWindows(std::move(methodChannel)) {}

	NsdWindowsPlugin::~NsdWindowsPlugin() {};

}  // namespace nsd_windows
