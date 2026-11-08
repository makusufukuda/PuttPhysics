import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ExtractedVideoFrame {
  const ExtractedVideoFrame({
    required this.position,
    required this.imageBytes,
    this.pixelFormat = 'JPEG',
    this.width,
    this.height,
    this.bytesPerRow,
  });

  final Duration position;
  final Uint8List imageBytes;
  final String pixelFormat;
  final int? width;
  final int? height;
  final int? bytesPerRow;
}

class FrameExtractor {
  const FrameExtractor._();

  static img.Image? decodeFrame(ExtractedVideoFrame frame) {
    if (frame.pixelFormat == 'JPEG') {
      return img.decodeImage(frame.imageBytes);
    }

    if (frame.pixelFormat == 'BGRA8888') {
      final width = frame.width;
      final height = frame.height;
      final bytesPerRow = frame.bytesPerRow;

      if (width == null || height == null || bytesPerRow == null ||
          width <= 0 || height <= 0 ||
          bytesPerRow < width * 4 ||
          frame.imageBytes.lengthInBytes != bytesPerRow * height) {
        throw StateError('Invalid BGRA frame data.');
      }

      return img.Image.fromBytes(
        width: width,
        height: height,
        bytes: frame.imageBytes.buffer,
        bytesOffset: frame.imageBytes.offsetInBytes,
        numChannels: 4,
        rowStride: bytesPerRow,
        order: img.ChannelOrder.bgra,
      );
    }

    throw StateError('Unsupported pixel format: ${frame.pixelFormat}');
  }

  static const MethodChannel _nativeFrameChannel = MethodChannel(
    'com.chainaflower.puttphysics/frame_extractor',
  );

  static Future<Uint8List?> extractFrame({
    required String videoPath,
    required Duration position,
    int maxWidth = 1280,
    int quality = 95,
  }) {
    return VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      timeMs: position.inMilliseconds,
      maxWidth: maxWidth,
      quality: quality,
    );
  }

  static Future<ExtractedVideoFrame?> extractFrameByIndex({
    required String videoPath,
    required int frameIndex,
  }) async {
    final result = await _nativeFrameChannel.invokeMapMethod<String, Object?>(
      'readFrameImage',
      <String, Object?>{'videoPath': videoPath, 'frameIndex': frameIndex},
    );

    if (result == null) {
      return null;
    }

    final imageBytes = result['imageBytes'];
    final ptsMs = result['ptsMs'];

    if (imageBytes is! Uint8List || ptsMs is! num) {
      return null;
    }

    return ExtractedVideoFrame(
      position: Duration(microseconds: (ptsMs.toDouble() * 1000.0).round()),
      imageBytes: imageBytes,
    );
  }

  static Stream<ExtractedVideoFrame> extractFrames({
    required String videoPath,
    required Duration duration,
    double framesPerSecond = 30.0,
    int maxWidth = 1280,
    int quality = 95,
    bool useBGRA = false,
  }) async* {
    var readerOpened = false;
    var frameReadCount = 0;
    var frameReadMicroseconds = 0;

    try {
      final openResult = await _nativeFrameChannel
          .invokeMapMethod<String, Object?>(
            'openFrameReader',
            <String, Object?>{
              'videoPath': videoPath,
              'quality': quality,
              'useBGRA': useBGRA,
            },
          );

      if (openResult == null || openResult['ok'] != true) {
        throw StateError('Native frame reader failed to open.');
      }

      readerOpened = true;

      while (true) {
        final readWatch = Stopwatch()..start();
        final result = await _nativeFrameChannel
            .invokeMapMethod<String, Object?>('readNextFrame');
        readWatch.stop();

        if (result == null) {
          throw StateError('Native frame reader returned null.');
        }

        if (result['done'] == true) {
          break;
        }

        final ptsUs = result['ptsUs'];
        final imageBytes = result['imageBytes'];
        final pixelFormat = result['pixelFormat'];
        final width = result['width'];
        final height = result['height'];
        final bytesPerRow = result['bytesPerRow'];

        if (ptsUs is! int || imageBytes is! Uint8List) {
          throw StateError('Native frame reader returned invalid frame data.');
        }

        if (pixelFormat == 'BGRA8888' &&
            (width is! int ||
                height is! int ||
                bytesPerRow is! int ||
                width <= 0 ||
                height <= 0 ||
                bytesPerRow < width * 4 ||
                imageBytes.lengthInBytes != bytesPerRow * height)) {
          throw StateError('Invalid BGRA frame dimensions or data.');
        }

        frameReadCount++;
        frameReadMicroseconds += readWatch.elapsedMicroseconds;

        yield ExtractedVideoFrame(
          position: Duration(microseconds: ptsUs),
          imageBytes: imageBytes,
          pixelFormat: pixelFormat is String ? pixelFormat : 'JPEG',
          width: width is int ? width : null,
          height: height is int ? height : null,
          bytesPerRow: bytesPerRow is int ? bytesPerRow : null,
        );
      }
    } finally {
      if (frameReadCount > 0) {
        debugPrint(
          'FRAME READ TIMING '
          'frames=$frameReadCount '
          'totalMs=${(frameReadMicroseconds / 1000).toStringAsFixed(1)} '
          'averageMs=${(frameReadMicroseconds / 1000 / frameReadCount).toStringAsFixed(2)}',
        );
      }
      if (readerOpened) {
        try {
          await _nativeFrameChannel.invokeMethod<Object?>('closeFrameReader');
        } on PlatformException {
          // Preserve the original extraction error, if any.
        }
      }
    }
  }
}
