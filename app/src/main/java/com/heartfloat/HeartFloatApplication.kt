package com.heartfloat

import android.app.Application
import android.graphics.Typeface

class HeartFloatApplication : Application() {

    companion object {
        private var instance: HeartFloatApplication? = null
        
        fun getInstance(): HeartFloatApplication? = instance
        
        fun getGlobalTypeface(): Typeface? {
            val app = instance ?: return null
            val fontPath = SettingsManager.getGlobalFont()
            return FontManager.getTypeface(fontPath)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        
        SettingsManager.init(this)
        FontManager.init(this)
    }
}
