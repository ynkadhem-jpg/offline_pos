package com.example.offline_pos

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

class AutomaticBackupStorage(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingLegacyStore: PendingStore? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "storeFile" -> storeFile(call, result)
            "listAutomaticBackups" -> runAsync(result) { listAutomaticBackups() }
            "deleteBackup" -> runAsync(result) { deleteBackup(call) }
            else -> result.notImplemented()
        }
    }

    private fun storeFile(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")
        if (sourcePath == null || fileName == null || !isPlainFileName(fileName)) {
            result.error("invalid_arguments", "A valid source and file name are required.", null)
            return
        }

        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingLegacyStore != null) {
                result.error("already_running", "A storage request is already pending.", null)
                return
            }
            pendingLegacyStore = PendingStore(sourcePath, fileName, result)
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                LEGACY_STORAGE_REQUEST,
            )
            return
        }

        runStore(sourcePath, fileName, result)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != LEGACY_STORAGE_REQUEST) return false
        val pending = pendingLegacyStore ?: return true
        pendingLegacyStore = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            runStore(pending.sourcePath, pending.fileName, pending.result)
        } else {
            pending.result.error(
                "permission_denied",
                "Storage permission is required on Android 8 and 9.",
                null,
            )
        }
        return true
    }

    private fun runStore(sourcePath: String, fileName: String, result: MethodChannel.Result) {
        runAsync(result) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                storeWithMediaStore(sourcePath, fileName)
            } else {
                storeInLegacyDownloads(sourcePath, fileName)
            }
        }
    }

    private fun storeWithMediaStore(sourcePath: String, fileName: String): Map<String, Any> {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.RELATIVE_PATH, RELATIVE_PATH)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create the backup file.")
        try {
            resolver.openOutputStream(uri, "w").use { output ->
                requireNotNull(output) { "Could not open the backup destination." }
                FileInputStream(sourcePath).use { input -> input.copyTo(output, COPY_BUFFER_SIZE) }
                output.flush()
            }
            resolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Downloads.IS_PENDING, 0) },
                null,
                null,
            )
            val source = File(sourcePath)
            return backupMap(uri.toString(), fileName, System.currentTimeMillis(), source.length())
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun storeInLegacyDownloads(sourcePath: String, fileName: String): Map<String, Any> {
        val folder = legacyFolder()
        if (!folder.exists() && !folder.mkdirs()) {
            throw IllegalStateException("Could not create the backup folder.")
        }
        val destination = File(folder, fileName)
        val temporary = File(folder, ".$fileName.part")
        try {
            FileInputStream(sourcePath).use { input ->
                FileOutputStream(temporary).use { output ->
                    input.copyTo(output, COPY_BUFFER_SIZE)
                    output.flush()
                    output.fd.sync()
                }
            }
            if (destination.exists() && !destination.delete()) {
                throw IllegalStateException("Could not replace the existing backup.")
            }
            if (!temporary.renameTo(destination)) {
                throw IllegalStateException("Could not finish writing the backup.")
            }
            return backupMap(
                destination.canonicalPath,
                destination.name,
                destination.lastModified(),
                destination.length(),
            )
        } finally {
            if (temporary.exists()) temporary.delete()
        }
    }

    private fun listAutomaticBackups(): List<Map<String, Any>> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            listMediaStoreBackups()
        } else {
            val folder = legacyFolder()
            folder.listFiles()
                ?.filter { it.isFile }
                ?.map {
                    backupMap(it.canonicalPath, it.name, it.lastModified(), it.length())
                }
                ?: emptyList()
        }
    }

    private fun listMediaStoreBackups(): List<Map<String, Any>> {
        val output = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.Downloads._ID,
            MediaStore.Downloads.DISPLAY_NAME,
            MediaStore.Downloads.DATE_MODIFIED,
            MediaStore.Downloads.SIZE,
        )
        activity.contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Downloads.RELATIVE_PATH} = ? AND ${MediaStore.Downloads.IS_PENDING} = 0",
            arrayOf(RELATIVE_PATH),
            null,
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
            val dateIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads.DATE_MODIFIED)
            val sizeIndex = cursor.getColumnIndexOrThrow(MediaStore.Downloads.SIZE)
            while (cursor.moveToNext()) {
                val uri = Uri.withAppendedPath(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    cursor.getLong(idIndex).toString(),
                )
                output.add(
                    backupMap(
                        uri.toString(),
                        cursor.getString(nameIndex),
                        cursor.getLong(dateIndex) * 1000L,
                        cursor.getLong(sizeIndex),
                    ),
                )
            }
        }
        return output
    }

    private fun deleteBackup(call: MethodCall): Boolean {
        val identifier = call.argument<String>("identifier")
            ?: throw IllegalArgumentException("Missing backup identifier.")
        val fileName = call.argument<String>("fileName")
            ?: throw IllegalArgumentException("Missing backup file name.")
        if (!isPlainFileName(fileName)) throw IllegalArgumentException("Invalid backup file name.")

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val uri = Uri.parse(identifier)
            if (uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) {
                throw SecurityException("The backup identifier is outside MediaStore.")
            }
            activity.contentResolver.delete(uri, null, null) > 0
        } else {
            val folder = legacyFolder().canonicalFile
            val file = File(identifier).canonicalFile
            if (file.parentFile != folder || file.name != fileName) {
                throw SecurityException("The backup is outside the dedicated folder.")
            }
            !file.exists() || file.delete()
        }
    }

    private fun legacyFolder(): File = File(
        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
        FOLDER_NAME,
    )

    private fun isPlainFileName(value: String): Boolean =
        value.isNotBlank() && value == File(value).name && !value.contains('/') && !value.contains('\\')

    private fun backupMap(
        identifier: String,
        name: String,
        modifiedAtMillis: Long,
        size: Long,
    ): Map<String, Any> = mapOf(
        "identifier" to identifier,
        "name" to name,
        "modifiedAtMillis" to modifiedAtMillis,
        "size" to size,
    )

    private fun <T> runAsync(result: MethodChannel.Result, operation: () -> T) {
        executor.execute {
            try {
                val value = operation()
                mainHandler.post { result.success(value) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error("storage_error", error.message ?: "Storage operation failed.", null)
                }
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingLegacyStore?.result?.error("activity_destroyed", "The activity was destroyed.", null)
        pendingLegacyStore = null
        executor.shutdown()
    }

    private data class PendingStore(
        val sourcePath: String,
        val fileName: String,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL_NAME = "offline_pos/automatic_backup_storage"
        private const val FOLDER_NAME = "Offline POS Backups"
        private const val RELATIVE_PATH = "Download/$FOLDER_NAME/"
        private const val COPY_BUFFER_SIZE = 64 * 1024
        private const val LEGACY_STORAGE_REQUEST = 6202
    }
}
