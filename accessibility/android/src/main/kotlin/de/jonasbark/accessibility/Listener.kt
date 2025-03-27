package de.jonasbark.accessibility

object Observable {
    var toService: Listener? = null
    var fromService: Receiver? = null
}

interface Listener {
    fun performTouch(x: Double, y: Double)
}

interface Receiver {
    fun onChange(packageName: String, windowWidth: Int, windowHeight: Int)
}