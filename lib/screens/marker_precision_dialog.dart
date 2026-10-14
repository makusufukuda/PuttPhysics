import 'dart:typed_data';

import 'package:flutter/material.dart';

class MarkerPrecisionDialog extends StatefulWidget {
  const MarkerPrecisionDialog({
    super.key,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.initialPosition,
    this.title = 'マーカー中心の精密調整',
  });

  final Uint8List imageBytes;
  final int imageWidth;
  final int imageHeight;
  final Offset initialPosition;
  final String title;

  @override
  State<MarkerPrecisionDialog> createState() => _MarkerPrecisionDialogState();
}

class _MarkerPrecisionDialogState extends State<MarkerPrecisionDialog> {
  static const double _zoom = 5.0;
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  void _moveImage(DragUpdateDetails details, Size viewport) {
    setState(() {
      _position = Offset(
        (_position.dx -
                details.delta.dx * widget.imageWidth / (viewport.width * _zoom))
            .clamp(0.0, widget.imageWidth.toDouble() - 1),
        (_position.dy -
                details.delta.dy *
                    widget.imageHeight /
                    (viewport.height * _zoom))
            .clamp(0.0, widget.imageHeight.toDouble() - 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(
              constraints.maxWidth,
              constraints.maxHeight - 110,
            );

            return Column(
              children: [
                SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => _moveImage(details, viewport),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            left:
                                viewport.width / 2 -
                                _position.dx *
                                    viewport.width *
                                    _zoom /
                                    widget.imageWidth,
                            top:
                                viewport.height / 2 -
                                _position.dy *
                                    viewport.height *
                                    _zoom /
                                    widget.imageHeight,
                            width: viewport.width * _zoom,
                            height: viewport.height * _zoom,
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _PrecisionCrosshairPainter(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  'X: ${_position.dx.toStringAsFixed(1)}  '
                  'Y: ${_position.dy.toStringAsFixed(1)}',
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_position),
                  child: const Text('この位置で確定'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PrecisionCrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawCircle(center, 10, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
