package com.heartfloat

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject
import java.net.InetAddress
import java.net.NetworkInterface

object HttpServerManager {

    private const val TAG = "HttpServerManager"
    
    private var httpServer: HeartRateHttpServer? = null
    private var isRunning = false
    private var currentPort = 8080
    
    private var currentHeartRate: Int = 0
    private var isContact: Boolean = false
    private var lastUpdateTime: Long = 0
    
    fun updateHeartRate(heartRate: Int, contact: Boolean = true) {
        synchronized(this) {
            currentHeartRate = heartRate
            isContact = contact
            lastUpdateTime = System.currentTimeMillis()
        }
        Log.d(TAG, "心率数据已更新: $heartRate BPM, 接触状态: $contact")
    }
    
    fun getHeartRateData(): HeartRateData {
        synchronized(this) {
            return HeartRateData(
                bpm = currentHeartRate,
                isContact = isContact,
                lastUpdate = lastUpdateTime
            )
        }
    }
    
    data class HeartRateData(
        val bpm: Int,
        val isContact: Boolean,
        val lastUpdate: Long
    )
    
    fun startServer(port: Int): Boolean {
        if (isRunning) {
            Log.w(TAG, "HTTP服务器已在运行中")
            return true
        }
        
        return try {
            currentPort = port
            httpServer = HeartRateHttpServer(port)
            httpServer?.start()
            isRunning = true
            Log.i(TAG, "HTTP服务器启动成功，端口: $port")
            true
        } catch (e: Exception) {
            Log.e(TAG, "HTTP服务器启动失败", e)
            isRunning = false
            false
        }
    }
    
    fun stopServer() {
        if (!isRunning) {
            return
        }
        
        try {
            httpServer?.stop()
            httpServer = null
            isRunning = false
            Log.i(TAG, "HTTP服务器已停止")
        } catch (e: Exception) {
            Log.e(TAG, "HTTP服务器停止失败", e)
        }
    }
    
    fun isRunning(): Boolean = isRunning
    
    fun getPort(): Int = currentPort
    
