# OverlayActionBridge reflects into the running flutter_overlay_window
# OverlayService (its static `instance`, plus `flutterView` and `windowManager`)
# to re-top the overlay and toggle keep-screen-on, because the package exposes
# no API for either. R8 otherwise renames or removes those fields, so the
# reflection throws NoSuchFieldException at runtime ("No field instance in
# ...OverlayService"). Keep the service and its members intact.
-keep class flutter.overlay.window.flutter_overlay_window.OverlayService { *; }
