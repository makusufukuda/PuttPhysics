import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

class ExtractedVideoFrame {
  const ExtractedVideoFrame({required this.position, required this.imageBytes});

  final Duration position;
  final Uint8List imageBytes;
}

class FrameExtractor {
  const FrameExtractor._();

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
    if (framesPerSecond <= 0) {
      throw ArgumentError.value(
        framesPerSecond,
        'framesPerSecond',
        'must be greater than zero',
      );
    }

    var frameIndex = 0;

    while (true) {
      final positionMicroseconds =
          (frameIndex * Duration.microsecondsPerSecond / framesPerSecond)
              .round();

      final position = Duration(microseconds: positionMicroseconds);

      if (position > duration) {
        break;
      }

      final imageBytes = await extractFrame(
        videoPath: videoPath,
        position: position,
        maxWidth: maxWidth,
        quality: quality,
      );

      if (imageBytes != null && imageBytes.isNotEmpty) {
        yield ExtractedVideoFrame(position: position, imageBytes: imageBytes);
      }

      frameIndex++;
    }
  }
}
