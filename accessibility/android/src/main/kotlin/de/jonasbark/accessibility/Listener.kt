package de.jonasbark.accessibility

import android.graphics.Rect
import android.view.KeyEvent

object Observable {
    var toService: Listener? = null
    var fromServiceWindow: Receiver? = null
    var fromServiceKeys: Receiver? = null
}

interface Listener {
    fun performTouch(x: Double, y: Double, isKeyDown: Boolean, isKeyUp: Boolean)
}

interface Receiver {
    fun onChange(packageName: String, window: Rect)
    fun onKeyEvent(event: KeyEvent)
}
