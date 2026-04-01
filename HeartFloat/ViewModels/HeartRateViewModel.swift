import Foundation
import Combine
import UIKit
import AVKit
import AVFoundation

class HeartRateViewModel: NSObject, ObservableObject {
    @Published var heartRate: Int = 0
    @Published var connectionState: BleService.ConnectionState = .disconnected
    @Published var isContact: Bool = false
    @Published var logMessages: [String] = []
    @Published var isPipActive: Bool = false
    @Published var isLogPaused: Bool = false
    var pausedLogSnapshot: String?

    private let bleService = BleService.shared
    private let httpServer = HttpServerManager.shared
    private let settings = SettingsManager.shared
    private let renderer = HeartRateVideoRenderer.shared
    private var cancellables = Set<AnyCancellable>()
    private var settingsCancellable: AnyCancellable?
    private var pipController: AVPictureInPictureController?
    private var pipPlayer: AVQueuePlayer?
    private var pipPlayerLayer: AVPlayerLayer?
    private var pipPlayerView: UIView?
    private var pipKvoObserver: NSKeyValueObservation?
    private var pipTimeObserver: Any?
    private var pipLooper: AVPlayerLooper?
    private var lastRenderedHeartRate: Int = -1
    private var lastRenderedSettingsHash: Int = 0
    private var pendingRefreshWorkItem: DispatchWorkItem?
    private var isRefreshingVideo = false
    private var userRequestedStop = false

    override init() {
        super.init()
        setupBindings()
        observeSettingsChanges()
    }

    deinit {
        userRequestedStop = true
        stopPip()
        pipKvoObserver?.invalidate()
        settingsCancellable?.cancel()
        if let obs = pipTimeObserver { pipPlayer?.removeTimeObserver(obs) }
    }

    private func setupBindings() {
        bleService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.heartRate = rate
                self?.httpServer.updateHeartRate(rate, contact: self?.isContact ?? false)
                if self?.isPipActive == true {
                    self?.schedulePipRefresh(heartRate: rate)
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

    private func observeSettingsChanges() {
        settingsCancellable = settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isPipActive else { return }
                self.schedulePipRefresh(heartRate: self.heartRate)
            }
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

        addLog("正在生成心率视频...")
        isRefreshingVideo = true
        userRequestedStop = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let url = self.renderer.generateVideo(
                heartRate: self.heartRate,
                settings: self.settings
            ) else {
                DispatchQueue.main.async {
                    self.addLog("视频生成失败")
                    self.isRefreshingVideo = false
                }
                return
            }

            self.lastRenderedHeartRate = self.heartRate
            self.lastRenderedSettingsHash = self.settingsHash()

            DispatchQueue.main.async {
                self.isRefreshingVideo = false
                self.setupPipPlayer(videoURL: url)
            }
        }
    }

    func stopPip() {
        userRequestedStop = true
        pendingRefreshWorkItem?.cancel()
        pendingRefreshWorkItem = nil
        pipKvoObserver?.invalidate()
        pipKvoObserver = nil

        isPipActive = false
        pipController?.delegate = nil
        pipController?.stopPictureInPicture()
        pipController = nil

        if let obs = pipTimeObserver { pipPlayer?.removeTimeObserver(obs) }
        pipTimeObserver = nil
        pipLooper = nil
        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil
        pipPlayerView?.removeFromSuperview()
        pipPlayerView = nil

        restoreAudioSession()
        addLog("画中画已关闭")
    }

