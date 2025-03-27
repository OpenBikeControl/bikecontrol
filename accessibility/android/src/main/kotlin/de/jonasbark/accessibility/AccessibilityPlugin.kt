package de.jonasbark.accessibility

import Accessibility
import PigeonEventSink
import StreamEventsStreamHandler
import WindowEvent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat.startActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result


/** AccessibilityPlugin */
class AccessibilityPlugin: FlutterPlugin, MethodCallHandler, Accessibility {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var eventHandler: EventListener

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "accessibility")

    eventHandler = EventListener()

    context = flutterPluginBinding.applicationContext
    Accessibility.setUp(flutterPluginBinding.binaryMessenger, this)
    StreamEventsStreamHandler.register(flutterPluginBinding.binaryMessenger, eventHandler)
    Observable.fromService = eventHandler
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun hasPermission(): Boolean {
    val enabledServices: String? = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
    return enabledServices != null && enabledServices.contains(context.packageName)
  }

  override fun openPermissions() {
    startActivity(context, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
    }, Bundle.EMPTY)
  }

  override fun performTouch(x: Double, y: Double) {
    Observable.toService?.performTouch(x = x, y = y) ?: error("Service not running")
  }

}

class EventListener : StreamEventsStreamHandler(), Receiver {
  private var eventSink: PigeonEventSink<WindowEvent>? = null

  override fun onListen(p0: Any?, sink: PigeonEventSink<WindowEvent>) {
    eventSink = sink
  }

  fun onEventsDone() {
    eventSink?.endOfStream()
    eventSink = null
  }

  override fun onChange(packageName: String, windowWidth: Int, windowHeight: Int) {
    eventSink?.success(WindowEvent(packageName = packageName, windowWidth = windowWidth.toLong(), windowHeight = windowHeight.toLong()))
  }

}
