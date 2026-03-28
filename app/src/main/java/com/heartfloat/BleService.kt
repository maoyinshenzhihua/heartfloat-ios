package com.heartfloat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.UUID

class BleService : Service() {

    companion object {
        const val TAG = "BleService"
        const val CHANNEL_ID = "heart_rate_monitor"
        const val NOTIFICATION_ID = 1001
        
        const val ACTION_HEART_RATE_UPDATE = "com.heartfloat.HEART_RATE_UPDATE"
        const val ACTION_CONNECTION_STATE_UPDATE = "com.heartfloat.CONNECTION_STATE_UPDATE"
        const val ACTION_LOG_UPDATE = "com.heartfloat.LOG_UPDATE"
        const val EXTRA_HEART_RATE = "heart_rate"
        const val EXTRA_CONNECTION_STATE = "connection_state"
        const val EXTRA_LOG_MSG = "log_msg"
        
        const val STATE_DISCONNECTED = 0
        const val STATE_CONNECTING = 1
        const val STATE_CONNECTED = 2
        
        // 标准心率服务和特征
        val HEART_RATE_SERVICE_UUID: UUID = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        val HEART_RATE_MEASUREMENT_UUID: UUID = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        val HEART_RATE_CONTROL_POINT_UUID: UUID = UUID.fromString("00002a38-0000-1000-8000-00805f9b34fb")
        val CLIENT_CHARACTERISTIC_CONFIG_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        
        private const val SCAN_TIMEOUT: Long = 30000
        private const val RECONNECT_DELAY: Long = 10000
        
        val TARGET_DEVICE_NAMES = listOf(
            "Mi Smart Band 9 Pro",
            "Mi Smart Band 9",
            "Mi Band 9 Pro",
            "Mi Band 9",
            "Band 9 Pro",
            "Band 9",
            "Mi Smart Band",
            "Mi Band",
            "Xiaomi Smart Band"
        )
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var connectionState = STATE_DISCONNECTED
    private var isScanning = false
    private var lastHeartRate: Int = 0
    private var heartRateCharacteristic: BluetoothGattCharacteristic? = null
    private var heartRateControlPoint: BluetoothGattCharacteristic? = null
    
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var sharedPreferences: SharedPreferences
    
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name ?: ""
            
            Log.d(TAG, "Found device: $deviceName - ${device.address}")
            if (deviceName.isNotEmpty()) {
                broadcastLog("发现设备: $deviceName [${device.address}]")
            }
            
            if (TARGET_DEVICE_NAMES.any { deviceName.contains(it, ignoreCase = true) }) {
                Log.i(TAG, "Found target device: $deviceName")
                broadcastLog("找到目标设备: $deviceName")
                stopScan()
                connectToDevice(device)
            }
        }
        
        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "Scan failed with error: $errorCode")
            broadcastLog("扫描失败: 错误码 $errorCode")
            isScanning = false
            broadcastConnectionState(STATE_DISCONNECTED)
        }
    }
    
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.i(TAG, "Connected to GATT server")
                    broadcastLog("GATT连接成功")
                    connectionState = STATE_CONNECTED
                    broadcastConnectionState(STATE_CONNECTED)
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.i(TAG, "Disconnected from GATT server")
                    broadcastLog("GATT连接断开")
                    connectionState = STATE_DISCONNECTED
                    broadcastConnectionState(STATE_DISCONNECTED)
                    bluetoothGatt?.close()
                    bluetoothGatt = null
                    heartRateCharacteristic = null
                    heartRateControlPoint = null
                    scheduleReconnect()
                }
            }
        }
        
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.i(TAG, "Services discovered")
                broadcastLog("服务发现成功，共${gatt.services.size}个服务")
                discoverHeartRateService(gatt)
            } else {
                Log.e(TAG, "Service discovery failed: $status")
                broadcastLog("服务发现失败: $status")
            }
        }
        
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid == HEART_RATE_MEASUREMENT_UUID) {
                val value = characteristic.value
                if (value != null) {
                    parseHeartRateData(value)
                }
            }
        }
        
        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val charUuid = descriptor.characteristic.uuid.toString().take(8)
                Log.i(TAG, "Descriptor write successful for $charUuid")
                broadcastLog("通知已启用: $charUuid")
            } else {
                broadcastLog("通知启用失败: status=$status")
            }
        }
        
        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val charUuid = characteristic.uuid.toString().take(8)
                Log.i(TAG, "Characteristic write successful for $charUuid")
                broadcastLog("命令发送成功: $charUuid")
            } else {
                broadcastLog("命令发送失败: status=$status")
            }
        }
    }
    
    private val scanTimeoutRunnable = Runnable {
        if (isScanning) {
            Log.w(TAG, "Scan timeout")
            broadcastLog("扫描超时，未找到设备")
            stopScan()
            broadcastConnectionState(STATE_DISCONNECTED)
        }
    }
    
    private val reconnectRunnable = Runnable {
        if (connectionState == STATE_DISCONNECTED) {
            Log.i(TAG, "Attempting to reconnect...")
            broadcastLog("尝试重新连接...")
            startScan()
        }
    }

    override fun onCreate() {
        super.onCreate()
        sharedPreferences = getSharedPreferences("HeartFloat", Context.MODE_PRIVATE)
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        broadcastLog("BLE服务已启动")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "CONNECT" -> {
                val savedMac = sharedPreferences.getString("device_mac", null)
                if (savedMac != null) {
                    broadcastLog("尝试连接已保存设备: $savedMac")
                    val device = bluetoothAdapter?.getRemoteDevice(savedMac)
                    device?.let { connectToDevice(it) }
                } else {
                    startScan()
                }
            }
            "DISCONNECT" -> {
                disconnect()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopScan()
        disconnect()
        handler.removeCallbacksAndMessages(null)
        broadcastLog("BLE服务已停止")
    }

    private fun startScan() {
        if (isScanning || bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            Log.w(TAG, "Cannot start scan")
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                broadcastLog("蓝牙未开启")
            }
            return
        }
        
        Log.i(TAG, "Starting BLE scan...")
        broadcastLog("开始扫描BLE设备...")
        isScanning = true
        connectionState = STATE_CONNECTING
        broadcastConnectionState(STATE_CONNECTING)
        
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        scanner?.startScan(scanCallback)
        
        handler.postDelayed(scanTimeoutRunnable, SCAN_TIMEOUT)
    }

    private fun stopScan() {
        if (isScanning) {
            Log.i(TAG, "Stopping BLE scan")
            broadcastLog("停止扫描")
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            isScanning = false
            handler.removeCallbacks(scanTimeoutRunnable)
        }
    }

    private fun connectToDevice(device: BluetoothDevice) {
        Log.i(TAG, "Connecting to device: ${device.name} - ${device.address}")
        broadcastLog("连接设备: ${device.name}")
        connectionState = STATE_CONNECTING
        broadcastConnectionState(STATE_CONNECTING)
        
        sharedPreferences.edit().putString("device_mac", device.address).apply()
        
        bluetoothGatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            device.connectGatt(this, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(this, false, gattCallback)
        }
    }

    private fun disconnect() {
        Log.i(TAG, "Disconnecting...")
        broadcastLog("断开连接")
        stopScan()
        handler.removeCallbacks(reconnectRunnable)
        bluetoothGatt?.disconnect()
        bluetoothGatt?.close()
        bluetoothGatt = null
        heartRateCharacteristic = null
        heartRateControlPoint = null
        connectionState = STATE_DISCONNECTED
        broadcastConnectionState(STATE_DISCONNECTED)
    }

    private fun discoverHeartRateService(gatt: BluetoothGatt) {
        broadcastLog("--- 扫描所有服务 ---")
        
        for (service in gatt.services) {
            val serviceUuid = service.uuid.toString()
            val shortUuid = serviceUuid.take(8)
            broadcastLog("服务: $shortUuid")
            
            for (characteristic in service.characteristics) {
                val charUuid = characteristic.uuid.toString()
                val shortCharUuid = charUuid.take(8)
                val props = characteristic.properties
                val canNotify = (props and BluetoothGattCharacteristic.PROPERTY_NOTIFY) != 0
                val canRead = (props and BluetoothGattCharacteristic.PROPERTY_READ) != 0
                val canWrite = (props and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0
                
                broadcastLog("  特征: $shortCharUuid [N:$canNotify R:$canRead W:$canWrite]")
            }
        }
        
        // 查找标准心率服务
        val heartRateService = gatt.getService(HEART_RATE_SERVICE_UUID)
        if (heartRateService != null) {
            broadcastLog("找到标准心率服务 (180d)")
            
            // 查找心率测量特征
            heartRateCharacteristic = heartRateService.getCharacteristic(HEART_RATE_MEASUREMENT_UUID)
            if (heartRateCharacteristic != null) {
                broadcastLog("找到心率测量特征 (2a37)")
                enableNotification(gatt, heartRateCharacteristic!!)
                
                // 查找心率控制点特征
                heartRateControlPoint = heartRateService.getCharacteristic(HEART_RATE_CONTROL_POINT_UUID)
                if (heartRateControlPoint != null) {
                    broadcastLog("找到心率控制点特征 (2a38)")
                    // 发送开启心率监测命令
                    startHeartRateMeasurement(gatt)
                }
            }
        } else {
            broadcastLog("未找到标准心率服务")
        }
    }

    private fun enableNotification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        val enabled = gatt.setCharacteristicNotification(characteristic, true)
        if (!enabled) {
            Log.e(TAG, "Failed to enable notification")
            broadcastLog("启用通知失败")
            return
        }
        
        val descriptor = characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG_UUID)
        if (descriptor != null) {
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(descriptor)
            Log.i(TAG, "Notification enabled for ${characteristic.uuid.toString().take(8)}")
        } else {
            broadcastLog("未找到CCCD描述符")
        }
    }

    private fun startHeartRateMeasurement(gatt: BluetoothGatt) {
        heartRateControlPoint?.let {controlPoint ->
            // 标准心率控制命令：开始连续心率测量
            val command = byteArrayOf(0x01, 0x00) // 0x01: 开始, 0x00: 连续模式
            controlPoint.value = command
            val success = gatt.writeCharacteristic(controlPoint)
            if (success) {
                broadcastLog("已发送心率监测启动命令")
            } else {
                broadcastLog("发送命令失败")
            }
        }
    }

    private fun parseHeartRateData(data: ByteArray) {
        if (data.isEmpty()) return
        
        val flags = data[0].toInt() and 0xFF
        val is16Bit = (flags and 0x01) != 0
        val hasSensorContact = (flags and 0x02) != 0
        
        val heartRate = if (is16Bit && data.size >= 3) {
            ((data[2].toInt() and 0xFF) shl 8) or (data[1].toInt() and 0xFF)
        } else if (data.size >= 2) {
            data[1].toInt() and 0xFF
        } else {
            return
        }
        
        if (heartRate in 30..220) {
            lastHeartRate = heartRate
            val sensorContact = if (hasSensorContact) "(已接触)" else "(未接触)"
            broadcastLog("心率: $heartRate BPM $sensorContact")
            broadcastHeartRate(heartRate)
            // 直接更新悬浮窗，即使应用在后台
            Log.d(TAG, "更新悬浮窗心率: $heartRate")
            FloatingWindowManager.updateHeartRateFromService(heartRate)
            // 更新HTTP服务器的全局心率数据
            HttpServerManager.updateHeartRate(heartRate, hasSensorContact)
        }
    }

    private fun broadcastHeartRate(heartRate: Int) {
        val intent = Intent(ACTION_HEART_RATE_UPDATE)
        intent.putExtra(EXTRA_HEART_RATE, heartRate)
        sendBroadcast(intent)
    }

    private fun broadcastConnectionState(state: Int) {
        connectionState = state
        val intent = Intent(ACTION_CONNECTION_STATE_UPDATE)
        intent.putExtra(EXTRA_CONNECTION_STATE, state)
        sendBroadcast(intent)
    }

    private fun broadcastLog(message: String) {
        val intent = Intent(ACTION_LOG_UPDATE)
        intent.putExtra(EXTRA_LOG_MSG, message)
        sendBroadcast(intent)
    }

    private fun scheduleReconnect() {
        handler.removeCallbacks(reconnectRunnable)
        handler.postDelayed(reconnectRunnable, RECONNECT_DELAY)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = getString(R.string.channel_description)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(getString(R.string.notification_content))
            .setSmallIcon(android.R.drawable.ic_menu_myplaces)
            .setOngoing(true)
            .build()
    }
}
