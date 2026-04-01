import Foundation
import Combine
import AVKit
import AVFoundation

class HeartRateViewModel: ObservableObject {
    @Published var heartRate: Int = 0
    @Published var connectionState: BleService.ConnectionState = .disconnected
    @Published var isContact: Bool = false
    @Published var logMessages: [String] = []
    @Published var isPipActive: Bool = false
    @Published var isLogPaused: Bool = false
    var pausedLogSnapshot: String?

    private let bleService = BleService.shared
    private let httpServer = HttpServerManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var pipController: AVPictureInPictureController?
    private var pipPlayer: AVPlayer?
    private var pipPlayerLayer: AVPlayerLayer?
    private var pipWindow: UIWindow?
    private var pipContentView: UIView?

    init() {
        setupBindings()
    }

    private func setupBindings() {
        bleService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.heartRate = rate
                self?.httpServer.updateHeartRate(rate, contact: self?.isContact ?? false)
                if self?.isPipActive == true {
                    self?.updatePipContent()
                }
            }
            .store(in: &cancellables)

        bleService.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        bleService.$isContact
            .receive(on: DispatchQueue.main)
            .assign(to: &$isContact)

        bleService.$logMessages
            .receive(on: DispatchQueue.main)
            .assign(to: &$logMessages)
    }

    func connect() {
        bleService.startScan()
    }

    func disconnect() {
        bleService.disconnect()
    }

    func togglePip() {
        if isPipActive {
            stopPip()
        } else {
            startPip()
        }
    }

    func startPip() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            addLog("设备不支持画中画")
            return
        }
        guard connectionState == .connected else {
            addLog("请先连接手环")
            return
        }

        setupPipPlayer()
        addLog("画中画已启动")
    }

    func stopPip() {
        isPipActive = false
        pipController?.delegate = nil
        pipController?.stopPictureInPicture()
        pipController = nil

        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil

        pipContentView?.removeFromSuperview()
        pipContentView = nil

        if let window = pipWindow {
            window.isHidden = true
            window.resignKey()
            pipWindow = nil
        }

        addLog("画中画已关闭")
    }

    private func setupPipPlayer() {
        let playerItem = AVPlayerItem(url: URL(fileURLWithPath: "/dev/null"))
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        playerLayer.backgroundColor = UIColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect

        let pipWindow = UIWindow(windowScene: UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first ?? UIApplication.shared.windows.first?.windowScene)
        pipWindow.windowLevel = .statusBar + 1
        pipWindow.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        pipWindow.backgroundColor = .clear
        pipWindow.clipsToBounds = true
        pipWindow.layer.cornerRadius = 20
        pipWindow.isHidden = false

        let contentView = UIView(frame: pipWindow.bounds)
        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        contentView.layer.cornerRadius = 20
        contentView.clipsToBounds = true
        pipWindow.addSubview(contentView)
        pipWindow.layer.addSublayer(playerLayer)

        let label = UILabel(frame: CGRect(x: 0, y: 30, width: 120, height: 40))
        label.text = "\(heartRate)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.tag = 1001
        contentView.addSubview(label)

        let subLabel = UILabel(frame: CGRect(x: 0, y: 68, width: 120, height: 16))
        subLabel.text = "BPM"
        subLabel.textColor = .white.withAlphaComponent(0.7)
        subLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subLabel.textAlignment = .center
        subLabel.tag = 1002
        contentView.addSubview(subLabel)

        let controller = AVPictureInPictureController(playerLayer: playerLayer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self

        pipPlayer = player
        pipPlayerLayer = playerLayer
        pipWindow.isHidden = true
        pipWindow = pipWindow
        pipContentView = contentView
        pipController = controller

        player.play()
        if controller?.isPictureInPicturePossible == true {
            controller?.startPictureInPicture()
            isPipActive = true
        } else {
            addLog("画中画暂不可用，请稍后再试")
            cleanupPipResources()
        }
    }

    private func updatePipContent() {
        guard let view = pipContentView else { return }
        if let label = view.viewWithTag(1001) as? UILabel {
            label.text = "\(heartRate > 0 ? heartRate : "--")"
        }
    }

    private func cleanupPipResources() {
        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil
        pipContentView?.removeFromSuperview()
        pipContentView = nil
        if let window = pipWindow {
            window.isHidden = true
            window.resignKey()
            pipWindow = nil
        }
        pipController = nil
        isPipActive = false
    }

    func clearLogs() {
        logMessages.removeAll()
        addLog("日志已清空")
    }

    func copyLogs() {
        let logText = logMessages.joined(separator: "\n")
        UIPasteboard.general.string = logText
        addLog("日志已复制到剪贴板")
    }

    func toggleLogPause() {
        if isLogPaused {
            isLogPaused = false
            pausedLogSnapshot = nil
            addLog("日志已恢复")
        } else {
            isLogPaused = true
            pausedLogSnapshot = logMessages.suffix(100).joined(separator: "\n")
            addLog("日志已暂停")
        }
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logMessages.append("[\(timestamp)] \(message)")
        if logMessages.count > 200 {
            logMessages.removeFirst()
        }
    }

    func startHttpServer(port: Int) {
        if httpServer.startServer(port: port) {
            addLog("HTTP服务已启动，端口: \(port)")
        } else {
            addLog("HTTP服务启动失败")
        }
    }

    func stopHttpServer() {
        httpServer.stopServer()
        addLog("HTTP服务已停止")
    }
}

extension HeartRateViewModel: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipWindow?.isHidden = true
        isPipActive = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        cleanupPipResources()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        addLog("画中画启动失败: \(error.localizedDescription)")
        cleanupPipResources()
    }

    deinit {
        stopPip()
    }
}
