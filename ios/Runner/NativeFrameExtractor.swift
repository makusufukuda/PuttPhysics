import AVFoundation
import CoreImage
import Flutter
import Foundation
import UIKit

final class NativeFrameExtractor {
    static let channelName =
        "com.chainaflower.puttphysics/frame_extractor"

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
