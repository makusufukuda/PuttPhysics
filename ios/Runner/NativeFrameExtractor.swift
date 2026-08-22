import AVFoundation
import Flutter
import Foundation

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
}
