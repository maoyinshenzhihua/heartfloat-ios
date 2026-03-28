import UIKit
import AVKit
import AVFoundation

class MainViewController: UIViewController {
    
    private let heartRateLabel = UILabel()
    private let bpmLabel = UILabel()
    private let statusLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let pipButton = UIButton(type: .system)
    private let logTextView = UITextView()
    private let clearLogButton = UIButton(type: .system)
    private let copyLogButton = UIButton(type: .system)
    
    private var logText = ""
    private let maxLogLines = 200
    private let timeFormatter = DateFormatter()
    
    private var isConnected = false
    private var isConnecting = false
    
    private var pipController: AVPictureInPictureController?
    private var pipView: HeartRatePIPView?
    private var pipPlayer: AVPlayer?
    private var pipPlayerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        do {
            try setupPIP()
        } catch {
            appendLog("画中画初始化失败: \(error.localizedDescription)")
            pipButton.isEnabled = false
            pipButton.alpha = 0.5
        }
        BleService.shared.delegate = self
        BleService.shared.startService()
        appendLog("应用启动")
        appendLog("等待连接设备...")
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "心率监测"
        
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let heartRateContainer = UIView()
        heartRateContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heartRateContainer)
        
        heartRateLabel.font = .systemFont(ofSize: 72, weight: .bold)
        heartRateLabel.textColor = .systemRed
        heartRateLabel.text = "--"
        heartRateLabel.textAlignment = .center
        heartRateLabel.translatesAutoresizingMaskIntoConstraints = false
        heartRateContainer.addSubview(heartRateLabel)
        
        bpmLabel.font = .systemFont(ofSize: 24, weight: .medium)
        bpmLabel.textColor = .secondaryLabel
        bpmLabel.text = "BPM"
        bpmLabel.textAlignment = .center
        bpmLabel.translatesAutoresizingMaskIntoConstraints = false
        heartRateContainer.addSubview(bpmLabel)
        
        statusLabel.font = .systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "未连接"
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        connectButton.setTitle("连接", for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        connectButton.backgroundColor = .systemRed
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 12
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(connectButton)
        
        pipButton.setTitle("悬浮窗", for: .normal)
        pipButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        pipButton.backgroundColor = .systemBlue
        pipButton.setTitleColor(.white, for: .normal)
        pipButton.layer.cornerRadius = 12
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(pipButton)
        
        settingsButton.setTitle("设置", for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        settingsButton.backgroundColor = .systemGray
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.layer.cornerRadius = 12
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.addArrangedSubview(settingsButton)
        
        let logContainer = UIView()
        logContainer.backgroundColor = .secondarySystemBackground
        logContainer.layer.cornerRadius = 12
        logContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logContainer)
        
        let logTitleLabel = UILabel()
        logTitleLabel.text = "日志"
        logTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        logTitleLabel.textColor = .secondaryLabel
        logTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        logContainer.addSubview(logTitleLabel)
        
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = .clear
        logTextView.isEditable = false
        logTextView.isScrollEnabled = true
        logTextView.translatesAutoresizingMaskIntoConstraints = false
        logContainer.addSubview(logTextView)
        
        let logButtonStack = UIStackView()
        logButtonStack.axis = .horizontal
        logButtonStack.spacing = 8
        logButtonStack.translatesAutoresizingMaskIntoConstraints = false
        logContainer.addSubview(logButtonStack)
        
        clearLogButton.setTitle("清空", for: .normal)
        clearLogButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        clearLogButton.backgroundColor = .systemGray3
        clearLogButton.setTitleColor(.label, for: .normal)
        clearLogButton.layer.cornerRadius = 8
        clearLogButton.translatesAutoresizingMaskIntoConstraints = false
        logButtonStack.addArrangedSubview(clearLogButton)
        
        copyLogButton.setTitle("复制", for: .normal)
        copyLogButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        copyLogButton.backgroundColor = .systemGray3
        copyLogButton.setTitleColor(.label, for: .normal)
        copyLogButton.layer.cornerRadius = 8
        copyLogButton.translatesAutoresizingMaskIntoConstraints = false
        logButtonStack.addArrangedSubview(copyLogButton)
        
        NSLayoutConstraint.activate([
            heartRateContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            heartRateContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            heartRateLabel.topAnchor.constraint(equalTo: heartRateContainer.topAnchor),
            heartRateLabel.leadingAnchor.constraint(equalTo: heartRateContainer.leadingAnchor),
            heartRateLabel.trailingAnchor.constraint(equalTo: heartRateContainer.trailingAnchor),
            
            bpmLabel.topAnchor.constraint(equalTo: heartRateLabel.bottomAnchor, constant: 8),
            bpmLabel.leadingAnchor.constraint(equalTo: heartRateContainer.leadingAnchor),
            bpmLabel.trailingAnchor.constraint(equalTo: heartRateContainer.trailingAnchor),
            bpmLabel.bottomAnchor.constraint(equalTo: heartRateContainer.bottomAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: heartRateContainer.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            buttonStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            pipButton.heightAnchor.constraint(equalToConstant: 50),
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
            
            logContainer.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 24),
            logContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            logTitleLabel.topAnchor.constraint(equalTo: logContainer.topAnchor, constant: 12),
            logTitleLabel.leadingAnchor.constraint(equalTo: logContainer.leadingAnchor, constant: 12),
            
            logTextView.topAnchor.constraint(equalTo: logTitleLabel.bottomAnchor, constant: 8),
            logTextView.leadingAnchor.constraint(equalTo: logContainer.leadingAnchor, constant: 12),
            logTextView.trailingAnchor.constraint(equalTo: logContainer.trailingAnchor, constant: -12),
            logTextView.bottomAnchor.constraint(equalTo: logButtonStack.topAnchor, constant: -12),
            
            logButtonStack.trailingAnchor.constraint(equalTo: logContainer.trailingAnchor, constant: -12),
            logButtonStack.bottomAnchor.constraint(equalTo: logContainer.bottomAnchor, constant: -12),
            
            clearLogButton.widthAnchor.constraint(equalToConstant: 60),
            clearLogButton.heightAnchor.constraint(equalToConstant: 32),
            copyLogButton.widthAnchor.constraint(equalToConstant: 60),
            copyLogButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupActions() {
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        pipButton.addTarget(self, action: #selector(pipButtonTapped), for: .touchUpInside)
        clearLogButton.addTarget(self, action: #selector(clearLogButtonTapped), for: .touchUpInside)
        copyLogButton.addTarget(self, action: #selector(copyLogButtonTapped), for: .touchUpInside)
    }
    
    private func setupPIP() throws {
        if #available(iOS 15.0, *) {
            if AVPictureInPictureController.isPictureInPictureSupported() {
                let pipView = HeartRatePIPView()
                pipPlayerLayer = AVPlayerLayer(player: nil)
                pipPlayerLayer?.videoGravity = .resizeAspectFill
                pipPlayerLayer?.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                
                if let playerLayer = pipPlayerLayer {
                    pipController = AVPictureInPictureController(contentSource: .init(playerLayer: playerLayer))
                    pipController?.delegate = self
                    if #available(iOS 14.2, *) {
                        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
                    }
                    pipPlayer = AVPlayer()
                    pipPlayerLayer?.player = pipPlayer
                    
                    try generateSilentAudioForPIP()
                }
            } else {
                pipButton.isEnabled = false
                pipButton.alpha = 0.5
                appendLog("画中画不支持此设备")
            }
        } else {
            pipButton.isEnabled = false
            pipButton.alpha = 0.5
            appendLog("需要iOS 15.0或更高版本")
        }
    }
    
    private func generateSilentAudioForPIP() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try audioSession.setActive(true)
        
        let tempDir = FileManager.default.temporaryDirectory
        let silencePath = tempDir.appendingPathComponent("silence.mp3")
        
        if !FileManager.default.fileExists(atPath: silencePath.path) {
            let silentData = createSilentAudioData()
            try silentData.write(to: silencePath)
        }
        
        let playerItem = AVPlayerItem(url: silencePath)
        pipPlayer?.replaceCurrentItem(with: playerItem)
        pipPlayer?.play()
    }
    
    private func createSilentAudioData() -> Data {
        let sampleRate: Double = 44100
        let duration: Double = 1.0
        let numSamples = Int(sampleRate * duration)
        
        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        var fileSize = UInt32(36 + numSamples * 2)
        header.append(Data(bytes: &fileSize, count: 4))
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        header.append(contentsOf: [0x10, 0x00, 0x00, 0x00])
        header.append(contentsOf: [0x01, 0x00])
        header.append(contentsOf: [0x01, 0x00])
        var sampRate = UInt32(sampleRate)
        header.append(Data(bytes: &sampRate, count: 4))
        var byteRate = UInt32(sampleRate * 2)
        header.append(Data(bytes: &byteRate, count: 4))
        header.append(contentsOf: [0x02, 0x00])
        header.append(contentsOf: [0x10, 0x00])
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        var dataSize = UInt32(numSamples * 2)
        header.append(Data(bytes: &dataSize, count: 4))
        
        var audioData = header
        let silentSamples = Data(repeating: 0x00, count: numSamples * 2)
        audioData.append(silentSamples)
        
        return audioData
    }
    
    @objc private func connectButtonTapped() {
        if isConnecting {
            BleService.shared.stopScan()
            isConnecting = false
            updateConnectionState(.disconnected)
            appendLog("已取消连接")
        } else if isConnected {
            BleService.shared.disconnect()
        } else {
            BleService.shared.startScan()
        }
    }
    
    @objc private func settingsButtonTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    @objc private func pipButtonTapped() {
        guard let pipController = pipController else {
            appendLog("画中画不可用")
            return
        }
        
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
    }
    
    @objc private func clearLogButtonTapped() {
        logText = ""
        logTextView.text = ""
        appendLog("日志已清空")
    }
    
    @objc private func copyLogButtonTapped() {
        UIPasteboard.general.string = logText
        appendLog("日志已复制到剪贴板")
    }
    
    private func updateConnectionState(_ state: BleService.ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .disconnected:
                self.isConnected = false
                self.isConnecting = false
                self.statusLabel.text = "未连接"
                self.statusLabel.textColor = .secondaryLabel
                self.connectButton.setTitle("连接", for: .normal)
                self.connectButton.backgroundColor = .systemRed
            case .connecting:
                self.isConnecting = true
                self.statusLabel.text = "连接中..."
                self.statusLabel.textColor = .systemOrange
                self.connectButton.setTitle("取消", for: .normal)
                self.connectButton.backgroundColor = .systemOrange
            case .connected:
                self.isConnected = true
                self.isConnecting = false
                self.statusLabel.text = "已连接"
                self.statusLabel.textColor = .systemGreen
                self.connectButton.setTitle("断开", for: .normal)
                self.connectButton.backgroundColor = .systemGray
            }
        }
    }
    
    private func updateHeartRate(_ heartRate: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if heartRate > 0 {
                self.heartRateLabel.text = "\(heartRate)"
            } else {
                self.heartRateLabel.text = "--"
            }
        }
    }
    
    private func appendLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = self.timeFormatter.string(from: Date())
            let logLine = "[\(timestamp)] \(message)\n"
            
            self.logText += logLine
            
            let lines = self.logText.components(separatedBy: "\n")
            if lines.count > self.maxLogLines {
                self.logText = lines.suffix(self.maxLogLines).joined(separator: "\n")
            }
            
            self.logTextView.text = self.logText
            
            let range = NSRange(location: self.logTextView.text.count - 1, length: 1)
            self.logTextView.scrollRangeToVisible(range)
        }
    }
}

