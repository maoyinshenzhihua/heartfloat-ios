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
    private var cancellables = Set<AnyCancellable>()
    private var pipController: AVPictureInPictureController?
    private var pipPlayer: AVPlayer?
    private var pipPlayerLayer: AVPlayerLayer?
    private var pipPlayerView: UIView?
    private var pipOverlayView: UIView?
    private var pipStatusLabel: UILabel?
    private var pipSubLabel: UILabel?
    private var generatedVideoURL: URL?
    private var looper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var pipKvoObserver: NSKeyValueObservation?

    override init() {
        super.init()
        setupBindings()
        generateBlankVideo()
    }

    deinit {
        stopPip()
        pipKvoObserver?.invalidate()
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
        guard let url = generatedVideoURL else {
            addLog("视频资源未就绪，正在重新生成...")
            generateBlankVideo()
            return
        }
        addLog("视频已就绪: \(url.lastPathComponent)")
        setupPipPlayer(videoURL: url)
    }

    func stopPip() {
        pipKvoObserver?.invalidate()
        pipKvoObserver = nil

        isPipActive = false
        pipController?.delegate = nil
        pipController?.stopPictureInPicture()
        pipController = nil

        looper = nil
        queuePlayer?.pause()
        queuePlayer = nil
        pipPlayer = nil

        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil

        pipPlayerView?.removeFromSuperview()
        pipPlayerView = nil
        pipOverlayView?.removeFromSuperview()
        pipOverlayView = nil
        pipStatusLabel = nil
        pipSubLabel = nil

        addLog("画中画已关闭")
    }

    private func generateBlankVideo() {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("blank_pip_video.mp4")

        if FileManager.default.fileExists(atPath: url.path) {
            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attr?[.size] as? Int64 ?? 0
            if fileSize > 1000 {
                generatedVideoURL = url
                addLog("PiP 视频缓存已存在 (\(fileSize) bytes)")
                return
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let size = CGSize(width: 120, height: 120)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 50000,
                AVVideoMaxKeyFrameIntervalKey: 60
            ]
        ]

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            addLog("创建 AVAssetWriter 失败")
            return
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = 30
        var frameCount = 0

        while frameCount < totalFrames {
            guard input.isReadyForMoreMediaData else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            guard let pool = adaptor.pixelBufferPool else {
                addLog("无法获取 pixel buffer pool")
                return
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else {
                addLog("无法创建 pixel buffer (frame \(frameCount))")
                return
            }

            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            context?.setFillColor(UIColor.black.cgColor)
            context?.fill(CGRect(origin: .zero, size: size))
            CVPixelBufferUnlockBaseAddress(buffer, [])

            let presentationTime = CMTime(value: Int64(frameCount), timescale: 30)
            if !adaptor.append(buffer, withPresentationTime: presentationTime) {
                addLog("追加帧 \(frameCount) 失败")
                return
            }
            frameCount += 1
        }

        input.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting {
            sem.signal()
        }
        sem.wait()

        switch writer.status {
        case .completed:
            generatedVideoURL = url
            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attr?[.size] as? Int64 ?? 0
            addLog("PiP 视频生成成功 (\(totalFrames) 帧, \(fileSize) bytes)")
        case .failed:
            addLog("生成视频失败: \(writer.error?.localizedDescription ?? "未知错误")")
        default:
            addLog("生成视频状态异常: \(writer.status.rawValue)")
        }
    }

    private func setupPipPlayer(videoURL: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) else {
            addLog("无法获取窗口")
            return
        }

        addLog("获取到 keyWindow: \(keyWindow.bounds.size)")

        let playerItem = AVPlayerItem(url: videoURL)
        let qPlayer = AVQueuePlayer(playerItem: playerItem)
        qPlayer.isMuted = true
        qPlayer.preventsDisplaySleepDuringVideoPlayback = false
        qPlayer.allowsExternalPlayback = false

        let playerLooper = AVPlayerLooper(player: qPlayer, templateItem: playerItem)

        let layer = AVPlayerLayer(player: qPlayer)
        layer.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        layer.backgroundColor = UIColor.black.cgColor
        layer.videoGravity = .resizeAspectFill

        let playerContainer = UIView(frame: CGRect(x: keyWindow.bounds.midX - 20, y: keyWindow.bounds.midY - 20, width: 40, height: 40))
        playerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.01)
        playerContainer.clipsToBounds = true
        playerContainer.layer.addSublayer(layer)
        playerContainer.accessibilityLabel = "pip_player"
        keyWindow.addSubview(playerContainer)

        addLog("Player 已添加到窗口中心, 开始播放...")

        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self

        pipPlayer = qPlayer
        looper = playerLooper
        queuePlayer = qPlayer
        pipPlayerLayer = layer
        pipPlayerView = playerContainer
        pipController = controller

        qPlayer.play()

        pipKvoObserver = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, change in
            guard let self = self, let possible = change.newValue, possible else { return }
            if possible && self.pipController != nil {
                self.addLog("PiP 已就绪! 正在启动...")
                self.pipController?.startPictureInPicture()
                self.hidePlayerContainer()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, self.pipController != nil else { return }
            if !self.isPipActive {
                self.addLog("PiP 超时未就绪, 当前状态:")
                self.addLog("  isPictureInPicturePossible: \(self.pipController?.isPictureInPicturePossible ?? false)")
                self.addLog("  player.timeControlStatus: \(self.pipPlayer?.timeControlStatus.rawValue ?? -1)")
                self.addLog("  player.currentItem: \(self.pipPlayer?.currentItem != nil ? "有" : "无")")
                self.cleanupPipResources()
            }
        }
    }

    private func hidePlayerContainer() {
        pipPlayerView?.alpha = 0
        pipPlayerView?.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
    }

    private func updatePipContent() {
        pipStatusLabel?.text = heartRate > 0 ? "\(heartRate)" : "--"
    }

    private func cleanupPipResources() {
        pipKvoObserver?.invalidate()
        pipKvoObserver = nil
        looper = nil
        queuePlayer?.pause()
        queuePlayer = nil
        pipPlayer = nil
        pipPlayerLayer?.removeFromSuperlayer()
        pipPlayerLayer = nil
        pipPlayerView?.removeFromSuperview()
        pipPlayerView = nil
        pipOverlayView?.removeFromSuperview()
        pipOverlayView = nil
        pipStatusLabel = nil
        pipSubLabel = nil
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
        isPipActive = true
        hidePlayerContainer()
        addLog("画中画已启动 ✅")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        cleanupPipResources()
        addLog("画中画已停止")
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        addLog("画中画启动失败: \(error.localizedDescription)")
        cleanupPipResources()
    }
}
