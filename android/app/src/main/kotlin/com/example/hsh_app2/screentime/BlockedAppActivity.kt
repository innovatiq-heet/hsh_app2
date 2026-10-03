package com.example.hsh_app2.screentime

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedAppActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
        const val EXTRA_REASON = "extra_reason"
        const val EXTRA_IS_DEVICE_LOCKED = "extra_is_device_locked"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isDeviceLocked = false

    /** Re-check lock policy periodically while this activity is shown */
    private val lockCheckRunnable = object : Runnable {
        override fun run() {
            val prefs = getSharedPreferences("hsh_screen_time_policy", MODE_PRIVATE)
            val stillLocked = prefs.getBoolean("is_locked", false)
            if (!stillLocked && isDeviceLocked) {
                // Lock was released! Auto-dismiss the block screen
                goToHomeScreen()
                return
            }
            handler.postDelayed(this, 3000) // Check every 3 seconds
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Lock screen flags — show even over lock screen, keep screen on
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        val pkgName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: "Restricted Application"
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: pkgName
        val reason = intent.getStringExtra(EXTRA_REASON)
            ?: "Access to this app has been restricted by your Hostel Administration."
        isDeviceLocked = intent.getBooleanExtra(EXTRA_IS_DEVICE_LOCKED, false)

        // Root container
        val rootLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#121212")) // Dark background
            val pad = dp(24)
            setPadding(pad, pad, pad, pad)
        }

        // Inner Card
        val cardLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E1E"))
                cornerRadius = dp(20).toFloat()
                setStroke(dp(1), Color.parseColor("#333333"))
            }
            background = bg
            val cPad = dp(24)
            setPadding(cPad, cPad, cPad, cPad)
        }

        // Real App Icon if available from device PackageManager
        var hasRealIcon = false
        if (!isDeviceLocked) {
            try {
                val appDrawable = packageManager.getApplicationIcon(pkgName)
                val appIconView = android.widget.ImageView(this).apply {
                    setImageDrawable(appDrawable)
                    val s = dp(64)
                    layoutParams = LinearLayout.LayoutParams(s, s).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                        bottomMargin = dp(8)
                    }
                }
                cardLayout.addView(appIconView)
                hasRealIcon = true
            } catch (_: Exception) {
                // PackageManager icon not available, fallback to warning badge below
            }
        }

        // Warning Icon Circle
        val iconBadge = TextView(this).apply {
            text = if (isDeviceLocked) "🔒" else (if (hasRealIcon) "🚫" else "🛡️")
            textSize = if (hasRealIcon) 24f else 48f
            gravity = Gravity.CENTER
            if (hasRealIcon) {
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER_HORIZONTAL
                    bottomMargin = dp(4)
                }
                layoutParams = lp
            }
        }
        cardLayout.addView(iconBadge)

        // Pill Tag
        val tagText = if (isDeviceLocked) "DEVICE REMOTELY LOCKED" else "HOSTEL POLICY ENFORCEMENT"
        val tagView = TextView(this).apply {
            text = tagText
            textSize = 11f
            setTextColor(Color.parseColor("#FF5252"))
            setTypeface(Typeface.DEFAULT_BOLD)
            val tagBg = GradientDrawable().apply {
                setColor(Color.parseColor("#33FF5252"))
                cornerRadius = dp(6).toFloat()
            }
            background = tagBg
            val hPad = dp(10)
            val vPad = dp(4)
            setPadding(hPad, vPad, hPad, vPad)
        }
        val tagLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(16)
        }
        cardLayout.addView(tagView, tagLp)

        // Title
        val titleText = if (isDeviceLocked) "Phone Locked" else "App Restricted"
        val titleView = TextView(this).apply {
            text = titleText
            textSize = 22f
            setTextColor(Color.WHITE)
            setTypeface(Typeface.DEFAULT_BOLD)
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val titleLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(12)
        }
        cardLayout.addView(titleView, titleLp)

        // App Name Callout
        val appNameView = TextView(this).apply {
            text = "\"$appName\""
            textSize = 18f
            setTextColor(Color.parseColor("#FFA726"))
            setTypeface(Typeface.DEFAULT_BOLD)
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val appNameLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(6)
        }
        cardLayout.addView(appNameView, appNameLp)

        // Subtitle / Reason
        val descView = TextView(this).apply {
            text = reason
            textSize = 13f
            setTextColor(Color.parseColor("#B0B0B0"))
            gravity = Gravity.CENTER_HORIZONTAL
            setLineSpacing(dp(3).toFloat(), 1.0f)
        }
        val descLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(12)
        }
        cardLayout.addView(descView, descLp)

        // Extra note for device locked
        if (isDeviceLocked) {
            val lockNote = TextView(this).apply {
                text = "Your warden has remotely locked this device.\nContact hostel administration to unlock."
                textSize = 12f
                setTextColor(Color.parseColor("#EF5350"))
                gravity = Gravity.CENTER_HORIZONTAL
                setLineSpacing(dp(2).toFloat(), 1.0f)
            }
            val lockNoteLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(8)
            }
            cardLayout.addView(lockNote, lockNoteLp)
        }

        // Package Name Note
        val pkgView = TextView(this).apply {
            text = pkgName
            textSize = 11f
            setTextColor(Color.parseColor("#757575"))
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val pkgLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(8)
        }
        cardLayout.addView(pkgView, pkgLp)

        // Home Screen Button
        val homeBtn = Button(this).apply {
            text = "Return to Home Screen"
            textSize = 14f
            setTextColor(Color.WHITE)
            setTypeface(Typeface.DEFAULT_BOLD)
            val btnBg = GradientDrawable().apply {
                setColor(Color.parseColor("#D32F2F")) // Red
                cornerRadius = dp(12).toFloat()
            }
            background = btnBg
            setOnClickListener {
                goToHomeScreen()
            }
        }
        val btnLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(48)
        ).apply {
            topMargin = dp(24)
        }
        cardLayout.addView(homeBtn, btnLp)

        // Open HSH Seva Button
        val hshBtn = Button(this).apply {
            text = "Open HSH Seva"
            textSize = 13f
            setTextColor(Color.parseColor("#BBDEFB"))
            val hshBg = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
            }
            background = hshBg
            setOnClickListener {
                openHshApp()
            }
        }
        val hshLp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(40)
        ).apply {
            topMargin = dp(8)
        }
        cardLayout.addView(hshBtn, hshLp)

        rootLayout.addView(cardLayout)
        setContentView(rootLayout)

        // If device is locked, start periodic check for unlock
        if (isDeviceLocked) {
            handler.postDelayed(lockCheckRunnable, 3000)
        }
    }

    override fun onResume() {
        super.onResume()
        // When user comes back to this activity from recents, re-enforce
        if (isDeviceLocked) {
            handler.removeCallbacks(lockCheckRunnable)
            handler.postDelayed(lockCheckRunnable, 3000)
        }
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(lockCheckRunnable)
    }

    override fun onDestroy() {
        handler.removeCallbacks(lockCheckRunnable)
        super.onDestroy()
    }

    private fun goToHomeScreen() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(homeIntent)
        finish()
    }

    private fun openHshApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(launchIntent)
        } else {
            goToHomeScreen()
        }
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Prevent bypassing the block with back press; send user to device launcher
        goToHomeScreen()
    }


    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