    fun getLocalIpAddress(context: Context): String? {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val wifiInfo = wifiManager.connectionInfo
            val ipAddress = wifiInfo.ipAddress
            
            if (ipAddress != 0) {
                return String.format(
                    "%d.%d.%d.%d",
                    ipAddress and 0xff,
                    ipAddress shr 8 and 0xff,
                    ipAddress shr 16 and 0xff,
                    ipAddress shr 24 and 0xff
                )
            }
            
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                
                if (networkInterface.name.startsWith("wlan") || 
                    networkInterface.name.startsWith("eth") ||
                    networkInterface.name.startsWith("rmnet")) {
                    
                    val addresses = networkInterface.inetAddresses
                    while (addresses.hasMoreElements()) {
                        val address = addresses.nextElement()
                        if (!address.isLoopbackAddress && address is InetAddress) {
                            val hostAddress = address.hostAddress
                            if (hostAddress != null && !hostAddress.contains(":")) {
                                return hostAddress
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取本地IP地址失败", e)
        }
        return null
    }
    
    private class HeartRateHttpServer(port: Int) : NanoHTTPD(port) {
        
        override fun serve(session: IHTTPSession): Response {
            val uri = session.uri
            
            return when (uri) {
                "/heartbeat" -> {
                    val data = getHeartRateData()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "text/plain",
                        data.bpm.toString()
                    )
                }
                "/heartbeat.json" -> {
                    val data = getHeartRateData()
                    val json = JSONObject().apply {
                        put("bpm", data.bpm)
                        put("isContact", data.isContact)
                        put("lastUpdate", data.lastUpdate)
                        put("timestamp", System.currentTimeMillis())
                    }
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "application/json",
                        json.toString()
                    )
                }
                "/live" -> {
                    val html = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>心率 - 直播</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            background: transparent;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            transition: all 0.3s ease;
        }
        
        .display-container {
            position: relative;
            transition: all 0.3s ease;
        }
        
        /* 默认样式 */
        body.style-default .display-container {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 20px 30px;
            background: rgba(0, 0, 0, 0.6);
            border-radius: 50px;
            backdrop-filter: blur(10px);
        }
        
        body.style-default .heart-icon {
            font-size: 48px;
            animation: heartbeat 1s ease-in-out infinite;
            filter: drop-shadow(0 0 10px rgba(255, 107, 107, 0.8));
        }
        
        body.style-default .heart-rate-value {
            font-size: 72px;
            font-weight: 800;
            color: #FF6B6B;
            text-shadow: 0 0 20px rgba(255, 107, 107, 0.6);
            min-width: 120px;
            text-align: center;
        }
        
        body.style-default .heart-rate-unit {
            font-size: 28px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.9);
        }
        
        @keyframes heartbeat {
            0%, 100% { transform: scale(1); }
            25% { transform: scale(1.2); }
            50% { transform: scale(1); }
        }
        
        /* 心电图样式 */
        body.style-ecg .display-container {
            background: rgba(0, 20, 0, 0.9);
            padding: 30px 50px;
            border-radius: 10px;
            border: 2px solid #00ff00;
            box-shadow: 0 0 30px rgba(0, 255, 0, 0.4);
            position: relative;
            overflow: hidden;
        }
        
        body.style-ecg .ecg-line {
            position: absolute;
            top: 50%;
            left: 0;
            width: 100%;
            height: 2px;
            background: linear-gradient(90deg, transparent, #00ff00 50%, transparent);
            animation: ecgScan 2s linear infinite;
        }
        
        body.style-ecg .ecg-wave {
            position: absolute;
            top: 0;
            left: 0;
            width: 200%;
            height: 100%;
            background: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 50'%3E%3Cpath d='M0,25 L20,25 L25,25 L30,10 L35,40 L40,25 L60,25 L80,25 L85,25 L90,10 L95,40 L100,25 L120,25 L140,25 L145,25 L150,10 L155,40 L160,25 L180,25 L200,25' stroke='%2300ff00' stroke-width='1' fill='none' opacity='0.3'/%3E%3C/svg%3E");
            background-size: 200px 50px;
            background-repeat: repeat-x;
            background-position-y: center;
            animation: ecgWave 1s linear infinite;
            pointer-events: none;
        }
        
        @keyframes ecgScan {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(100%); }
        }
        
        @keyframes ecgWave {
            0% { transform: translateX(0); }
            100% { transform: translateX(-200px); }
        }
        
        body.style-ecg .heart-rate-value {
            font-size: 80px;
            font-weight: 700;
            color: #00ff00;
            text-shadow: 0 0 30px #00ff00, 0 0 60px #00ff00;
            font-family: 'Courier New', monospace;
            position: relative;
            z-index: 2;
        }
        
        body.style-ecg .heart-rate-unit {
            font-size: 24px;
            color: #00ff00;
            margin-left: 10px;
            text-shadow: 0 0 10px #00ff00;
            position: relative;
            z-index: 2;
        }
        
        body.style-ecg .heart-icon { display: none; }
        
        /* 复古街机样式 */
        body.style-arcade .display-container {
            background: #000;
            padding: 25px 35px;
            border: 4px solid #fff;
            box-shadow: 
                inset 0 0 0 4px #000,
                inset 0 0 0 8px #ff0,
                0 0 0 4px #f0f,
                0 0 20px #f0f;
            image-rendering: pixelated;
        }
        
        body.style-arcade .heart-icon {
            font-size: 48px;
            animation: arcadeHeart 0.3s steps(2) infinite;
            filter: none;
        }
        
        @keyframes arcadeHeart {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.7; transform: scale(1.15); }
        }
        
        body.style-arcade .heart-rate-value {
            font-size: 72px;
            font-weight: 900;
            color: #ff0;
            text-shadow: 4px 4px 0 #f00, -4px -4px 0 #0ff, 0 0 20px #ff0;
            font-family: 'Courier New', monospace;
            letter-spacing: 4px;
        }
        
        body.style-arcade .heart-rate-unit {
            font-size: 24px;
            color: #0f0;
            font-family: 'Courier New', monospace;
            text-shadow: 0 0 10px #0f0;
        }
        
        /* 赛博霓虹样式 */
        body.style-cyber .display-container {
            background: linear-gradient(135deg, rgba(0, 0, 0, 0.95), rgba(30, 0, 50, 0.95));
            padding: 30px 45px;
            border-radius: 0;
            border: 2px solid;
            border-image: linear-gradient(45deg, #f0f, #0ff, #f0f, #0ff) 1;
            box-shadow: 
                0 0 30px #f0f,
                0 0 60px #0ff,
                inset 0 0 30px rgba(255, 0, 255, 0.2);
            position: relative;
            overflow: hidden;
        }
        
        body.style-cyber .cyber-grid {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: 
                linear-gradient(90deg, rgba(255,0,255,0.1) 1px, transparent 1px),
                linear-gradient(rgba(0,255,255,0.1) 1px, transparent 1px);
            background-size: 20px 20px;
            animation: gridMove 2s linear infinite;
            pointer-events: none;
        }
        
        @keyframes gridMove {
            0% { transform: translate(0, 0); }
            100% { transform: translate(20px, 20px); }
        }
        
        body.style-cyber .heart-icon {
            font-size: 52px;
            animation: cyberHeart 1s ease-in-out infinite;
            filter: drop-shadow(0 0 15px #f0f) drop-shadow(0 0 30px #0ff);
            position: relative;
            z-index: 2;
        }
        
        @keyframes cyberHeart {
            0%, 100% { transform: scale(1) rotate(0deg); }
            25% { transform: scale(1.15) rotate(-5deg); }
            75% { transform: scale(1.15) rotate(5deg); }
        }
        
        body.style-cyber .heart-rate-value {
            font-size: 80px;
            font-weight: 800;
            color: #fff;
            text-shadow: 
                0 0 10px #f0f,
                0 0 20px #f0f,
                0 0 40px #0ff,
                0 0 80px #0ff;
            position: relative;
            z-index: 2;
        }
        
        body.style-cyber .heart-rate-unit {
            font-size: 28px;
            color: #0ff;
            text-shadow: 0 0 10px #0ff, 0 0 20px #0ff;
            position: relative;
            z-index: 2;
        }
        
        /* 心率表样式 */
        body.style-gauge .display-container {
            width: 220px;
            height: 220px;
            background: radial-gradient(circle at center, #1a1a2e 0%, #0a0a15 70%, #000 100%);
            border-radius: 50%;
            border: 5px solid #333;
            box-shadow: 
                0 0 30px rgba(0, 0, 0, 0.8),
                inset 0 0 40px rgba(0, 0, 0, 0.6),
                0 0 60px rgba(255, 107, 107, 0.2);
            position: relative;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
        }
        
        body.style-gauge .gauge-ring {
            position: absolute;
            width: 190px;
            height: 190px;
            border-radius: 50%;
            border: 4px solid transparent;
            border-top-color: #FF6B6B;
            border-right-color: #FF6B6B;
            transform: rotate(-45deg);
            transition: transform 0.5s ease;
            box-shadow: 0 0 20px rgba(255, 107, 107, 0.5);
        }
        
        body.style-gauge .gauge-inner {
            position: absolute;
            width: 160px;
            height: 160px;
            border-radius: 50%;
            border: 2px solid rgba(255, 255, 255, 0.1);
        }
        
        body.style-gauge .gauge-ticks {
            position: absolute;
            width: 100%;
            height: 100%;
        }
        
        body.style-gauge .gauge-tick {
            position: absolute;
            width: 2px;
            height: 10px;
            background: #444;
            left: 50%;
            top: 8px;
            transform-origin: center 102px;
        }
        
        body.style-gauge .gauge-tick.major {
            height: 15px;
            background: #666;
        }
        
        body.style-gauge .heart-rate-value {
            font-size: 52px;
            font-weight: 700;
            color: #FF6B6B;
            text-shadow: 0 0 15px rgba(255, 107, 107, 0.6);
            z-index: 1;
        }
        
        body.style-gauge .heart-rate-unit {
            font-size: 16px;
            color: #888;
            z-index: 1;
            margin-top: -5px;
        }
        
        body.style-gauge .heart-icon { display: none; }
        
        /* 设置面板 */
        .settings-toggle {
            position: fixed;
            top: 10px;
            right: 10px;
            width: 44px;
            height: 44px;
            background: rgba(0, 0, 0, 0.85);
            border: 2px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            cursor: pointer;
            z-index: 1001;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
            transition: all 0.3s ease;
        }
        
        .settings-toggle:hover {
            background: rgba(255, 107, 107, 0.4);
            border-color: #FF6B6B;
            transform: scale(1.1);
        }
        
        .settings-toggle.active {
            background: #FF6B6B;
            border-color: #FF6B6B;
        }
        
        .settings-panel {
            position: fixed;
            top: 60px;
            right: 10px;
            background: rgba(20, 20, 30, 0.95);
            border-radius: 16px;
            padding: 20px;
            z-index: 1000;
            width: 300px;
            max-height: calc(100vh - 80px);
            overflow-y: auto;
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.15);
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
            opacity: 0;
            visibility: hidden;
            transform: translateY(-10px);
        }
        
        .settings-panel.visible {
            opacity: 1;
            visibility: visible;
            transform: translateY(0);
        }
        
        .settings-title {
            color: #fff;
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.15);
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .style-buttons {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
            margin-bottom: 15px;
        }
        
        .style-btn {
            padding: 10px 8px;
            background: rgba(255, 255, 255, 0.08);
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 8px;
            color: #fff;
            font-size: 11px;
            cursor: pointer;
            transition: all 0.2s ease;
            text-align: center;
        }
        
        .style-btn:hover {
            background: rgba(255, 107, 107, 0.25);
            border-color: rgba(255, 107, 107, 0.5);
        }
        
        .style-btn.active {
            background: linear-gradient(135deg, #FF6B6B, #ff8e8e);
            border-color: #FF6B6B;
            box-shadow: 0 0 15px rgba(255, 107, 107, 0.4);
        }
        
        .custom-section {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .custom-label {
            color: #aaa;
            font-size: 12px;
            margin-bottom: 8px;
            display: block;
            font-weight: 500;
        }
        
        .custom-row {
            display: flex;
            align-items: center;
            gap: 10px;
            margin-bottom: 12px;
        }
        
        .custom-row label {
            color: #888;
            font-size: 11px;
            min-width: 45px;
        }
        
        .color-input {
            width: 36px;
            height: 30px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            background: transparent;
        }
        
        .custom-row input[type="range"] {
            flex: 1;
            height: 6px;
            -webkit-appearance: none;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 3px;
            outline: none;
        }
        
        .custom-row input[type="range"]::-webkit-slider-thumb {
            -webkit-appearance: none;
            width: 16px;
            height: 16px;
            background: #FF6B6B;
            border-radius: 50%;
            cursor: pointer;
        }
        
        .value-display {
            color: #fff;
            font-size: 12px;
            min-width: 50px;
            text-align: right;
        }
        
        .btn-row {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        
        .apply-btn {
            flex: 1;
            padding: 12px;
            background: linear-gradient(135deg, #4ECDC4, #3dbdb5);
            border: none;
            border-radius: 8px;
            color: #000;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .apply-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(78, 205, 196, 0.4);
        }
        
        .reset-btn {
            flex: 1;
            padding: 12px;
            background: transparent;
            border: 1px solid rgba(255, 255, 255, 0.2);
            border-radius: 8px;
            color: #aaa;
            font-size: 13px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .reset-btn:hover {
            border-color: #FF6B6B;
            color: #FF6B6B;
        }
        
        /* 响应式 */
        @media (max-width: 400px) {
            .settings-panel {
                width: calc(100vw - 20px);
                right: 10px;
            }
            .style-buttons {
                grid-template-columns: repeat(2, 1fr);
            }
        }
    </style>
</head>
<body class="style-default">
    <button class="settings-toggle" id="settingsToggle">⚙️</button>
    
    <div class="settings-panel" id="settingsPanel">
        <div class="settings-title">🎨 样式设置</div>
        
        <div class="style-buttons">
            <button class="style-btn active" data-style="default">默认</button>
            <button class="style-btn" data-style="ecg">心电图</button>
            <button class="style-btn" data-style="arcade">街机</button>
            <button class="style-btn" data-style="cyber">赛博</button>
            <button class="style-btn" data-style="gauge">表盘</button>
        </div>
        
        <div class="custom-section">
            <label class="custom-label">自定义颜色</label>
            <div class="custom-row">
                <label>数字</label>
                <input type="color" class="color-input" id="colorValue" value="#FF6B6B">
                <label>单位</label>
                <input type="color" class="color-input" id="colorUnit" value="#FFFFFF">
            </div>
            <div class="custom-row">
                <label>背景</label>
                <input type="color" class="color-input" id="colorBg" value="#000000">
                <input type="range" id="bgOpacity" min="0" max="100" value="60">
                <span class="value-display" id="bgOpacityVal">60%</span>
            </div>
        </div>
        
        <div class="custom-section">
            <label class="custom-label">字体大小</label>
            <div class="custom-row">
                <input type="range" id="fontSize" min="40" max="120" value="72" style="width:100%">
                <span class="value-display" id="fontSizeVal">72px</span>
            </div>
        </div>
        
        <div class="btn-row">
            <button class="apply-btn" id="applyCustom">应用样式</button>
            <button class="reset-btn" id="resetBtn">重置</button>
        </div>
    </div>
    
    <div class="display-container">
        <div class="ecg-wave"></div>
        <div class="ecg-line"></div>
        <div class="cyber-grid"></div>
        <div class="gauge-ring" id="gaugeRing"></div>
        <div class="gauge-inner"></div>
        <div class="gauge-ticks" id="gaugeTicks"></div>
        <span class="heart-icon" id="heart">❤️</span>
        <span class="heart-rate-value" id="bpm">--</span>
        <span class="heart-rate-unit">BPM</span>
    </div>
    
    <script>
        var currentBpm = 0;
        var currentStyle = 'default';
        var panelVisible = false;
        
        // 样式预设配置
        var stylePresets = {
            default: { value: '#FF6B6B', unit: '#FFFFFF', bg: '#000000', opacity: 60, fontSize: 72 },
            ecg: { value: '#00ff00', unit: '#00ff00', bg: '#001400', opacity: 90, fontSize: 80 },
            arcade: { value: '#ffff00', unit: '#00ff00', bg: '#000000', opacity: 100, fontSize: 72 },
            cyber: { value: '#ffffff', unit: '#00ffff', bg: '#1a0030', opacity: 95, fontSize: 80 },
            gauge: { value: '#FF6B6B', unit: '#888888', bg: '#0a0a15', opacity: 100, fontSize: 52 }
        };
        
        function init() {
            createGaugeTicks();
            loadSettings();
            setupEventListeners();
            updateHeartRate();
            setInterval(updateHeartRate, 500);
        }
        
        function createGaugeTicks() {
            var ticks = document.getElementById('gaugeTicks');
            for (var i = 0; i <= 255; i += 10) {
                var tick = document.createElement('div');
                tick.className = 'gauge-tick' + (i % 50 === 0 ? ' major' : '');
                tick.style.transform = 'rotate(' + (-135 + (i / 255) * 270) + 'deg)';
                ticks.appendChild(tick);
            }
        }
        
        function loadSettings() {
            var savedStyle = localStorage.getItem('hrStyle');
            var savedCustom = localStorage.getItem('hrCustom');
            
            if (savedStyle) {
                setStyle(savedStyle, false);
            }
            
            if (savedCustom) {
                var c = JSON.parse(savedCustom);
                document.getElementById('colorValue').value = c.value || '#FF6B6B';
                document.getElementById('colorUnit').value = c.unit || '#FFFFFF';
                document.getElementById('colorBg').value = c.bg || '#000000';
                document.getElementById('bgOpacity').value = c.opacity || 60;
                document.getElementById('fontSize').value = c.fontSize || 72;
                updateDisplayValues();
            }
        }
        
        function saveSettings() {
            localStorage.setItem('hrStyle', currentStyle);
            localStorage.setItem('hrCustom', JSON.stringify({
                value: document.getElementById('colorValue').value,
                unit: document.getElementById('colorUnit').value,
                bg: document.getElementById('colorBg').value,
                opacity: document.getElementById('bgOpacity').value,
                fontSize: document.getElementById('fontSize').value
            }));
        }
        
        function setStyle(style, animate) {
            currentStyle = style;
            document.body.className = 'style-' + style;
            
            document.querySelectorAll('.style-btn').forEach(function(btn) {
                btn.classList.toggle('active', btn.dataset.style === style);
            });
            
            // 更新控件为对应预设值
            var preset = stylePresets[style];
            if (preset) {
                document.getElementById('colorValue').value = preset.value;
                document.getElementById('colorUnit').value = preset.unit;
                document.getElementById('colorBg').value = preset.bg;
                document.getElementById('bgOpacity').value = preset.opacity;
                document.getElementById('fontSize').value = preset.fontSize;
                updateDisplayValues();
            }
            
            saveSettings();
            
            if (style === 'gauge') {
                updateGauge(currentBpm);
            }
        }
        
        function updateDisplayValues() {
            document.getElementById('bgOpacityVal').textContent = document.getElementById('bgOpacity').value + '%';
            document.getElementById('fontSizeVal').textContent = document.getElementById('fontSize').value + 'px';
        }
        
        function updateGauge(bpm) {
            var ring = document.getElementById('gaugeRing');
            if (ring) {
                var rotation = -45 + (bpm / 255) * 270;
                ring.style.transform = 'rotate(' + rotation + 'deg)';
            }
        }
        
        function setupEventListeners() {
            var toggle = document.getElementById('settingsToggle');
            var panel = document.getElementById('settingsPanel');
            
            toggle.addEventListener('click', function() {
                panelVisible = !panelVisible;
                panel.classList.toggle('visible', panelVisible);
                toggle.classList.toggle('active', panelVisible);
                toggle.textContent = panelVisible ? '✕' : '⚙️';
            });
            
            document.querySelectorAll('.style-btn').forEach(function(btn) {
                btn.addEventListener('click', function() {
                    setStyle(this.dataset.style, true);
                });
            });
            
            document.getElementById('bgOpacity').addEventListener('input', updateDisplayValues);
            document.getElementById('fontSize').addEventListener('input', updateDisplayValues);
            
            document.getElementById('applyCustom').addEventListener('click', function() {
                var colorValue = document.getElementById('colorValue').value;
                var colorUnit = document.getElementById('colorUnit').value;
                var colorBg = document.getElementById('colorBg').value;
                var bgOpacity = document.getElementById('bgOpacity').value / 100;
                var fontSize = document.getElementById('fontSize').value;
                
                var container = document.querySelector('.display-container');
                var bpmEl = document.getElementById('bpm');
                var unitEl = document.querySelector('.heart-rate-unit');
                
                function hexToRgba(hex, alpha) {
                    var r = parseInt(hex.slice(1, 3), 16);
                    var g = parseInt(hex.slice(3, 5), 16);
                    var b = parseInt(hex.slice(5, 7), 16);
                    return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
                }
                
                container.style.background = hexToRgba(colorBg, bgOpacity);
                bpmEl.style.color = colorValue;
                bpmEl.style.fontSize = fontSize + 'px';
                unitEl.style.color = colorUnit;
                
                saveSettings();
            });
            
            document.getElementById('resetBtn').addEventListener('click', function() {
                localStorage.clear();
                location.reload();
            });
        }
        
        function updateHeartbeatSpeed(bpm) {
            if (bpm > 0) {
                var duration = 60 / bpm;
                document.getElementById('heart').style.animationDuration = duration + 's';
                if (currentStyle === 'gauge') {
                    updateGauge(bpm);
                }
            }
        }
        
        function updateHeartRate() {
            fetch('/heartbeat.json')
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    var el = document.getElementById('bpm');
                    if (data.bpm > 0) {
                        el.textContent = data.bpm;
                        if (data.bpm !== currentBpm) {
                            currentBpm = data.bpm;
                            updateHeartbeatSpeed(data.bpm);
                        }
                    } else {
                        el.textContent = '--';
                    }
                })
                .catch(function() {});
        }
        
        init();
    </script>
</body>
</html>
                    """.trimIndent()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "text/html; charset=utf-8",
                        html
                    )
                }
                "/" -> {
                    val html = """
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>心率监测服务</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            max-width: 500px;
            width: 100%;
        }
        
        .heart-rate-card {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 24px;
            padding: 40px 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.1);
            text-align: center;
            margin-bottom: 20px;
        }
        
        .heart-icon {
            font-size: 60px;
            animation: heartbeat 1s ease-in-out infinite;
            display: inline-block;
        }
        
        @keyframes heartbeat {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.1); }
        }
        
        .heart-rate-value {
            font-size: 96px;
            font-weight: 700;
            color: #FF6B6B;
            line-height: 1;
            margin: 20px 0;
            text-shadow: 0 0 30px rgba(255, 107, 107, 0.5);
        }
        
        .heart-rate-unit {
            font-size: 32px;
            color: #fff;
            opacity: 0.8;
            margin-left: 10px;
        }
        
        .status-badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
            margin-top: 15px;
        }
        
        .status-badge.connected {
            background: rgba(78, 205, 196, 0.2);
            color: #4ECDC4;
        }
        
        .status-badge.disconnected {
            background: rgba(255, 107, 107, 0.2);
            color: #FF6B6B;
        }
        
        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            animation: pulse 1.5s ease-in-out infinite;
        }
        
        .status-badge.connected .status-dot {
            background: #4ECDC4;
        }
        
        .status-badge.disconnected .status-dot {
            background: #FF6B6B;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .last-update {
            color: rgba(255, 255, 255, 0.5);
            font-size: 12px;
            margin-top: 15px;
        }
        
        .api-card {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 16px;
            padding: 25px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .api-title {
            color: #fff;
            font-size: 16px;
            font-weight: 600;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .api-endpoint {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 10px;
            padding: 12px 15px;
            margin-bottom: 10px;
            border-left: 3px solid #4ECDC4;
        }
        
        .api-method {
            display: inline-block;
            background: #4ECDC4;
            color: #1a1a2e;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: 700;
            margin-right: 10px;
        }
        
        .api-url {
            color: #fff;
            font-family: 'Monaco', 'Consolas', monospace;
            font-size: 13px;
        }
        
        .api-desc {
            color: rgba(255, 255, 255, 0.5);
            font-size: 12px;
            margin-top: 5px;
            margin-left: 55px;
        }
        
        .refresh-info {
            color: rgba(255, 255, 255, 0.4);
            font-size: 12px;
            text-align: center;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="heart-rate-card">
            <div class="heart-icon">❤️</div>
            <div class="heart-rate-value">
                <span id="bpm">--</span>
                <span class="heart-rate-unit">BPM</span>
            </div>
            <div class="status-badge connected" id="statusBadge">
                <span class="status-dot"></span>
                <span id="statusText">已连接</span>
            </div>
            <div class="last-update" id="lastUpdate">最后更新: --</div>
        </div>
        
        <div class="api-card">
            <div class="api-title">📡 API 接口</div>
            <div class="api-endpoint">
                <span class="api-method">GET</span>
                <span class="api-url">/heartbeat</span>
                <div class="api-desc">返回纯文本心率值</div>
            </div>
            <div class="api-endpoint">
                <span class="api-method">GET</span>
                <span class="api-url">/heartbeat.json</span>
                <div class="api-desc">返回 JSON 格式数据</div>
            </div>
            <div class="api-endpoint" style="border-left-color: #FF6B6B;">
                <span class="api-method" style="background: #FF6B6B;">GET</span>
                <span class="api-url">/live</span>
                <div class="api-desc">直播专用页面（含多个预设）</div>
            </div>
        </div>
        
        <div class="refresh-info">每 0.5 秒自动刷新</div>
    </div>
    
    <script>
        function formatTime(timestamp) {
            const date = new Date(timestamp);
            return date.toLocaleTimeString('zh-CN', { 
                hour: '2-digit', 
                minute: '2-digit', 
                second: '2-digit' 
            });
        }
        
        function updateHeartRate() {
            fetch('/heartbeat.json')
                .then(response => response.json())
                .then(data => {
                    const bpmElement = document.getElementById('bpm');
                    const statusBadge = document.getElementById('statusBadge');
                    const statusText = document.getElementById('statusText');
                    const lastUpdate = document.getElementById('lastUpdate');
                    
                    if (data.bpm > 0) {
                        bpmElement.textContent = data.bpm;
                        bpmElement.style.color = '#FF6B6B';
                    } else {
                        bpmElement.textContent = '--';
                        bpmElement.style.color = 'rgba(255, 255, 255, 0.5)';
                    }
                    
                    statusBadge.className = 'status-badge connected';
                    statusText.textContent = '已连接';
                    
                    if (data.lastUpdate > 0) {
                        lastUpdate.textContent = '最后更新: ' + formatTime(data.lastUpdate);
                    }
                })
                .catch(error => {
                    console.error('获取心率数据失败:', error);
                    document.getElementById('bpm').textContent = '--';
                    document.getElementById('statusBadge').className = 'status-badge disconnected';
                    document.getElementById('statusText').textContent = '连接失败';
                });
        }
        
        updateHeartRate();
        setInterval(updateHeartRate, 500);
    </script>
</body>
</html>
                    """.trimIndent()
                    newFixedLengthResponse(
                        Response.Status.OK,
                        "text/html; charset=utf-8",
                        html
                    )
                }
                else -> {
                    newFixedLengthResponse(
                        Response.Status.NOT_FOUND,
                        "text/plain",
                        "Not Found"
                    )
                }
            }
        }
    }
}
