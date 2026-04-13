package com.baakhapaa.com

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.baakhapaa.student.R

class ReadingStreakWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.reading_streak_widget)

            // Tap the widget to open the app
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            // Read data from home_widget SharedPreferences
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val streakDays = getIntSafe(prefs, "streak_days", 0)
            val totalChapters = getIntSafe(prefs, "total_chapters", 0)
            val totalBooks = getIntSafe(prefs, "total_books", 0)
            val lastBook = prefs.getString("last_book", "") ?: ""

            // Flame icon
            if (streakDays > 0) {
                views.setImageViewResource(R.id.flame_icon, R.drawable.ic_widget_flame)
            } else {
                views.setImageViewResource(R.id.flame_icon, R.drawable.ic_widget_flame_gray)
            }

            views.setTextViewText(R.id.streak_count, "$streakDays")
            views.setTextViewText(R.id.streak_label, "day streak")
            views.setTextViewText(R.id.chapters_count, "$totalChapters")
            views.setTextViewText(R.id.books_count, "$totalBooks")

            if (streakDays == 0) {
                views.setViewVisibility(R.id.cta_start, View.VISIBLE)
                views.setViewVisibility(R.id.last_book_row, View.GONE)
                views.setViewVisibility(R.id.streak_message, View.GONE)
            } else if (lastBook.isNotEmpty()) {
                views.setViewVisibility(R.id.cta_start, View.GONE)
                views.setViewVisibility(R.id.last_book_row, View.VISIBLE)
                views.setViewVisibility(R.id.streak_message, View.GONE)
                views.setTextViewText(R.id.last_book_text, lastBook)
            } else {
                views.setViewVisibility(R.id.cta_start, View.GONE)
                views.setViewVisibility(R.id.last_book_row, View.GONE)
                views.setViewVisibility(R.id.streak_message, View.VISIBLE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        } catch (e: Exception) {
            // Fallback: render minimal safe widget
            try {
                val views = RemoteViews(context.packageName, R.layout.reading_streak_widget)
                views.setTextViewText(R.id.streak_count, "0")
                views.setTextViewText(R.id.streak_label, "day streak")
                views.setTextViewText(R.id.chapters_count, "0")
                views.setTextViewText(R.id.books_count, "0")
                views.setImageViewResource(R.id.flame_icon, R.drawable.ic_widget_flame_gray)
                views.setViewVisibility(R.id.cta_start, View.VISIBLE)
                views.setViewVisibility(R.id.last_book_row, View.GONE)
                views.setViewVisibility(R.id.streak_message, View.GONE)
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                // Layout itself is broken, nothing we can do
            }
        }
    }

    private fun getIntSafe(prefs: SharedPreferences, key: String, defaultVal: Int): Int {
        return try {
            prefs.getInt(key, defaultVal)
        } catch (e: ClassCastException) {
            try {
                prefs.getLong(key, defaultVal.toLong()).toInt()
            } catch (_: Exception) {
                try {
                    prefs.getString(key, null)?.toIntOrNull() ?: defaultVal
                } catch (_: Exception) {
                    defaultVal
                }
            }
        }
    }
}
