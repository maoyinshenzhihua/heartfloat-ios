package com.heartfloat

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color

object SettingsManager {

    private const val PREFS_NAME = "HeartFloatSettings"
    
    private const val KEY_BPM_NUMBER_SIZE = "bpm_number_size"
    private const val KEY_BPM_NUMBER_COLOR = "bpm_number_color"
    private const val KEY_BPM_NUMBER_FONT = "bpm_number_font"
    
    private const val KEY_BPM_LABEL_SIZE = "bpm_label_size"
    private const val KEY_BPM_LABEL_COLOR = "bpm_label_color"
    private const val KEY_BPM_LABEL_FONT = "bpm_label_font"
    
    private const val KEY_BPM_POSITION = "bpm_position"
    
    private const val KEY_BACKGROUND_OPACITY = "background_opacity"
    
    private const val KEY_HTTP_PUSH_ENABLED = "http_push_enabled"
    private const val KEY_HTTP_PUSH_PORT = "http_push_port"
    
    private const val KEY_GLOBAL_FONT = "global_font"
    
    private const val KEY_CUSTOM_FONTS = "custom_fonts"
    
    const val POSITION_TOP = 0
    const val POSITION_BOTTOM = 1
    const val POSITION_LEFT = 2
    const val POSITION_RIGHT = 3
    
    const val DEFAULT_BPM_NUMBER_SIZE = 36
    const val DEFAULT_BPM_LABEL_SIZE = 14
    val DEFAULT_BPM_NUMBER_COLOR = Color.parseColor("#FF6B6B")
    val DEFAULT_BPM_LABEL_COLOR = Color.parseColor("#FFFFFF")
    const val DEFAULT_BPM_POSITION = POSITION_RIGHT
    const val DEFAULT_FONT = "default"
    const val DEFAULT_BACKGROUND_OPACITY = 80
    const val DEFAULT_HTTP_PUSH_ENABLED = false
    const val DEFAULT_HTTP_PUSH_PORT = 8080
    
    const val BPM_NUMBER_SIZE_MIN = 12
    const val BPM_NUMBER_SIZE_MAX = 48
    const val BPM_LABEL_SIZE_MIN = 8
    const val BPM_LABEL_SIZE_MAX = 32
    const val BACKGROUND_OPACITY_MIN = 0
    const val BACKGROUND_OPACITY_MAX = 100
    const val HTTP_PORT_MIN = 1024
    const val HTTP_PORT_MAX = 65535
    
    private var sharedPreferences: SharedPreferences? = null
    private val listeners = mutableListOf<OnSettingsChangedListener>()
    
    interface OnSettingsChangedListener {
        fun onSettingsChanged()
    }
    
