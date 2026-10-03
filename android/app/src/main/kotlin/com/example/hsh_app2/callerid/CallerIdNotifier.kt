package com.example.hsh_app2.callerid

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * "Call from Rohan Sharma (Room B-204) · Father" — posted at ring time so it
 * survives the call and doubles as the missed-call record. Also the fallback
 * when the overlay permission is missing or the ROM blocks overlays.
 */
object CallerIdNotifier {
    private const val CHANNEL_ID = "hsh_caller_id"

    fun notifyIncoming(context: Context, number: String, matches: List<CallerMatch>) {
        ensureChannel(context)
        val m = matches.first()
        val title = if (matches.size > 1 && m.relation != "Student") {
            "${m.relation} of ${matches.joinToString(" & ") { it.name.substringBefore(' ') }}"
        } else m.headline
        val body = listOfNotNull(m.place.takeIf { it.isNotBlank() }, CallerIdOverlay.pretty(number)).joinToString(" · ")

        val open = PendingIntent.getActivity(
            context, number.hashCode(), CallerIdOverlay.launchIntent(context, m),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val callBack = PendingIntent.getActivity(
            context, number.hashCode() + 1,
            Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText(body)
            .setSubText("HSH Phonebook")
            .setContentIntent(open)
            .addAction(android.R.drawable.sym_action_call, "Call back", callBack)
            .addAction(android.R.drawable.ic_menu_search, "Open phonebook", open)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .build()

        runCatching {
            // POST_NOTIFICATIONS may be unanswered on Android 13+; the overlay still works.
            NotificationManagerCompat.from(context).notify(number.hashCode(), notification)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Caller ID", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Shows which student or parent is calling"
            },
        )
    }
}
