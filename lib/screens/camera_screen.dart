import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/frame_extractor.dart';
import '../services/image_inspector.dart';
import '../models/tracking_session.dart';
import '../services/ball_tracker.dart';
import 'frame_preview_dialog.dart';
import 'video_player_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final controller = _cameraController;

    if (controller == null) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        await controller.dispose();
        _cameraController = null;
        _initializeCameraFuture = null;
        break;

      case AppLifecycleState.resumed:
        if (_cameraController == null) {
          await _initializeCamera();
        }
        break;

      case AppLifecycleState.detached:
        break;
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
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
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

      _recordedVideoPath = videoFile.path;

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
      if (trackedBall != null) {
        _trackingSession.add(trackedBall);
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
      body: VideoPlayerView(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleMainButton,
        child: Icon(_mainButtonIcon()),
      ),
    );
  }
}