    fun init(context: Context) {
        sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    fun addListener(listener: OnSettingsChangedListener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener)
        }
    }
    
    fun removeListener(listener: OnSettingsChangedListener) {
        listeners.remove(listener)
    }
    
    private fun notifySettingsChanged() {
        listeners.forEach { it.onSettingsChanged() }
    }
    
    // BPM Number Size
    fun getBpmNumberSize(): Int {
        return sharedPreferences?.getInt(KEY_BPM_NUMBER_SIZE, DEFAULT_BPM_NUMBER_SIZE) ?: DEFAULT_BPM_NUMBER_SIZE
    }
    
    fun setBpmNumberSize(size: Int) {
        val clampedSize = size.coerceIn(BPM_NUMBER_SIZE_MIN, BPM_NUMBER_SIZE_MAX)
        sharedPreferences?.edit()?.putInt(KEY_BPM_NUMBER_SIZE, clampedSize)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Number Color
    fun getBpmNumberColor(): Int {
        return sharedPreferences?.getInt(KEY_BPM_NUMBER_COLOR, DEFAULT_BPM_NUMBER_COLOR) ?: DEFAULT_BPM_NUMBER_COLOR
    }
    
    fun setBpmNumberColor(color: Int) {
        sharedPreferences?.edit()?.putInt(KEY_BPM_NUMBER_COLOR, color)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Number Font
    fun getBpmNumberFont(): String {
        return sharedPreferences?.getString(KEY_BPM_NUMBER_FONT, DEFAULT_FONT) ?: DEFAULT_FONT
    }
    
    fun setBpmNumberFont(font: String) {
        sharedPreferences?.edit()?.putString(KEY_BPM_NUMBER_FONT, font)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Label Size
    fun getBpmLabelSize(): Int {
        return sharedPreferences?.getInt(KEY_BPM_LABEL_SIZE, DEFAULT_BPM_LABEL_SIZE) ?: DEFAULT_BPM_LABEL_SIZE
    }
    
    fun setBpmLabelSize(size: Int) {
        val clampedSize = size.coerceIn(BPM_LABEL_SIZE_MIN, BPM_LABEL_SIZE_MAX)
        sharedPreferences?.edit()?.putInt(KEY_BPM_LABEL_SIZE, clampedSize)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Label Color
    fun getBpmLabelColor(): Int {
        return sharedPreferences?.getInt(KEY_BPM_LABEL_COLOR, DEFAULT_BPM_LABEL_COLOR) ?: DEFAULT_BPM_LABEL_COLOR
    }
    
    fun setBpmLabelColor(color: Int) {
        sharedPreferences?.edit()?.putInt(KEY_BPM_LABEL_COLOR, color)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Label Font
    fun getBpmLabelFont(): String {
        return sharedPreferences?.getString(KEY_BPM_LABEL_FONT, DEFAULT_FONT) ?: DEFAULT_FONT
    }
    
    fun setBpmLabelFont(font: String) {
        sharedPreferences?.edit()?.putString(KEY_BPM_LABEL_FONT, font)?.apply()
        notifySettingsChanged()
    }
    
    // BPM Position
    fun getBpmPosition(): Int {
        return sharedPreferences?.getInt(KEY_BPM_POSITION, DEFAULT_BPM_POSITION) ?: DEFAULT_BPM_POSITION
    }
    
    fun setBpmPosition(position: Int) {
        val validPosition = when (position) {
            POSITION_TOP, POSITION_BOTTOM, POSITION_LEFT, POSITION_RIGHT -> position
            else -> DEFAULT_BPM_POSITION
        }
        sharedPreferences?.edit()?.putInt(KEY_BPM_POSITION, validPosition)?.apply()
        notifySettingsChanged()
    }
    
    // Background Opacity
    fun getBackgroundOpacity(): Int {
        return sharedPreferences?.getInt(KEY_BACKGROUND_OPACITY, DEFAULT_BACKGROUND_OPACITY) ?: DEFAULT_BACKGROUND_OPACITY
    }
    
    fun setBackgroundOpacity(opacity: Int) {
        val clampedOpacity = opacity.coerceIn(BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX)
        sharedPreferences?.edit()?.putInt(KEY_BACKGROUND_OPACITY, clampedOpacity)?.apply()
        notifySettingsChanged()
    }
    
    // HTTP Push Enabled
    fun isHttpPushEnabled(): Boolean {
        return sharedPreferences?.getBoolean(KEY_HTTP_PUSH_ENABLED, DEFAULT_HTTP_PUSH_ENABLED) ?: DEFAULT_HTTP_PUSH_ENABLED
    }
    
    fun setHttpPushEnabled(enabled: Boolean) {
        sharedPreferences?.edit()?.putBoolean(KEY_HTTP_PUSH_ENABLED, enabled)?.apply()
        notifySettingsChanged()
    }
    
    // HTTP Push Port
    fun getHttpPushPort(): Int {
        return sharedPreferences?.getInt(KEY_HTTP_PUSH_PORT, DEFAULT_HTTP_PUSH_PORT) ?: DEFAULT_HTTP_PUSH_PORT
    }
    
    fun setHttpPushPort(port: Int) {
        val clampedPort = port.coerceIn(HTTP_PORT_MIN, HTTP_PORT_MAX)
        sharedPreferences?.edit()?.putInt(KEY_HTTP_PUSH_PORT, clampedPort)?.apply()
        notifySettingsChanged()
    }
    
    // Global Font
    fun getGlobalFont(): String {
        return sharedPreferences?.getString(KEY_GLOBAL_FONT, DEFAULT_FONT) ?: DEFAULT_FONT
    }
    
    fun setGlobalFont(font: String) {
        sharedPreferences?.edit()?.putString(KEY_GLOBAL_FONT, font)?.apply()
        notifySettingsChanged()
    }
    
    // Custom Fonts
    fun getCustomFonts(): Set<String> {
        return sharedPreferences?.getStringSet(KEY_CUSTOM_FONTS, emptySet()) ?: emptySet()
    }
    
    fun addCustomFont(fontPath: String) {
        val fonts = getCustomFonts().toMutableSet()
        fonts.add(fontPath)
        sharedPreferences?.edit()?.putStringSet(KEY_CUSTOM_FONTS, fonts)?.apply()
        notifySettingsChanged()
    }
    
    fun removeCustomFont(fontPath: String) {
        val fonts = getCustomFonts().toMutableSet()
        fonts.remove(fontPath)
        sharedPreferences?.edit()?.putStringSet(KEY_CUSTOM_FONTS, fonts)?.apply()
        notifySettingsChanged()
    }
    
    // Reset to defaults
    fun resetToDefaults() {
        sharedPreferences?.edit()?.apply {
            putInt(KEY_BPM_NUMBER_SIZE, DEFAULT_BPM_NUMBER_SIZE)
            putInt(KEY_BPM_NUMBER_COLOR, DEFAULT_BPM_NUMBER_COLOR)
            putString(KEY_BPM_NUMBER_FONT, DEFAULT_FONT)
            putInt(KEY_BPM_LABEL_SIZE, DEFAULT_BPM_LABEL_SIZE)
            putInt(KEY_BPM_LABEL_COLOR, DEFAULT_BPM_LABEL_COLOR)
            putString(KEY_BPM_LABEL_FONT, DEFAULT_FONT)
            putInt(KEY_BPM_POSITION, DEFAULT_BPM_POSITION)
            putInt(KEY_BACKGROUND_OPACITY, DEFAULT_BACKGROUND_OPACITY)
            putBoolean(KEY_HTTP_PUSH_ENABLED, DEFAULT_HTTP_PUSH_ENABLED)
            putInt(KEY_HTTP_PUSH_PORT, DEFAULT_HTTP_PUSH_PORT)
            putString(KEY_GLOBAL_FONT, DEFAULT_FONT)
            apply()
        }
        notifySettingsChanged()
    }
}
