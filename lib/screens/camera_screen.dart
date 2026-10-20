import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../services/frame_extractor.dart';
import '../services/debug_log.dart';
import '../services/image_inspector.dart';
import '../models/tracking_session.dart';
import '../models/putter_tracking_session.dart';
import '../models/marker_calibration_result.dart';
import '../models/marker_candidate.dart';
import '../services/ball_tracker.dart';
import '../services/blue_marker_diagnostic.dart';
import '../services/green_marker_diagnostic.dart';
import '../services/pink_marker_diagnostic.dart';
import '../services/putter_detector.dart';
import '../services/putter_tracker.dart';
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

  double _videoFps = 60.0;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  VideoPlayerController? _videoPlayerController;
  String? _recordedVideoPath;
  Map<String, Offset>? _confirmedMarkerPositions;

  // User-confirmed initial ball position in image coordinates.
  Offset? _confirmedBallPosition;

  final BallTracker _ballTracker = BallTracker();
  final PutterTracker _putterTracker = PutterTracker();
  final TrackingSession _trackingSession = TrackingSession();
  final PutterTrackingSession _putterTrackingSession = PutterTrackingSession();

  int _frameAnalysisCount = 0;

  String? _errorMessage;
  String? _analysisResultMessage;
  String? _putterTrackingReport;
  bool _isRecording = false;
  bool _isAnalyzingVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _testNativeFrameChannel();
  }

  Future<void> _readNativeFrameImage(
    String videoPath, {
    required int frameIndex,
  }) async {
    try {
      debugPrint(
        'NATIVE FRAME IMAGE START '
        'frameIndex=$frameIndex '
        'videoPath=$videoPath',
      );

      final result = await _nativeFrameChannel.invokeMapMethod<String, Object?>(
        'readFrameImage',
        <String, Object?>{'videoPath': videoPath, 'frameIndex': frameIndex},
      );

      if (result == null) {
        debugPrint('NATIVE FRAME IMAGE ERROR result=null');
        return;
      }

      final imageBytes = result['imageBytes'];

      final byteLength = imageBytes is Uint8List ? imageBytes.length : -1;

      debugPrint(
        'NATIVE FRAME IMAGE '
        'frameIndex=${result['frameIndex']} '
        'ptsMs=${result['ptsMs']} '
        'width=${result['width']} '
        'height=${result['height']} '
        'jpegBytes=$byteLength',
      );

      if (imageBytes is! Uint8List) {
        debugPrint(
          'NATIVE FRAME INSPECT ERROR '
          'imageBytes is not Uint8List',
        );
        return;
      }

      final imageInfo = ImageInspector.inspect(
        imageBytes,
        debugFrameIndex: frameIndex,
      );

      if (imageInfo == null) {
        debugPrint(
          'NATIVE FRAME INSPECT ERROR '
          'frameIndex=$frameIndex '
          'ImageInspector returned null',
        );
        return;
      }

      debugPrint(
        'NATIVE FRAME INSPECT '
        'frameIndex=$frameIndex '
        'width=${imageInfo.width} '
        'height=${imageInfo.height} '
        'blobCount=${imageInfo.blobCount} '
        'ballCandidateCount=${imageInfo.ballCandidateCount} '
        'bestBallCandidate=${imageInfo.bestBallCandidate}',
      );

      BlueMarkerDiagnostic.inspect(imageBytes, frameIndex: frameIndex);
      GreenMarkerDiagnostic.inspect(imageBytes, frameIndex: frameIndex);
      PinkMarkerDiagnostic.inspect(imageBytes, frameIndex: frameIndex);

      final putterCandidates = PutterDetector.detect(
        imageBytes,
        frameIndex: frameIndex,
      );

      debugPrint(
        'NATIVE FRAME PUTTER DETECTION '
        'frameIndex=$frameIndex '
        'count=${putterCandidates.length} '
        'best=${putterCandidates.isEmpty ? null : putterCandidates.first}',
      );

      final markers = MarkerDetector.detect(imageBytes);

      debugPrint(
        'NATIVE FRAME MARKER DETECTION '
        'frameIndex=$frameIndex '
        'count=${markers.length}',
      );

      for (final marker in markers) {
        debugPrint(
          'NATIVE FRAME MARKER '
          'frameIndex=$frameIndex '
          'position=${marker.position.name} '
          'x=${marker.centerX.toStringAsFixed(1)} '
          'y=${marker.centerY.toStringAsFixed(1)} '
          'width=${marker.width} '
          'height=${marker.height} '
          'pixels=${marker.pixelCount}',
        );
      }
    } on PlatformException catch (error) {
      debugPrint(
        'NATIVE FRAME IMAGE ERROR '
        'code=${error.code} '
        'message=${error.message} '
        'details=${error.details}',
      );
    } catch (error) {
      debugPrint('NATIVE FRAME IMAGE ERROR $error');
    }
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

      final frameCount = result['frameCount'];
      final firstPtsMs = result['firstPtsMs'];
      final lastPtsMs = result['lastPtsMs'];
      final minimumStepMs = result['minimumStepMs'];
      final maximumStepMs = result['maximumStepMs'];

      if (frameCount is num &&
          firstPtsMs is num &&
          lastPtsMs is num &&
          minimumStepMs is num &&
          maximumStepMs is num &&
          frameCount > 1 &&
          lastPtsMs > firstPtsMs &&
          minimumStepMs > 0 &&
          (maximumStepMs - minimumStepMs).abs() < 0.1) {
        final fps = (frameCount - 1) * 1000.0 / (lastPtsMs - firstPtsMs);

        if (fps >= 1 && fps <= 240 && mounted) {
          setState(() {
            _videoFps = fps;
          });
          debugPrint('VIDEO FPS DETECTED fps=$_videoFps');
        }
      }
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
        fps: 60,
      );

      _cameraController = controller;
      _initializeCameraFuture = controller.initialize();

      await _initializeCameraFuture;

      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      const requestedZoom = 1.5;
      final zoom = requestedZoom.clamp(minZoom, maxZoom).toDouble();

      await controller.setZoomLevel(zoom);

      debugPrint(
        'CAMERA ZOOM requested=$requestedZoom '
        'applied=$zoom min=$minZoom max=$maxZoom',
      );

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

  Future<void> _captureInitialSetupImage() async {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized || _isRecording) {
      _showMessage("カメラの準備ができていません。");
      return;
    }
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      debugPrint("INITIAL SETUP IMAGE bytes=${bytes.length}");
      final imageInfo = ImageInspector.inspect(bytes);
      debugPrint(
        "INITIAL SETUP INSPECT width=${imageInfo?.width} height=${imageInfo?.height} ballCandidates=${imageInfo?.ballCandidateCount}",
      );
      final markers = MarkerDetector.detect(bytes);
      debugPrint("INITIAL SETUP MARKERS count=${markers.length}");
      if (imageInfo == null || !mounted) return;
      await _showInitialSetupDialog(bytes, Duration.zero, imageInfo, markers);
      _showMessage("初期設定用の画像を取得しました。");
    } catch (error) {
      _showMessage("初期設定用の画像取得に失敗しました。\n$error");
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

      await _readNativeFrameImage(videoFile.path, frameIndex: 0);

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

  Future<void> _selectVideo() async {
    if (_isRecording || _isAnalyzingVideo) {
      return;
    }

    try {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);

      if (video == null || !mounted) {
        return;
      }

      await _readNativeFrameMetadata(video.path);
      await _initializeVideoPlayer(video);

      if (!mounted) {
        return;
      }

      setState(() {
        _recordedVideoPath = video.path;
        _analysisResultMessage = null;
        _putterTrackingReport = null;
      });

      _showMessage('動画を読み込みました。');
    } catch (error) {
      debugPrint('VIDEO PICK ERROR $error');
      if (mounted) {
        _showMessage('動画を読み込めませんでした: $error');
      }
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

    final frameIndex =
        (position.inMicroseconds * _videoFps / Duration.microsecondsPerSecond)
            .round();

    try {
      final frame = await FrameExtractor.extractFrameByIndex(
        videoPath: videoPath,
        frameIndex: frameIndex,
      );

      if (!mounted) {
        return;
      }

      if (frame == null || frame.imageBytes.isEmpty) {
        _showMessage('フレーム画像を取得できませんでした。');
        return;
      }

      final imageBytes = frame.imageBytes;
      final actualPosition = frame.position;

      debugPrint(
        'CAPTURE NATIVE FRAME '
        'requestedFrame=$frameIndex '
        'playerMs=${position.inMilliseconds} '
        'actualMs=${actualPosition.inMilliseconds}',
      );

      final imageInfo = ImageInspector.inspect(
        imageBytes,
        debugFrameIndex: frameIndex,
      );
      GreenMarkerDiagnostic.inspect(imageBytes, frameIndex: frameIndex);
      PinkMarkerDiagnostic.inspect(imageBytes, frameIndex: frameIndex);

      final putterCandidates = PutterDetector.detect(
        imageBytes,
        frameIndex: frameIndex,
      );

      debugPrint(
        'VIDEO FRAME PUTTER DETECTION '
        'frameIndex=$frameIndex '
        'count=${putterCandidates.length} '
        'best=${putterCandidates.isEmpty ? null : putterCandidates.first}',
      );

      final markers = MarkerDetector.detect(imageBytes);

      if (imageInfo == null) {
        _showMessage('フレーム画像を読み込めませんでした。');
        return;
      }
      _frameAnalysisCount++;

      final trackedBall = _ballTracker.track(
        frameIndex: _frameAnalysisCount,
        timestamp: actualPosition,
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
      await _showInitialSetupDialog(
        imageBytes,
        actualPosition,
        imageInfo,
        markers,
      );
    } catch (error) {
      _showMessage('フレーム画像の取得中にエラーが発生しました。\n$error');
    }
  }

  Future<void> _showInitialSetupDialog(
    Uint8List imageBytes,
    Duration actualPosition,
    ImageInfoResult imageInfo,
    List<MarkerCandidate> markers,
  ) async {
    final largestBlob = imageInfo.largestBlob;
    final bestBallCandidate = imageInfo.bestBallCandidate;
    debugPrint(
      'PREVIEW SAVED MARKERS '
      'count=${_confirmedMarkerPositions?.length ?? 0} '
      'positions=$_confirmedMarkerPositions',
    );

    final confirmedSetup = await showDialog<FrameSetupResult>(
      context: context,
      builder: (context) {
        return FramePreviewDialog(
          imageBytes: imageBytes,
          position: actualPosition,
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
          confirmedMarkerPositions: _confirmedMarkerPositions,
          markers: markers
              .map(
                (marker) => MarkerViewData(
                  centerX: marker.centerX,
                  centerY: marker.centerY,
                  width: marker.width,
                  height: marker.height,
                  position: marker.position.name,
                ),
              )
              .toList(),
        );
      },
    );

    if (confirmedSetup != null) {
      final confirmedMarkers = confirmedSetup.markerPositions;
      _confirmedMarkerPositions = Map<String, Offset>.from(confirmedMarkers);
      _confirmedBallPosition = confirmedSetup.ballPosition;

      debugPrint('CONFIRMED MARKERS count=${confirmedMarkers.length}');
      for (final entry in confirmedMarkers.entries) {
        debugPrint(
          'CONFIRMED MARKER ${entry.key} '
          'x=${entry.value.dx} y=${entry.value.dy}',
        );
      }

      if (_confirmedBallPosition != null) {
        debugPrint(
          'CONFIRMED BALL '
          'x=${_confirmedBallPosition!.dx.toStringAsFixed(1)} '
          'y=${_confirmedBallPosition!.dy.toStringAsFixed(1)}',
        );
      } else {
        debugPrint('BALL POSITION NOT CONFIRMED');
      }
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
      _putterTracker.reset();
      _trackingSession.clear();
      _putterTrackingSession.clear();
      _frameAnalysisCount = 0;
      var putterTrackedFrames = 0;
      var putterDetectedFrames = 0;
      final putterMissedFrameIndices = <int>[];
      final putterTrackingFailedIndices = <int>[];
      var putterCurrentStreak = 0;
      var putterLongestStreak = 0;
      var putterTrackingGaps = 0;
      int? putterFirstFrame;
      int? putterLastFrame;

      MarkerCalibrationResult? calibration;

      final duration = videoController.value.duration;

      final analysisStopwatch = Stopwatch()..start();
      var imageInspectMicroseconds = 0;

      await for (final frame in FrameExtractor.extractFrames(
        videoPath: videoPath,
        duration: duration,
      )) {
        final imageInspectStopwatch = Stopwatch()..start();
        final imageInfo = ImageInspector.inspect(
          frame.imageBytes,
          debugFrameIndex: DebugLog.verbose ? _frameAnalysisCount + 1 : null,
        );
        imageInspectStopwatch.stop();
        imageInspectMicroseconds += imageInspectStopwatch.elapsedMicroseconds;

        if (imageInfo == null) {
          continue;
        }

        if (_frameAnalysisCount == 0) {
          final saved = _confirmedMarkerPositions;
          final markerPositions = MarkerPosition.values;

          final markers =
              saved != null &&
                  markerPositions.every((p) => saved.containsKey(p.name))
              ? [
                  for (final position in markerPositions)
                    MarkerCandidate(
                      position: position,
                      centerX: saved[position.name]!.dx,
                      centerY: saved[position.name]!.dy,
                      width: 1,
                      height: 1,
                      pixelCount: 1,
                    ),
                ]
              : MarkerDetector.detect(frame.imageBytes);

          debugPrint(
            'CALIBRATION MARKER SOURCE '
            '${saved != null && markerPositions.every((p) => saved.containsKey(p.name)) ? "manual" : "automatic"}',
          );

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

            final leftVerticalScale =
                calibration.leftDistancePixels /
                MarkerCalibration.verticalMarkerDistanceMillimeters;

            final rightVerticalScale =
                calibration.rightDistancePixels /
                MarkerCalibration.verticalMarkerDistanceMillimeters;

            debugPrint(
              'CALIBRATION VERTICAL '
              'left=${calibration.leftDistancePixels.toStringAsFixed(2)}px '
              'leftScale=${leftVerticalScale.toStringAsFixed(4)}px/mm',
            );

            debugPrint(
              'CALIBRATION VERTICAL '
              'right=${calibration.rightDistancePixels.toStringAsFixed(2)}px '
              'rightScale=${rightVerticalScale.toStringAsFixed(4)}px/mm',
            );

            debugPrint(
              'CALIBRATION '
              'scaleDifference=${(calibration.scaleDifferenceRatio * 100).toStringAsFixed(1)}%',
            );
          }
        }

        _frameAnalysisCount++;

        final putterCandidates = PutterDetector.detect(
          frame.imageBytes,
          frameIndex: _frameAnalysisCount,
        );

        if (putterCandidates.isNotEmpty) {
          putterDetectedFrames++;
        } else {
          putterMissedFrameIndices.add(_frameAnalysisCount);
        }

        final trackedPutter = _putterTracker.track(
          frameIndex: _frameAnalysisCount,
          timestamp: frame.position,
          candidates: putterCandidates,
        );

        if (trackedPutter == null && putterCandidates.isNotEmpty) {
          putterTrackingFailedIndices.add(_frameAnalysisCount);
        }

        if (trackedPutter != null) {
          _putterTrackingSession.add(trackedPutter);
          putterTrackedFrames++;
          putterCurrentStreak++;
          putterFirstFrame ??= _frameAnalysisCount;
          putterLastFrame = _frameAnalysisCount;

          if (putterCurrentStreak > putterLongestStreak) {
            putterLongestStreak = putterCurrentStreak;
          }
        } else {
          if (putterCurrentStreak > 0) {
            putterTrackingGaps++;
          }
          putterCurrentStreak = 0;
        }

        DebugLog.print(
          'AUTO PUTTER TRACKING '
          'frame=$_frameAnalysisCount '
          'time=${frame.position.inMilliseconds}ms '
          'result=$trackedPutter',
        );

        DebugLog.print(
          'AUTO PUTTER DETECTION '
          'frame=$_frameAnalysisCount '
          'time=${frame.position.inMilliseconds}ms '
          'count=${putterCandidates.length} '
          'best=${putterCandidates.isEmpty ? null : putterCandidates.first}',
        );

        if (_frameAnalysisCount <= 20) {
          DebugLog.print(
            'INITIAL CANDIDATES '
            'frame=$_frameAnalysisCount '
            'count=${imageInfo.ballCandidates.length}',
          );

          for (var i = 0; i < imageInfo.ballCandidates.length; i++) {
            final candidate = imageInfo.ballCandidates[i];

            DebugLog.print(
              'INITIAL CANDIDATE '
              'frame=$_frameAnalysisCount '
              'index=$i '
              'x=${candidate.centerX.toStringAsFixed(1)} '
              'y=${candidate.centerY.toStringAsFixed(1)} '
              'r=${candidate.radius.toStringAsFixed(1)} '
              'confidence=${candidate.confidence.toStringAsFixed(3)} '
              'combined=${candidate.isCombinedRedYellow} '
              'motionBlur=${candidate.isMotionBlur}',
            );
          }
        }

        final trackedBall = _ballTracker.track(
          frameIndex: _frameAnalysisCount,
          timestamp: frame.position,
          candidates: imageInfo.ballCandidates,
        );

        if (trackedBall == null) {
          final largestBlob = imageInfo.largestBlob;

          DebugLog.print(
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

        if (_trackingSession.length == 0 && _confirmedBallPosition != null) {
          final dx = trackedBall.centerX - _confirmedBallPosition!.dx;
          final dy = trackedBall.centerY - _confirmedBallPosition!.dy;
          final distance = Offset(dx, dy).distance;

          DebugLog.print(
            'INITIAL BALL POSITION CHECK '
            'confirmedX=${_confirmedBallPosition!.dx.toStringAsFixed(1)} '
            'confirmedY=${_confirmedBallPosition!.dy.toStringAsFixed(1)} '
            'trackedX=${trackedBall.centerX.toStringAsFixed(1)} '
            'trackedY=${trackedBall.centerY.toStringAsFixed(1)} '
            'distance=${distance.toStringAsFixed(1)}px',
          );
        }

        _trackingSession.add(trackedBall);

        final metrics = _trackingSession.latestMetrics();
        final smoothedMetrics = _trackingSession.latestSmoothedMetrics();

        DebugLog.print(
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

          DebugLog.print(
            'BALL SCALE '
            'frame=${trackedBall.frameIndex} '
            'y=${trackedBall.centerY.toStringAsFixed(1)} '
            'scale=${pixelsPerMillimeter.toStringAsFixed(4)}px/mm',
          );
        }

        if (metrics != null) {
          DebugLog.print(
            'AutoTrackingMetrics '
            'dt=${metrics.deltaTimeSeconds.toStringAsFixed(4)}s '
            'distance=${metrics.distancePixels.toStringAsFixed(2)}px '
            'speed=${metrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
          );

          if (calibration != null &&
              _confirmedBallPosition != null &&
              _trackingSession.length >= 2) {
            final previousBall =
                _trackingSession.balls[_trackingSession.length - 2];

            final realSpeed = RealSpeedCalculator.calculate(
              calibration: calibration,
              previous: previousBall,
              current: trackedBall,
              metrics: metrics,
            );

            if (realSpeed != null) {
              DebugLog.print(
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
          DebugLog.print(
            'AutoTrackingSmoothed '
            'dt=${smoothedMetrics.deltaTimeSeconds.toStringAsFixed(4)}s '
            'distance=${smoothedMetrics.distancePixels.toStringAsFixed(2)}px '
            'speed=${smoothedMetrics.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
          );
        }
      }

      analysisStopwatch.stop();
      debugPrint(
        "IMAGE INSPECT TIMING totalMs=${(imageInspectMicroseconds / 1000).toStringAsFixed(1)} averageMs=${_frameAnalysisCount == 0 ? 0 : (imageInspectMicroseconds / 1000 / _frameAnalysisCount).toStringAsFixed(2)}",
      );
      debugPrint(
        'VIDEO ANALYSIS TIMING '
        'frames=$_frameAnalysisCount '
        'elapsedMs=${analysisStopwatch.elapsedMilliseconds} '
        'elapsedSeconds=${(analysisStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}',
      );

      DebugLog.print(
        'AutoTracking finished '
        'frames=$_frameAnalysisCount '
        'tracked=${_trackingSession.length}',
      );

      debugPrint(
        'PUTTER TRACKING SUMMARY '
        'detected=$putterDetectedFrames '
        'tracked=$putterTrackedFrames '
        'total=$_frameAnalysisCount '
        'longest=$putterLongestStreak '
        'gaps=$putterTrackingGaps '
        'first=$putterFirstFrame '
        'last=$putterLastFrame',
      );

      debugPrint(
        "PUTTER MISSED FRAMES "
        "count=${putterMissedFrameIndices.length} "
        "indices=$putterMissedFrameIndices",
      );

      debugPrint(
        'PUTTER TRACKING FAILED FRAMES '
        'count=${putterTrackingFailedIndices.length} '
        'indices=$putterTrackingFailedIndices',
      );

      _putterTrackingReport =
          'パター追跡結果\\n'
          '総フレーム: $_frameAnalysisCount\\n'
          '検出成功: $putterDetectedFrames\\n'
          '追跡成功: $putterTrackedFrames\\n'
          '検出失敗 (${putterMissedFrameIndices.length}): '
          '$putterMissedFrameIndices\\n'
          '追跡失敗 (${putterTrackingFailedIndices.length}): '
          '$putterTrackingFailedIndices';

      final putterMetrics = _putterTrackingSession.latestMetrics();

      debugPrint(
        'PUTTER SPEED '
        'tracked=${_putterTrackingSession.length} '
        'speed=${putterMetrics?.speedPixelsPerSecond.toStringAsFixed(2) ?? "N/A"}px/s',
      );

      final putterPeak = _putterTrackingSession.peakSpeed();

      debugPrint(
        'PUTTER PEAK SPEED '
        'previousFrame=${putterPeak?.previousFrame ?? "N/A"} '
        'frame=${putterPeak?.currentFrame ?? "N/A"} '
        'speed=${putterPeak?.speedPixelsPerSecond.toStringAsFixed(2) ?? "N/A"}px/s',
      );

      if (putterPeak != null) {
        debugPrint('===== PUTTER PEAK CONTEXT =====');

        final putterSpeeds = _putterTrackingSession.allFrameSpeeds();

        for (final item in putterSpeeds) {
          if ((item.currentFrame - putterPeak.currentFrame).abs() <= 5) {
            debugPrint(
              'PUTTER FRAME SPEED '
              'previousFrame=${item.previousFrame} '
              'frame=${item.currentFrame} '
              'speed=${item.speedPixelsPerSecond.toStringAsFixed(2)}px/s',
            );
          }
        }

        debugPrint('===== END PUTTER PEAK CONTEXT =====');
      }

      final peak = _trackingSession.peakMetrics();
      final smoothedPeak = _trackingSession.smoothedPeakMetrics();

      RealSpeedResult? smoothedRealSpeed;

      if (calibration != null &&
          _confirmedBallPosition != null &&
          smoothedPeak != null) {
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
          if (_putterTrackingReport != null)
            SizedBox(
              height: 180,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(_putterTrackingReport!),
              ),
            ),
          if (_videoPlayerController == null)
            ElevatedButton.icon(
              onPressed: _captureInitialSetupImage,
              icon: const Icon(Icons.tune),
              label: const Text("初期設定"),
            ),
          ElevatedButton.icon(
            onPressed: (_isRecording || _isAnalyzingVideo)
                ? null
                : _selectVideo,
            icon: const Icon(Icons.video_library),
            label: const Text("動画を選択"),
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
