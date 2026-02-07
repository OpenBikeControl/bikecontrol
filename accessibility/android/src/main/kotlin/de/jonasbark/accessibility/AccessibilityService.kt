package de.jonasbark.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.accessibilityservice.GestureDescription.StrokeDescription
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.graphics.Path
import android.graphics.Rect
import android.media.AudioManager
import android.os.Build
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.ViewConfiguration
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
import GlobalAction


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
        Observable.fromServiceWindow?.onChange(packageName = currentPackageName, window = windowSize)
    }

    private fun getWindowSize(): Rect {
        val outBounds = Rect()
        rootInActiveWindow?.getBoundsInScreen(outBounds)
        return outBounds
    }


    override fun onInterrupt() {
        Log.d("AccessibilityService", "Service Interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Request key event filtering so we receive onKeyEvent for hardware/HID media keys
        try {
            val info = serviceInfo ?: AccessibilityServiceInfo()
            info.flags = info.flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            // keep other capabilities as defined in XML
            setServiceInfo(info)
        } catch (e: Exception) {
            Log.w("AccessibilityService", "Failed to set service info for key events: ${e.message}")
        }
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val keyString = KeyEvent.keyCodeToString(event.keyCode)
        // if currently active app is BikeControl => handle it, so keymap can be created
        if (!Observable.ignoreHidDevices && isBleRemote(event) && (rootInActiveWindow?.packageName == "de.jonasbark.swiftcontrol" || Observable.handledKeys.contains(keyString))) {
            // Handle keys that have a keymap defined
            Log.d(
                "AccessibilityService",
                "onKeyEvent: keyCode=${event.keyCode} action=${event.action} scanCode=${event.scanCode} flags=${event.flags}"
            )

            // Forward key events to the plugin (Flutter) and swallow them so they don't propagate.
            Observable.fromServiceKeys?.onKeyEvent(event)
            // Return true to indicate we've handled the event and it should be swallowed.
            return true
        } else {
            return false
        }
    }

    private fun isBleRemote(event: KeyEvent): Boolean {
        val dev = InputDevice.getDevice(event.deviceId) ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            dev.isExternal
        } else {
            true
        }
    }

    override fun performGlobalAction(action: GlobalAction) {
        val mappedAction = when (action) {
            GlobalAction.BACK -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK
            GlobalAction.DPAD_CENTER -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_DPAD_CENTER
            GlobalAction.DOWN -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_DPAD_DOWN
            GlobalAction.RIGHT -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_DPAD_RIGHT
            GlobalAction.UP -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_DPAD_UP
            GlobalAction.LEFT -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_DPAD_LEFT
            GlobalAction.HOME -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME
            GlobalAction.RECENTS -> android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS
        }
        performGlobalAction(mappedAction)
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
