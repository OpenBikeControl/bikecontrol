package de.jonasbark.swiftcontrol

import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Workaround for flutter_overlay_window 0.5.0's broken overlay→main bridge:
 * `FlutterOverlayWindow.shareData()` from the overlay isolate logs but the
 * message never arrives at main's Dart. This singleton owns a custom
 * MethodChannel between the two engines, plumbed through Java/Kotlin so we
 * control both ends.
 *
 * Wiring:
 * - MainActivity creates a MethodChannel on the main engine and points
 *   `mainChannel` at it via [bindMainChannel]. Main Dart sets a method-call
 *   handler on this channel to receive `"action"` calls.
 * - When the overlay is shown, main Dart calls `installOverlayHandler` (via
 *   MethodChannel from the main engine) which looks up the overlay engine via
 *   [FlutterEngineCache] and registers a handler on it. That handler forwards
 *   `"push"` calls received from overlay Dart back through `mainChannel` as
 *   `"action"` calls to main Dart.
 */
object OverlayActionBridge {
    const val CHANNEL = "bike_control/overlay_actions"
    private const val TAG = "OverlayActionBridge"
    private const val OVERLAY_ENGINE_KEY = "myCachedEngine" // matches OverlayConstants.CACHED_TAG

    private var mainChannel: MethodChannel? = null
    private var overlayChannel: MethodChannel? = null

    fun bindMainChannel(channel: MethodChannel) {
        mainChannel = channel
    }

    /**
     * Looks up the overlay engine from [FlutterEngineCache] and registers a
     * MethodChannel handler on it. Idempotent; safe to call multiple times.
     * Returns true on success, false if the overlay engine is not cached yet.
     */
    fun installOverlayHandler(): Boolean {
        if (overlayChannel != null) return true
        val engine = FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_KEY)
        if (engine == null) {
            Log.w(TAG, "overlay engine not in cache yet")
            return false
        }
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "push" -> {
                    val action = call.arguments as? String
                    if (action != null) {
                        // Forward to main Dart as an "action" call.
                        mainChannel?.invokeMethod("action", action)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        overlayChannel = channel
        Log.i(TAG, "overlay-side handler installed")
        return true
    }

    /** Tear down the overlay-side handler when the overlay closes. */
    fun uninstallOverlayHandler() {
        overlayChannel?.setMethodCallHandler(null)
        overlayChannel = null
    }
}