extension MainViewController: BleServiceDelegate {
    
    func bleServiceDidUpdateHeartRate(_ heartRate: Int) {
        updateHeartRate(heartRate)
        appendLog("心率: \(heartRate) BPM")
    }
    
    func bleServiceDidChangeState(_ state: BleService.ConnectionState) {
        updateConnectionState(state)
        switch state {
        case .connected:
            appendLog("已连接到设备")
        case .disconnected:
            appendLog("已断开连接")
        case .connecting:
            appendLog("正在连接...")
        }
    }
    
    func bleServiceDidLog(_ message: String) {
        appendLog(message)
    }
}

extension MainViewController: AVPictureInPictureControllerDelegate {
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        appendLog("画中画已启动")
        pipButton.setTitle("关闭悬浮", for: .normal)
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        appendLog("画中画已关闭")
        pipButton.setTitle("悬浮窗", for: .normal)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        appendLog("画中画启动失败: \(error.localizedDescription)")
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}

class HeartRatePIPView {
    private let containerView = UIView()
    private let heartRateLabel = UILabel()
    private let bpmLabel = UILabel()
    
    init() {
        setupView()
    }
    
    private func setupView() {
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        heartRateLabel.font = .systemFont(ofSize: 48, weight: .bold)
        heartRateLabel.textColor = .systemRed
        heartRateLabel.text = "--"
        stackView.addArrangedSubview(heartRateLabel)
        
        bpmLabel.font = .systemFont(ofSize: 16, weight: .medium)
        bpmLabel.textColor = .white
        bpmLabel.text = "BPM"
        stackView.addArrangedSubview(bpmLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func updateHeartRate(_ heartRate: Int) {
        DispatchQueue.main.async {
            self.heartRateLabel.text = heartRate > 0 ? "\(heartRate)" : "--"
        }
    }
}