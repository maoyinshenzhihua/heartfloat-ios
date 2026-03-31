import Foundation
import GCDWebServer

class HttpServerManager: ObservableObject {
    static let shared = HttpServerManager()

    @Published var isRunning: Bool = false
    @Published var currentPort: Int = 8080
    @Published var localIP: String?

    private var webServer: GCDWebServer?

    private var currentHeartRate: Int = 0
    private var isContact: Bool = false
    private var lastUpdateTime: Date = Date()

    func updateHeartRate(_ heartRate: Int, contact: Bool = true) {
        currentHeartRate = heartRate
        isContact = contact
        lastUpdateTime = Date()
    }

    func getHeartRateData() -> HeartRateData {
        return HeartRateData(
            bpm: currentHeartRate,
            isContact: isContact,
            lastUpdate: lastUpdateTime.timeIntervalSince1970 * 1000
        )
    }

    func startServer(port: Int) -> Bool {
        if isRunning {
            return true
        }

        webServer = GCDWebServer()

        webServer?.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
            return self?.handleRequest(request) ?? GCDWebServerResponse(statusCode: 404)
        }

        do {
            try webServer?.start(options: [
                GCDWebServerOption_Port: port,
                GCDWebServerOption_BonjourName: "HeartFloat"
            ])

            isRunning = true
            currentPort = port
            localIP = getLocalIPAddress()
            return true
        } catch {
            isRunning = false
            return false
        }
    }

    func stopServer() {
        webServer?.stop()
        webServer = nil
        isRunning = false
        localIP = nil
    }

    private func handleRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse? {
        switch request.path {
        case "/heartbeat":
            return GCDWebServerDataResponse(text: "\(currentHeartRate)")

        case "/heartbeat.json":
            let data = getHeartRateData()
            let json: [String: Any] = [
                "bpm": data.bpm,
                "isContact": data.isContact,
                "lastUpdate": data.lastUpdate,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: json),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return GCDWebServerDataResponse(text: jsonString, contentType: "application/json")
            }
            return GCDWebServerResponse(statusCode: 500)

        case "/live":
            return GCDWebServerDataResponse(html: livePageHTML())

        case "/":
            return GCDWebServerDataResponse(html: indexPageHTML())

        default:
            return GCDWebServerResponse(statusCode: 404)
        }
    }

    private func indexPageHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>心率监测服务</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%);
                    min-height: 100vh;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 20px;
                }
                .container { max-width: 500px; width: 100%; }
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
                    background: rgba(78, 205, 196, 0.2);
                    color: #4ECDC4;
                }
                .status-dot {
                    width: 8px;
                    height: 8px;
                    border-radius: 50%;
                    background: #4ECDC4;
                    animation: pulse 1.5s ease-in-out infinite;
                }
                @keyframes pulse {
                    0%, 100% { opacity: 1; }
                    50% { opacity: 0.5; }
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
                    font-family: monospace;
                    font-size: 13px;
                }
                .api-desc {
                    color: rgba(255, 255, 255, 0.5);
                    font-size: 12px;
                    margin-top: 5px;
                    margin-left: 55px;
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
                    <div class="status-badge">
                        <span class="status-dot"></span>
                        <span id="statusText">等待数据</span>
                    </div>
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
                        <div class="api-desc">直播专用页面</div>
                    </div>
                </div>
            </div>
            <script>
                function updateHeartRate() {
                    fetch('/heartbeat.json')
                        .then(r => r.json())
                        .then(data => {
                            document.getElementById('bpm').textContent = data.bpm > 0 ? data.bpm : '--';
                            document.getElementById('statusText').textContent = data.bpm > 0 ? '已连接' : '等待数据';
                        })
                        .catch(() => {});
                }
                updateHeartRate();
                setInterval(updateHeartRate, 500);
            </script>
        </body>
        </html>
        """
    }

    private func livePageHTML() -> String {
        return """
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
                }
                .display-container {
                    display: flex;
                    align-items: center;
                    gap: 15px;
                    padding: 20px 30px;
                    background: rgba(0, 0, 0, 0.6);
                    border-radius: 50px;
                    backdrop-filter: blur(10px);
                }
                .heart-icon {
                    font-size: 48px;
                    animation: heartbeat 1s ease-in-out infinite;
                    filter: drop-shadow(0 0 10px rgba(255, 107, 107, 0.8));
                }
                @keyframes heartbeat {
                    0%, 100% { transform: scale(1); }
                    25% { transform: scale(1.2); }
                    50% { transform: scale(1); }
                }
                .heart-rate-value {
                    font-size: 72px;
                    font-weight: 800;
                    color: #FF6B6B;
                    text-shadow: 0 0 20px rgba(255, 107, 107, 0.6);
                    min-width: 120px;
                    text-align: center;
                }
                .heart-rate-unit {
                    font-size: 28px;
                    font-weight: 600;
                    color: rgba(255, 255, 255, 0.9);
                }
            </style>
        </head>
        <body>
            <div class="display-container">
                <span class="heart-icon" id="heart">❤️</span>
                <span class="heart-rate-value" id="bpm">--</span>
                <span class="heart-rate-unit">BPM</span>
            </div>
            <script>
                function updateHeartbeatSpeed(bpm) {
                    if (bpm > 0) {
                        var duration = 60 / bpm;
                        document.getElementById('heart').style.animationDuration = duration + 's';
                    }
                }
                function updateHeartRate() {
                    fetch('/heartbeat.json')
                        .then(r => r.json())
                        .then(data => {
                            if (data.bpm > 0) {
                                document.getElementById('bpm').textContent = data.bpm;
                                updateHeartbeatSpeed(data.bpm);
                            } else {
                                document.getElementById('bpm').textContent = '--';
                            }
                        })
                        .catch(() => {});
                }
                updateHeartRate();
                setInterval(updateHeartRate, 500);
            </script>
        </body>
        </html>
        """
    }

    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        return address
    }

    struct HeartRateData {
        let bpm: Int
        let isContact: Bool
        let lastUpdate: Double
    }
}
