import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/color_detector.dart';
import '../services/initial_ball_search_region.dart';
import 'marker_precision_dialog.dart';

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

class MarkerViewData {
  const MarkerViewData({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
    required this.position,
  });

  final double centerX;
  final double centerY;
  final int width;
  final int height;
  final String position;
}

class FrameSetupResult {
  const FrameSetupResult({
    required this.markerPositions,
    required this.ballPosition,
  });

  final Map<String, Offset> markerPositions;
  final Offset? ballPosition;
}

class FramePreviewDialog extends StatefulWidget {
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
    required this.markers,
    this.confirmedMarkerPositions,
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
  final List<MarkerViewData> markers;
  final Map<String, Offset>? confirmedMarkerPositions;

  @override
  State<FramePreviewDialog> createState() => _FramePreviewDialogState();
}

class _FramePreviewDialogState extends State<FramePreviewDialog> {
  Offset? _tappedImagePosition;

  // Ball center confirmed by the user, in original image coordinates.
  Offset? _editableBallPosition;

  // True only after the user confirms the ball center.
  bool _isBallPositionConfirmed = false;

  // マーカー確定後にボール位置の設定へ進む。
  bool _areMarkersConfirmed = false;

  // User-confirmed marker positions, stored in original image coordinates.
  late final Map<String, Offset> _editableMarkerPositions;

  // Marker currently selected for manual position correction.
  String? _selectedMarkerPosition;

  @override
  void initState() {
    super.initState();

    // Automatic detection is only a starting point.
    // The user must confirm the ball position separately.
    if (widget.bestCandidateCenterX != null &&
        widget.bestCandidateCenterY != null) {
      _editableBallPosition = Offset(
        widget.bestCandidateCenterX!,
        widget.bestCandidateCenterY!,
      );
    }

    _editableMarkerPositions = {
      for (final marker in widget.markers)
        marker.position: Offset(marker.centerX, marker.centerY),
      if (widget.confirmedMarkerPositions != null)
        ...widget.confirmedMarkerPositions!,
    };
  }

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

  Future<void> _handleImageTap(Offset localPosition, Size displaySize) async {
    if (_selectedMarkerPosition == null) {
      if (!_areMarkersConfirmed) return;

      final x = (localPosition.dx / displaySize.width * widget.imageWidth)
          .clamp(0.0, widget.imageWidth.toDouble() - 1);
      final y = (localPosition.dy / displaySize.height * widget.imageHeight)
          .clamp(0.0, widget.imageHeight.toDouble() - 1);

      setState(() {
        _editableBallPosition = Offset(x, y);
        _isBallPositionConfirmed = false;
        _tappedImagePosition = Offset(x, y);
      });

      debugPrint(
        'BALL POSITION SELECTED '
        'x=${x.toStringAsFixed(1)} '
        'y=${y.toStringAsFixed(1)}',
      );
      return;
    }

    final markerPosition = _selectedMarkerPosition!;

    final x = (localPosition.dx / displaySize.width * widget.imageWidth).clamp(
      0.0,
      widget.imageWidth.toDouble() - 1,
    );
    final y = (localPosition.dy / displaySize.height * widget.imageHeight)
        .clamp(0.0, widget.imageHeight.toDouble() - 1);

    final confirmedPosition = await Navigator.of(context, rootNavigator: true)
        .push<Offset>(
          MaterialPageRoute(
            builder: (context) => MarkerPrecisionDialog(
              imageBytes: widget.imageBytes,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
              initialPosition: Offset(x, y),
            ),
          ),
        );

    if (!mounted || confirmedPosition == null) return;

    setState(() {
      _editableMarkerPositions[markerPosition] = confirmedPosition;
      _tappedImagePosition = confirmedPosition;
    });

    debugPrint(
      'PRECISION MARKER CONFIRMED '
      'marker=$markerPosition '
      'x=${confirmedPosition.dx.toStringAsFixed(1)} '
      'y=${confirmedPosition.dy.toStringAsFixed(1)}',
    );
  }

  Future<void> _confirmBallPosition() async {
    final initialPosition =
        _editableBallPosition ??
        Offset(widget.imageWidth / 2, widget.imageHeight / 2);

    final confirmedPosition = await Navigator.of(context, rootNavigator: true)
        .push<Offset>(
          MaterialPageRoute(
            builder: (context) => MarkerPrecisionDialog(
              imageBytes: widget.imageBytes,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
              initialPosition: initialPosition,
              title: 'ボール中心の精密調整',
            ),
          ),
        );

    if (!mounted || confirmedPosition == null) return;

    setState(() {
      _editableBallPosition = confirmedPosition;
      _isBallPositionConfirmed = true;
      _selectedMarkerPosition = null;
      _tappedImagePosition = confirmedPosition;
    });

    debugPrint(
      'PRECISION BALL CONFIRMED '
      'x=${confirmedPosition.dx.toStringAsFixed(1)} '
      'y=${confirmedPosition.dy.toStringAsFixed(1)}',
    );
  }

