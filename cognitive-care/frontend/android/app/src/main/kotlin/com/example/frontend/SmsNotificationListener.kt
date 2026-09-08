package com.example.frontend

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.concurrent.ConcurrentLinkedQueue

class SmsNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "SmsNotificationListener"
        private val smsQueue = ConcurrentLinkedQueue<Map<String, Any>>()
        private var listener: SmsNotificationCallback? = null

        fun getLatestSms(count: Int): List<Map<String, Any>> {
            val result = mutableListOf<Map<String, Any>>()
            val iterator = smsQueue.iterator()
            var i = 0
            while (iterator.hasNext() && i < count) {
                result.add(iterator.next())
                i++
            }
            return result
        }

        fun clearProcessed(count: Int) {
            var i = 0
            while (i < count && smsQueue.isNotEmpty()) {
                smsQueue.poll()
                i++
            }
        }

        fun setListener(cb: SmsNotificationCallback?) {
            listener = cb
        }
    }

    interface SmsNotificationCallback {
        fun onNewSms(address: String, body: String, timestamp: Long)
    }

    private val smsPackages = setOf(
        "com.android.mms",
        "com.android.messaging",
        "com.google.android.apps.messaging",
        "com.samsung.android.messaging",
        "com.whatsapp",
        "org.telegram.messenger",
        "com.truecaller",
        "com.viber.voip",
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        val isSms = smsPackages.any { pkg -> packageName.contains(pkg, ignoreCase = true) }
        if (!isSms) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()

        val body = bigText ?: text
        if (body.isBlank()) return

        val address = if (title.isNotBlank() && !title.contains("message", ignoreCase = true)) {
            title
        } else {
            "SMS"
        }

        val smsData = mapOf(
            "address" to address,
            "body" to body,
            "timestamp" to sbn.postTime,
            "package" to packageName,
        )

        smsQueue.add(smsData)

        Log.d(TAG, "Captured SMS from $address: ${body.take(50)}...")

        listener?.onNewSms(address, body, sbn.postTime)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // No-op
    }
}
