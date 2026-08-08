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
    Duration interval = const Duration(milliseconds: 100),
    int maxWidth = 1280,
    int quality = 95,
  }) async* {
    var position = Duration.zero;

    while (position <= duration) {
      final imageBytes = await extractFrame(
        videoPath: videoPath,
        position: position,
        maxWidth: maxWidth,
        quality: quality,
      );

      if (imageBytes != null && imageBytes.isNotEmpty) {
        yield ExtractedVideoFrame(position: position, imageBytes: imageBytes);
      }

      position += interval;
    }
  }
}
