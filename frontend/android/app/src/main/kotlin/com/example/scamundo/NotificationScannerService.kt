package com.example.scamundo

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.os.Bundle
import android.app.Notification
import android.util.Log

class NotificationScannerService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val extras: Bundle? = sbn.notification.extras
        val allText = StringBuilder()
        
        extras?.keySet()?.forEach { key ->
            val value = extras.get(key)
            if (value is CharSequence) {
                allText.append(value).append(" ")
            } else if (value is Array<*>) {
                value.forEach { item ->
                    if (item is CharSequence) allText.append(item).append(" ")
                    else if (item is android.os.Bundle) {
                        item.keySet().forEach { k ->
                            val v = item.get(k)
                            if (v is CharSequence) allText.append(v).append(" ")
                        }
                    }
                }
            }
        }

        val fullText = allText.toString().trim()
        if (fullText.isEmpty()) return
        
        // Simple fast check, let Dart do the strict URL parsing
        val urlRegex = "(?i)(https?://|www\\.)[a-z0-9-]+(\\.[a-z0-9-]+)+".toRegex()
        val hasUrl = urlRegex.containsMatchIn(fullText)

        if (!hasUrl) return

        val currentTime = System.currentTimeMillis()
        // Clean up old cache entries (older than 10 minutes)
        scannedNotifications.entries.removeIf { currentTime - it.value > 10 * 60 * 1000 }

        val notificationKey = "${sbn.packageName}_${sbn.id}_${sbn.postTime}"
        if (scannedNotifications.containsKey(notificationKey)) {
            return
        }
        scannedNotifications[notificationKey] = currentTime

        Log.d("NotificationScanner", "Found URL in notification from ${sbn.packageName}")

        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val existingStr = prefs.getString("flutter.pending_urls", "[]") ?: "[]"
            val jsonArray = org.json.JSONArray(existingStr)
            jsonArray.put(fullText)
            prefs.edit().putString("flutter.pending_urls", jsonArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val jsonArray = org.json.JSONArray()
                jsonArray.put(fullText)
                prefs.edit().putString("flutter.pending_urls", jsonArray.toString()).apply()
            } catch (e2: Exception) {}
        }
    }

    companion object {
        private val scannedNotifications = mutableMapOf<String, Long>()
    }
}
