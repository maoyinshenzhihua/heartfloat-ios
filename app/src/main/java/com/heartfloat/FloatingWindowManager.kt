package com.heartfloat

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

class FloatingWindowManager(private val context: Context) : SettingsManager.OnSettingsChangedListener {

    companion object {
        private const val PREFS_NAME = "HeartFloat"
        private const val KEY_FLOAT_X = "float_x"
        private const val KEY_FLOAT_Y = "float_y"
        private var instance: FloatingWindowManager? = null
        
        fun updateHeartRateFromService(heartRate: Int) {
            instance?.updateHeartRate(heartRate)
        }
    }

    private var windowManager: WindowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var floatingView: View? = null
    private var containerBpm: LinearLayout? = null
    private var tvBpmNumber: TextView? = null
    private var tvBpmLabel: TextView? = null
    private var isShowing = false
    private var sharedPreferences: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private var currentHeartRate: Int = 0
    
    init {
        instance = this
        SettingsManager.addListener(this)
    }

    private val params: WindowManager.LayoutParams = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        },
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        val savedX = sharedPreferences.getInt(KEY_FLOAT_X, 100)
        val savedY = sharedPreferences.getInt(KEY_FLOAT_Y, 100)
        x = savedX
        y = savedY
    }

    @SuppressLint("ClickableViewAccessibility", "InflateParams")
    fun showFloatingWindow() {
        if (isShowing || floatingView != null) {
            return
        }

        floatingView = LayoutInflater.from(context).inflate(R.layout.float_layout, null)
        containerBpm = floatingView?.findViewById(R.id.containerBpm)
        tvBpmNumber = floatingView?.findViewById(R.id.tvBpmNumber)
        tvBpmLabel = floatingView?.findViewById(R.id.tvBpmLabel)

        applySettings()
        setupTouchListener()

        try {
            windowManager.addView(floatingView, params)
            isShowing = true
            instance = this
        } catch (e: Exception) {
            e.printStackTrace()
            floatingView = null
            tvBpmNumber = null
            tvBpmLabel = null
            containerBpm = null
        }
    }

    fun hideFloatingWindow() {
        if (!isShowing || floatingView == null) {
            return
        }

        try {
            windowManager.removeView(floatingView)
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            floatingView = null
            tvBpmNumber = null
            tvBpmLabel = null
            containerBpm = null
            isShowing = false
        }
    }

    override fun onSettingsChanged() {
        if (isShowing && floatingView != null) {
            floatingView?.post {
                applySettings()
            }
        }
    }

    fun applySettings() {
        applyTextSizes()
        applyColors()
        applyFonts()
        applyPosition()
        applyBackgroundOpacity()
    }

    private fun applyTextSizes() {
        tvBpmNumber?.textSize = SettingsManager.getBpmNumberSize().toFloat()
        tvBpmLabel?.textSize = SettingsManager.getBpmLabelSize().toFloat()
    }

    private fun applyColors() {
        tvBpmNumber?.setTextColor(SettingsManager.getBpmNumberColor())
        tvBpmLabel?.setTextColor(SettingsManager.getBpmLabelColor())
    }

    private fun applyFonts() {
        val numberFont = SettingsManager.getBpmNumberFont()
        val labelFont = SettingsManager.getBpmLabelFont()
        
        val numberTypeface = FontManager.getTypeface(numberFont)
        val labelTypeface = FontManager.getTypeface(labelFont)
        
        tvBpmNumber?.typeface = numberTypeface
        tvBpmLabel?.typeface = labelTypeface
    }
    
    private fun applyBackgroundOpacity() {
        val opacity = SettingsManager.getBackgroundOpacity()
        val alpha = (opacity * 255 / 100).coerceIn(0, 255)
        
        floatingView?.let { view ->
            val background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = 24f * context.resources.displayMetrics.density
                setColor(Color.argb(alpha, 0, 0, 0))
            }
            view.background = background
        }
    }

    private fun applyPosition() {
        val position = SettingsManager.getBpmPosition()
        
        containerBpm?.let { container ->
            when (position) {
                SettingsManager.POSITION_TOP, SettingsManager.POSITION_BOTTOM -> {
                    container.orientation = LinearLayout.VERTICAL
                }
                SettingsManager.POSITION_LEFT, SettingsManager.POSITION_RIGHT -> {
                    container.orientation = LinearLayout.HORIZONTAL
                }
            }
            
            container.removeAllViews()
            
            when (position) {
                SettingsManager.POSITION_TOP -> {
                    container.addView(tvBpmLabel)
                    container.addView(tvBpmNumber)
                }
                SettingsManager.POSITION_BOTTOM -> {
                    container.addView(tvBpmNumber)
                    container.addView(tvBpmLabel)
                }
                SettingsManager.POSITION_LEFT -> {
                    container.addView(tvBpmLabel)
                    container.addView(tvBpmNumber)
                }
                SettingsManager.POSITION_RIGHT -> {
                    container.addView(tvBpmNumber)
                    container.addView(tvBpmLabel)
                }
            }
            
            val marginParams = if (position == SettingsManager.POSITION_TOP || position == SettingsManager.POSITION_BOTTOM) {
                val topBottomMargin = (4 * context.resources.displayMetrics.density).toInt()
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    topMargin = topBottomMargin
                    bottomMargin = topBottomMargin
                }
            } else {
                val leftRightMargin = (4 * context.resources.displayMetrics.density).toInt()
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    marginStart = leftRightMargin
                    marginEnd = leftRightMargin
                }
            }
            
            tvBpmNumber?.layoutParams = marginParams
            tvBpmLabel?.layoutParams = marginParams
        }
    }

    fun updateHeartRate(heartRate: Int) {
        currentHeartRate = heartRate
        if (floatingView != null) {
            floatingView?.post {
                if (tvBpmNumber != null) {
                    tvBpmNumber?.text = if (heartRate > 0) {
                        heartRate.toString()
                    } else {
                        "--"
                    }
                    android.util.Log.d("FloatingWindowManager", "更新心率显示: $heartRate")
                } else {
                    android.util.Log.d("FloatingWindowManager", "tvBpmNumber为null，无法更新心率")
                }
            }
        } else {
            android.util.Log.d("FloatingWindowManager", "floatingView为null，无法更新心率")
        }
    }

    fun isShowing(): Boolean = isShowing

    @SuppressLint("ClickableViewAccessibility")
    private fun setupTouchListener() {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var lastAction = 0

        floatingView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    lastAction = MotionEvent.ACTION_DOWN
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    var newX = initialX + (event.rawX - initialTouchX).toInt()
                    var newY = initialY + (event.rawY - initialTouchY).toInt()
                    
                    val displayMetrics = context.resources.displayMetrics
                    val screenWidth = displayMetrics.widthPixels
                    val screenHeight = displayMetrics.heightPixels
                    
                    floatingView?.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
                    val floatWidth = floatingView?.measuredWidth ?: 0
                    val floatHeight = floatingView?.measuredHeight ?: 0
                    
                    newX = newX.coerceAtLeast(0)
                    newX = newX.coerceAtMost(screenWidth - floatWidth)
                    
                    newY = newY.coerceAtLeast(0)
                    newY = newY.coerceAtMost(screenHeight - floatHeight)
                    
                    params.x = newX
                    params.y = newY
                    
                    try {
                        windowManager.updateViewLayout(floatingView, params)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    lastAction = MotionEvent.ACTION_MOVE
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (lastAction == MotionEvent.ACTION_MOVE) {
                        sharedPreferences.edit()
                            .putInt(KEY_FLOAT_X, params.x)
                            .putInt(KEY_FLOAT_Y, params.y)
                            .apply()
                    }
                    true
                }
                else -> false
            }
        }
    }
}
