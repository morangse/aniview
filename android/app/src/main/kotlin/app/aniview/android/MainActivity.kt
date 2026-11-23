package app.aniview.android

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Rational
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var mediaChannel: MethodChannel? = null
    private var pendingPicker: MethodChannel.Result? = null
    private var persistVideoAccess = false
    private var pendingBackupPayload: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.aniview/media")
        mediaChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickVideo" -> pickDocument(result, "video/*")
                    "pickAttachment" -> pickDocument(result, "*/*")
                    "readAttachment" -> readAttachment(call.arguments as? String, result)
                    "createBackup" -> createBackup(call.arguments as? Map<*, *>, result)
                    "readBackup" -> pickBackup(result)
                    "availableBytes" -> result.success(filesDir.usableSpace)
                    "getWindowBrightness" ->
                        result.success(window.attributes.screenBrightness.toDouble())
                    "setWindowBrightness" -> setWindowBrightness(call.arguments, result)
                    "supportsPip" -> result.success(supportsPipMode())
                    "enterPip" -> enterPipMode(call.arguments as? Map<*, *>, result)
                    "openBangumi" -> {
                        val uri = Uri.parse(call.arguments as? String ?: "")
                        if (uri.scheme != "https" || uri.host !in listOf("bgm.tv", "next.bgm.tv")) {
                            result.error("invalid_address", "Invalid Bangumi URL", null)
                        } else {
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, uri))
                                result.success(null)
                            } catch (_: android.content.ActivityNotFoundException) {
                                result.error("browser_unavailable", "No browser installed", null)
                            }
                        }
                    }
                    "setFullscreen" -> {
                        val controller = WindowCompat.getInsetsController(window, window.decorView)
                        controller.systemBarsBehavior =
                            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        if (call.arguments == true) {
                            controller.hide(WindowInsetsCompat.Type.systemBars())
                        } else {
                            controller.show(WindowInsetsCompat.Type.systemBars())
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setWindowBrightness(argument: Any?, result: MethodChannel.Result) {
        val value = (argument as? Number)?.toFloat()
        val attrs = window.attributes
        attrs.screenBrightness = if (value == null || value < 0f) {
            WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        } else {
            value.coerceIn(0.01f, 1.0f)
        }
        window.attributes = attrs
        result.success(null)
    }

    private fun supportsPipMode(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPipMode(args: Map<*, *>?, result: MethodChannel.Result) {
        if (!supportsPipMode() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        val rawWidth = (args?.get("width") as? Number)?.toInt() ?: 16
        val rawHeight = (args?.get("height") as? Number)?.toInt() ?: 9
        val width = if (rawWidth > 0) rawWidth else 16
        val height = if (rawHeight > 0) rawHeight else 9
        val ratio = width.toDouble() / height.toDouble()
        val aspectRatio = when {
            ratio > 2.38 -> Rational(238, 100)
            ratio < 0.42 -> Rational(100, 238)
            else -> Rational(width, height)
        }
        try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(aspectRatio)
                .build()
            result.success(enterPictureInPictureMode(params))
        } catch (_: Exception) {
            result.success(false)
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        }
        mediaChannel?.invokeMethod("onPipChanged", isInPictureInPictureMode)
    }

    @Suppress("DEPRECATION")
    private fun pickDocument(result: MethodChannel.Result, mime: String) {
        if (pendingPicker != null) {
            result.error("picker_busy", "A document picker is already active.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mime)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        pendingPicker = result
        persistVideoAccess = mime == "video/*"
        try {
            startActivityForResult(intent, PICK_VIDEO)
        } catch (_: android.content.ActivityNotFoundException) {
            pendingPicker = null
            result.error("picker_unavailable", "No Android document picker is installed.", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun createBackup(args: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingPicker != null) {
            result.error("picker_busy", "A document picker is already active.", null)
            return
        }
        val name = (args?.get("name") as? String)?.takeIf { it.isNotBlank() }
            ?: "aniview-backup.json"
        val content = args?.get("content") as? String
        if (content == null) {
            result.error("backup_invalid", "Backup payload missing.", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/json")
            .putExtra(Intent.EXTRA_TITLE, name)
        pendingPicker = result
        pendingBackupPayload = content.toByteArray(Charsets.UTF_8)
        try {
            startActivityForResult(intent, CREATE_BACKUP)
        } catch (_: android.content.ActivityNotFoundException) {
            pendingPicker = null
            pendingBackupPayload = null
            result.error("picker_unavailable", "No Android document picker is installed.", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun pickBackup(result: MethodChannel.Result) {
        if (pendingPicker != null) {
            result.error("picker_busy", "A document picker is already active.", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
        pendingPicker = result
        try {
            startActivityForResult(intent, PICK_BACKUP)
        } catch (_: android.content.ActivityNotFoundException) {
            pendingPicker = null
            result.error("picker_unavailable", "No Android document picker is installed.", null)
        }
    }

    @Deprecated("FlutterActivity delivers document results through this lifecycle callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_VIDEO &&
            requestCode != CREATE_BACKUP &&
            requestCode != PICK_BACKUP
        ) return
        val reply = pendingPicker ?: return
        pendingPicker = null
        val backupBytes = pendingBackupPayload
        pendingBackupPayload = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            reply.success(if (requestCode == CREATE_BACKUP) false else null)
            return
        }
        if (requestCode == CREATE_BACKUP) {
            val payload = backupBytes ?: ByteArray(0)
            Thread {
                try {
                    contentResolver.openOutputStream(uri)?.use { stream ->
                        stream.write(payload)
                    } ?: throw java.io.IOException("Unable to open output stream")
                    runOnUiThread { reply.success(true) }
                } catch (_: Exception) {
                    runOnUiThread {
                        reply.error("backup_write", "Unable to write backup file", null)
                    }
                }
            }.start()
            return
        }
        if (requestCode == PICK_BACKUP) {
            readTextDocument(uri, 32 * 1024 * 1024, reply)
            return
        }
        try {
            if (persistVideoAccess) {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            reply.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
        } catch (_: SecurityException) {
            reply.error("document_permission", "This provider cannot grant permanent access.", null)
        }
    }

    private fun readTextDocument(uri: Uri, maxBytes: Int, result: MethodChannel.Result) {
        Thread {
            try {
                val bytes = readBytesLimited(uri, maxBytes)
                val text = bytes.toString(Charsets.UTF_8)
                runOnUiThread { result.success(text) }
            } catch (_: Exception) {
                runOnUiThread { result.error("backup_read", "Unable to read backup file", null) }
            }
        }.start()
    }

    private fun readBytesLimited(uri: Uri, maxBytes: Int): ByteArray =
        contentResolver.openInputStream(uri)?.use { stream ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(16 * 1024)
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                if (output.size() + read > maxBytes) {
                    throw java.io.IOException("Document exceeds $maxBytes bytes")
                }
                output.write(buffer, 0, read)
            }
            output.toByteArray()
        } ?: throw java.io.IOException("Empty document provider")

    private fun displayName(uri: Uri): String =
        runCatching {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
        }.getOrNull() ?: "本地视频"

    private fun readAttachment(value: String?, result: MethodChannel.Result) {
        val uri = Uri.parse(value ?: "")
        if (uri.scheme != "content") {
            result.error("attachment_uri", "Invalid document", null)
            return
        }
        Thread {
            try {
                val bytes = readBytesLimited(uri, 4 * 1024 * 1024)
                runOnUiThread { result.success(bytes) }
            } catch (_: Exception) {
                runOnUiThread { result.error("attachment_read", "Unable to read document", null) }
            }
        }.start()
    }

    private companion object {
        const val PICK_VIDEO = 4901
        const val CREATE_BACKUP = 4902
        const val PICK_BACKUP = 4903
    }
}
