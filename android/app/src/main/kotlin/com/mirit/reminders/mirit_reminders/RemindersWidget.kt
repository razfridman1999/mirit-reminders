package com.mirit.reminders.mirit_reminders

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RemindersWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.reminders_widget)

            // Tap anywhere (including "+") → open app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val launchPending = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchPending)
            views.setOnClickPendingIntent(R.id.btn_add, launchPending)

            // shared_preferences Flutter plugin writes to "FlutterSharedPreferences"
            // with a "flutter." key prefix.
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.widget_upcoming_reminders", null)

            val containerIds = intArrayOf(R.id.row1, R.id.row2, R.id.row3)
            val titleIds = intArrayOf(R.id.row1_title, R.id.row2_title, R.id.row3_title)
            val timeIds = intArrayOf(R.id.row1_time, R.id.row2_time, R.id.row3_time)

            data class Row(val title: String, val time: String)

            val rows = mutableListOf<Row>()
            if (json != null) {
                try {
                    val arr = JSONArray(json)
                    val now = System.currentTimeMillis()
                    val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())
                    val dateFmt = SimpleDateFormat("dd/MM", Locale.getDefault())

                    for (i in 0 until arr.length()) {
                        if (rows.size >= 3) break
                        val obj = arr.getJSONObject(i)
                        val millis = if (obj.has("millis")) obj.getLong("millis") else 0L

                        // Skip reminders that have already passed (stale data from
                        // a previous Flutter session); millis==0 means no epoch
                        // stored (older data format) — keep those to be safe.
                        if (millis > 0 && millis <= now) continue

                        val timeLabel = if (millis > 0) {
                            recomputeLabel(millis, now, timeFmt, dateFmt)
                        } else {
                            obj.getString("time")
                        }
                        rows.add(Row(obj.getString("title"), timeLabel))
                    }
                } catch (_: Exception) {}
            }

            val count = rows.size
            for (i in 0 until count) {
                views.setTextViewText(titleIds[i], rows[i].title)
                views.setTextViewText(timeIds[i], rows[i].time)
                views.setViewVisibility(containerIds[i], View.VISIBLE)
            }
            for (i in count until 3) {
                views.setViewVisibility(containerIds[i], View.GONE)
            }
            views.setViewVisibility(
                R.id.empty_text,
                if (count == 0) View.VISIBLE else View.GONE
            )

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        private fun recomputeLabel(
            millis: Long,
            nowMillis: Long,
            timeFmt: SimpleDateFormat,
            dateFmt: SimpleDateFormat
        ): String {
            val date = Date(millis)
            val timeStr = timeFmt.format(date)

            // Strip to midnight for day comparison
            val dayMs = 24 * 60 * 60 * 1000L
            val todayStart = (nowMillis / dayMs) * dayMs
            val tomorrowStart = todayStart + dayMs
            val targetStart = (millis / dayMs) * dayMs

            return when (targetStart) {
                todayStart -> "היום $timeStr"
                tomorrowStart -> "מחר $timeStr"
                else -> "${dateFmt.format(date)} $timeStr"
            }
        }
    }
}
