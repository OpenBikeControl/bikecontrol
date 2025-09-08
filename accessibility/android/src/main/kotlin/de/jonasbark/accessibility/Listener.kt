package de.jonasbark.accessibility

import android.graphics.Rect

object Observable {
    var toService: Listener? = null
    var fromService: Receiver? = null
}

interface Listener {
    fun performTouch(x: Double, y: Double, isKeyDown: Boolean, isKeyUp: Boolean)
}

interface Receiver {
    fun onChange(packageName: String, window: Rect)
}
