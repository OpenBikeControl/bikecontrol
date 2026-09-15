package de.jonasbark.swiftcontrol

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Phone vibration for shift cues, driven straight from the Vibrator service.
 *
 * Flutter's HapticFeedback is View.performHapticFeedback(), which obeys the
 * system "touch feedback" setting and is a no-op unless our window is focused —
 * mid-ride BikeControl is normally behind the trainer app or its own overlay.
 * The Vibrator service has neither constraint; the foreground service keeps
 * the process "foreground" for Android 12+'s background-vibration rule.
 */
object ShiftHapticsChannel {
    const val CHANNEL = "de.jonasbark.swiftcontrol/shift_haptics"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    vibrate(context.applicationContext, call.arguments as? String ?: "up")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun vibrate(context: Context, cue: String) {
        val vibrator = vibrator(context) ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Predefined effects fall back to a framework default on hardware
            // that can't render them, so they are safe to use unconditionally.
            val effect = when (cue) {
                "down" -> VibrationEffect.EFFECT_CLICK
                "limit" -> VibrationEffect.EFFECT_DOUBLE_CLICK
                else -> VibrationEffect.EFFECT_HEAVY_CLICK
            }
            vibrator.vibrate(VibrationEffect.createPredefined(effect))
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = when (cue) {
                "down" -> VibrationEffect.createOneShot(25, 160)
                "limit" -> VibrationEffect.createWaveform(longArrayOf(0, 40, 70, 40), -1)
                else -> VibrationEffect.createOneShot(40, 255)
            }
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            when (cue) {
                "down" -> vibrator.vibrate(25)
                "limit" -> vibrator.vibrate(longArrayOf(0, 40, 70, 40), -1)
                else -> vibrator.vibrate(40)
            }
        }
    }
}
