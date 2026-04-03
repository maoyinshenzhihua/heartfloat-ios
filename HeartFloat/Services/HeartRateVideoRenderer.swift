import Foundation
import SwiftUI
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
                AVVideoAverageBitRateKey: 500000,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 5
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
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
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
        let image = renderHeartRateImage(heartRate: heartRate, settings: settings)
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private func renderHeartRateImage(heartRate: Int, settings: SettingsManager) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: videoSize)
        return renderer.image { ctx in
            let w = videoSize.width
            let h = videoSize.height
            let cornerRadius: CGFloat = 28
            let bgOpacity = CGFloat(settings.backgroundOpacity) / 100.0

            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            UIColor.black.withAlphaComponent(bgOpacity).setFill()
            let bgPath = UIBezierPath(roundedRect: CGRect(x: 4, y: 4, width: w - 8, height: h - 8), cornerRadius: cornerRadius)
            bgPath.fill()

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
                (labelText as NSString).draw(at: CGPoint(x: centerX - labelSize.width / 2, y: labelY), withAttributes: attrLabel)
                (hrText as NSString).draw(at: CGPoint(x: centerX - numberSize.width / 2, y: centerY - numberSize.height / 2), withAttributes: attrNumber)
            case 1:
                (hrText as NSString).draw(at: CGPoint(x: centerX - numberSize.width / 2, y: centerY - numberSize.height / 2), withAttributes: attrNumber)
                let labelY = centerY + numberSize.height / 2 + 4
                (labelText as NSString).draw(at: CGPoint(x: centerX - labelSize.width / 2, y: labelY), withAttributes: attrLabel)
            case 2:
                let startX = centerX - totalWidth / 2
                (labelText as NSString).draw(at: CGPoint(x: startX, y: centerY - labelSize.height / 2), withAttributes: attrLabel)
                (hrText as NSString).draw(at: CGPoint(x: startX + labelSize.width + spacing, y: centerY - numberSize.height / 2), withAttributes: attrNumber)
            case 3:
                let startX = centerX - totalWidth / 2
                (hrText as NSString).draw(at: CGPoint(x: startX, y: centerY - numberSize.height / 2), withAttributes: attrNumber)
                (labelText as NSString).draw(at: CGPoint(x: startX + numberSize.width + spacing, y: centerY - labelSize.height / 2), withAttributes: attrLabel)
            default:
                (hrText as NSString).draw(at: CGPoint(x: centerX - numberSize.width / 2, y: centerY - numberSize.height / 2), withAttributes: attrNumber)
            }
        }
    }

    private func cleanupOldFiles(keep keepURL: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: URL(fileURLWithPath: NSTemporaryDirectory()), includingPropertiesForKeys: [.creationDateKey], options: []) else { return }
        let pipFiles = files.filter { $0.lastPathComponent.hasPrefix("pip_hr_") && $0.path != keepURL.path }
        pipFiles.forEach { try? fm.removeItem(at: $0) }
    }
}
