import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:video_player/video_player.dart';

import '../services/frame_extractor.dart';
import '../services/image_inspector.dart';
import '../models/tracking_session.dart';
import '../models/marker_calibration_result.dart';
import '../services/ball_tracker.dart';
import '../services/marker_detector.dart';
import '../services/marker_calibration.dart';
import '../services/real_speed_calculator.dart';
import 'frame_preview_dialog.dart';
import 'video_player_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _nativeFrameChannel = MethodChannel(
    'com.chainaflower.puttphysics/frame_extractor',
  );

  Future<void> _testNativeFrameChannel() async {
    try {
      final result = await _nativeFrameChannel.invokeMethod<Object?>('ping');

      debugPrint('NATIVE FRAME CHANNEL PING result=$result');
    } on PlatformException catch (error) {
      debugPrint(
        'NATIVE FRAME CHANNEL PING ERROR '
        'code=${error.code} '
        'message=${error.message}',
      );
    } catch (error) {
      debugPrint('NATIVE FRAME CHANNEL PING ERROR $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final controller = _cameraController;

    if (state == AppLifecycleState.inactive) {
      // 初期化途中なら、ここでは解放しない。
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      _cameraController = null;
      _initializeCameraFuture = null;

      await controller.dispose();

      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null) {
        await _initializeCamera();
      }
    }
  }

  static const double _videoFps = 30.0;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  VideoPlayerController? _videoPlayerController;
  String? _recordedVideoPath;

  final BallTracker _ballTracker = BallTracker();
  final TrackingSession _trackingSession = TrackingSession();

  int _frameAnalysisCount = 0;

  String? _errorMessage;
  String? _analysisResultMessage;
  bool _isRecording = false;
  bool _isAnalyzingVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _testNativeFrameChannel();
  }

  Future<void> _readNativeFrameMetadata(String videoPath) async {
    try {
      debugPrint(
        'NATIVE FRAME METADATA START '
        'videoPath=$videoPath',
      );

      final result = await _nativeFrameChannel.invokeMapMethod<String, Object?>(
        'readFrameMetadata',
        <String, Object?>{'videoPath': videoPath},
      );

      if (result == null) {
        debugPrint('NATIVE FRAME METADATA ERROR result=null');
        return;
      }

      debugPrint(
        'NATIVE FRAME METADATA '
        'frameCount=${result['frameCount']} '
        'firstPtsMs=${result['firstPtsMs']} '
        'lastPtsMs=${result['lastPtsMs']} '
        'minimumStepMs=${result['minimumStepMs']} '
        'maximumStepMs=${result['maximumStepMs']} '
        'duplicateCount=${result['duplicateCount']} '
        'nonIncreasingCount=${result['nonIncreasingCount']} '
        'readerStatus=${result['readerStatus']}',
      );

      final sampleFrames = result['sampleFrames'];

      debugPrint(
        'NATIVE FRAME METADATA SAMPLE '
        '$sampleFrames',
      );
    } on PlatformException catch (error) {
      debugPrint(
        'NATIVE FRAME METADATA ERROR '
        'code=${error.code} '
        'message=${error.message} '
        'details=${error.details}',
      );
    } catch (error) {
      debugPrint('NATIVE FRAME METADATA ERROR $error');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = '利用できるカメラが見つかりません。';
          });
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraController = controller;
      _initializeCameraFuture = controller.initialize();

      await _initializeCameraFuture;

      if (mounted) {
        setState(() {});
      }
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'カメラの初期化に失敗しました。\n'
              '${error.code}: ${error.description ?? ''}';
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized || _isRecording) {
      return;
    }

    try {
      await controller.startVideoRecording();

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }
    } on CameraException catch (error) {
      _showMessage(
        '録画を開始できませんでした。\n'
        '${error.code}: ${error.description ?? ''}',
      );
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;

    if (controller == null || !_isRecording) {
      return;
    }

    try {
      final videoFile = await controller.stopVideoRecording();

      debugPrint('RECORDED VIDEO path=${videoFile.path}');

      _recordedVideoPath = videoFile.path;

      await _readNativeFrameMetadata(videoFile.path);

      await _initializeVideoPlayer(videoFile);

      if (mounted) {
        setState(() {
          _isRecording = false;
        });

        _showMessage('録画を保存しました。\n${videoFile.path}');
      }
    } on CameraException catch (error) {
      _showMessage(
        '録画を停止できませんでした。\n'
        '${error.code}: ${error.description ?? ''}',
      );
    }
  }

  Future<void> _initializeVideoPlayer(XFile videoFile) async {
    await _videoPlayerController?.dispose();

    final controller = VideoPlayerController.file(File(videoFile.path));

    await controller.initialize();

    controller.addListener(_onVideoChanged);
    _videoPlayerController = controller;

    if (mounted) {
      setState(() {});
    }
  }

  void _onVideoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoPlayerController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }

      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _seekOneFrame({required bool forward}) async {
    final controller = _videoPlayerController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await controller.pause();

    final currentMicroseconds = controller.value.position.inMicroseconds;

    final durationMicroseconds = controller.value.duration.inMicroseconds;

    final currentFrame =
        (currentMicroseconds * _videoFps / Duration.microsecondsPerSecond)
            .round();

    final totalFrames =
        (durationMicroseconds * _videoFps / Duration.microsecondsPerSecond)
            .floor();

    final targetFrame = forward
        ? (currentFrame + 1).clamp(0, totalFrames)
        : (currentFrame - 1).clamp(0, totalFrames);

    final targetMicroseconds =
        (targetFrame * Duration.microsecondsPerSecond / _videoFps).round();

    await controller.seekTo(Duration(microseconds: targetMicroseconds));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _captureCurrentFrame() async {
    final videoController = _videoPlayerController;
    final videoPath = _recordedVideoPath;

    if (videoController == null ||
        !videoController.value.isInitialized ||
        videoPath == null) {
      _showMessage('先に動画を録画してください。');
      return;
    }

    await videoController.pause();

    final position = videoController.value.position;

    try {
      final Uint8List? imageBytes = await FrameExtractor.extractFrame(
        videoPath: videoPath,
        position: position,
      );

      if (!mounted) {
        return;
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        _showMessage('フレーム画像を取得できませんでした。');
        return;
      }

      final imageInfo = ImageInspector.inspect(imageBytes);

      if (imageInfo == null) {
        _showMessage('フレーム画像を読み込めませんでした。');
        return;
      }
      _frameAnalysisCount++;

      final trackedBall = _ballTracker.track(
        frameIndex: _frameAnalysisCount,
        timestamp: position,
        candidates: imageInfo.ballCandidates,
      );

      debugPrint('BallTracker missedFrames=${_ballTracker.missedFrameCount}');
      if (trackedBall != null) {
        _trackingSession.add(trackedBall);
        final trackingMetrics = _trackingSession.latestMetrics();

        if (trackingMetrics != null) {
          debugPrint(
            'TrackingMetrics '
            'dt=${trackingMetrics.deltaTimeSeconds.toStringAsFixed(4)}s '
            'distance=${trackingMetrics.distancePixels.toStringAsFixed(2)}px '
            'speed=${trackingMetrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
          );
        }
      }

      if (trackedBall != null) {
        debugPrint(
          'TrackedBall '
          'frame=${trackedBall.frameIndex} '
          'count=${_trackingSession.length} '
          'time=${trackedBall.timestamp.inMilliseconds}ms '
          'x=${trackedBall.centerX.toStringAsFixed(1)} '
          'y=${trackedBall.centerY.toStringAsFixed(1)} '
          'r=${trackedBall.radius.toStringAsFixed(1)} '
          'conf=${(trackedBall.confidence * 100).toStringAsFixed(1)}%',
        );
      }
      final largestBlob = imageInfo.largestBlob;
      final bestBallCandidate = imageInfo.bestBallCandidate;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return FramePreviewDialog(
            imageBytes: imageBytes,
            position: position,
            imageWidth: imageInfo.width,
            imageHeight: imageInfo.height,
            centerX: imageInfo.centerX,
            centerY: imageInfo.centerY,
            centerRed: imageInfo.centerRed,
            centerGreen: imageInfo.centerGreen,
            centerBlue: imageInfo.centerBlue,
            centerHue: imageInfo.centerHue,
            centerSaturation: imageInfo.centerSaturation,
            centerValue: imageInfo.centerValue,
            centerIsYellow: imageInfo.centerIsYellow,
            centerIsRed: imageInfo.centerIsRed,
            totalPixels: imageInfo.totalPixels,
            yellowPixels: imageInfo.yellowPixels,
            redPixels: imageInfo.redPixels,
            targetColorPixels: imageInfo.targetColorPixels,
            yellowRatio: imageInfo.yellowRatio,
            redRatio: imageInfo.redRatio,
            blobCount: imageInfo.blobCount,
            largestBlobPixelCount: largestBlob?.pixelCount,
            largestBlobCentroidX: largestBlob?.centroidX,
            largestBlobCentroidY: largestBlob?.centroidY,
            largestBlobMinX: largestBlob?.minX,
            largestBlobMinY: largestBlob?.minY,
            largestBlobWidth: largestBlob?.width,
            largestBlobHeight: largestBlob?.height,
            ballCandidateCount: imageInfo.ballCandidateCount,
            ballCandidates: imageInfo.ballCandidates
                .map(
                  (candidate) => BallCandidateViewData(
                    centerX: candidate.centerX,
                    centerY: candidate.centerY,
                    radius: candidate.radius,
                    confidence: candidate.confidence,
                  ),
                )
                .toList(),
            bestCandidateCenterX: bestBallCandidate?.centerX,
            bestCandidateCenterY: bestBallCandidate?.centerY,
            bestCandidateRadius: bestBallCandidate?.radius,
            bestCandidateConfidence: bestBallCandidate?.confidence,
          );
        },
      );
    } catch (error) {
      _showMessage('フレーム画像の取得中にエラーが発生しました。\n$error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleMainButton() async {
    final videoController = _videoPlayerController;

    if (videoController != null && videoController.value.isInitialized) {
      await _toggleVideoPlayback();
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  IconData _mainButtonIcon() {
    final videoController = _videoPlayerController;

    if (videoController != null && videoController.value.isInitialized) {
      return videoController.value.isPlaying ? Icons.pause : Icons.play_arrow;
    }

    return _isRecording ? Icons.stop : Icons.videocam;
  }

  Future<void> _analyzeRecordedVideoFrames() async {
    if (_isAnalyzingVideo) {
      debugPrint('AutoTracking ignored: analysis already running');
      return;
    }

    final videoController = _videoPlayerController;
    final videoPath = _recordedVideoPath;

    if (videoController == null ||
        !videoController.value.isInitialized ||
        videoPath == null) {
      _showMessage('先に動画を録画してください。');
      return;
    }

    if (mounted) {
      setState(() {
        _isAnalyzingVideo = true;
      });
    } else {
      _isAnalyzingVideo = true;
    }

    try {
      _ballTracker.reset();
      _trackingSession.clear();
      _frameAnalysisCount = 0;

      MarkerCalibrationResult? calibration;

      final duration = videoController.value.duration;

      await for (final frame in FrameExtractor.extractFrames(
        videoPath: videoPath,
        duration: duration,
      )) {
        final imageInfo = ImageInspector.inspect(
          frame.imageBytes,
          debugFrameIndex: _frameAnalysisCount + 1,
        );

        if (imageInfo == null) {
          continue;
        }

        if (_frameAnalysisCount == 0) {
          final markers = MarkerDetector.detect(frame.imageBytes);

          debugPrint('MARKER DETECTION count=${markers.length}');

          for (final marker in markers) {
            debugPrint(
              'MARKER '
              'position=${marker.position.name} '
              'x=${marker.centerX.toStringAsFixed(1)} '
              'y=${marker.centerY.toStringAsFixed(1)} '
              'width=${marker.width} '
              'height=${marker.height} '
              'pixels=${marker.pixelCount}',
            );
          }

          calibration = MarkerCalibration.calculate(markers);

          if (calibration != null) {
            debugPrint(
              'CALIBRATION '
              'top=${calibration.topDistancePixels.toStringAsFixed(2)}px '
              'topScale=${calibration.topScale.pixelsPerMillimeter.toStringAsFixed(4)}px/mm',
            );

            debugPrint(
              'CALIBRATION '
              'bottom=${calibration.bottomDistancePixels.toStringAsFixed(2)}px '
              'bottomScale=${calibration.bottomScale.pixelsPerMillimeter.toStringAsFixed(4)}px/mm',
            );

            debugPrint(
              'CALIBRATION '
              'scaleDifference=${(calibration.scaleDifferenceRatio * 100).toStringAsFixed(1)}%',
            );
          }
        }

        _frameAnalysisCount++;

        final trackedBall = _ballTracker.track(
          frameIndex: _frameAnalysisCount,
          timestamp: frame.position,
          candidates: imageInfo.ballCandidates,
        );

        if (trackedBall == null) {
          final largestBlob = imageInfo.largestBlob;

          debugPrint(
            'AutoTrackMiss '
            'frame=$_frameAnalysisCount '
            'time=${frame.position.inMilliseconds}ms '
            'candidates=${imageInfo.ballCandidates.length} '
            'targetPixels=${imageInfo.targetColorPixels} '
            'blobs=${imageInfo.blobCount} '
            'largestPixels=${largestBlob?.pixelCount ?? 0} '
            'largestWidth=${largestBlob?.width ?? 0} '
            'largestHeight=${largestBlob?.height ?? 0} '
            'largestFill=${largestBlob?.fillRatio.toStringAsFixed(3) ?? '-'} '
            'missedFrames=${_ballTracker.missedFrameCount}',
          );
          continue;
        }

        _trackingSession.add(trackedBall);

        final metrics = _trackingSession.latestMetrics();
        final smoothedMetrics = _trackingSession.latestSmoothedMetrics();

        debugPrint(
          'AutoTrackedBall '
          'frame=${trackedBall.frameIndex} '
          'time=${trackedBall.timestamp.inMilliseconds}ms '
          'x=${trackedBall.centerX.toStringAsFixed(1)} '
          'y=${trackedBall.centerY.toStringAsFixed(1)} '
          'conf=${(trackedBall.confidence * 100).toStringAsFixed(1)}%',
        );

        if (calibration != null) {
          final pixelsPerMillimeter = calibration.pixelsPerMillimeterAtY(
            trackedBall.centerY,
          );

          debugPrint(
            'BALL SCALE '
            'frame=${trackedBall.frameIndex} '
            'y=${trackedBall.centerY.toStringAsFixed(1)} '
            'scale=${pixelsPerMillimeter.toStringAsFixed(4)}px/mm',
          );
        }

        if (metrics != null) {
          debugPrint(
            'AutoTrackingMetrics '
            'dt=${metrics.deltaTimeSeconds.toStringAsFixed(4)}s '
            'distance=${metrics.distancePixels.toStringAsFixed(2)}px '
            'speed=${metrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
          );

          if (calibration != null && _trackingSession.length >= 2) {
            final previousBall =
                _trackingSession.balls[_trackingSession.length - 2];

            final realSpeed = RealSpeedCalculator.calculate(
              calibration: calibration,
              previous: previousBall,
              current: trackedBall,
              metrics: metrics,
            );

            if (realSpeed != null) {
              debugPrint(
                'REAL SPEED '
                'frame=${previousBall.frameIndex}->${trackedBall.frameIndex} '
                'middleY=${realSpeed.middleY.toStringAsFixed(1)} '
                'scale=${realSpeed.pixelsPerMillimeter.toStringAsFixed(4)}px/mm '
                'speed=${realSpeed.speedMillimetersPerSecond.toStringAsFixed(1)}mm/s '
                'speed=${realSpeed.speedMetersPerSecond.toStringAsFixed(3)}m/s',
              );
            }
          }
        }

        if (smoothedMetrics != null) {
          debugPrint(
            'AutoTrackingSmoothed '
            'dt=${smoothedMetrics.deltaTimeSeconds.toStringAsFixed(4)}s '
            'distance=${smoothedMetrics.distancePixels.toStringAsFixed(2)}px '
            'speed=${smoothedMetrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
          );
        }
      }

      debugPrint(
        'AutoTracking finished '
        'frames=$_frameAnalysisCount '
        'tracked=${_trackingSession.length}',
      );

      final peak = _trackingSession.peakMetrics();
      final smoothedPeak = _trackingSession.smoothedPeakMetrics();

      RealSpeedResult? smoothedRealSpeed;

      if (calibration != null && smoothedPeak != null) {
        smoothedRealSpeed = RealSpeedCalculator.calculate(
          calibration: calibration,
          previous: smoothedPeak.previous,
          current: smoothedPeak.current,
          metrics: smoothedPeak.metrics,
        );
      }

      if (peak != null) {
        debugPrint(
          'RAW PEAK SPEED '
          'previousFrame=${peak.previous.frameIndex} '
          'frame=${peak.current.frameIndex} '
          'time=${peak.current.timestamp.inMilliseconds}ms '
          'speed=${peak.metrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s '
          'distance=${peak.metrics.distancePixels.toStringAsFixed(2)}px '
          'dt=${peak.metrics.deltaTimeSeconds.toStringAsFixed(4)}s',
        );

        final continuousMetrics = _trackingSession.continuousMetrics();
        final peakIndex = continuousMetrics.indexWhere(
          (item) =>
              item.previous.frameIndex == peak.previous.frameIndex &&
              item.current.frameIndex == peak.current.frameIndex,
        );

        if (peakIndex >= 0) {
          debugPrint('===== PEAK CONTEXT =====');

          final start = peakIndex - 3 < 0 ? 0 : peakIndex - 3;
          final end = peakIndex + 3 >= continuousMetrics.length
              ? continuousMetrics.length - 1
              : peakIndex + 3;

          for (var i = start; i <= end; i++) {
            final item = continuousMetrics[i];

            debugPrint(
              'PEAK CONTEXT '
              'frame=${item.previous.frameIndex}->${item.current.frameIndex} '
              'time=${item.current.timestamp.inMilliseconds}ms '
              'distance=${item.metrics.distancePixels.toStringAsFixed(2)}px '
              'speed=${item.metrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s'
              '${i == peakIndex ? ' <-- PEAK' : ''}',
            );
          }
        }
      }

      if (smoothedPeak != null) {
        debugPrint(
          'SMOOTHED PEAK SPEED '
          'startFrame=${smoothedPeak.previous.frameIndex} '
          'frame=${smoothedPeak.current.frameIndex} '
          'time=${smoothedPeak.current.timestamp.inMilliseconds}ms '
          'speed=${smoothedPeak.metrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s '
          'distance=${smoothedPeak.metrics.distancePixels.toStringAsFixed(2)}px '
          'dt=${smoothedPeak.metrics.deltaTimeSeconds.toStringAsFixed(4)}s',
        );
      }

      if (mounted) {
        setState(() {
          if (smoothedRealSpeed != null) {
            _analysisResultMessage =
                '解析完了: ${_trackingSession.length}フレーム追跡 / '
                '実速度 ${smoothedRealSpeed.speedMetersPerSecond.toStringAsFixed(3)} m/s '
                '(平滑化)';
          } else if (smoothedPeak != null) {
            _analysisResultMessage =
                '解析完了: ${_trackingSession.length}フレーム追跡 / '
                '最大速度 ${smoothedPeak.metrics.speedPixelsPerSecond.toStringAsFixed(1)} px/s '
                '(平滑化)';
          } else if (peak != null) {
            _analysisResultMessage =
                '解析完了: ${_trackingSession.length}フレーム追跡 / '
                '最大速度 ${peak.metrics.speedPixelsPerSecond.toStringAsFixed(1)} px/s '
                '(Raw)';
          } else {
            _analysisResultMessage = '解析完了: ${_trackingSession.length}フレーム追跡';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingVideo = false;
        });
      } else {
        _isAnalyzingVideo = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController?.removeListener(_onVideoChanged);
    _videoPlayerController?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カメラ確認')),
      body: Column(
        children: [
          if (_analysisResultMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_analysisResultMessage!, textAlign: TextAlign.center),
            ),
          Expanded(
            child: VideoPlayerView(
              cameraController: _cameraController,
              initializeCameraFuture: _initializeCameraFuture,
              errorMessage: _errorMessage,
              videoController: _videoPlayerController,
              videoFps: _videoFps,
              onPreviousFrame: () {
                _seekOneFrame(forward: false);
              },
              onNextFrame: () {
                _seekOneFrame(forward: true);
              },
              onCaptureFrame: () {
                _captureCurrentFrame();
              },
              onAnalyzeVideo: () {
                _analyzeRecordedVideoFrames();
              },
              isAnalyzingVideo: _isAnalyzingVideo,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleMainButton,
        child: Icon(_mainButtonIcon()),
      ),
    );
  }
}
