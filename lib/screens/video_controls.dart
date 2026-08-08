import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoControls extends StatelessWidget {
  const VideoControls({
    super.key,
    required this.controller,
    required this.videoFps,
    this.onPreviousFrame,
    this.onNextFrame,
    this.onCaptureFrame,
    this.onAnalyzeVideo,
  });

  final VideoPlayerController controller;
  final double videoFps;
  final VoidCallback? onPreviousFrame;
  final VoidCallback? onNextFrame;
  final VoidCallback? onCaptureFrame;
  final VoidCallback? onAnalyzeVideo;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = duration.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');

    return '$minutes:$seconds.$milliseconds';
  }

  int _currentFrame(Duration position) {
    return (position.inMicroseconds * videoFps / Duration.microsecondsPerSecond)
        .round();
  }

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final frameNumber = _currentFrame(position);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          Text(
            '${_formatDuration(position)} / ${_formatDuration(duration)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Frame $frameNumber / ${videoFps.toStringAsFixed(0)} fps',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '1コマ戻る',
                icon: const Icon(Icons.skip_previous),
                onPressed: onPreviousFrame,
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: onCaptureFrame,
                icon: const Icon(Icons.photo_camera),
                label: const Text('画像取得'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onAnalyzeVideo,
                icon: const Icon(Icons.analytics),
                label: const Text('動画解析'),
              ),
              const SizedBox(width: 20),
              IconButton(
                tooltip: '1コマ進む',
                icon: const Icon(Icons.skip_next),
                onPressed: onNextFrame,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
