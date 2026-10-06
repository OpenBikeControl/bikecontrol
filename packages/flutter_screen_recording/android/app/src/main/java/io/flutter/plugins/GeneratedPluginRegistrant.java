package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import com.isvisoft.flutter_screen_recording.FlutterScreenRecordingPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
    FlutterScreenRecordingPlugin.registerWith(registry.registrarFor("com.isvisoft.flutter_screen_recording.FlutterScreenRecordingPlugin"));
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
