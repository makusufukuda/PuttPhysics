import 'dart:typed_data';

import 'package:flutter/material.dart';

class FramePreviewDialog extends StatelessWidget {
  const FramePreviewDialog({
    super.key,
    required this.imageBytes,
    required this.position,
  });

  final Uint8List imageBytes;
  final Duration position;

  String _formatPosition(Duration value) {
    final minutes =
        value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds =
        value.inMilliseconds.remainder(1000).toString().padLeft(3, '0');

    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('取得フレーム ${_formatPosition(position)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 600,
        ),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
