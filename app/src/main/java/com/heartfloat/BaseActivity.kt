package com.heartfloat

import android.graphics.Typeface
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

open class BaseActivity : AppCompatActivity() {

    override fun setContentView(layoutResID: Int) {
        super.setContentView(layoutResID)
        applyGlobalFont()
    }
    
    override fun setContentView(view: View) {
        super.setContentView(view)
        applyGlobalFont()
    }
    
    override fun setContentView(view: View, params: ViewGroup.LayoutParams) {
        super.setContentView(view, params)
        applyGlobalFont()
    }
    
    private fun applyGlobalFont() {
        val typeface = HeartFloatApplication.getGlobalTypeface() ?: return
        val rootView = window.decorView.findViewById<View>(android.R.id.content) as? ViewGroup ?: return
        applyFontRecursive(rootView, typeface)
    }
    
    private fun applyFontRecursive(view: View, typeface: Typeface) {
        if (view is TextView) {
            if (view.tag != "keep_font") {
                view.typeface = typeface
            }
        }
        
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                applyFontRecursive(view.getChildAt(i), typeface)
            }
        }
    }
}
