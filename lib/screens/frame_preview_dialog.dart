import 'dart:typed_data';

import 'package:flutter/material.dart';

class FramePreviewDialog extends StatelessWidget {
  const FramePreviewDialog({
    super.key,
    required this.imageBytes,
    required this.position,
    required this.imageWidth,
    required this.imageHeight,
    required this.centerX,
    required this.centerY,
    required this.centerRed,
    required this.centerGreen,
    required this.centerBlue,
    required this.centerHue,
    required this.centerSaturation,
    required this.centerValue,
    required this.centerIsYellow,
    required this.centerIsRed,
    required this.totalPixels,
    required this.yellowPixels,
    required this.redPixels,
    required this.targetColorPixels,
    required this.yellowRatio,
    required this.redRatio,
  });

  final Uint8List imageBytes;
  final Duration position;

  final int imageWidth;
  final int imageHeight;

  final int centerX;
  final int centerY;

  final int centerRed;
  final int centerGreen;
  final int centerBlue;

  final double centerHue;
  final double centerSaturation;
  final double centerValue;

  final bool centerIsYellow;
  final bool centerIsRed;

  final int totalPixels;
  final int yellowPixels;
  final int redPixels;
  final int targetColorPixels;

  final double yellowRatio;
  final double redRatio;

  String _formatPosition(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = value.inMilliseconds
        .remainder(1000)
        .toString()
        .padLeft(3, '0');

    return '$minutes:$seconds.$milliseconds';
  }

  String _formatPercent(double ratio) {
    return '${(ratio * 100).toStringAsFixed(3)}%';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('取得フレーム ${_formatPosition(position)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$imageWidth × $imageHeight px'),
            const SizedBox(height: 4),
            Text(
              '中央座標: ($centerX, $centerY)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '中央 RGB: $centerRed, $centerGreen, $centerBlue',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '中央 HSV: '
              '${centerHue.toStringAsFixed(1)}, '
              '${centerSaturation.toStringAsFixed(3)}, '
              '${centerValue.toStringAsFixed(3)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '中央色判定: '
              '${centerIsYellow ? '黄色 ' : ''}'
              '${centerIsRed ? '赤' : ''}'
              '${!centerIsYellow && !centerIsRed ? '対象外' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 20),
            Text(
              '全画素数: $totalPixels',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '黄色画素数: $yellowPixels '
              '(${_formatPercent(yellowRatio)})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '赤色画素数: $redPixels '
              '(${_formatPercent(redRatio)})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '対象色合計: $targetColorPixels',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
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
          ],
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
