package com.example.scamundo

import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.scamundo/intents"
    private var sharedUrl: String? = null
    private var sharedFile: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedUrl" -> {
                    result.success(sharedUrl)
                    sharedUrl = null // Clear after reading
                }
                "getSharedFile" -> {
                    result.success(sharedFile)
                    sharedFile = null // Clear after reading
                }
                "vibrate" -> {
                    val duration = call.argument<Int>("duration")?.toLong() ?: 500L
                    val intensity = call.argument<Int>("intensity") ?: 255
                    vibrateDevice(duration, intensity)
                    result.success(null)
                }
                "playSound" -> {
                    playSound()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
        } else if (intent.action == Intent.ACTION_PROCESS_TEXT) {
            sharedUrl = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
        } else if (intent.action == Intent.ACTION_VIEW) {
            sharedUrl = intent.dataString
            val scheme = intent.data?.scheme
            if (scheme == "content" || scheme == "file") {
                val path = copyUriToTempFile(intent.data!!)
                if (path != null) {
                    sharedFile = path
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("onSharedFileReceived", path)
                    }
                    sharedUrl = null
                    return
                }
            }
        } else if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") != true) {
            val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
            if (uri != null) {
                val path = copyUriToTempFile(uri)
                if (path != null) {
                    sharedFile = path
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, CHANNEL).invokeMethod("onSharedFileReceived", path)
                    }
                    sharedUrl = null
                    return
                }
            }
        }

        if (sharedUrl != null && !sharedUrl!!.startsWith("content://") && !sharedUrl!!.startsWith("file://")) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onSharedUrlReceived", sharedUrl)
            }
        }
    }

    private fun copyUriToTempFile(uri: android.net.Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            var fileName = "shared_file"
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        fileName = cursor.getString(nameIndex)
                    }
                }
            }
            val tempFile = java.io.File(cacheDir, fileName)
            tempFile.outputStream().use { outputStream ->
                inputStream.copyTo(outputStream)
            }
            return tempFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun vibrateDevice(duration: Long, intensity: Int) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (vibrator.hasVibrator()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, intensity))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
            }
        }
    }

    private fun playSound() {
        try {
            val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val r = RingtoneManager.getRingtone(applicationContext, notification)
            r.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
