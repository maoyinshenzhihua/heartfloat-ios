package com.heartfloat

import android.app.AlertDialog
import android.app.Dialog
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.ArrayAdapter
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView

class SettingsActivity : BaseActivity(), SettingsManager.OnSettingsChangedListener {

    private lateinit var previewContainer: View
    private lateinit var previewBpmContainer: LinearLayout
    private lateinit var previewBpmNumber: TextView
    private lateinit var previewBpmLabel: TextView
    
    private lateinit var seekBpmNumberSize: SeekBar
    private lateinit var tvBpmNumberSizeValue: TextView
    private lateinit var viewBpmNumberColor: View
    private lateinit var btnBpmNumberColor: android.widget.Button
    private lateinit var spinnerBpmNumberFont: android.widget.Spinner
    
    private lateinit var seekBpmLabelSize: SeekBar
    private lateinit var tvBpmLabelSizeValue: TextView
    private lateinit var viewBpmLabelColor: View
    private lateinit var btnBpmLabelColor: android.widget.Button
    private lateinit var spinnerBpmLabelFont: android.widget.Spinner
    
    private lateinit var rbPositionTop: RadioButton
    private lateinit var rbPositionBottom: RadioButton
    private lateinit var rbPositionLeft: RadioButton
    private lateinit var rbPositionRight: RadioButton
    
    private lateinit var seekBackgroundOpacity: SeekBar
    private lateinit var tvBackgroundOpacityValue: TextView
    
    private lateinit var switchHttpPush: androidx.appcompat.widget.SwitchCompat
    private lateinit var containerHttpSettings: LinearLayout
    private lateinit var etHttpPort: android.widget.EditText
    private lateinit var btnApplyPort: android.widget.Button
    private lateinit var tvLocalIp: TextView
    private lateinit var tvApiEndpoints: TextView
    
    private lateinit var spinnerGlobalFont: android.widget.Spinner
    
    private lateinit var btnPresetClassic: android.widget.Button
    private lateinit var btnPresetNeon: android.widget.Button
    private lateinit var btnPresetOcean: android.widget.Button
    
    private lateinit var btnImportFont: android.widget.Button
    private lateinit var rvCustomFonts: RecyclerView
    private lateinit var tvNoCustomFonts: TextView
    
    private lateinit var btnRestoreDefault: android.widget.Button
    private lateinit var btnBack: android.widget.ImageButton
    
    private var fontAdapter: FontAdapter? = null
    private var fontList = mutableListOf<FontManager.FontInfo>()
    
    private var currentColorTarget: ColorTarget? = null
    private var colorPickerDialog: Dialog? = null
    private var isGlobalFontFirstSelection = true
    
    private enum class ColorTarget {
        BPM_NUMBER, BPM_LABEL
    }
    
    companion object {
        private const val REQUEST_CODE_IMPORT_FONT = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)
        
