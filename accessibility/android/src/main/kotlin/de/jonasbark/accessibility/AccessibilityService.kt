package de.jonasbark.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.accessibilityservice.GestureDescription.StrokeDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.util.Log
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED


class AccessibilityService : AccessibilityService(), Listener {


    override fun onCreate() {
        super.onCreate()
        Observable.toService = this
    }

    override fun onDestroy() {
        super.onDestroy()
        Observable.toService = null
    }

    private val ignorePackages = listOf("com.android.systemui", "com.android.launcher", "com.android.settings")

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.packageName == null || rootInActiveWindow == null) {
            return
        }
        if (event.eventType != TYPE_WINDOW_STATE_CHANGED || event.packageName in ignorePackages) {
            // we're not interested
            return
        }
        val currentPackageName = event.packageName.toString()
        val windowSize = getWindowSize()
        Observable.fromService?.onChange(packageName = currentPackageName, window = windowSize)
    }

    private fun getWindowSize(): Rect {
        val outBounds = Rect()
        rootInActiveWindow?.getBoundsInScreen(outBounds)
        return outBounds
    }


    override fun onInterrupt() {
        Log.d("AccessibilityService", "Service Interrupted")
    }

    override fun performTouch(x: Double, y: Double, isKeyDown: Boolean, isKeyUp: Boolean) {
        val gestureBuilder = GestureDescription.Builder()
        val path = Path()
        path.moveTo(x.toFloat(), y.toFloat())
        path.lineTo(x.toFloat()+1, y.toFloat())

        val stroke = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            StrokeDescription(path, 0, ViewConfiguration.getTapTimeout().toLong(), isKeyDown && !isKeyUp)
        } else {
            // API 24–25: no “willContinue” support
            StrokeDescription(path, 0L, ViewConfiguration.getTapTimeout().toLong())
        }
        gestureBuilder.addStroke(stroke)

        dispatchGesture(gestureBuilder.build(), null, null)
    }
}
