package de.jonasbark.accessibility

import android.graphics.Rect
import android.view.KeyEvent
import GlobalAction
import java.util.concurrent.ConcurrentHashMap

object Observable {
    var toService: Listener? = null
    var fromServiceWindow: Receiver? = null
    var fromServiceKeys: Receiver? = null
    var ignoreHidDevices: Boolean = false
    // Use concurrent set for thread-safe access from AccessibilityService and plugin
    var handledKeys: Set<String> = ConcurrentHashMap.newKeySet()
}

interface Listener {
    fun performTouch(x: Double, y: Double, isKeyDown: Boolean, isKeyUp: Boolean)
    fun performGlobalAction(action: GlobalAction)
}

interface Receiver {
    fun onChange(packageName: String, window: Rect)
    fun onKeyEvent(event: KeyEvent)
}