        initViews()
        loadSettings()
        setupListeners()
        updatePreview()
    }
    
    override fun onStart() {
        super.onStart()
        SettingsManager.addListener(this)
    }
    
    override fun onStop() {
        super.onStop()
        SettingsManager.removeListener(this)
    }
    
    private fun initViews() {
        previewContainer = findViewById(R.id.previewContainer)
        previewBpmContainer = findViewById(R.id.previewBpmContainer)
        previewBpmNumber = findViewById(R.id.previewBpmNumber)
        previewBpmLabel = findViewById(R.id.previewBpmLabel)
        
        seekBpmNumberSize = findViewById(R.id.seekBpmNumberSize)
        tvBpmNumberSizeValue = findViewById(R.id.tvBpmNumberSizeValue)
        viewBpmNumberColor = findViewById(R.id.viewBpmNumberColor)
        btnBpmNumberColor = findViewById(R.id.btnBpmNumberColor)
        spinnerBpmNumberFont = findViewById(R.id.spinnerBpmNumberFont)
        
        seekBpmLabelSize = findViewById(R.id.seekBpmLabelSize)
        tvBpmLabelSizeValue = findViewById(R.id.tvBpmLabelSizeValue)
        viewBpmLabelColor = findViewById(R.id.viewBpmLabelColor)
        btnBpmLabelColor = findViewById(R.id.btnBpmLabelColor)
        spinnerBpmLabelFont = findViewById(R.id.spinnerBpmLabelFont)
        
        rbPositionTop = findViewById(R.id.rbPositionTop)
        rbPositionBottom = findViewById(R.id.rbPositionBottom)
        rbPositionLeft = findViewById(R.id.rbPositionLeft)
        rbPositionRight = findViewById(R.id.rbPositionRight)
        
        seekBackgroundOpacity = findViewById(R.id.seekBackgroundOpacity)
        tvBackgroundOpacityValue = findViewById(R.id.tvBackgroundOpacityValue)
        
        switchHttpPush = findViewById(R.id.switchHttpPush)
        containerHttpSettings = findViewById(R.id.containerHttpSettings)
        etHttpPort = findViewById(R.id.etHttpPort)
        btnApplyPort = findViewById(R.id.btnApplyPort)
        tvLocalIp = findViewById(R.id.tvLocalIp)
        tvApiEndpoints = findViewById(R.id.tvApiEndpoints)
        
        spinnerGlobalFont = findViewById(R.id.spinnerGlobalFont)
        
        btnPresetClassic = findViewById(R.id.btnPresetClassic)
        btnPresetNeon = findViewById(R.id.btnPresetNeon)
        btnPresetOcean = findViewById(R.id.btnPresetOcean)
        
        btnImportFont = findViewById(R.id.btnImportFont)
        rvCustomFonts = findViewById(R.id.rvCustomFonts)
        tvNoCustomFonts = findViewById(R.id.tvNoCustomFonts)
        
        btnRestoreDefault = findViewById(R.id.btnRestoreDefault)
        btnBack = findViewById(R.id.btnBack)
        
        setupFontSpinners()
        setupCustomFontsList()
    }
    
    private fun setupFontSpinners() {
        val fonts = FontManager.getAllFonts()
        val fontNames = fonts.map { it.name }
        
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, fontNames)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        
        spinnerBpmNumberFont.adapter = adapter
        spinnerBpmLabelFont.adapter = adapter
        spinnerGlobalFont.adapter = adapter
    }
    
    private fun setupCustomFontsList() {
        fontList.clear()
        fontList.addAll(FontManager.getCustomFonts())
        
        fontAdapter = FontAdapter(fontList) { font ->
            showDeleteFontDialog(font)
        }
        
        rvCustomFonts.layoutManager = LinearLayoutManager(this)
        rvCustomFonts.adapter = fontAdapter
        
        updateCustomFontsVisibility()
    }
    
    private fun updateCustomFontsVisibility() {
        if (fontList.isEmpty()) {
            rvCustomFonts.visibility = View.GONE
            tvNoCustomFonts.visibility = View.VISIBLE
        } else {
            rvCustomFonts.visibility = View.VISIBLE
            tvNoCustomFonts.visibility = View.GONE
        }
    }
    
    private fun setupListeners() {
        btnBack.setOnClickListener {
            finish()
        }
        
        seekBpmNumberSize.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val size = progress + SettingsManager.BPM_NUMBER_SIZE_MIN
                tvBpmNumberSizeValue.text = "${size}sp"
                if (fromUser) {
                    SettingsManager.setBpmNumberSize(size)
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        
        seekBpmLabelSize.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val size = progress + SettingsManager.BPM_LABEL_SIZE_MIN
                tvBpmLabelSizeValue.text = "${size}sp"
                if (fromUser) {
                    SettingsManager.setBpmLabelSize(size)
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        
        btnBpmNumberColor.setOnClickListener {
            currentColorTarget = ColorTarget.BPM_NUMBER
            showColorPickerDialog(SettingsManager.getBpmNumberColor())
        }
        
        btnBpmLabelColor.setOnClickListener {
            currentColorTarget = ColorTarget.BPM_LABEL
            showColorPickerDialog(SettingsManager.getBpmLabelColor())
        }
        
        spinnerBpmNumberFont.setOnItemSelectedListener(object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                val fonts = FontManager.getAllFonts()
                if (position < fonts.size) {
                    SettingsManager.setBpmNumberFont(fonts[position].path)
                }
            }
            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        })
        
        spinnerBpmLabelFont.setOnItemSelectedListener(object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                val fonts = FontManager.getAllFonts()
                if (position < fonts.size) {
                    SettingsManager.setBpmLabelFont(fonts[position].path)
                }
            }
            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        })
        
        spinnerGlobalFont.onItemSelectedListener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (!isGlobalFontFirstSelection) {
                    val fonts = FontManager.getAllFonts()
                    if (position < fonts.size) {
                        SettingsManager.setGlobalFont(fonts[position].path)
                        Toast.makeText(this@SettingsActivity, R.string.global_font_applied, Toast.LENGTH_SHORT).show()
                    }
                }
                isGlobalFontFirstSelection = false
            }
            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        }
        
        rbPositionTop.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) SettingsManager.setBpmPosition(SettingsManager.POSITION_TOP)
        }
        
        rbPositionBottom.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) SettingsManager.setBpmPosition(SettingsManager.POSITION_BOTTOM)
        }
        
        rbPositionLeft.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) SettingsManager.setBpmPosition(SettingsManager.POSITION_LEFT)
        }
        
        rbPositionRight.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) SettingsManager.setBpmPosition(SettingsManager.POSITION_RIGHT)
        }
        
        seekBackgroundOpacity.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tvBackgroundOpacityValue.text = "${progress}%"
                if (fromUser) {
                    SettingsManager.setBackgroundOpacity(progress)
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        
        switchHttpPush.setOnCheckedChangeListener { _, isChecked ->
            SettingsManager.setHttpPushEnabled(isChecked)
            if (isChecked) {
                startHttpServer()
            } else {
                stopHttpServer()
            }
            updateHttpSettingsVisibility()
        }
        
        btnApplyPort.setOnClickListener {
            val portText = etHttpPort.text.toString()
            val port = portText.toIntOrNull()
            if (port != null && port in SettingsManager.HTTP_PORT_MIN..SettingsManager.HTTP_PORT_MAX) {
                SettingsManager.setHttpPushPort(port)
                if (SettingsManager.isHttpPushEnabled()) {
                    stopHttpServer()
                    startHttpServer()
                }
                updateApiEndpoints()
                Toast.makeText(this, R.string.port_applied, Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, R.string.invalid_port, Toast.LENGTH_SHORT).show()
            }
        }
        
        btnPresetClassic.setOnClickListener {
            applyPresetClassic()
        }
        
        btnPresetNeon.setOnClickListener {
            applyPresetNeon()
        }
        
        btnPresetOcean.setOnClickListener {
            applyPresetOcean()
        }
        
        btnImportFont.setOnClickListener {
            openFontFilePicker()
        }
        
        btnRestoreDefault.setOnClickListener {
            showRestoreDefaultDialog()
        }
    }
    
    private fun loadSettings() {
        val bpmNumberSize = SettingsManager.getBpmNumberSize()
        seekBpmNumberSize.progress = bpmNumberSize - SettingsManager.BPM_NUMBER_SIZE_MIN
        tvBpmNumberSizeValue.text = "${bpmNumberSize}sp"
        
        val bpmLabelSize = SettingsManager.getBpmLabelSize()
        seekBpmLabelSize.progress = bpmLabelSize - SettingsManager.BPM_LABEL_SIZE_MIN
        tvBpmLabelSizeValue.text = "${bpmLabelSize}sp"
        
        viewBpmNumberColor.setBackgroundColor(SettingsManager.getBpmNumberColor())
        viewBpmLabelColor.setBackgroundColor(SettingsManager.getBpmLabelColor())
        
        val fonts = FontManager.getAllFonts()
        val bpmNumberFont = SettingsManager.getBpmNumberFont()
        val bpmLabelFont = SettingsManager.getBpmLabelFont()
        
        val numberFontIndex = fonts.indexOfFirst { it.path == bpmNumberFont }.coerceAtLeast(0)
        val labelFontIndex = fonts.indexOfFirst { it.path == bpmLabelFont }.coerceAtLeast(0)
        
        spinnerBpmNumberFont.setSelection(numberFontIndex)
        spinnerBpmLabelFont.setSelection(labelFontIndex)
        
        val globalFont = SettingsManager.getGlobalFont()
        val globalFontIndex = fonts.indexOfFirst { it.path == globalFont }.coerceAtLeast(0)
        spinnerGlobalFont.setSelection(globalFontIndex)
        
        when (SettingsManager.getBpmPosition()) {
            SettingsManager.POSITION_TOP -> rbPositionTop.isChecked = true
            SettingsManager.POSITION_BOTTOM -> rbPositionBottom.isChecked = true
            SettingsManager.POSITION_LEFT -> rbPositionLeft.isChecked = true
            SettingsManager.POSITION_RIGHT -> rbPositionRight.isChecked = true
        }
        
        val backgroundOpacity = SettingsManager.getBackgroundOpacity()
        seekBackgroundOpacity.progress = backgroundOpacity
        tvBackgroundOpacityValue.text = "${backgroundOpacity}%"
        
        val httpPushEnabled = SettingsManager.isHttpPushEnabled()
        switchHttpPush.isChecked = httpPushEnabled
        etHttpPort.setText(SettingsManager.getHttpPushPort().toString())
        updateHttpSettingsVisibility()
        
        if (httpPushEnabled && !HttpServerManager.isRunning()) {
            startHttpServer()
        }
    }
    
    override fun onSettingsChanged() {
        updatePreview()
        viewBpmNumberColor.setBackgroundColor(SettingsManager.getBpmNumberColor())
        viewBpmLabelColor.setBackgroundColor(SettingsManager.getBpmLabelColor())
    }
    
    private fun updatePreview() {
        previewBpmNumber.textSize = SettingsManager.getBpmNumberSize().toFloat()
        previewBpmLabel.textSize = SettingsManager.getBpmLabelSize().toFloat()
        
        previewBpmNumber.setTextColor(SettingsManager.getBpmNumberColor())
        previewBpmLabel.setTextColor(SettingsManager.getBpmLabelColor())
        
        val numberFont = SettingsManager.getBpmNumberFont()
        val labelFont = SettingsManager.getBpmLabelFont()
        
        previewBpmNumber.typeface = FontManager.getTypeface(numberFont)
        previewBpmLabel.typeface = FontManager.getTypeface(labelFont)
        
        val position = SettingsManager.getBpmPosition()
        
        previewBpmContainer.orientation = when (position) {
            SettingsManager.POSITION_TOP, SettingsManager.POSITION_BOTTOM -> LinearLayout.VERTICAL
            else -> LinearLayout.HORIZONTAL
        }
        
        previewBpmContainer.removeAllViews()
        
        when (position) {
            SettingsManager.POSITION_TOP -> {
                previewBpmContainer.addView(previewBpmLabel)
                previewBpmContainer.addView(previewBpmNumber)
            }
            SettingsManager.POSITION_BOTTOM -> {
                previewBpmContainer.addView(previewBpmNumber)
                previewBpmContainer.addView(previewBpmLabel)
            }
            SettingsManager.POSITION_LEFT -> {
                previewBpmContainer.addView(previewBpmLabel)
                previewBpmContainer.addView(previewBpmNumber)
            }
            SettingsManager.POSITION_RIGHT -> {
                previewBpmContainer.addView(previewBpmNumber)
                previewBpmContainer.addView(previewBpmLabel)
            }
        }
        
        val opacity = SettingsManager.getBackgroundOpacity()
        val alpha = (opacity * 255 / 100).coerceIn(0, 255)
        previewContainer.setBackgroundColor(Color.argb(alpha, 0, 0, 0))
    }
    
    private fun showColorPickerDialog(initialColor: Int) {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_color_picker, null)
        
        val viewColorPreview = dialogView.findViewById<View>(R.id.viewColorPreview)
        val rgColorMode = dialogView.findViewById<android.widget.RadioGroup>(R.id.rgColorMode)
        val rbRgbMode = dialogView.findViewById<RadioButton>(R.id.rbRgbMode)
        val rbHslMode = dialogView.findViewById<RadioButton>(R.id.rbHslMode)
        
        val containerRgb = dialogView.findViewById<LinearLayout>(R.id.containerRgb)
        val containerHsl = dialogView.findViewById<LinearLayout>(R.id.containerHsl)
        
        val seekR = dialogView.findViewById<SeekBar>(R.id.seekR)
        val seekG = dialogView.findViewById<SeekBar>(R.id.seekG)
        val seekB = dialogView.findViewById<SeekBar>(R.id.seekB)
        val tvRValue = dialogView.findViewById<TextView>(R.id.tvRValue)
        val tvGValue = dialogView.findViewById<TextView>(R.id.tvGValue)
        val tvBValue = dialogView.findViewById<TextView>(R.id.tvBValue)
        
        val seekH = dialogView.findViewById<SeekBar>(R.id.seekH)
        val seekS = dialogView.findViewById<SeekBar>(R.id.seekS)
        val seekL = dialogView.findViewById<SeekBar>(R.id.seekL)
        val tvHValue = dialogView.findViewById<TextView>(R.id.tvHValue)
        val tvSValue = dialogView.findViewById<TextView>(R.id.tvSValue)
        val tvLValue = dialogView.findViewById<TextView>(R.id.tvLValue)
        
        val seekAlpha = dialogView.findViewById<SeekBar>(R.id.seekAlpha)
        val tvAlphaValue = dialogView.findViewById<TextView>(R.id.tvAlphaValue)
        
        val gridPresetColors = dialogView.findViewById<GridLayout>(R.id.gridPresetColors)
        
        val btnCancel = dialogView.findViewById<android.widget.Button>(R.id.btnCancel)
        val btnConfirm = dialogView.findViewById<android.widget.Button>(R.id.btnConfirm)
        
        var currentColor = initialColor
        var alpha = Color.alpha(initialColor)
        var red = Color.red(initialColor)
        var green = Color.green(initialColor)
        var blue = Color.blue(initialColor)
        
        fun updateColorPreview() {
            currentColor = Color.argb(alpha, red, green, blue)
            viewColorPreview.setBackgroundColor(currentColor)
        }
        
        fun updateRgbFromColor(color: Int) {
            red = Color.red(color)
            green = Color.green(color)
            blue = Color.blue(color)
            seekR.progress = red
            seekG.progress = green
            seekB.progress = blue
            tvRValue.text = red.toString()
            tvGValue.text = green.toString()
            tvBValue.text = blue.toString()
        }
        
        fun updateHslFromColor(color: Int) {
            val hsv = FloatArray(3)
            Color.colorToHSV(color, hsv)
            seekH.progress = hsv[0].toInt()
            seekS.progress = (hsv[1] * 100).toInt()
            seekL.progress = (hsv[2] * 100).toInt()
            tvHValue.text = seekH.progress.toString()
            tvSValue.text = seekS.progress.toString()
            tvLValue.text = seekL.progress.toString()
        }
        
        seekR.progress = red
        seekG.progress = green
        seekB.progress = blue
        seekAlpha.progress = alpha
        tvRValue.text = red.toString()
        tvGValue.text = green.toString()
        tvBValue.text = blue.toString()
        tvAlphaValue.text = "${(alpha * 100 / 255)}%"
        
        updateHslFromColor(initialColor)
        updateColorPreview()
        
        val rgbListener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                when (seekBar?.id) {
                    R.id.seekR -> { red = progress; tvRValue.text = progress.toString() }
                    R.id.seekG -> { green = progress; tvGValue.text = progress.toString() }
                    R.id.seekB -> { blue = progress; tvBValue.text = progress.toString() }
                }
                if (fromUser) {
                    updateHslFromColor(Color.argb(alpha, red, green, blue))
                    updateColorPreview()
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        }
        
        seekR.setOnSeekBarChangeListener(rgbListener)
        seekG.setOnSeekBarChangeListener(rgbListener)
        seekB.setOnSeekBarChangeListener(rgbListener)
        
        val hslListener = object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                when (seekBar?.id) {
                    R.id.seekH -> { tvHValue.text = progress.toString() }
                    R.id.seekS -> { tvSValue.text = progress.toString() }
                    R.id.seekL -> { tvLValue.text = progress.toString() }
                }
                if (fromUser) {
                    val hsv = floatArrayOf(
                        seekH.progress.toFloat(),
                        seekS.progress / 100f,
                        seekL.progress / 100f
                    )
                    val color = Color.HSVToColor(alpha, hsv)
                    red = Color.red(color)
                    green = Color.green(color)
                    blue = Color.blue(color)
                    updateRgbFromColor(color)
                    updateColorPreview()
                }
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        }
        
        seekH.setOnSeekBarChangeListener(hslListener)
        seekS.setOnSeekBarChangeListener(hslListener)
        seekL.setOnSeekBarChangeListener(hslListener)
        
        seekAlpha.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                alpha = progress
                tvAlphaValue.text = "${(progress * 100 / 255)}%"
                if (fromUser) updateColorPreview()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })
        
        rgColorMode.setOnCheckedChangeListener { _, checkedId ->
            when (checkedId) {
                R.id.rbRgbMode -> {
                    containerRgb.visibility = View.VISIBLE
                    containerHsl.visibility = View.GONE
                }
                R.id.rbHslMode -> {
                    containerRgb.visibility = View.GONE
                    containerHsl.visibility = View.VISIBLE
                }
            }
        }
        
        val presetColors = intArrayOf(
            Color.parseColor("#FF6B6B"),
            Color.parseColor("#4ECDC4"),
            Color.parseColor("#45B7D1"),
            Color.parseColor("#96CEB4"),
            Color.parseColor("#FFEAA7"),
            Color.parseColor("#DFE6E9"),
            Color.parseColor("#FF7675"),
            Color.parseColor("#74B9FF"),
            Color.parseColor("#A29BFE"),
            Color.parseColor("#FD79A8"),
            Color.parseColor("#00B894"),
            Color.parseColor("#E17055")
        )
        
        gridPresetColors.removeAllViews()
        presetColors.forEach { color ->
            val colorView = View(this).apply {
                layoutParams = GridLayout.LayoutParams().apply {
                    width = 48
                    height = 48
                    setMargins(4, 4, 4, 4)
                }
                setBackgroundColor(color)
                setBackgroundResource(android.R.drawable.dialog_holo_light_frame)
                setOnClickListener {
                    alpha = Color.alpha(color)
                    red = Color.red(color)
                    green = Color.green(color)
                    blue = Color.blue(color)
                    updateRgbFromColor(color)
                    updateHslFromColor(color)
                    seekAlpha.progress = alpha
                    tvAlphaValue.text = "${(alpha * 100 / 255)}%"
                    updateColorPreview()
                }
            }
            gridPresetColors.addView(colorView)
        }
        
        colorPickerDialog = AlertDialog.Builder(this)
            .setView(dialogView)
            .setCancelable(true)
            .create()
        
        btnCancel.setOnClickListener { colorPickerDialog?.dismiss() }
        
        btnConfirm.setOnClickListener {
            when (currentColorTarget) {
                ColorTarget.BPM_NUMBER -> SettingsManager.setBpmNumberColor(currentColor)
                ColorTarget.BPM_LABEL -> SettingsManager.setBpmLabelColor(currentColor)
                null -> {}
            }
            colorPickerDialog?.dismiss()
        }
        
        colorPickerDialog?.show()
    }
    
    private fun applyPresetClassic() {
        SettingsManager.setBpmNumberColor(Color.parseColor("#FF6B6B"))
        SettingsManager.setBpmLabelColor(Color.parseColor("#FFFFFF"))
        SettingsManager.setBpmNumberSize(36)
        SettingsManager.setBpmLabelSize(14)
        loadSettings()
        Toast.makeText(this, R.string.preset_applied, Toast.LENGTH_SHORT).show()
    }
    
    private fun startHttpServer() {
        val port = SettingsManager.getHttpPushPort()
        val success = HttpServerManager.startServer(port)
        if (success) {
            updateLocalIp()
            updateApiEndpoints()
            val localIp = HttpServerManager.getLocalIpAddress(this)
            if (localIp != null) {
                Toast.makeText(this, getString(R.string.http_server_started, port), Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, R.string.http_server_started_no_ip, Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, R.string.http_server_failed, Toast.LENGTH_SHORT).show()
            switchHttpPush.isChecked = false
        }
    }
    
    private fun stopHttpServer() {
        HttpServerManager.stopServer()
        Toast.makeText(this, R.string.http_server_stopped, Toast.LENGTH_SHORT).show()
    }
    
    private fun updateHttpSettingsVisibility() {
        val isEnabled = SettingsManager.isHttpPushEnabled()
        containerHttpSettings.visibility = if (isEnabled) View.VISIBLE else View.GONE
        
        if (isEnabled) {
            updateLocalIp()
            updateApiEndpoints()
        }
    }
    
    private fun updateLocalIp() {
        val localIp = HttpServerManager.getLocalIpAddress(this)
        tvLocalIp.text = if (localIp != null) {
            "http://$localIp:${SettingsManager.getHttpPushPort()}"
        } else {
            getString(R.string.no_network_connection)
        }
    }
    
    private fun updateApiEndpoints() {
        val localIp = HttpServerManager.getLocalIpAddress(this)
        val port = SettingsManager.getHttpPushPort()
        
        if (localIp != null) {
            val endpoints = """
GET http://$localIp:$port/heartbeat
GET http://$localIp:$port/heartbeat.json
GET http://$localIp:$port/live (直播专用)
            """.trimIndent()
            tvApiEndpoints.text = endpoints
        } else {
            tvApiEndpoints.text = getString(R.string.no_network_connection)
        }
    }
    
    private fun applyPresetNeon() {
        SettingsManager.setBpmNumberColor(Color.parseColor("#00FF88"))
        SettingsManager.setBpmLabelColor(Color.parseColor("#00FFFF"))
        SettingsManager.setBpmNumberSize(40)
        SettingsManager.setBpmLabelSize(16)
        loadSettings()
        Toast.makeText(this, R.string.preset_applied, Toast.LENGTH_SHORT).show()
    }
    
    private fun applyPresetOcean() {
        SettingsManager.setBpmNumberColor(Color.parseColor("#00BFFF"))
        SettingsManager.setBpmLabelColor(Color.parseColor("#87CEEB"))
        SettingsManager.setBpmNumberSize(38)
        SettingsManager.setBpmLabelSize(15)
        loadSettings()
        Toast.makeText(this, R.string.preset_applied, Toast.LENGTH_SHORT).show()
    }
    
    private fun openFontFilePicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf("font/ttf", "font/otf", "application/x-font-ttf", "application/x-font-otf", "application/octet-stream")
                )
        }
        startActivityForResult(intent, REQUEST_CODE_IMPORT_FONT)
    }
    
    private fun importFont(uri: Uri, isGlobalFont: Boolean = false) {
        val fileName = getFileName(uri)
        
        if (!FontManager.isValidFontFile(fileName)) {
            Toast.makeText(this, R.string.invalid_font_file, Toast.LENGTH_SHORT).show()
            return
        }
        
        try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val fontInfo = FontManager.importFont(inputStream, fileName)
                if (fontInfo != null) {
                    if (isGlobalFont) {
                        Toast.makeText(this, R.string.global_font_applied, Toast.LENGTH_SHORT).show()
                    } else {
                        Toast.makeText(this, R.string.font_imported, Toast.LENGTH_SHORT).show()
                        refreshFontLists()
                    }
                } else {
                    Toast.makeText(this, R.string.font_import_failed, Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            Toast.makeText(this, R.string.font_import_failed, Toast.LENGTH_SHORT).show()
        }
    }
    
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_IMPORT_FONT && resultCode == RESULT_OK) {
            data?.data?.let { uri ->
                importFont(uri)
            }
        }
    }
    
    private fun importFont(uri: Uri) {
        val fileName = getFileName(uri)
        
        if (!FontManager.isValidFontFile(fileName)) {
            Toast.makeText(this, R.string.invalid_font_file, Toast.LENGTH_SHORT).show()
            return
        }
        
        try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val fontInfo = FontManager.importFont(inputStream, fileName)
                if (fontInfo != null) {
                    Toast.makeText(this, R.string.font_imported, Toast.LENGTH_SHORT).show()
                    refreshFontLists()
                } else {
                    Toast.makeText(this, R.string.font_import_failed, Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            Toast.makeText(this, R.string.font_import_failed, Toast.LENGTH_SHORT).show()
        }
    }
    
    private fun getFileName(uri: Uri): String {
        var name = "font.ttf"
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    name = it.getString(nameIndex)
                }
            }
        }
        return name
    }
    
    private fun refreshFontLists() {
        isGlobalFontFirstSelection = true
        setupFontSpinners()
        loadSettings()
        
        fontList.clear()
        fontList.addAll(FontManager.getCustomFonts())
        fontAdapter?.notifyDataSetChanged()
        updateCustomFontsVisibility()
    }
    
    private fun showDeleteFontDialog(font: FontManager.FontInfo) {
        AlertDialog.Builder(this)
            .setTitle(R.string.delete_font)
            .setMessage(getString(R.string.delete_font_confirm, font.name))
            .setPositiveButton(android.R.string.ok) { _, _ ->
                FontManager.deleteFont(font.path)
                refreshFontLists()
                Toast.makeText(this, R.string.font_deleted, Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
    
    private fun showRestoreDefaultDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.restore_default)
            .setMessage(R.string.restore_default_confirm)
            .setPositiveButton(android.R.string.ok) { _, _ ->
                isGlobalFontFirstSelection = true
                SettingsManager.resetToDefaults()
                loadSettings()
                Toast.makeText(this, R.string.settings_restored, Toast.LENGTH_SHORT).show()
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }
    
    private inner class FontAdapter(
        private val fonts: List<FontManager.FontInfo>,
        private val onDeleteClick: (FontManager.FontInfo) -> Unit
    ) : RecyclerView.Adapter<FontAdapter.FontViewHolder>() {
        
        override fun onCreateViewHolder(parent: android.view.ViewGroup, viewType: Int): FontViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_custom_font, parent, false)
            return FontViewHolder(view)
        }
        
        override fun onBindViewHolder(holder: FontViewHolder, position: Int) {
            val font = fonts[position]
            holder.tvFontName.text = font.name
            holder.btnDelete.setOnClickListener { onDeleteClick(font) }
        }
        
        override fun getItemCount() = fonts.size
        
        inner class FontViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val tvFontName: TextView = view.findViewById(R.id.tvFontName)
            val btnDelete: android.widget.ImageButton = view.findViewById(R.id.btnDeleteFont)
        }
    }
}
