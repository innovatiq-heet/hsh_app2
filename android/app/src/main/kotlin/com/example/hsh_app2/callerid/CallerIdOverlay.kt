package com.example.hsh_app2.callerid

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Truecaller-style card drawn over the incoming-call screen. Dismisses itself
 * when the call is answered or ends, or after a safety timeout.
 */
object CallerIdOverlay {
    private const val AUTO_DISMISS_MS = 60_000L

    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var windowManager: WindowManager? = null
    private var telephony: TelephonyManager? = null
    private var callback: Any? = null

    fun canDraw(context: Context): Boolean = Settings.canDrawOverlays(context)

    fun show(context: Context, number: String, matches: List<CallerMatch>) {
        if (!canDraw(context)) return
        handler.post {
            hide()
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val card = buildCard(context, number, matches)
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP
                y = dp(context, 72)
            }
            try {
                wm.addView(card, params)
                view = card
                windowManager = wm
                watchCallState(context)
                handler.postDelayed({ hide() }, AUTO_DISMISS_MS)
            } catch (_: Exception) {
                // Some ROMs refuse overlays during calls; the notification still shows.
            }
        }
    }

    fun hide() {
        handler.removeCallbacksAndMessages(null)
        unwatchCallState()
        val v = view ?: return
        runCatching { windowManager?.removeView(v) }
        view = null
        windowManager = null
    }

    // ---------- call state ----------

    private fun watchCallState(context: Context) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) return
        val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephony = tm
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = onState(state)
                }
                tm.registerTelephonyCallback(ContextCompat.getMainExecutor(context), cb)
                callback = cb
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) = onState(state)
                }
                @Suppress("DEPRECATION")
                tm.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                callback = listener
            }
        } catch (_: Exception) {
        }
    }

    private fun onState(state: Int) {
        // Answered or ended → the card has done its job.
        if (state == TelephonyManager.CALL_STATE_IDLE || state == TelephonyManager.CALL_STATE_OFFHOOK) hide()
    }

    private fun unwatchCallState() {
        val tm = telephony ?: return
        val cb = callback ?: return
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && cb is TelephonyCallback) {
                tm.unregisterTelephonyCallback(cb)
            } else if (cb is PhoneStateListener) {
                @Suppress("DEPRECATION")
                tm.listen(cb, PhoneStateListener.LISTEN_NONE)
            }
        }
        telephony = null
        callback = null
    }

    // ---------- view ----------

    private fun buildCard(context: Context, number: String, matches: List<CallerMatch>): View {
        val m = matches.first()
        val pad = dp(context, 16)
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(pad, pad, pad, pad)
            val margin = dp(context, 12)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { setMargins(margin, 0, margin, 0) }
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#7A3723"))
                cornerRadius = dp(context, 18).toFloat()
            }
            elevation = dp(context, 8).toFloat()
            setOnClickListener {
                context.startActivity(launchIntent(context, m))
                hide()
            }
        }

        // Avatar with initials
        val initials = m.name.trim().split(Regex("\\s+")).take(2).mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")
        root.addView(
            TextView(context).apply {
                text = initials.ifEmpty { "S" }
                setTextColor(Color.parseColor("#7A3723"))
                setTypeface(Typeface.DEFAULT_BOLD)
                textSize = 18f
                gravity = Gravity.CENTER
                background = GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(Color.WHITE) }
            },
            LinearLayout.LayoutParams(dp(context, 48), dp(context, 48)),
        )

        val textCol = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(context, 14), 0, dp(context, 8), 0)
        }
        textCol.addView(TextView(context).apply {
            text = "HSH Phonebook · ${m.relation}"
            setTextColor(Color.parseColor("#F5D2C4"))
            textSize = 11f
            setTypeface(Typeface.DEFAULT_BOLD)
            letterSpacing = 0.05f
        })
        textCol.addView(TextView(context).apply {
            text = if (matches.size > 1 && m.relation != "Student") {
                "${m.relation} of ${matches.joinToString(" & ") { it.name.substringBefore(' ') }}"
            } else m.headline
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(Typeface.DEFAULT_BOLD)
            maxLines = 1
        })
        textCol.addView(TextView(context).apply {
            val bits = listOfNotNull(m.place.takeIf { it.isNotBlank() }, m.studentId.takeIf { it.isNotBlank() }?.let { "ID $it" }, pretty(number))
            text = bits.joinToString(" · ")
            setTextColor(Color.parseColor("#F5D2C4"))
            textSize = 12.5f
            maxLines = 1
        })
        root.addView(textCol, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        root.addView(TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#F5D2C4"))
            textSize = 16f
            setPadding(dp(context, 8), dp(context, 4), dp(context, 4), dp(context, 4))
            setOnClickListener { hide() }
        })
        return root
    }

    fun launchIntent(context: Context, m: CallerMatch): Intent =
        context.packageManager.getLaunchIntentForPackage(context.packageName)!!.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_TARGET, "phonebook")
            putExtra(EXTRA_STUDENT_ID, m.studentId)
            putExtra(EXTRA_QUERY, m.studentId.ifBlank { m.name })
        }

    fun pretty(raw: String): String {
        val n = CallerIdStore.normalize(raw) ?: return raw
        return "+91 ${n.substring(0, 5)} ${n.substring(5)}"
    }

    private fun dp(context: Context, v: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), context.resources.displayMetrics).toInt()

    const val EXTRA_TARGET = "hsh_target"
    const val EXTRA_STUDENT_ID = "hsh_student_id"
    const val EXTRA_QUERY = "hsh_query"
}
