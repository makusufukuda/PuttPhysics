import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_controls.dart';

class VideoPlayerView extends StatelessWidget {
  const VideoPlayerView({
    super.key,
    required this.cameraController,
    required this.initializeCameraFuture,
    required this.errorMessage,
    required this.videoController,
    required this.videoFps,
    required this.onPreviousFrame,
    required this.onNextFrame,
    required this.onCaptureFrame,
    required this.onAnalyzeVideo,
    required this.isAnalyzingVideo,
  });

  final CameraController? cameraController;
  final Future<void>? initializeCameraFuture;
  final String? errorMessage;
  final VideoPlayerController? videoController;
  final double videoFps;
  final VoidCallback onPreviousFrame;
  final VoidCallback onNextFrame;
  final VoidCallback onCaptureFrame;
  final VoidCallback onAnalyzeVideo;
  final bool isAnalyzingVideo;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    final camera = cameraController;
    final cameraFuture = initializeCameraFuture;

    if (camera == null || cameraFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: cameraFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('カメラを表示できませんでした。'));
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !camera.value.isInitialized) {
          return const Center(child: CircularProgressIndicator());
        }

        final video = videoController;

        if (video != null && video.value.isInitialized) {
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: video.value.aspectRatio,
                      child: VideoPlayer(video),
                    ),
                  ),
                ),
                VideoControls(
                  controller: video,
                  videoFps: videoFps,
                  onPreviousFrame: onPreviousFrame,
                  onNextFrame: onNextFrame,
                  onCaptureFrame: onCaptureFrame,
                  onAnalyzeVideo: onAnalyzeVideo,
                  isAnalyzingVideo: isAnalyzingVideo,
                ),
              ],
            ),
          );
        }

        return Center(child: CameraPreview(camera));
      },
    );
  }
}
