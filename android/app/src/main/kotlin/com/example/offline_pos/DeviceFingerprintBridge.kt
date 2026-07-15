package com.example.offline_pos

import android.content.Context
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale

class DeviceFingerprintBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getFingerprint" -> result.success(createFingerprint())
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun createFingerprint(): String {
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID,
        ).orEmpty()

        val identifiers = listOf(
            "android_id:$androidId",
            "brand:${Build.BRAND}",
            "manufacturer:${Build.MANUFACTURER}",
            "model:${Build.MODEL}",
            "device:${Build.DEVICE}",
            "product:${Build.PRODUCT}",
            "board:${Build.BOARD}",
            "hardware:${Build.HARDWARE}",
            "bootloader:${Build.BOOTLOADER}",
            "abis:${Build.SUPPORTED_ABIS.joinToString(",")}",
        )
            .map { it.trim().lowercase(Locale.US) }
            .filter { it.substringAfter(':').isNotBlank() }

        return sha256(identifiers.joinToString("|"))
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(
            value.toByteArray(Charsets.UTF_8),
        )
        return digest.joinToString("") { byte -> "%02X".format(byte) }
    }

    companion object {
        private const val CHANNEL_NAME = "com.example.offline_pos/device_fingerprint"
    }
}
