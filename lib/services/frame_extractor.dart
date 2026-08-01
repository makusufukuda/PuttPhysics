import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

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
}
