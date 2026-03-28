import Foundation

class HttpServerManager {
    
    static let shared = HttpServerManager()
    
    private var server: HttpServer?
    private(set) var isRunning = false
    private(set) var currentPort: Int = 8080
    
    private var currentHeartRate: Int = 0
    private var isContact: Bool = false
    private var lastUpdateTime: TimeInterval = 0
    
    private init() {}
    
    func updateHeartRate(_ heartRate: Int, contact: Bool = true) {
        synchronized(self) {
            currentHeartRate = heartRate
            isContact = contact
            lastUpdateTime = Date().timeIntervalSince1970
        }
    }
    
    func getHeartRateData() -> HeartRateData {
        synchronized(self) {
            return HeartRateData(
                bpm: currentHeartRate,
                isContact: isContact,
                lastUpdate: lastUpdateTime,
                timestamp: Date().timeIntervalSince1970
            )
        }
    }
    
    func startServer(port: Int) -> Bool {
        if isRunning {
            print("[HttpServerManager] 服务器已在运行")
            return true
        }
        
        do {
            currentPort = port
            server = HttpServer(port: port, delegate: self)
            try server?.start()
            isRunning = true
            print("[HttpServerManager] 服务器已启动，端口: \(port)")
            return true
        } catch {
            print("[HttpServerManager] 服务器启动失败: \(error)")
            isRunning = false
            return false
        }
    }
    
    func stopServer() {
        server?.stop()
        server = nil
        isRunning = false
        print("[HttpServerManager] 服务器已停止")
    }
    
    func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    private func synchronized<T>(_ lock: AnyObject, _ block: () -> T) -> T {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }
        return block()
    }
}

extension HttpServerManager: HttpServerDelegate {
    
    func handleRequest(path: String, method: String) -> HttpResponse {
        switch path {
        case "/heartbeat":
            let data = getHeartRateData()
            return .ok(.text("\(data.bpm)"))
            
        case "/heartbeat.json":
            let data = getHeartRateData()
            do {
                let jsonData = try JSONEncoder().encode(data)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    return .ok(.json(jsonString))
                }
                return .internalServerError
            } catch {
                return .internalServerError
            }
            
        case "/live":
            let html = getLivePageHTML()
            return .ok(.html(html))
            
        case "/":
            let html = getIndexPageHTML()
            return .ok(.html(html))
            
        default:
            return .notFound
        }
    }
    
    private func getLivePageHTML() -> String {
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
                @keyframes heartbeat {
                    0%, 100% { transform: scale(1); }
                    25% { transform: scale(1.2); }
                    50% { transform: scale(1); }
                }
            </style>
        </head>
        <body>
            <div class="display-container">
                <span class="heart-icon">❤️</span>
                <span class="heart-rate-value" id="bpm">--</span>
                <span class="heart-rate-unit">BPM</span>
            </div>
            <script>
                var currentBpm = 0;
                function updateHeartRate() {
                    fetch('/heartbeat.json')
                        .then(function(r) { return r.json(); })
                        .then(function(data) {
                            var el = document.getElementById('bpm');
                            if (data.bpm > 0) {
                                el.textContent = data.bpm;
                                if (data.bpm !== currentBpm) {
                                    currentBpm = data.bpm;
                                    var duration = 60 / data.bpm;
                                    document.querySelector('.heart-icon').style.animationDuration = duration + 's';
                                }
                            } else {
                                el.textContent = '--';
                            }
                        })
                        .catch(function() {});
                }
                setInterval(updateHeartRate, 500);
                updateHeartRate();
            </script>
        </body>
        </html>
        """
    }
    
    private func getIndexPageHTML() -> String {
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
                }
                .api-card {
                    background: rgba(255, 255, 255, 0.05);
                    border-radius: 16px;
                    padding: 25px;
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
                        .then(response => response.json())
                        .then(data => {
                            const el = document.getElementById('bpm');
                            el.textContent = data.bpm > 0 ? data.bpm : '--';
                        })
                        .catch(() => {});
                }
                setInterval(updateHeartRate, 500);
                updateHeartRate();
            </script>
        </body>
        </html>
        """
    }
}

enum HttpResponse {
    case ok(HttpContent)
    case notFound
    case internalServerError
    
    var statusCode: Int {
        switch self {
        case .ok: return 200
        case .notFound: return 404
        case .internalServerError: return 500
        }
    }
    
    var body: String {
        switch self {
        case .ok(let content): return content.content
        case .notFound: return "未找到"
        case .internalServerError: return "服务器内部错误"
        }
    }
    
    var contentType: String {
        switch self {
        case .ok(let content): return content.contentType
        case .notFound: return "text/plain"
        case .internalServerError: return "text/plain"
        }
    }
}

enum HttpContent {
    case text(String)
    case json(String)
    case html(String)
    
    var content: String {
        switch self {
        case .text(let s), .json(let s), .html(let s): return s
        }
    }
    
    var contentType: String {
        switch self {
        case .text: return "text/plain"
        case .json: return "application/json"
        case .html: return "text/html; charset=utf-8"
        }
    }
}

protocol HttpServerDelegate: AnyObject {
    func handleRequest(path: String, method: String) -> HttpResponse
}

class HttpServer {
    private let port: Int
    private weak var delegate: HttpServerDelegate?
    private var listener: URLSessionStreamTask?
    private var isListening = false
    
    init(port: Int, delegate: HttpServerDelegate) {
        self.port = port
        self.delegate = delegate
    }
    
    func start() throws {
        isListening = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.listen()
        }
    }
    
    func stop() {
        isListening = false
        listener?.cancel()
        listener = nil
    }
    
    private func listen() {
        let socket = socket(AF_INET, SOCK_STREAM, 0)
        if socket < 0 {
            print("创建套接字失败")
            return
        }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.bind(socket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        if bindResult < 0 {
            print("绑定套接字失败")
            close(socket)
            return
        }
        
        Darwin.listen(socket, 5)
        
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        while isListening {
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    Darwin.accept(socket, sockPtr, &clientAddrLen)
                }
            }
            
            if clientSocket >= 0 {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.handleClient(socket: clientSocket)
                }
            }
        }
        
        close(socket)
    }
    
    private func handleClient(socket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(socket, &buffer, buffer.count, 0)
        
        if bytesRead > 0 {
            let requestString = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
            let lines = requestString.components(separatedBy: "\r\n")
            
            var path = "/"
            var method = "GET"
            
            if let firstLine = lines.first {
                let parts = firstLine.components(separatedBy: " ")
                if parts.count >= 2 {
                    method = parts[0]
                    if let urlComponents = URLComponents(string: parts[1]) {
                        path = urlComponents.path
                    }
                }
            }
            
            let response = delegate?.handleRequest(path: path, method: method) ?? .notFound
            
            let httpResponse = "HTTP/1.1 \(response.statusCode) OK\r\n" +
                "Content-Type: \(response.contentType)\r\n" +
                "Content-Length: \(response.body.utf8.count)\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "\r\n" + response.body
            
            if let data = httpResponse.data(using: .utf8) {
                send(socket, data.bytes, data.count, 0)
            }
        }
        
        close(socket)
    }
}
