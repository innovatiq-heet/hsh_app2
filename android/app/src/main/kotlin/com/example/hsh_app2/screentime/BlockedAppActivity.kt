package com.example.hsh_app2.screentime

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BlockedAppActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val pkgName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: "Restricted Application"
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: pkgName

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

        // Warning Icon Circle
        val iconBadge = TextView(this).apply {
            text = "🚫"
            textSize = 48f
            gravity = Gravity.CENTER
        }
        cardLayout.addView(iconBadge)

        // Pill Tag: "RESTRICTED ACCESS"
        val tagView = TextView(this).apply {
            text = "HOSTEL POLICY ENFORCEMENT"
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
        val titleView = TextView(this).apply {
            text = "App Restricted"
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
            text = "Access to this app has been restricted by your Hostel Administration to help students stay focused during study and curfew hours."
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
