import 'dart:typed_data';

import 'package:flutter/material.dart';

class BallCandidateViewData {
  const BallCandidateViewData({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.confidence,
  });

  final double centerX;
  final double centerY;
  final double radius;
  final double confidence;
}

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
    required this.blobCount,
    required this.largestBlobPixelCount,
    required this.largestBlobCentroidX,
    required this.largestBlobCentroidY,
    required this.largestBlobMinX,
    required this.largestBlobMinY,
    required this.largestBlobWidth,
    required this.largestBlobHeight,
    required this.ballCandidateCount,
    required this.bestCandidateCenterX,
    required this.bestCandidateCenterY,
    required this.bestCandidateRadius,
    required this.bestCandidateConfidence,
    required this.ballCandidates,
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

  final int blobCount;
  final int? largestBlobPixelCount;
  final double? largestBlobCentroidX;
  final double? largestBlobCentroidY;
  final int? largestBlobMinX;
  final int? largestBlobMinY;
  final int? largestBlobWidth;
  final int? largestBlobHeight;

  final int ballCandidateCount;
  final double? bestCandidateCenterX;
  final double? bestCandidateCenterY;
  final double? bestCandidateRadius;
  final double? bestCandidateConfidence;
  final List<BallCandidateViewData> ballCandidates;

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
    final hasBestCandidate =
        bestCandidateCenterX != null &&
        bestCandidateCenterY != null &&
        bestCandidateRadius != null &&
        bestCandidateConfidence != null;
    final hasLargestBlob =
        largestBlobPixelCount != null &&
        largestBlobCentroidX != null &&
        largestBlobCentroidY != null &&
        largestBlobMinX != null &&
        largestBlobMinY != null &&
        largestBlobWidth != null &&
        largestBlobHeight != null;

    return AlertDialog(
      title: Text('取得フレーム ${_formatPosition(position)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
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
            const Divider(height: 20),
            Text(
              'Blob候補数: $blobCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (hasLargestBlob) ...[
              Text(
                '最大Blob画素数: $largestBlobPixelCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '重心: '
                '(${largestBlobCentroidX!.toStringAsFixed(1)}, '
                '${largestBlobCentroidY!.toStringAsFixed(1)})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '外接矩形: '
                '$largestBlobWidth × $largestBlobHeight px',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              const Divider(height: 20),
            Text(
              'BallCandidate候補数: $ballCandidateCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (ballCandidates.isNotEmpty)
              CustomPaint(
                painter: _AllBallCandidatePainter(
                  sourceWidth: imageWidth,
                  sourceHeight: imageHeight,
                  ballCandidates: ballCandidates,
                ),
              ),

            if (hasBestCandidate) ...[
              Text(
                '最良候補の中心: '
                '(${bestCandidateCenterX!.toStringAsFixed(1)}, '
                '${bestCandidateCenterY!.toStringAsFixed(1)})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '推定半径: ${bestCandidateRadius!.toStringAsFixed(1)} px',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '信頼度: '
                '${bestCandidateConfidence!.toStringAsFixed(3)} '
                '(${(bestCandidateConfidence! * 100).toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text('最良候補: なし', style: Theme.of(context).textTheme.bodySmall),

            Text('最大Blob: なし', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: AspectRatio(
                  aspectRatio: imageWidth / imageHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        imageBytes,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      if (hasLargestBlob)
                        CustomPaint(
                          painter: _BlobOverlayPainter(
                            sourceWidth: imageWidth,
                            sourceHeight: imageHeight,
                            minX: largestBlobMinX!,
                            minY: largestBlobMinY!,
                            blobWidth: largestBlobWidth!,
                            blobHeight: largestBlobHeight!,
                            centroidX: largestBlobCentroidX!,
                            centroidY: largestBlobCentroidY!,
                          ),
                        ),

                      if (hasBestCandidate)
                        CustomPaint(
                          painter: _BallCandidatePainter(
                            sourceWidth: imageWidth,
                            sourceHeight: imageHeight,
                            centerX: bestCandidateCenterX!,
                            centerY: bestCandidateCenterY!,
                            radius: bestCandidateRadius!,
                            confidence: bestCandidateConfidence!,
                          ),
                        ),
                    ],
                  ),
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

class _BlobOverlayPainter extends CustomPainter {
  const _BlobOverlayPainter({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.minX,
    required this.minY,
    required this.blobWidth,
    required this.blobHeight,
    required this.centroidX,
    required this.centroidY,
  });

  final int sourceWidth;
  final int sourceHeight;

  final int minX;
  final int minY;
  final int blobWidth;
  final int blobHeight;

  final double centroidX;
  final double centroidY;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final blobRect = Rect.fromLTWH(
      minX * scaleX,
      minY * scaleY,
      blobWidth * scaleX,
      blobHeight * scaleY,
    );

    final rectanglePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(blobRect, rectanglePaint);

    final center = Offset(centroidX * scaleX, centroidY * scaleY);

    final centerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5, centerPaint);

    final crossPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      crossPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BlobOverlayPainter oldDelegate) {
    return sourceWidth != oldDelegate.sourceWidth ||
        sourceHeight != oldDelegate.sourceHeight ||
        minX != oldDelegate.minX ||
        minY != oldDelegate.minY ||
        blobWidth != oldDelegate.blobWidth ||
        blobHeight != oldDelegate.blobHeight ||
        centroidX != oldDelegate.centroidX ||
        centroidY != oldDelegate.centroidY;
  }
}

class _BallCandidatePainter extends CustomPainter {
  const _BallCandidatePainter({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.confidence,
  });

  final int sourceWidth;
  final int sourceHeight;
  final double centerX;
  final double centerY;
  final double radius;
  final double confidence;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final center = Offset(centerX * scaleX, centerY * scaleY);

    final displayedRadius = radius * ((scaleX + scaleY) / 2);

    final circlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, displayedRadius, circlePaint);

    final crossPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      crossPaint,
    );

    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      crossPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(center.dx + displayedRadius + 6, center.dy - displayedRadius),
    );
  }

  @override
  bool shouldRepaint(covariant _BallCandidatePainter oldDelegate) {
    return sourceWidth != oldDelegate.sourceWidth ||
        sourceHeight != oldDelegate.sourceHeight ||
        centerX != oldDelegate.centerX ||
        centerY != oldDelegate.centerY ||
        radius != oldDelegate.radius ||
        confidence != oldDelegate.confidence;
  }
}

class _AllBallCandidatePainter extends CustomPainter {
  const _AllBallCandidatePainter({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.ballCandidates,
  });

  final int sourceWidth;
  final int sourceHeight;
  final List<BallCandidateViewData> ballCandidates;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final paint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < ballCandidates.length; i++) {
      final candidate = ballCandidates[i];

      final center = Offset(
        candidate.centerX * scaleX,
        candidate.centerY * scaleY,
      );

      final radius = candidate.radius * ((scaleX + scaleY) / 2);

      canvas.drawCircle(center, radius, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1} ${(candidate.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(canvas, Offset(center.dx + radius + 4, center.dy));
    }
  }

  @override
  bool shouldRepaint(covariant _AllBallCandidatePainter oldDelegate) {
    return ballCandidates != oldDelegate.ballCandidates;
  }
}
