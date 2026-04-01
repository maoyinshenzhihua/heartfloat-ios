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

    override init() {
        super.init()
        setupBindings()
        generateBlankVideo()
    }

    deinit {
        stopPip()
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
        guard let videoURL = generatedVideoURL else {
            addLog("视频资源未就绪")
            return
        }

        setupPipPlayer(videoURL: videoURL)
    }

    func stopPip() {
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
            generatedVideoURL = url
            return
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

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
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

        let frameCount = 0
        let totalFrames = 30

        func appendFrame() {
            guard input.isReadyForMoreMediaData, frameCount < totalFrames else {
                if frameCount >= totalFrames {
                    input.markAsFinished()
                    writer.finishWriting { [weak self] in
                        switch writer.status {
                        case .completed:
                            self?.generatedVideoURL = url
                        case .failed:
                            self?.addLog("生成视频失败: \(writer.error?.localizedDescription ?? "未知错误")")
                        default:
                            break
                        }
                    }
                }
                return
            }

            guard let pool = adaptor.pixelBufferPool else { return }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else { return }

            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.height),
                height: Int(size.width),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            context?.setFillColor(UIColor.black.cgColor)
            context?.fill(CGRect(origin: .zero, size: size))
            CVPixelBufferUnlockBaseAddress(buffer, [])

            let presentationTime = CMTime(value: Int64(frameCount), timescale: 30)
            adaptor.append(buffer, withPresentationTime: presentationTime)
            frameCount += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { appendFrame() }
        }

        appendFrame()
    }

    private func setupPipPlayer(videoURL: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) else {
            addLog("无法获取窗口")
            return
        }

        let playerItem = AVPlayerItem(url: videoURL)
        let qPlayer = AVQueuePlayer(playerItem: playerItem)
        qPlayer.isMuted = true
        qPlayer.preventsDisplaySleepDuringVideoPlayback = false

        let playerLooper = AVPlayerLooper(player: qPlayer, templateItem: playerItem)

        let layer = AVPlayerLayer(player: qPlayer)
        layer.frame = CGRect(x: 0, y: 0, width: 4, height: 4)
        layer.backgroundColor = UIColor.black.cgColor
        layer.videoGravity = .resizeAspectFill
        layer.zPosition = -1

        let playerContainer = UIView(frame: CGRect(x: keyWindow.bounds.width - 8, y: keyWindow.bounds.height - 8, width: 4, height: 4))
        playerContainer.backgroundColor = .clear
        playerContainer.clipsToBounds = true
        playerContainer.layer.addSublayer(layer)
        keyWindow.addSubview(playerContainer)

        let overlay = UIView(frame: CGRect(x: 20, y: 80, width: 120, height: 120))
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        overlay.layer.cornerRadius = 24
        overlay.clipsToBounds = true
        overlay.alpha = 0
        keyWindow.addSubview(overlay)

        let statusLabel = UILabel(frame: CGRect(x: 0, y: 28, width: 120, height: 44))
        statusLabel.text = "\(heartRate)"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 36, weight: .bold)
        statusLabel.textAlignment = .center
        overlay.addSubview(statusLabel)

        let subLabel = UILabel(frame: CGRect(x: 0, y: 72, width: 120, height: 16))
        subLabel.text = "BPM"
        subLabel.textColor = .white.withAlphaComponent(0.7)
        subLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subLabel.textAlignment = .center
        overlay.addSubview(subLabel)

        let controller = AVPictureInPictureController(playerLayer: layer)
        controller?.canStartPictureInPictureAutomaticallyFromInline = true
        controller?.delegate = self

        pipPlayer = qPlayer
        looper = playerLooper
        queuePlayer = qPlayer
        pipPlayerLayer = layer
        pipPlayerView = playerContainer
        pipOverlayView = overlay
        pipStatusLabel = statusLabel
        pipSubLabel = subLabel
        pipController = controller

        qPlayer.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.pipController?.isPictureInPicturePossible == true {
                self.pipController?.startPictureInPicture()
                self.addLog("正在启动画中画...")
            } else {
                self.addLog("画中画暂不可用，请确保应用在后台运行")
                self.cleanupPipResources()
            }
        }
    }

    private func updatePipContent() {
        pipStatusLabel?.text = heartRate > 0 ? "\(heartRate)" : "--"
    }

    private func cleanupPipResources() {
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
        pipPlayerView?.alpha = 0
        pipOverlayView?.alpha = 0
        isPipActive = true
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
