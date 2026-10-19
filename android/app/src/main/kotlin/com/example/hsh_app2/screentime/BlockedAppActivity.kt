package com.example.hsh_app2.screentime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher

class BlockedAppActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
        const val EXTRA_REASON_CODE = "extra_reason_code"

        fun intent(context: Context, packageName: String, appName: String, reason: BlockReason): Intent =
            Intent(context, BlockedAppActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(EXTRA_PACKAGE_NAME, packageName)
                putExtra(EXTRA_APP_NAME, appName)
                putExtra(EXTRA_REASON_CODE, reason.wireName)
            }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isDeviceLocked = false
    private var blockedPackage = ""

    /** Dismiss automatically the moment the policy no longer blocks this app (unlock, curfew end…). */
    private val lockCheckRunnable = object : Runnable {
        override fun run() {
            if (PolicyEvaluator.evaluate(this@BlockedAppActivity, blockedPackage) == null) {
                goToHomeScreen()
                return
            }
            handler.postDelayed(this, 3000)
        }
    }

    private val policyListener: () -> Unit = { handler.post(lockCheckRunnable) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Lock screen flags — show even over lock screen, keep screen on
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                OnBackInvokedDispatcher.PRIORITY_DEFAULT
            ) { goToHomeScreen() }
        }

        renderContent(intent)
        PolicyStore.addPolicyListener(policyListener)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent != null) {
            renderContent(intent)
        }
    }

    private fun renderContent(intent: Intent) {
        val pkgName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: "Restricted Application"
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: pkgName
        val blockReason = BlockReason.fromWire(intent.getStringExtra(EXTRA_REASON_CODE)) ?: BlockReason.APP_BLOCKED
        val reason = blockReason.message
        blockedPackage = pkgName
        isDeviceLocked = blockReason == BlockReason.DEVICE_LOCKED

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
        val tagText = blockReason.tag
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
        val titleText = blockReason.title
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

        // Request Approval Button (when app is blocked / restricted or installer blocked)
        if (blockReason == BlockReason.APP_BLOCKED || blockReason == BlockReason.INSTALLER_BLOCKED) {
            val reqBtn = Button(this).apply {
                text = if (blockReason == BlockReason.INSTALLER_BLOCKED) "Request App Download" else "Request Approval from Warden"
                textSize = 14f
                setTextColor(Color.WHITE)
                setTypeface(Typeface.DEFAULT_BOLD)
                val bg = GradientDrawable().apply {
                    setColor(Color.parseColor("#0284C7")) // Primary Blue
                    cornerRadius = dp(12).toFloat()
                }
                background = bg
                setOnClickListener {
                    showAppRequestDialog(pkgName, appName, blockReason, this)
                }
            }
            val reqLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(48)
            ).apply {
                topMargin = dp(20)
            }
            cardLayout.addView(reqBtn, reqLp)
        }

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
            topMargin = if (blockReason == BlockReason.APP_BLOCKED || blockReason == BlockReason.INSTALLER_BLOCKED) dp(10) else dp(24)
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

    override fun onResume() {
        super.onResume()
        handler.removeCallbacks(lockCheckRunnable)
        handler.postDelayed(lockCheckRunnable, 3000)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(lockCheckRunnable)
    }

    override fun onDestroy() {
        PolicyStore.removePolicyListener(policyListener)
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

    private fun showAppRequestDialog(
        pkgName: String,
        defaultAppName: String,
        reasonCode: BlockReason,
        requestButton: Button
    ) {
        val isInstaller = reasonCode == BlockReason.INSTALLER_BLOCKED
        val dialogView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val p = dp(20)
            setPadding(p, p, p, p)
            setBackgroundColor(Color.parseColor("#1E1E1E"))
        }

        val titleView = TextView(this).apply {
            text = if (isInstaller) "Request App Download" else "Request App Access"
            textSize = 18f
            setTextColor(Color.WHITE)
            setTypeface(Typeface.DEFAULT_BOLD)
            setPadding(0, 0, 0, dp(6))
        }
        dialogView.addView(titleView)

        val descView = TextView(this).apply {
            text = if (isInstaller)
                "Tell the warden which app you need to download from Play Store and why."
            else
                "Explain why you need access to this application."
            textSize = 13f
            setTextColor(Color.parseColor("#B0B0B0"))
            setPadding(0, 0, 0, dp(14))
        }
        dialogView.addView(descView)

        // App Name Input
        val appNameLabel = TextView(this).apply {
            text = "App Name"
            textSize = 12f
            setTextColor(Color.parseColor("#0284C7"))
            setTypeface(Typeface.DEFAULT_BOLD)
            setPadding(0, 0, 0, dp(4))
        }
        dialogView.addView(appNameLabel)

        val appNameInput = android.widget.EditText(this).apply {
            hint = if (isInstaller) "e.g. Duolingo, Zoom, Classroom" else defaultAppName
            setText(if (isInstaller) "" else defaultAppName)
            if (!isInstaller) isEnabled = false
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#666666"))
            textSize = 14f
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2A2A2A"))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), Color.parseColor("#444444"))
            }
            background = bg
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
        }
        dialogView.addView(appNameInput)

        // Reason Input
        val reasonLabel = TextView(this).apply {
            text = "Reason / Purpose"
            textSize = 12f
            setTextColor(Color.parseColor("#0284C7"))
            setTypeface(Typeface.DEFAULT_BOLD)
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(12); bottomMargin = dp(4) }
            layoutParams = lp
        }
        dialogView.addView(reasonLabel)

        val reasonInput = android.widget.EditText(this).apply {
            hint = "e.g. Needed for college classes or exams"
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#666666"))
            textSize = 14f
            minLines = 3
            gravity = Gravity.TOP or Gravity.START
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#2A2A2A"))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), Color.parseColor("#444444"))
            }
            background = bg
            val pad = dp(12)
            setPadding(pad, pad, pad, pad)
        }
        dialogView.addView(reasonInput)

        val dialog = android.app.AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setView(dialogView)
            .setPositiveButton("Submit Request", null)
            .setNegativeButton("Cancel") { d, _ -> d.dismiss() }
            .create()

        dialog.setOnShowListener {
            val submitBtn = dialog.getButton(android.app.AlertDialog.BUTTON_POSITIVE)
            submitBtn.setTextColor(Color.parseColor("#0284C7"))
            submitBtn.setOnClickListener {
                val targetAppName = appNameInput.text.toString().trim().ifEmpty { defaultAppName }
                val targetReason = reasonInput.text.toString().trim()

                if (isInstaller && targetAppName.isEmpty()) {
                    android.widget.Toast.makeText(this, "Please enter the app name you want to download", android.widget.Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }
                if (targetReason.isEmpty()) {
                    android.widget.Toast.makeText(this, "Please provide a reason for the warden", android.widget.Toast.LENGTH_SHORT).show()
                    return@setOnClickListener
                }

                dialog.dismiss()
                requestButton.isEnabled = false
                requestButton.text = "Sending Request…"

                val targetPkg = if (isInstaller) "com.android.vending" else pkgName
                PackageInstallReceiver.requestAppApproval(this, targetPkg, targetAppName, targetReason) { success ->
                    runOnUiThread {
                        if (success) {
                            requestButton.text = "✓ Request Sent to Warden"
                            val doneBg = GradientDrawable().apply {
                                setColor(Color.parseColor("#16A34A"))
                                cornerRadius = dp(12).toFloat()
                            }
                            requestButton.background = doneBg
                            android.widget.Toast.makeText(
                                this,
                                "Request submitted for \"$targetAppName\". Once approved, you will have a download window.",
                                android.widget.Toast.LENGTH_LONG
                            ).show()
                        } else {
                            requestButton.text = "Request Failed (Tap to retry)"
                            requestButton.isEnabled = true
                        }
                    }
                }
            }
        }

        dialog.show()
    }



    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
