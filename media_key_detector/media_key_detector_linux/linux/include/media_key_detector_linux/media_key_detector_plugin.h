#ifndef FLUTTER_PLUGIN_MEDIA_KEY_DETECTOR_LINUX_PLUGIN_H_
#define FLUTTER_PLUGIN_MEDIA_KEY_DETECTOR_LINUX_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

G_DECLARE_FINAL_TYPE(FlMediaKeyDetectorPlugin, fl_media_key_detector_plugin, FL,
                     MEDIA_KEY_DETECTOR_PLUGIN, GObject)

FLUTTER_PLUGIN_EXPORT FlMediaKeyDetectorPlugin* fl_media_key_detector_plugin_new(
    FlPluginRegistrar* registrar);

FLUTTER_PLUGIN_EXPORT void media_key_detector_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_MEDIA_KEY_DETECTOR_LINUX_PLUGIN_H_