  void _inspectTappedPixel(Offset localPosition, Size displaySize) {
    final x = (localPosition.dx / displaySize.width * widget.imageWidth)
        .floor()
        .clamp(0, widget.imageWidth - 1);
    final y = (localPosition.dy / displaySize.height * widget.imageHeight)
        .floor()
        .clamp(0, widget.imageHeight - 1);

    setState(() {
      _tappedImagePosition = Offset(x.toDouble(), y.toDouble());

      // Marker positions will be updated only after
      // confirmation in the precision adjustment screen.
    });

    final image = img.decodeImage(widget.imageBytes);

    if (image == null) {
      debugPrint('TAP COLOR DIAGNOSTIC ERROR image decode failed');
      return;
    }

    final pixel = image.getPixel(x, y);

    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();

    final hsv = ColorDetector.rgbToHsv(red: red, green: green, blue: blue);

    var nearbyPixelCount = 0;
    var nearbyBluePixelCount = 0;

    final minX = (x - 10).clamp(0, image.width - 1);
    final maxX = (x + 10).clamp(0, image.width - 1);
    final minY = (y - 10).clamp(0, image.height - 1);
    final maxY = (y + 10).clamp(0, image.height - 1);

    for (var sampleY = minY; sampleY <= maxY; sampleY++) {
      for (var sampleX = minX; sampleX <= maxX; sampleX++) {
        nearbyPixelCount++;

        final nearbyPixel = image.getPixel(sampleX, sampleY);
        final nearbyHsv = ColorDetector.rgbToHsv(
          red: nearbyPixel.r.toInt(),
          green: nearbyPixel.g.toInt(),
          blue: nearbyPixel.b.toInt(),
        );

        final isBlue =
            nearbyHsv.hue >= 205 &&
            nearbyHsv.hue <= 255 &&
            nearbyHsv.saturation >= 0.20 &&
            nearbyHsv.value >= 0.15;

        if (isBlue) {
          nearbyBluePixelCount++;
        }
      }
    }

    debugPrint(
      'TAP COLOR DIAGNOSTIC '
      'x=$x y=$y '
      'RGB=$red,$green,$blue '
      'HSV=${hsv.hue.toStringAsFixed(1)},'
      '${hsv.saturation.toStringAsFixed(3)},'
      '${hsv.value.toStringAsFixed(3)}',
    );

    debugPrint(
      'TAP BLUE NEARBY '
      'center=$x,$y '
      'area=${maxX - minX + 1}x${maxY - minY + 1} '
      'bluePixels=$nearbyBluePixelCount/$nearbyPixelCount',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBestCandidate =
        widget.bestCandidateCenterX != null &&
        widget.bestCandidateCenterY != null &&
        widget.bestCandidateRadius != null &&
        widget.bestCandidateConfidence != null;
    final hasLargestBlob =
        widget.largestBlobPixelCount != null &&
        widget.largestBlobCentroidX != null &&
        widget.largestBlobCentroidY != null &&
        widget.largestBlobMinX != null &&
        widget.largestBlobMinY != null &&
        widget.largestBlobWidth != null &&
        widget.largestBlobHeight != null;

    return AlertDialog(
      title: Text('取得フレーム ${_formatPosition(widget.position)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color-tap diagnostic mode:
            // Hide the text diagnostics temporarily so the preview image
            // has enough room for accurate marker tapping.
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: AspectRatio(
                  aspectRatio: widget.imageWidth / widget.imageHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final displaySize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          _handleImageTap(details.localPosition, displaySize);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                            ),
                            if (_areMarkersConfirmed && hasLargestBlob)
                              CustomPaint(
                                painter: _BlobOverlayPainter(
                                  sourceWidth: widget.imageWidth,
                                  sourceHeight: widget.imageHeight,
                                  minX: widget.largestBlobMinX!,
                                  minY: widget.largestBlobMinY!,
                                  blobWidth: widget.largestBlobWidth!,
                                  blobHeight: widget.largestBlobHeight!,
                                  centroidX: widget.largestBlobCentroidX!,
                                  centroidY: widget.largestBlobCentroidY!,
                                ),
                              ),

                            if (_areMarkersConfirmed && hasBestCandidate)
                              CustomPaint(
                                painter: _BallCandidatePainter(
                                  sourceWidth: widget.imageWidth,
                                  sourceHeight: widget.imageHeight,
                                  centerX: widget.bestCandidateCenterX!,
                                  centerY: widget.bestCandidateCenterY!,
                                  radius: widget.bestCandidateRadius!,
                                  confidence: widget.bestCandidateConfidence!,
                                ),
                              ),
                            if (_editableMarkerPositions.isNotEmpty)
                              CustomPaint(
                                painter: _MarkerOverlayPainter(
                                  sourceWidth: widget.imageWidth,
                                  sourceHeight: widget.imageHeight,
                                  markers: [
                                    for (final entry
                                        in _editableMarkerPositions.entries)
                                      MarkerViewData(
                                        centerX: entry.value.dx,
                                        centerY: entry.value.dy,
                                        width: 16,
                                        height: 16,
                                        position: entry.key,
                                      ),
                                  ],
                                ),
                              ),
                            if (_tappedImagePosition != null)
                              CustomPaint(
                                painter: _TapPositionPainter(
                                  sourceWidth: widget.imageWidth,
                                  sourceHeight: widget.imageHeight,
                                  position: _tappedImagePosition!,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                for (final row in const [
                  [('topLeft', '左奥（赤）'), ('topRight', '右奥（青）')],
                  [('bottomLeft', '左手前（緑）'), ('bottomRight', '右手前（オレンジ）')],
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final entry in row)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ChoiceChip(
                              label: Text(
                                entry.$2,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _selectedMarkerPosition == entry.$1,
                              onSelected: (_) {
                                setState(() {
                                  _selectedMarkerPosition =
                                      _selectedMarkerPosition == entry.$1
                                      ? null
                                      : entry.$1;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _areMarkersConfirmed ? _confirmBallPosition : null,
              icon: const Icon(Icons.adjust),
              label: const Text('ボール位置を確認'),
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
        FilledButton(
          onPressed:
              !_areMarkersConfirmed && _editableMarkerPositions.length == 4
              ? () {
                  setState(() {
                    _areMarkersConfirmed = true;
                    _selectedMarkerPosition = null;
                    _tappedImagePosition = null;

                    final candidates = widget.ballCandidates
                        .where(
                          (candidate) => InitialBallSearchRegion.contains(
                            markers: _editableMarkerPositions,
                            point: Offset(candidate.centerX, candidate.centerY),
                          ),
                        )
                        .toList();

                    debugPrint(
                      'INITIAL BALL SEARCH '
                      'all=${widget.ballCandidates.length} '
                      'inside=${candidates.length} '
                      'markers=$_editableMarkerPositions',
                    );

                    for (final candidate in widget.ballCandidates) {
                      debugPrint(
                        'INITIAL BALL CANDIDATE '
                        'x=${candidate.centerX.toStringAsFixed(1)} '
                        'y=${candidate.centerY.toStringAsFixed(1)} '
                        'confidence=${candidate.confidence.toStringAsFixed(3)}',
                      );
                    }

                    if (candidates.isNotEmpty) {
                      candidates.sort(
                        (a, b) => b.confidence.compareTo(a.confidence),
                      );
                      final best = candidates.first;
                      _editableBallPosition = Offset(
                        best.centerX,
                        best.centerY,
                      );
                    } else {
                      _editableBallPosition = null;
                    }

                    _isBallPositionConfirmed = false;
                  });
                }
              : null,
          child: Text(_areMarkersConfirmed ? 'マーカー確定済み' : 'マーカー位置を確定'),
        ),
        if (_areMarkersConfirmed)
          FilledButton(
            onPressed: _isBallPositionConfirmed && _editableBallPosition != null
                ? () {
                    Navigator.of(context).pop(
                      FrameSetupResult(
                        markerPositions: Map<String, Offset>.from(
                          _editableMarkerPositions,
                        ),
                        ballPosition: _editableBallPosition,
                      ),
                    );
                  }
                : null,
            child: const Text('初期設定完了'),
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

class _MarkerOverlayPainter extends CustomPainter {
  const _MarkerOverlayPainter({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.markers,
  });

  final int sourceWidth;
  final int sourceHeight;
  final List<MarkerViewData> markers;

  String _labelForPosition(String position) {
    switch (position) {
      case 'topLeft':
        return 'TL';
      case 'topRight':
        return 'TR';
      case 'bottomLeft':
        return 'BL';
      case 'bottomRight':
        return 'BR';
      default:
        return position;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final rectanglePaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final centerPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    for (final marker in markers) {
      final center = Offset(marker.centerX * scaleX, marker.centerY * scaleY);

      // Keep the rectangle centered on the detected marker position, but make
      // very small distant markers large enough to see in the preview.
      final displayWidth = (marker.width * scaleX).clamp(16.0, double.infinity);
      final displayHeight = (marker.height * scaleY).clamp(
        16.0,
        double.infinity,
      );

      final rect = Rect.fromCenter(
        center: center,
        width: displayWidth,
        height: displayHeight,
      );

      canvas.drawRect(rect, rectanglePaint);

      canvas.drawCircle(center, 4, centerPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: _labelForPosition(marker.position),
          style: const TextStyle(
            color: Colors.purple,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerOverlayPainter oldDelegate) {
    return sourceWidth != oldDelegate.sourceWidth ||
        sourceHeight != oldDelegate.sourceHeight ||
        markers != oldDelegate.markers;
  }
}

class _TapPositionPainter extends CustomPainter {
  const _TapPositionPainter({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.position,
  });

  final int sourceWidth;
  final int sourceHeight;
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;

    final center = Offset(position.dx * scaleX, position.dy * scaleY);

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, 12, paint);
    canvas.drawLine(
      Offset(center.dx - 18, center.dy),
      Offset(center.dx + 18, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 18),
      Offset(center.dx, center.dy + 18),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TapPositionPainter oldDelegate) {
    return sourceWidth != oldDelegate.sourceWidth ||
        sourceHeight != oldDelegate.sourceHeight ||
        position != oldDelegate.position;
  }
}
