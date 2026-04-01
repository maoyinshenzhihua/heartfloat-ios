import Foundation
import UIKit
import AVFoundation

class HeartRateVideoRenderer {

    static let shared = HeartRateVideoRenderer()

    private let videoSize = CGSize(width: 240, height: 160)
    private let frameRate: Int32 = 15
    private var currentURL: URL?
    private var isGenerating = false

    func generateVideo(heartRate: Int, settings: SettingsManager) -> URL? {
        if isGenerating { return currentURL }

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pip_hr_\(heartRate)_\(Date().timeIntervalSince1970).mp4")

        isGenerating = true
        defer { isGenerating = false }

        let settingsDict: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 200000,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2
            ]
        ]

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return nil
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settingsDict)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = frameRate * 2
        for frameIndex in 0..<totalFrames {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }
            guard let buffer = createPixelBuffer(heartRate: heartRate, settings: settings) else { continue }
            let time = CMTime(value: Int64(frameIndex), timescale: frameRate)
            adaptor.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        sem.wait()

        if writer.status == .completed {
            cleanupOldFiles(keep: url)
            currentURL = url
            return url
        }
        return nil
    }

    private func createPixelBuffer(heartRate: Int, settings: SettingsManager) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(videoSize.width), Int(videoSize.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(videoSize.width),
            height: Int(videoSize.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return nil
        }

        drawFrame(ctx: ctx, heartRate: heartRate, settings: settings)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    private func drawFrame(ctx: CGContext, heartRate: Int, settings: SettingsManager) {
        let w = videoSize.width
        let h = videoSize.height
        let cornerRadius: CGFloat = 28
        let bgOpacity = CGFloat(settings.backgroundOpacity) / 100.0

        ctx.setFillColor(UIColor.black.withAlphaComponent(bgOpacity).cgColor)
        let bgPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: cornerRadius).cgPath
        ctx.addPath(bgPath)
        ctx.fillPath()

        let numberFont = UIFont.systemFont(ofSize: CGFloat(settings.bpmNumberSize) * 2.5, weight: .bold)
        let labelFont = UIFont.systemFont(ofSize: CGFloat(settings.bpmLabelSize) * 2, weight: .medium)
        let numberColor = UIColor(Color(hex: settings.bpmNumberColorHex))
        let labelColor = UIColor(Color(hex: settings.bpmLabelColorHex))

        let hrText = heartRate > 0 ? "\(heartRate)" : "--"
        let labelText = "BPM"

        let attrNumber: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: numberColor
        ]
        let attrLabel: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]

        let numberSize = (hrText as NSString).size(withAttributes: attrNumber)
        let labelSize = (labelText as NSString).size(withAttributes: attrLabel)
        let spacing: CGFloat = 8
        let totalWidth: CGFloat
        switch settings.bpmPosition {
        case 0, 1:
            totalWidth = max(numberSize.width, labelSize.width)
        default:
            totalWidth = numberSize.width + spacing + labelSize.width
        }

        let centerX = w / 2
        let centerY = h / 2

        switch settings.bpmPosition {
        case 0:
            let labelY = centerY - numberSize.height / 2 - labelSize.height - 4
            drawCenteredText(ctx: ctx, text: labelText, y: labelY, attributes: attrLabel, viewWidth: w)
            drawCenteredText(ctx: ctx, text: hrText, y: centerY - numberSize.height / 2, attributes: attrNumber, viewWidth: w)
        case 1:
            drawCenteredText(ctx: ctx, text: hrText, y: centerY - numberSize.height / 2, attributes: attrNumber, viewWidth: w)
            let labelY = centerY + numberSize.height / 2 + 4
            drawCenteredText(ctx: ctx, text: labelText, y: labelY, attributes: attrLabel, viewWidth: w)
        case 2:
            let startX = centerX - totalWidth / 2
            drawText(ctx: ctx, text: labelText, x: startX, y: centerY - labelSize.height / 2, attributes: attrLabel)
            drawText(ctx: ctx, text: hrText, x: startX + labelSize.width + spacing, y: centerY - numberSize.height / 2, attributes: attrNumber)
        case 3:
            let startX = centerX - totalWidth / 2
            drawText(ctx: ctx, text: hrText, x: startX, y: centerY - numberSize.height / 2, attributes: attrNumber)
            drawText(ctx: ctx, text: labelText, x: startX + numberSize.width + spacing, y: centerY - labelSize.height / 2, attributes: attrLabel)
        default:
            drawCenteredText(ctx: ctx, text: hrText, y: centerY - numberSize.height / 2, attributes: attrNumber, viewWidth: w)
        }
    }

    private func drawCenteredText(ctx: CGContext, text: String, y: CGFloat, attributes: [NSAttributedString.Key: Any], viewWidth: CGFloat) {
        let size = (text as NSString).size(withAttributes: attributes)
        let x = (viewWidth - size.width) / 2
        drawText(ctx: ctx, text: text, x: x, y: y, attributes: attributes)
    }

    private func drawText(ctx: CGContext, text: String, x: CGFloat, y: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        NSAttributedString(string: text, attributes: attributes).draw(at: CGPoint(x: x, y: y))
    }

    private func cleanupOldFiles(keep keepURL: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: NSTemporaryDirectory()), includingPropertiesForKeys: [.creationDateKey], options: []) else { return }
        let pipFiles = files.filter { $0.lastPathComponent.hasPrefix("pip_hr_") && $0.path != keepURL.path }
        pipFiles.forEach { try? fm.removeItem(at: $0) }
    }
}
