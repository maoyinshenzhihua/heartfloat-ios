package com.heartfloat

import android.content.Context
import android.graphics.Typeface
import android.os.Environment
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

object FontManager {

    private const val FONTS_DIR = "fonts"
    
    data class FontInfo(
        val name: String,
        val path: String,
        val isCustom: Boolean
    )
    
    private var context: Context? = null
    
    val systemFonts = listOf(
        FontInfo("默认", "default", false),
        FontInfo("Sans-serif", "sans-serif", false),
        FontInfo("Serif", "serif", false),
        FontInfo("Monospace", "monospace", false),
        FontInfo("Sans-serif-condensed", "sans-serif-condensed", false),
        FontInfo("Serif-monospace", "serif-monospace", false)
    )
    
    fun init(context: Context) {
        this.context = context.applicationContext
        ensureFontsDirectory()
    }
    
    private fun ensureFontsDirectory() {
        val fontsDir = File(context?.filesDir, FONTS_DIR)
        if (!fontsDir.exists()) {
            fontsDir.mkdirs()
        }
    }
    
    fun getFontsDirectory(): File {
        ensureFontsDirectory()
        return File(context?.filesDir, FONTS_DIR)
    }
    
    fun getAllFonts(): List<FontInfo> {
        val allFonts = systemFonts.toMutableList()
        val customFonts = getCustomFonts()
        allFonts.addAll(customFonts)
        return allFonts
    }
    
    fun getCustomFonts(): List<FontInfo> {
        val customFontPaths = SettingsManager.getCustomFonts()
        val fonts = mutableListOf<FontInfo>()
        
        customFontPaths.forEach { path ->
            val file = File(path)
            if (file.exists()) {
                val name = file.nameWithoutExtension
                fonts.add(FontInfo(name, path, true))
            }
        }
        
        return fonts
    }
    
    fun importFont(inputStream: InputStream, fileName: String): FontInfo? {
        return try {
            ensureFontsDirectory()
            val fontsDir = getFontsDirectory()
            val outputFile = File(fontsDir, fileName)
            
            FileOutputStream(outputFile).use { output ->
                val buffer = ByteArray(4 * 1024)
                var read: Int
                while (inputStream.read(buffer).also { read = it } != -1) {
                    output.write(buffer, 0, read)
                }
                output.flush()
            }
            
            val fontPath = outputFile.absolutePath
            SettingsManager.addCustomFont(fontPath)
            
            FontInfo(fileName.substringBeforeLast("."), fontPath, true)
        } catch (e: Exception) {
            android.util.Log.e("FontManager", "Failed to import font: $fileName", e)
            null
        }
    }
    
    fun deleteFont(fontPath: String): Boolean {
        return try {
            val file = File(fontPath)
            if (file.exists() && file.parentFile?.absolutePath == getFontsDirectory().absolutePath) {
                file.delete()
            }
            SettingsManager.removeCustomFont(fontPath)
            true
        } catch (e: Exception) {
            android.util.Log.e("FontManager", "Failed to delete font: $fontPath", e)
            false
        }
    }
    
    fun getTypeface(fontPath: String): Typeface? {
        if (fontPath == "default" || fontPath.isEmpty()) {
            return Typeface.DEFAULT
        }
        
        val systemFont = systemFonts.find { it.path == fontPath }
        if (systemFont != null) {
            return when (fontPath) {
                "sans-serif" -> Typeface.SANS_SERIF
                "serif" -> Typeface.SERIF
                "monospace" -> Typeface.MONOSPACE
                "sans-serif-condensed" -> Typeface.create("sans-serif-condensed", Typeface.NORMAL)
                "serif-monospace" -> Typeface.create("serif-monospace", Typeface.NORMAL)
                else -> Typeface.DEFAULT
            }
        }
        
        return try {
            val file = File(fontPath)
            if (file.exists()) {
                Typeface.createFromFile(file)
            } else {
                Typeface.DEFAULT
            }
        } catch (e: Exception) {
            android.util.Log.e("FontManager", "Failed to load font: $fontPath", e)
            Typeface.DEFAULT
        }
    }
    
    fun isValidFontFile(fileName: String): Boolean {
        val extension = fileName.substringAfterLast(".").lowercase()
        return extension == "ttf" || extension == "otf"
    }
}
