package de.jonasbark.swiftcontrol

import android.hardware.input.InputManager
import android.os.Handler
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity

class MainActivity: FlutterFragmentActivity(), GamepadsCompatibleActivity {
    var keyListener: ((KeyEvent) -> Boolean)? = null
    var motionListener: ((MotionEvent) -> Boolean)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Custom bridge for trainer overlay action buttons. The package's
        // own overlay→main path is broken in 0.5.0 (see OverlayActionBridge).
        val mainChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OverlayActionBridge.CHANNEL,
        )
        OverlayActionBridge.bindMainChannel(mainChannel)
        mainChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installOverlayHandler" -> {
                    result.success(OverlayActionBridge.installOverlayHandler())
                }
                "uninstallOverlayHandler" -> {
                    OverlayActionBridge.uninstallOverlayHandler()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun isGamepadsInputDevice(device: InputDevice): Boolean {
        return device.sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD
                || device.sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
                // Some bluetooth keyboards are identified as GamePad. Check if it is ALPHABETIC keyboard.
             //   && device.keyboardType != InputDevice.KEYBOARD_TYPE_ALPHABETIC
    }

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        return motionListener?.invoke(motionEvent) ?: false
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) {
            return true
        }
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
        listener: InputManager.InputDeviceListener, handler: Handler?) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }
}
