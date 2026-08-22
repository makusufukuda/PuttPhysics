import AVFoundation
import CoreImage
import Flutter
import Foundation
import UIKit

final class NativeFrameExtractor {
    static let channelName =
        "com.chainaflower.puttphysics/frame_extractor"

    private final class FrameReaderSession {
        let reader: AVAssetReader
        let output: AVAssetReaderTrackOutput
        let context: CIContext
        let jpegQuality: CGFloat
        var frameIndex: Int

        init(
            reader: AVAssetReader,
            output: AVAssetReaderTrackOutput,
            jpegQuality: CGFloat
        ) {
            self.reader = reader
            self.output = output
            self.context = CIContext()
            self.jpegQuality = jpegQuality
            self.frameIndex = 0
        }
    }

    private static var frameReaderSession: FrameReaderSession?

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "ping":
                result([
                    "ok": true,
                    "platform": "ios"
                ])

            case "openFrameReader":
                guard
                    let arguments = call.arguments as? [String: Any],
                    let videoPath = arguments["videoPath"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "videoPath is required",
                            details: nil
                        )
                    )
                    return
                }

                let quality =
                    arguments["quality"] as? Int ?? 95

                openFrameReader(
                    videoPath: videoPath,
                    quality: quality,
                    result: result
                )

            case "readNextFrame":
                readNextFrame(result: result)

            case "closeFrameReader":
                closeFrameReader(result: result)

            case "readFrameImage":
                guard
                    let arguments = call.arguments as? [String: Any],
                    let videoPath = arguments["videoPath"] as? String,
                    let frameIndex = arguments["frameIndex"] as? Int
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "videoPath and frameIndex are required",
                            details: nil
                        )
                    )
                    return
                }

                readFrameImage(
                    videoPath: videoPath,
                    frameIndex: frameIndex,
                    result: result
                )

            case "readFrameMetadata":
                guard
                    let arguments = call.arguments as? [String: Any],
                    let videoPath = arguments["videoPath"] as? String
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENTS",
                            message: "videoPath is required",
                            details: nil
                        )
                    )
                    return
                }

                readFrameMetadata(
                    videoPath: videoPath,
                    result: result
                )

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func openFrameReader(
        videoPath: String,
        quality: Int,
        result: @escaping FlutterResult
    ) {
        do {
            frameReaderSession = nil

            let url = URL(fileURLWithPath: videoPath)
            let asset = AVURLAsset(url: url)

            let tracks = asset.tracks(
                withMediaType: .video
            )

            guard let track = tracks.first else {
                result(
                    FlutterError(
                        code: "NO_VIDEO_TRACK",
                        message: "Video track not found",
                        details: nil
                    )
                )
                return
            }

            let reader = try AVAssetReader(asset: asset)

            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String:
                        kCVPixelFormatType_32BGRA
                ]
            )

            output.alwaysCopiesSampleData = false

            guard reader.canAdd(output) else {
                result(
                    FlutterError(
                        code: "CANNOT_ADD_OUTPUT",
                        message:
                            "Cannot add AVAssetReaderTrackOutput",
                        details: nil
                    )
                )
                return
            }

            reader.add(output)

            guard reader.startReading() else {
                result(
                    FlutterError(
                        code: "READER_START_FAILED",
                        message:
                            reader.error?.localizedDescription
                            ?? "AVAssetReader failed to start",
                        details: nil
                    )
                )
                return
            }

            let clampedQuality =
                max(0, min(100, quality))

            frameReaderSession = FrameReaderSession(
                reader: reader,
                output: output,
                jpegQuality:
                    CGFloat(clampedQuality) / 100.0
            )

            result([
                "ok": true
            ])
        } catch {
            frameReaderSession = nil

            result(
                FlutterError(
                    code: "OPEN_FRAME_READER_ERROR",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private static func readNextFrame(
        result: @escaping FlutterResult
    ) {
        guard let session = frameReaderSession else {
            result(
                FlutterError(
                    code: "FRAME_READER_NOT_OPEN",
                    message: "Frame reader is not open",
                    details: nil
                )
            )
            return
        }

        guard
            let sampleBuffer =
                session.output.copyNextSampleBuffer()
        else {
            let status = session.reader.status.rawValue

            result([
                "done": true,
                "readerStatus": status
            ])
            return
        }

        let currentFrameIndex = session.frameIndex
        session.frameIndex += 1

        let pts =
            CMSampleBufferGetPresentationTimeStamp(
                sampleBuffer
            )

        let ptsMicroseconds =
            Int64(
                (
                    CMTimeGetSeconds(pts)
                    * 1_000_000.0
                ).rounded()
            )

        guard
            let imageBuffer =
                CMSampleBufferGetImageBuffer(
                    sampleBuffer
                )
        else {
            result(
                FlutterError(
                    code: "NO_PIXEL_BUFFER",
                    message: "Pixel buffer not found",
                    details: currentFrameIndex
                )
            )
            return
        }

        let ciImage = CIImage(
            cvPixelBuffer: imageBuffer
        )

        guard
            let cgImage =
                session.context.createCGImage(
                    ciImage,
                    from: ciImage.extent
                )
        else {
            result(
                FlutterError(
                    code: "CGIMAGE_FAILED",
                    message: "Could not create CGImage",
                    details: currentFrameIndex
                )
            )
            return
        }

        let uiImage = UIImage(
            cgImage: cgImage
        )

        guard
            let jpegData =
                uiImage.jpegData(
                    compressionQuality:
                        session.jpegQuality
                )
        else {
            result(
                FlutterError(
                    code: "JPEG_FAILED",
                    message: "Could not encode JPEG",
                    details: currentFrameIndex
                )
            )
            return
        }

        result([
            "done": false,
            "frameIndex": currentFrameIndex,
            "ptsUs": ptsMicroseconds,
            "width": cgImage.width,
            "height": cgImage.height,
            "imageBytes":
                FlutterStandardTypedData(
                    bytes: jpegData
                )
        ])
    }

    private static func closeFrameReader(
        result: @escaping FlutterResult
    ) {
        frameReaderSession?.reader.cancelReading()
        frameReaderSession = nil

        result([
            "ok": true
        ])
    }

    private static func readFrameMetadata(
        videoPath: String,
        result: @escaping FlutterResult
    ) {
        Task {
            do {
                let url = URL(fileURLWithPath: videoPath)
                let asset = AVURLAsset(url: url)

                let tracks = asset.tracks(
                    withMediaType: .video
                )

                guard let track = tracks.first else {
                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "NO_VIDEO_TRACK",
                                message: "Video track not found",
                                details: nil
                            )
                        )
                    }
                    return
                }

                let reader = try AVAssetReader(asset: asset)

                let output = AVAssetReaderTrackOutput(
                    track: track,
                    outputSettings: [
                        kCVPixelBufferPixelFormatTypeKey as String:
                            kCVPixelFormatType_32BGRA
                    ]
                )

                output.alwaysCopiesSampleData = false

                guard reader.canAdd(output) else {
                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "CANNOT_ADD_OUTPUT",
                                message:
                                    "Cannot add AVAssetReaderTrackOutput",
                                details: nil
                            )
                        )
                    }
                    return
                }

                reader.add(output)

                guard reader.startReading() else {
                    let message =
                        reader.error?.localizedDescription
                        ?? "AVAssetReader failed to start"

                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "READER_START_FAILED",
                                message: message,
                                details: nil
                            )
                        )
                    }
                    return
                }

                var frameCount = 0
                var firstPtsMs: Double?
                var lastPtsMs: Double?
                var previousPtsMs: Double?

                var minimumStepMs =
                    Double.greatestFiniteMagnitude

                var maximumStepMs = 0.0
                var duplicateCount = 0
                var nonIncreasingCount = 0

                var sampleFrames:
                    [[String: Any]] = []

                while let sampleBuffer =
                    output.copyNextSampleBuffer()
                {
                    let pts =
                        CMSampleBufferGetPresentationTimeStamp(
                            sampleBuffer
                        )

                    let ptsMs =
                        CMTimeGetSeconds(pts) * 1000.0

                    if firstPtsMs == nil {
                        firstPtsMs = ptsMs
                    }

                    if let previous = previousPtsMs {
                        let step = ptsMs - previous

                        minimumStepMs =
                            min(minimumStepMs, step)

                        maximumStepMs =
                            max(maximumStepMs, step)

                        if abs(step) < 0.001 {
                            duplicateCount += 1
                        }

                        if step <= 0 {
                            nonIncreasingCount += 1
                        }
                    }

                    if frameCount >= 120 &&
                        frameCount <= 140
                    {
                        sampleFrames.append([
                            "index": frameCount,
                            "ptsMs": ptsMs
                        ])
                    }

                    previousPtsMs = ptsMs
                    lastPtsMs = ptsMs
                    frameCount += 1
                }

                let minimumStepValue:
                    Any = minimumStepMs ==
                        Double.greatestFiniteMagnitude
                        ? NSNull()
                        : minimumStepMs

                let response: [String: Any] = [
                    "frameCount": frameCount,
                    "firstPtsMs": firstPtsMs ?? NSNull(),
                    "lastPtsMs": lastPtsMs ?? NSNull(),
                    "minimumStepMs": minimumStepValue,
                    "maximumStepMs": maximumStepMs,
                    "duplicateCount": duplicateCount,
                    "nonIncreasingCount":
                        nonIncreasingCount,
                    "readerStatus":
                        reader.status.rawValue,
                    "sampleFrames": sampleFrames
                ]

                await MainActor.run {
                    result(response)
                }
            } catch {
                await MainActor.run {
                    result(
                        FlutterError(
                            code: "FRAME_METADATA_ERROR",
                            message:
                                error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }
    private static func readFrameImage(
        videoPath: String,
        frameIndex: Int,
        result: @escaping FlutterResult
    ) {
        guard frameIndex >= 0 else {
            result(
                FlutterError(
                    code: "INVALID_FRAME_INDEX",
                    message: "frameIndex must be zero or greater",
                    details: nil
                )
            )
            return
        }

        Task {
            do {
                let url = URL(fileURLWithPath: videoPath)
                let asset = AVURLAsset(url: url)

                let tracks = asset.tracks(
                    withMediaType: .video
                )

                guard let track = tracks.first else {
                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "NO_VIDEO_TRACK",
                                message: "Video track not found",
                                details: nil
                            )
                        )
                    }
                    return
                }

                let reader = try AVAssetReader(asset: asset)

                let output = AVAssetReaderTrackOutput(
                    track: track,
                    outputSettings: [
                        kCVPixelBufferPixelFormatTypeKey as String:
                            kCVPixelFormatType_32BGRA
                    ]
                )

                output.alwaysCopiesSampleData = false

                guard reader.canAdd(output) else {
                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "CANNOT_ADD_OUTPUT",
                                message: "Cannot add AVAssetReaderTrackOutput",
                                details: nil
                            )
                        )
                    }
                    return
                }

                reader.add(output)

                guard reader.startReading() else {
                    let message =
                        reader.error?.localizedDescription
                        ?? "AVAssetReader failed to start"

                    await MainActor.run {
                        result(
                            FlutterError(
                                code: "READER_START_FAILED",
                                message: message,
                                details: nil
                            )
                        )
                    }
                    return
                }

                var currentIndex = 0

                while let sampleBuffer =
                    output.copyNextSampleBuffer()
                {
                    if currentIndex == frameIndex {
                        let pts =
                            CMSampleBufferGetPresentationTimeStamp(
                                sampleBuffer
                            )

                        let ptsMs =
                            CMTimeGetSeconds(pts) * 1000.0

                        guard
                            let imageBuffer =
                                CMSampleBufferGetImageBuffer(
                                    sampleBuffer
                                )
                        else {
                            await MainActor.run {
                                result(
                                    FlutterError(
                                        code: "NO_PIXEL_BUFFER",
                                        message: "Pixel buffer not found",
                                        details: nil
                                    )
                                )
                            }
                            return
                        }

                        let ciImage = CIImage(
                            cvPixelBuffer: imageBuffer
                        )

                        let context = CIContext()

                        guard
                            let cgImage = context.createCGImage(
                                ciImage,
                                from: ciImage.extent
                            )
                        else {
                            await MainActor.run {
                                result(
                                    FlutterError(
                                        code: "CGIMAGE_FAILED",
                                        message: "Could not create CGImage",
                                        details: nil
                                    )
                                )
                            }
                            return
                        }

                        let uiImage = UIImage(
                            cgImage: cgImage
                        )

                        guard
                            let jpegData =
                                uiImage.jpegData(
                                    compressionQuality: 0.95
                                )
                        else {
                            await MainActor.run {
                                result(
                                    FlutterError(
                                        code: "JPEG_FAILED",
                                        message: "Could not encode JPEG",
                                        details: nil
                                    )
                                )
                            }
                            return
                        }

                        let response: [String: Any] = [
                            "frameIndex": frameIndex,
                            "ptsMs": ptsMs,
                            "width": cgImage.width,
                            "height": cgImage.height,
                            "imageBytes":
                                FlutterStandardTypedData(
                                    bytes: jpegData
                                )
                        ]

                        await MainActor.run {
                            result(response)
                        }

                        return
                    }

                    currentIndex += 1
                }

                await MainActor.run {
                    result(
                        FlutterError(
                            code: "FRAME_NOT_FOUND",
                            message:
                                "Requested frame index not found",
                            details: frameIndex
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    result(
                        FlutterError(
                            code: "FRAME_IMAGE_ERROR",
                            message:
                                error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

}
