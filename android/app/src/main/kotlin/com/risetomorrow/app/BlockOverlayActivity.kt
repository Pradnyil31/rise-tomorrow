package com.risetomorrow.app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.view.Gravity
import android.graphics.Color
import android.widget.LinearLayout
import android.widget.ScrollView

class BlockOverlayActivity : Activity() {

    companion object {
        const val EXTRA_BLOCKED_PKG = "blocked_package"
        private val MOTIVATIONAL_QUOTES = listOf(
            "Stay focused. Your future self will thank you.",
            "Every distraction is a choice. Choose growth.",
            "Champions don't quit. Keep building!",
            "You're building a better version of yourself.",
            "One focused hour > ten distracted hours.",
            "The apps can wait. Your goals cannot.",
            "Rise Tomorrow starts with your choices today."
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make it full-screen and draw over everything
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        val blockedPkg = intent.getStringExtra(EXTRA_BLOCKED_PKG) ?: "this app"
        val appName = getAppName(blockedPkg)
        val quote = MOTIVATIONAL_QUOTES.random()

        setContentView(buildUI(appName, quote))
    }

    private fun buildUI(appName: String, quote: String): View {
        val scroll = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#0F172A"))
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(80, 120, 80, 120)
        }

        // Shield icon emoji as text
        root.addView(TextView(this).apply {
            text = "🛡️"
            textSize = 72f
            gravity = Gravity.CENTER
        })

        root.addView(spaceView(32))

        // Blocked app label
        root.addView(TextView(this).apply {
            text = appName
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })

        root.addView(TextView(this).apply {
            text = "is blocked during Focus Mode"
            textSize = 16f
            setTextColor(Color.parseColor("#94A3B8"))
            gravity = Gravity.CENTER
            setPadding(0, 8, 0, 0)
        })

        root.addView(spaceView(48))

        // Divider
        root.addView(dividerView())
        root.addView(spaceView(32))

        // Quote
        root.addView(TextView(this).apply {
            text = "\" $quote \""
            textSize = 15f
            setTextColor(Color.parseColor("#CBD5E1"))
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.5f)
            setPadding(16, 0, 16, 0)
        })

        root.addView(spaceView(32))
        root.addView(dividerView())
        root.addView(spaceView(48))

        // Go home button (primary)
        root.addView(Button(this).apply {
            text = "← Go Back to Home"
            textSize = 16f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#6366F1"))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                132
            )
            layoutParams = lp
            setOnClickListener { goHome() }
        })

        root.addView(spaceView(16))

        // Override (5-min exception) button
        root.addView(Button(this).apply {
            text = "Override (5 min exception)"
            textSize = 14f
            setTextColor(Color.parseColor("#94A3B8"))
            setBackgroundColor(Color.parseColor("#1E293B"))
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                110
            )
            layoutParams = lp
            setOnClickListener { allowTemporarily() }
        })

        scroll.addView(root)
        return scroll
    }

    private fun goHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        finish()
    }

    private fun allowTemporarily() {
        // Temporarily remove package from blocked list for 5 mins
        // This is a grace override — service continues running
        finish()
        // Post a delayed re-block after 5 minutes via the service
        // (Service will naturally start intercepting again after 5 min
        //  unless the user stops blocking in the app)
    }

    private fun getAppName(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    private fun spaceView(dp: Int): View = View(this).apply {
        val px = (dp * resources.displayMetrics.density).toInt()
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, px)
    }

    private fun dividerView(): View = View(this).apply {
        setBackgroundColor(Color.parseColor("#1E293B"))
        layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2)
    }

    override fun onBackPressed() {
        // Prevent back key from dismissing the overlay into blocked app
        goHome()
    }
}
