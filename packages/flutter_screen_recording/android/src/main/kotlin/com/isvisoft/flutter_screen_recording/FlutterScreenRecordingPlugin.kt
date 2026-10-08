package com.isvisoft.flutter_screen_recording

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.util.DisplayMetrics
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.IOException

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding


class FlutterScreenRecordingPlugin : 
    MethodCallHandler, 
    PluginRegistry.ActivityResultListener,
    FlutterPlugin, 
    ActivityAware {

    private var mScreenDensity: Int = 0
    var mMediaRecorder: MediaRecorder? = null
    val mProjectionManager: MediaProjectionManager by lazy {
        ContextCompat.getSystemService(
            pluginBinding!!.applicationContext,
            MediaProjectionManager::class.java
        ) ?: throw Exception("MediaProjectionManager not found")
    }
    var mMediaProjection: MediaProjection? = null
    var mMediaProjectionCallback: MediaProjectionCallback? = null
    var mVirtualDisplay: VirtualDisplay? = null
    private var mDisplayWidth: Int = 1280
    private var mDisplayHeight: Int = 800
    private var videoName: String? = ""
    private var mFileName: String? = ""
    private var mTitle = "Your screen is being recorded"
    private var mMessage = "Your screen is being recorded"
    private var recordAudio: Boolean? = false;
    private val SCREEN_RECORD_REQUEST_CODE = 333

    private var pendingResult: Result? = null

    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var serviceConnection: ServiceConnection? = null

    private fun completePendingResult(value: Boolean) {
        pendingResult?.success(value)
        pendingResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {

        val context = pluginBinding!!.applicationContext
        
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (pendingResult == null) {
                Log.w("ScreenRecordingPlugin", "Ignoring activity result with no pending callback")
                if (resultCode != Activity.RESULT_OK) {
                    ForegroundService.stopService(context)
                }
                return true
            }

            if (resultCode == Activity.RESULT_OK) {

                ForegroundService.startService(context, mTitle, mMessage)
                val intentConnection = Intent(context, ForegroundService::class.java)

                serviceConnection = object : ServiceConnection {

                    override fun onServiceConnected(name: ComponentName?, service: IBinder?) {

                        try {
                            startRecordScreen()
                            mMediaProjectionCallback = MediaProjectionCallback()
                            mMediaProjection = mProjectionManager.getMediaProjection(resultCode, data!!)
                            mMediaProjection?.registerCallback(mMediaProjectionCallback!!, null)
                            mVirtualDisplay = createVirtualDisplay()
                            completePendingResult(true)

                        } catch (e: Throwable) {
                            e.message?.let {
                                Log.e("ScreenRecordingPlugin", it)
                            }
                            completePendingResult(false)
                        }
                    }

                    override fun onServiceDisconnected(name: ComponentName?) {
                    }
                }

                val isBound = context.bindService(intentConnection, serviceConnection!!, Activity.BIND_AUTO_CREATE)
                if (!isBound) {
                    ForegroundService.stopService(context)
                    completePendingResult(false)
                }

            } else {
                ForegroundService.stopService(context)
                completePendingResult(false)
            }
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val appContext = pluginBinding!!.applicationContext

        when (call.method) {
            "startRecordScreen" -> {
                if (pendingResult != null) {
                    result.error(
                        "already_pending",
                        "A screen recording request is already pending.",
                        null
                    )
                    return
                }

                try {
                    pendingResult = result
                    val title = call.argument<String?>("title")
                    val message = call.argument<String?>("message")

                    if (!title.isNullOrEmpty()) {
                        mTitle = title
                    }

                    if (!message.isNullOrEmpty()) {
                        mMessage = message
                    }

                    val metrics = DisplayMetrics()

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val display = activityBinding!!.activity.display
                        display?.getRealMetrics(metrics)
                    } else {
                        @SuppressLint("NewApi")
                        val defaultDisplay = appContext.display
                        defaultDisplay?.getMetrics(metrics)
                    }
                    mScreenDensity = metrics.densityDpi
                    calculateResolution(metrics)
                    videoName = call.argument<String?>("name")
                    recordAudio = call.argument<Boolean?>("audio")

                    val permissionIntent = mProjectionManager.createScreenCaptureIntent()
                    ActivityCompat.startActivityForResult(
                        activityBinding!!.activity,
                        permissionIntent,
                        SCREEN_RECORD_REQUEST_CODE,
                        null
                    )

                } catch (e: Exception) {
                    println("Error onMethodCall startRecordScreen")
                    println(e.message)
                    pendingResult = null
                    result.success(false)
                }
            }
            "stopRecordScreen" -> {
                try {
                    serviceConnection?.let {
                        appContext.unbindService(it)
                    }
                    ForegroundService.stopService(pluginBinding!!.applicationContext)
                    if (mMediaRecorder != null) {
                        stopRecordScreen()
                        result.success(mFileName)
                    } else {
                        result.success("")
                    }
                } catch (e: Exception) {
                    result.success("")
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun calculateResolution(metrics: DisplayMetrics) {

        mDisplayHeight = metrics.heightPixels
        mDisplayWidth = metrics.widthPixels

        var maxRes = 1280.0;
        if (metrics.scaledDensity >= 3.0f) {
            maxRes = 1920.0;
        }
        if (metrics.widthPixels > metrics.heightPixels) {
            var rate = metrics.widthPixels / maxRes

            if (rate > 1.5) {
                rate = 1.5
            }
            mDisplayWidth = maxRes.toInt()
            mDisplayHeight = (metrics.heightPixels / rate).toInt()
            println("Rate : $rate")
        } else {
            var rate = metrics.heightPixels / maxRes
            if (rate > 1.5) {
                rate = 1.5
            }
            mDisplayHeight = maxRes.toInt()
            mDisplayWidth = (metrics.widthPixels / rate).toInt()
            println("Rate : $rate")
        }

        println("Scaled Density")
        println(metrics.scaledDensity)
        println("Original Resolution ")
        println(metrics.widthPixels.toString() + " x " + metrics.heightPixels)
        println("Calcule Resolution ")
        println("$mDisplayWidth x $mDisplayHeight")
    }

    private fun startRecordScreen() {
        try {

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                mMediaRecorder = MediaRecorder(pluginBinding!!.applicationContext)
            } else {
                @Suppress("DEPRECATION")
                mMediaRecorder = MediaRecorder()
            }

            try {
                mFileName = if (Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED) {
                    pluginBinding!!.applicationContext.externalCacheDir?.absolutePath
                } else {
                    pluginBinding!!.applicationContext.cacheDir?.absolutePath
                }
                mFileName += "/$videoName.mp4"
            } catch (e: IOException) {
                println("Error creating name")
                return
            }

            mMediaRecorder?.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            if (recordAudio!!) {
                mMediaRecorder?.setAudioSource(MediaRecorder.AudioSource.MIC);
                mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
                mMediaRecorder?.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            } else {
                mMediaRecorder?.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            }
            mMediaRecorder?.setOutputFile(mFileName)
            mMediaRecorder?.setVideoSize(mDisplayWidth, mDisplayHeight)
            mMediaRecorder?.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            mMediaRecorder?.setVideoEncodingBitRate(5 * mDisplayWidth * mDisplayHeight)
            mMediaRecorder?.setVideoFrameRate(30)

            mMediaRecorder?.prepare()
            mMediaRecorder?.start()

        } catch (e: Exception) {
            Log.d("--INIT-RECORDER", e.message + "")
            println("Error startRecordScreen")
            println(e.message)
        }

    }

    private fun stopRecordScreen() {
        try {
            println("stopRecordScreen")
            mMediaRecorder?.stop()
            mMediaRecorder?.reset()
            println("stopRecordScreen success")

        } catch (e: Exception) {
            Log.d("--INIT-RECORDER", e.message + "")
            println("stopRecordScreen error")
            println(e.message)

        } finally {
            stopScreenSharing()
        }
    }

    private fun createVirtualDisplay(): VirtualDisplay? {
        try {
            return mMediaProjection?.createVirtualDisplay(
                "MainActivity", mDisplayWidth, mDisplayHeight, mScreenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, mMediaRecorder?.surface, null, null
            )
        } catch (e: Exception) {
            println("createVirtualDisplay err")
            println(e.message)
            return null
        }
    }

    private fun stopScreenSharing() {
        if (mVirtualDisplay != null) {
            mVirtualDisplay?.release()
            if (mMediaProjection != null && mMediaProjectionCallback != null) {
                mMediaProjection?.unregisterCallback(mMediaProjectionCallback!!)
                mMediaProjection?.stop()
                mMediaProjection = null
            }
            Log.d("TAG", "MediaProjection Stopped")
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = binding;
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding;
        val channel = MethodChannel(pluginBinding!!.binaryMessenger, "flutter_screen_recording")
        channel.setMethodCallHandler(this)
        activityBinding!!.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding;
    }

    override fun onDetachedFromActivity() {}

    inner class MediaProjectionCallback : MediaProjection.Callback() {
        override fun onStop() {
            mMediaRecorder?.reset()
            mMediaProjection = null
            stopScreenSharing()
        }
    }
}
