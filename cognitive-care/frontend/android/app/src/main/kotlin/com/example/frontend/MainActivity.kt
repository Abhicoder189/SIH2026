package com.example.frontend

import android.Manifest
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smiriti.sarthi/sms_reader"
    private val SMS_PERMISSION_CODE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasSmsPermission" -> {
                        resultGranted(result)
                    }
                    "requestSmsPermission" -> {
                        requestSmsPermission(result)
                    }
                    "readAllSms" -> {
                        val limit = call.argument<Int>("limit") ?: 200
                        readAllSms(limit, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun resultGranted(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
            result.success(granted)
        } else {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
            result.success(granted)
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_SMS),
                SMS_PERMISSION_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.READ_SMS),
                SMS_PERMISSION_CODE
            )
        }
        result.success(true)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun readAllSms(limit: Int, result: MethodChannel.Result) {
        try {
            val hasPermission = ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED

            if (!hasPermission) {
                result.error("PERMISSION_DENIED", "READ_SMS permission not granted", null)
                return
            }

            val smsList = JSONArray()
            val uri: Uri = Uri.parse("content://sms/inbox")
            val resolver: ContentResolver = contentResolver

            val cursor: Cursor? = resolver.query(
                uri,
                arrayOf("_id", "address", "body", "date", "read"),
                null,
                null,
                "date DESC"
            )

            cursor?.use {
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val id = it.getLong(0)
                    val address = it.getString(1) ?: ""
                    val body = it.getString(2) ?: ""
                    val date = it.getLong(3)
                    val read = it.getInt(4)

                    if (body.isNotBlank()) {
                        val sms = JSONObject()
                        sms.put("id", id)
                        sms.put("address", address)
                        sms.put("body", body)
                        sms.put("date", date)
                        sms.put("read", read == 1)
                        smsList.put(sms)
                        count++
                    }
                }
            }

            result.success(smsList.toString())
        } catch (e: Exception) {
            result.error("SMS_READ_ERROR", e.message, null)
        }
    }
}
