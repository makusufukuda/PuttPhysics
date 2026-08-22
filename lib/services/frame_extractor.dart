import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ExtractedVideoFrame {
  const ExtractedVideoFrame({required this.position, required this.imageBytes});

  final Duration position;
  final Uint8List imageBytes;
}

class FrameExtractor {
  const FrameExtractor._();

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

  static Stream<ExtractedVideoFrame> extractFrames({
    required String videoPath,
    required Duration duration,
    double framesPerSecond = 30.0,
    int maxWidth = 1280,
    int quality = 95,
  }) async* {
    var readerOpened = false;

    try {
      final openResult = await _nativeFrameChannel
          .invokeMapMethod<String, Object?>(
            'openFrameReader',
            <String, Object?>{'videoPath': videoPath, 'quality': quality},
          );

      if (openResult == null || openResult['ok'] != true) {
        throw StateError('Native frame reader failed to open.');
      }

      readerOpened = true;

      while (true) {
        final result = await _nativeFrameChannel
            .invokeMapMethod<String, Object?>('readNextFrame');

        if (result == null) {
          throw StateError('Native frame reader returned null.');
        }

        if (result['done'] == true) {
          break;
        }

        final ptsUs = result['ptsUs'];
        final imageBytes = result['imageBytes'];

        if (ptsUs is! int || imageBytes is! Uint8List) {
          throw StateError('Native frame reader returned invalid frame data.');
        }

        yield ExtractedVideoFrame(
          position: Duration(microseconds: ptsUs),
          imageBytes: imageBytes,
        );
      }
    } finally {
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
