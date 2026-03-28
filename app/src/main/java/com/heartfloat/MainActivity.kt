package com.heartfloat

import android.Manifest
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : BaseActivity() {

    companion object {
        private const val REQUEST_CODE_PERMISSIONS = 1001
        private const val REQUEST_CODE_OVERLAY_PERMISSION = 1002
        private const val MAX_LOG_LINES = 200
        
        private val REQUIRED_PERMISSIONS = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ).apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(Manifest.permission.BLUETOOTH_SCAN)
                add(Manifest.permission.BLUETOOTH_CONNECT)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }.toTypedArray()
    }

    private lateinit var tvHeartRate: TextView
    private lateinit var tvStatus: TextView
    private lateinit var btnConnect: Button
    private lateinit var btnFloat: Button
    private lateinit var btnSettings: Button
    private lateinit var tvLog: TextView
    private lateinit var scrollViewLog: ScrollView
    private lateinit var btnClearLog: Button
    private lateinit var btnCopyLog: Button
    
    private var floatingWindowManager: FloatingWindowManager? = null
    private var isConnected = false
    private var isConnecting = false
    private var isFloatingShowing = false
    private val logBuilder = StringBuilder()
    private val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
    private lateinit var sharedPreferences: SharedPreferences

    private val broadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                BleService.ACTION_HEART_RATE_UPDATE -> {
                    val heartRate = intent.getIntExtra(BleService.EXTRA_HEART_RATE, 0)
                    updateHeartRate(heartRate)
                }
                BleService.ACTION_CONNECTION_STATE_UPDATE -> {
                    val state = intent.getIntExtra(BleService.EXTRA_CONNECTION_STATE, BleService.STATE_DISCONNECTED)
                    updateConnectionState(state)
                }
                BleService.ACTION_LOG_UPDATE -> {
                    val logMsg = intent.getStringExtra(BleService.EXTRA_LOG_MSG) ?: ""
                    appendLog(logMsg)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        SettingsManager.init(this)
        FontManager.init(this)

        initViews()
        setupListeners()
        checkPermissions()
        
        sharedPreferences = getSharedPreferences("HeartFloat", Context.MODE_PRIVATE)
        isFloatingShowing = sharedPreferences.getBoolean("is_floating_showing", false)
        
        floatingWindowManager = FloatingWindowManager(this)
        
        // 恢复悬浮窗状态
        if (isFloatingShowing) {
            showFloatingWindow()
        }
        
        // 恢复HTTP服务器状态
        if (SettingsManager.isHttpPushEnabled()) {
            val port = SettingsManager.getHttpPushPort()
            HttpServerManager.startServer(port)
            appendLog("HTTP推送服务已启动，端口: $port")
        }
        
        appendLog("应用启动")
        appendLog("等待连接手环...")
    }

    override fun onStart() {
        super.onStart()
        registerReceiver()
    }

    override fun onStop() {
        super.onStop()
        unregisterReceiver()
    }

    override fun onDestroy() {
        super.onDestroy()
        // 确保在活动销毁时隐藏悬浮窗，避免内存泄漏
        floatingWindowManager?.hideFloatingWindow()
        floatingWindowManager = null
    }

    private fun initViews() {
        tvHeartRate = findViewById(R.id.tvHeartRate)
        tvStatus = findViewById(R.id.tvStatus)
        btnConnect = findViewById(R.id.btnConnect)
        btnFloat = findViewById(R.id.btnFloat)
        btnSettings = findViewById(R.id.btnSettings)
        tvLog = findViewById(R.id.tvLog)
        scrollViewLog = findViewById(R.id.scrollViewLog)
        btnClearLog = findViewById(R.id.btnClearLog)
        btnCopyLog = findViewById(R.id.btnCopyLog)
    }

    private fun setupListeners() {
        btnConnect.setOnClickListener {
            when {
                isConnecting -> {
                    cancelConnection()
                }
                isConnected -> {
                    disconnectFromDevice()
                }
                else -> {
                    if (checkOverlayPermission()) {
                        connectToDevice()
                    }
                }
            }
        }

        btnFloat.setOnClickListener {
            if (isFloatingShowing) {
                hideFloatingWindow()
            } else {
                if (checkOverlayPermission()) {
                    showFloatingWindow()
                }
            }
        }

        btnClearLog.setOnClickListener {
            clearLog()
        }

        btnCopyLog.setOnClickListener {
            copyLog()
        }

        btnSettings.setOnClickListener {
            val intent = Intent(this, SettingsActivity::class.java)
            startActivity(intent)
        }
    }

    private fun checkPermissions() {
        val permissionsToRequest = REQUIRED_PERMISSIONS.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                REQUEST_CODE_PERMISSIONS
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (!allGranted) {
                Toast.makeText(this, R.string.permission_bluetooth_required, Toast.LENGTH_LONG).show()
                appendLog("权限授予失败")
            } else {
                appendLog("权限已授予")
            }
        }
    }

    private fun checkOverlayPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, REQUEST_CODE_OVERLAY_PERMISSION)
            return false
        }
        return true
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_OVERLAY_PERMISSION) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && Settings.canDrawOverlays(this)) {
                Toast.makeText(this, "悬浮窗权限已授予", Toast.LENGTH_SHORT).show()
                appendLog("悬浮窗权限已授予")
            } else {
                Toast.makeText(this, R.string.permission_overlay_required, Toast.LENGTH_LONG).show()
                appendLog("悬浮窗权限授予失败")
            }
        }
    }

    private fun registerReceiver() {
        val filter = IntentFilter().apply {
            addAction(BleService.ACTION_HEART_RATE_UPDATE)
            addAction(BleService.ACTION_CONNECTION_STATE_UPDATE)
            addAction(BleService.ACTION_LOG_UPDATE)
        }
        registerReceiver(broadcastReceiver, filter)
    }

    private fun unregisterReceiver() {
        try {
            unregisterReceiver(broadcastReceiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun connectToDevice() {
        isConnecting = true
        btnConnect.text = getString(R.string.cancel_connect)
        appendLog("开始扫描BLE设备...")
        val intent = Intent(this, BleService::class.java).apply {
            action = "CONNECT"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
    
    private fun cancelConnection() {
        isConnecting = false
        btnConnect.text = getString(R.string.connect)
        appendLog("取消连接")
        val intent = Intent(this, BleService::class.java).apply {
            action = "DISCONNECT"
        }
        startService(intent)
    }

    private fun disconnectFromDevice() {
        appendLog("断开连接")
        val intent = Intent(this, BleService::class.java).apply {
            action = "DISCONNECT"
        }
        startService(intent)
        hideFloatingWindow()
    }

    private fun updateHeartRate(heartRate: Int) {
        tvHeartRate.text = if (heartRate > 0) {
            getString(R.string.heart_rate_format, heartRate)
        } else {
            getString(R.string.heart_rate_unknown)
        }
        floatingWindowManager?.updateHeartRate(heartRate)
        appendLog("心率: $heartRate BPM")
    }

    private fun updateConnectionState(state: Int) {
        when (state) {
            BleService.STATE_CONNECTED -> {
                isConnected = true
                isConnecting = false
                tvStatus.text = getString(R.string.status_connected)
                btnConnect.text = getString(R.string.disconnect)
                btnFloat.isEnabled = true
                appendLog("已连接到手环")
            }
            BleService.STATE_CONNECTING -> {
                isConnecting = true
                tvStatus.text = getString(R.string.status_connecting)
                btnConnect.text = getString(R.string.cancel_connect)
                appendLog("正在连接...")
            }
            BleService.STATE_DISCONNECTED -> {
                isConnected = false
                isConnecting = false
                tvStatus.text = getString(R.string.status_disconnected)
                btnConnect.text = getString(R.string.connect)
                btnFloat.isEnabled = false
                hideFloatingWindow()
                appendLog("已断开连接")
            }
        }
    }

    private fun showFloatingWindow() {
        floatingWindowManager?.showFloatingWindow()
        isFloatingShowing = true
        sharedPreferences.edit().putBoolean("is_floating_showing", true).apply()
        btnFloat.text = getString(R.string.hide_float)
        appendLog("显示悬浮窗")
    }

    private fun hideFloatingWindow() {
        floatingWindowManager?.hideFloatingWindow()
        isFloatingShowing = false
        sharedPreferences.edit().putBoolean("is_floating_showing", false).apply()
        btnFloat.text = getString(R.string.show_float)
        appendLog("隐藏悬浮窗")
    }

    private fun appendLog(message: String) {
        val timestamp = timeFormat.format(Date())
        val logLine = "[$timestamp] $message\n"
        logBuilder.append(logLine)
        
        val lines = logBuilder.toString().split("\n")
        if (lines.size > MAX_LOG_LINES) {
            logBuilder.clear()
            lines.takeLast(MAX_LOG_LINES).forEach {
                if (it.isNotEmpty()) {
                    logBuilder.append(it).append("\n")
                }
            }
        }
        
        tvLog.text = logBuilder.toString()
        scrollViewLog.post {
            scrollViewLog.fullScroll(ScrollView.FOCUS_DOWN)
        }
    }

    private fun clearLog() {
        logBuilder.clear()
        tvLog.text = ""
        appendLog("日志已清空")
    }

    private fun copyLog() {
        val logText = logBuilder.toString()
        if (logText.isNotEmpty()) {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("日志", logText)
            clipboard.setPrimaryClip(clip)
            Toast.makeText(this, "日志已复制到剪贴板", Toast.LENGTH_SHORT).show()
            appendLog("日志已复制到剪贴板")
        } else {
            Toast.makeText(this, "日志为空", Toast.LENGTH_SHORT).show()
        }
    }
}
