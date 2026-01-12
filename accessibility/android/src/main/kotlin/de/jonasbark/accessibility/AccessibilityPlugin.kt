package de.jonasbark.accessibility

import AKeyEvent
import Accessibility
import HidKeyPressedStreamHandler
import MediaAction
import PigeonEventSink
import StreamEventsStreamHandler
import WindowEvent
import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.content.ContextCompat.startActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel


/** AccessibilityPlugin */
class AccessibilityPlugin: FlutterPlugin, Accessibility {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var windowEventHandler: WindowEventListener
  private lateinit var hidEventHandler: HidEventListener

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "accessibility")

    windowEventHandler = WindowEventListener()
    hidEventHandler = HidEventListener()

    context = flutterPluginBinding.applicationContext
    Accessibility.setUp(flutterPluginBinding.binaryMessenger, this)
    StreamEventsStreamHandler.register(flutterPluginBinding.binaryMessenger, windowEventHandler)
    HidKeyPressedStreamHandler.register(flutterPluginBinding.binaryMessenger, hidEventHandler)
    Observable.fromServiceWindow = windowEventHandler
    Observable.fromServiceKeys = hidEventHandler
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun hasPermission(): Boolean {
    val enabledServices: String? = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
    return enabledServices != null && enabledServices.contains(context.packageName)
  }

  override fun isRunning(): Boolean {
    return Observable.toService != null
  }

  override fun openPermissions() {
    startActivity(context, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
    }, Bundle.EMPTY)
  }

  override fun performTouch(x: Double, y: Double, isKeyDown: Boolean, isKeyUp: Boolean) {
    Observable.toService?.performTouch(x = x, y = y, isKeyUp = isKeyUp, isKeyDown = isKeyDown) ?: error("Service not running")
  }

  override fun controlMedia(action: MediaAction) {
    val audioService = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
    when (action) {
      MediaAction.PLAY_PAUSE -> {
          audioService.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
          audioService.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
      }
      MediaAction.NEXT -> {
          audioService.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))
          audioService.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT))
      }
      MediaAction.VOLUME_DOWN -> {
          audioService.adjustVolume(android.media.AudioManager.ADJUST_LOWER, android.media.AudioManager.FLAG_SHOW_UI)
      }
      MediaAction.VOLUME_UP -> {
          audioService.adjustVolume(android.media.AudioManager.ADJUST_RAISE, android.media.AudioManager.FLAG_SHOW_UI)
      }
    }
  }

  override fun ignoreHidDevices() {
    Observable.ignoreHidDevices = true
  }

  override fun setHandledKeys(keys: List<String>) {
    // Clear and update the concurrent set
    Observable.handledKeys = keys.toSet()
  }

}

class WindowEventListener : StreamEventsStreamHandler(), Receiver {
  private var eventSink: PigeonEventSink<WindowEvent>? = null

  override fun onListen(p0: Any?, sink: PigeonEventSink<WindowEvent>) {
    eventSink = sink
  }

  override fun onCancel(p0: Any?) {
    eventSink?.endOfStream()
    eventSink = null
  }

  override fun onChange(packageName: String, window: Rect) {
    eventSink?.success(WindowEvent(packageName = packageName, right = window.right.toLong(), left = window.left.toLong(), bottom = window.bottom.toLong(), top = window.top.toLong()))
  }

  override fun onKeyEvent(event: KeyEvent) {

  }

}


class HidEventListener : HidKeyPressedStreamHandler(), Receiver {

  private var keyEventSink: PigeonEventSink<AKeyEvent>? = null

  override fun onListen(p0: Any?, sink: PigeonEventSink<AKeyEvent>) {
    keyEventSink = sink
  }

  override fun onChange(packageName: String, window: Rect) {

  }

  override fun onKeyEvent(event: KeyEvent) {
    val keyString = KeyEvent.keyCodeToString(event.keyCode)
    keyEventSink?.success(
      AKeyEvent(
        hidKey = keyString,
        source = event.device.name,
        keyUp = event.action == KeyEvent.ACTION_UP,
        keyDown = event.action == KeyEvent.ACTION_DOWN
      )
    )
  }
}
