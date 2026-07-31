import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  String? _errorMessage;
  bool _isRecording = false;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = '利用できるカメラが見つかりません。';
        });
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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '録画を開始できませんでした。\n'
            '${error.code}: ${error.description ?? ''}',
          ),
        ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('録画を保存しました。\n${videoFile.path}')),
        );
      }
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '録画を停止できませんでした。\n'
            '${error.code}: ${error.description ?? ''}',
          ),
        ),
      );
    }
  }

  Future<void> _initializeVideoPlayer(XFile videoFile) async {
    await _videoPlayerController?.dispose();

    final controller = VideoPlayerController.file(File(videoFile.path));

    await controller.initialize();

    _videoPlayerController = controller;

    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

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

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カメラ確認')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
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
        },
        child: Icon(
          _videoPlayerController != null &&
                  _videoPlayerController!.value.isInitialized
              ? (_videoPlayerController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow)
              : (_isRecording ? Icons.stop : Icons.videocam),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    final controller = _cameraController;
    final initializeFuture = _initializeCameraFuture;

    if (controller == null || initializeFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            controller.value.isInitialized) {
          if (_videoPlayerController != null &&
              _videoPlayerController!.value.isInitialized) {
            final videoController = _videoPlayerController!;

            return SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: videoController.value.aspectRatio,
                        child: VideoPlayer(videoController),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 80, 16),
                    child: VideoProgressIndicator(
                      videoController,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(child: CameraPreview(controller));
        }

        if (snapshot.hasError) {
          return const Center(child: Text('カメラを表示できませんでした。'));
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