    private func schedulePipRefresh(heartRate: Int) {
        if heartRate == lastRenderedHeartRate && settingsHash() == lastRenderedSettingsHash { return }
        if isRefreshingVideo { return }

        pendingRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshPipVideo(heartRate: heartRate)
        }
        pendingRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func refreshPipVideo(heartRate: Int) {
        guard isPipActive else { return }
        isRefreshingVideo = true

        addLog("更新心率视频...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let url = self.renderer.generateVideo(
                heartRate: heartRate,
                settings: self.settings
            ) else {
                DispatchQueue.main.async {
                    self.addLog("视频更新失败")
                    self.isRefreshingVideo = false
                }
                return
            }

            self.lastRenderedHeartRate = heartRate
            self.lastRenderedSettingsHash = self.settingsHash()

            DispatchQueue.main.async {
                self.isRefreshingVideo = false
                self.replacePlayerItem(url: url)
                self.addLog("心率视频已更新")
            }
        }
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            addLog("Audio Session 已配置为 Playback 模式")
        } catch {
            addLog("Audio Session 配置失败: \(error.localizedDescription)")
        }
    }

    private func restoreAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // ignore
        }
    }

    private func setupPipPlayer(videoURL: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) else {
            addLog("无法获取窗口")
            return
        }

        configureAudioSession()

        addLog("PiP 视频就绪，启动播放器...")

        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let qPlayer = AVQueuePlayer(playerItem: playerItem)
        qPlayer.isMuted = true
        qPlayer.preventsDisplaySleepDuringVideoPlayback = false
        qPlayer.allowsExternalPlayback = false

        let looper = AVPlayerLooper(player: qPlayer, templateItem: playerItem)
        pipLooper = looper

        let layer = AVPlayerLayer(player: qPlayer)
        layer.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        layer.backgroundColor = UIColor.black.cgColor
        layer.videoGravity = .resizeAspectFill

        let container = UIView(frame: CGRect(x: keyWindow.bounds.midX - 40, y: keyWindow.bounds.midY - 40, width: 80, height: 80))
        container.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        container.clipsToBounds = true
        container.layer.cornerRadius = 8
        container.layer.addSublayer(layer)
        keyWindow.addSubview(container)

        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self

        pipPlayer = qPlayer
        pipPlayerLayer = layer
        pipPlayerView = container
        pipController = controller

        qPlayer.play()

        var checkCount = 0
        let maxChecks = 20
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.pipController != nil else {
                timer.invalidate()
                return
            }
            checkCount += 1
            let possible = self.pipController?.isPictureInPicturePossible ?? false
            let status = self.pipPlayer?.timeControlStatus.rawValue ?? -1

            if checkCount <= 3 || checkCount % 3 == 0 {
                self.addLog("PiP 检查 \(checkCount): possible=\(possible), playerStatus=\(status)")
            }

            if possible && !self.isPipActive && !self.userRequestedStop {
                timer.invalidate()
                self.addLog("PiP 就绪! 启动中...")
                self.pipController?.startPictureInPicture()
            } else if checkCount >= maxChecks {
                timer.invalidate()
                let item = self.pipPlayer?.currentItem
                let loaded = item?.status.rawValue ?? -1
                let duration = item?.duration.seconds ?? 0
                self.addLog("PiP 超时 (\(maxChecks)次检查)")
                self.addLog("  isPossible: \(self.pipController?.isPictureInPicturePossible ?? false)")
                self.addLog("  playerStatus: \(self.pipPlayer?.timeControlStatus.rawValue ?? -1)")
                self.addLog("  itemStatus: \(loaded), duration: \(duration)s")
                self.cleanupPipResources()
            }
        }
    }

    private func replacePlayerItem(url: URL) {
        let newItem = AVPlayerItem(url: url)
        pipPlayer?.replaceCurrentItem(with: newItem)
        pipLooper = AVPlayerLooper(player: pipPlayer!, templateItem: newItem)
    }

    private func cleanupPipResources() {
        if let obs = pipTimeObserver { pipPlayer?.removeTimeObserver(obs) }
        pipTimeObserver = nil
        pipKvoObserver?.invalidate()
        pipKvoObserver = nil
        pipLooper = nil
        pipPlayer?.pause()
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil
        pipPlayerView?.removeFromSuperview()
        pipPlayerView = nil
        pipController = nil
        isPipActive = false
        restoreAudioSession()
    }

    private func settingsHash() -> Int {
        var hasher = Hasher()
        hasher.combine(settings.bpmNumberSize)
        hasher.combine(settings.bpmNumberColorHex)
        hasher.combine(settings.bpmLabelSize)
        hasher.combine(settings.bpmLabelColorHex)
        hasher.combine(settings.bpmPosition)
        hasher.combine(settings.backgroundOpacity)
        return hasher.finalize()
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
        hidePlayerContainer()
        isPipActive = true
        addLog("画中画已启动 ✅")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        if userRequestedStop {
            addLog("用户关闭了画中画")
            return
        }
        isPipActive = false
        addLog("系统暂停了画中画（非用户操作），播放器保持运行中")
        showPlayerContainer()
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        addLog("画中画启动失败: \(error.localizedDescription)")
        cleanupPipResources()
    }

    private func hidePlayerContainer() {
        pipPlayerView?.alpha = 0
        pipPlayerView?.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
    }

    private func showPlayerContainer() {
        guard let view = pipPlayerView, let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first(where: { $0.isKeyWindow }) else { return }
        view.alpha = 1
        view.frame = CGRect(x: window.bounds.midX - 40, y: window.bounds.midY - 40, width: 80, height: 80)
        window.addSubview(view)
        window.bringSubviewToFront(view)
    }
}
