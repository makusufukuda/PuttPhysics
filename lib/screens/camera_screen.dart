import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_player_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const double _videoFps = 30.0;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  VideoPlayerController? _videoPlayerController;

  String? _errorMessage;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleMainButton,
        child: Icon(_mainButtonIcon()),
      ),
    );
  }
}
