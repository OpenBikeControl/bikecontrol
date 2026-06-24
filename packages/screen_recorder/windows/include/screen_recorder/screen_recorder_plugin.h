#ifndef FLUTTER_PLUGIN_SCREEN_RECORDER_PLUGIN_H_PUBLIC_
#define FLUTTER_PLUGIN_SCREEN_RECORDER_PLUGIN_H_PUBLIC_
// Public header included by Flutter's generated_plugin_registrant.cc.
// Exposes the C-linkage registration entry point only.
#include <flutter_plugin_registrar.h>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void ScreenRecorderPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}
#endif
#endif  // FLUTTER_PLUGIN_SCREEN_RECORDER_PLUGIN_H_PUBLIC_
