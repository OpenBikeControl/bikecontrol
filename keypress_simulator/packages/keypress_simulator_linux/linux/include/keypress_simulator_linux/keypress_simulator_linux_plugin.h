#ifndef FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_LINUX_PLUGIN_H_
#define FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_LINUX_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

G_DECLARE_FINAL_TYPE(FlKeypressSimulatorLinuxPlugin, fl_keypress_simulator_linux_plugin, FL,
                     KEYPRESS_SIMULATOR_LINUX_PLUGIN, GObject)

FLUTTER_PLUGIN_EXPORT FlKeypressSimulatorLinuxPlugin* fl_keypress_simulator_linux_plugin_new(
    FlPluginRegistrar* registrar);

FLUTTER_PLUGIN_EXPORT void keypress_simulator_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_KEYPRESS_SIMULATOR_LINUX_PLUGIN_H_
