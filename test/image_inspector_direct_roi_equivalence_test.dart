import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:putt_physics_v1/models/ball_candidate.dart';
import 'package:putt_physics_v1/models/blob.dart';
import 'package:putt_physics_v1/services/frame_extractor.dart';
import 'package:putt_physics_v1/services/image_inspector.dart';

void compareBlob(Blob? expected, Blob? actual) {
  expect(actual == null, expected == null);
  if (expected == null || actual == null) return;

  expect(actual.pixelCount, expected.pixelCount);
  expect(actual.minX, expected.minX);
  expect(actual.minY, expected.minY);
  expect(actual.maxX, expected.maxX);
  expect(actual.maxY, expected.maxY);
  expect(actual.centroidX, closeTo(expected.centroidX, 1e-10));
  expect(actual.centroidY, closeTo(expected.centroidY, 1e-10));
}

void compareBall(BallCandidate? expected, BallCandidate? actual) {
  expect(actual == null, expected == null);
  if (expected == null || actual == null) return;

  expect(actual.centerX, closeTo(expected.centerX, 1e-10));
  expect(actual.centerY, closeTo(expected.centerY, 1e-10));
  expect(actual.radius, closeTo(expected.radius, 1e-10));
  expect(actual.confidence, closeTo(expected.confidence, 1e-10));
  expect(actual.isCombinedRedYellow, expected.isCombinedRedYellow);
  expect(actual.isMotionBlur, expected.isMotionBlur);
}

void compareResults(ImageInfoResult expected, ImageInfoResult actual) {
  expect(actual.width, expected.width);
  expect(actual.height, expected.height);
  expect(actual.centerX, expected.centerX);
  expect(actual.centerY, expected.centerY);

  expect(actual.centerRed, expected.centerRed);
  expect(actual.centerGreen, expected.centerGreen);
  expect(actual.centerBlue, expected.centerBlue);

  expect(actual.centerHue, closeTo(expected.centerHue, 1e-10));
  expect(actual.centerSaturation, closeTo(expected.centerSaturation, 1e-10));
  expect(actual.centerValue, closeTo(expected.centerValue, 1e-10));

  expect(actual.centerIsYellow, expected.centerIsYellow);
  expect(actual.centerIsRed, expected.centerIsRed);

  expect(actual.totalPixels, expected.totalPixels);
  expect(actual.yellowPixels, expected.yellowPixels);
  expect(actual.redPixels, expected.redPixels);
  expect(actual.targetColorPixels, expected.targetColorPixels);
  expect(actual.yellowRatio, closeTo(expected.yellowRatio, 1e-10));
  expect(actual.redRatio, closeTo(expected.redRatio, 1e-10));

  expect(actual.blobCount, expected.blobCount);
  compareBlob(expected.largestBlob, actual.largestBlob);

  expect(actual.ballCandidateCount, expected.ballCandidateCount);
  expect(actual.ballCandidates.length, expected.ballCandidates.length);

  for (var i = 0; i < expected.ballCandidates.length; i++) {
    compareBall(expected.ballCandidates[i], actual.ballCandidates[i]);
  }

  compareBall(expected.bestBallCandidate, actual.bestBallCandidate);
}

void main() {
  test('Direct BGRA ROI matches full decode inspection', () {
    const width = 240;
    const height = 180;
    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red ball region.
    for (var y = 50; y < 90; y++) {
      for (var x = 50; x < 90; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    expect(actual, isNotNull);
    compareResults(expected, actual!);
  });
  test('Direct BGRA ROI matches yellow ball inspection', () {
    const width = 240;
    const height = 180;
    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Yellow ball region.
    for (var y = 50; y < 90; y++) {
      for (var x = 50; x < 90; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 255;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    expect(expected.yellowPixels, 1600);
    expect(actual, isNotNull);
    compareResults(expected, actual!);
  });
  test('Direct BGRA ROI matches combined red-yellow ball', () {
    const width = 240;
    const height = 180;
    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red and yellow regions separated by a 10-pixel gap.
    for (var y = 50; y < 90; y++) {
      for (var x = 40; x < 90; x++) {
        if (x >= 60 && x < 70) continue;

        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = x < 60 ? 0 : 255;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    expect(expected.redPixels, 800);
    expect(expected.yellowPixels, 800);
    expect(actual, isNotNull);

    compareResults(expected, actual!);

    expect(
      expected.ballCandidates.any((ball) => ball.isCombinedRedYellow),
      isTrue,
      reason: '従来方式で赤・黄色の複合候補が生成されていません',
    );

    expect(
      actual.ballCandidates.any((ball) => ball.isCombinedRedYellow),
      isTrue,
      reason: 'ROI直接解析で赤・黄色の複合候補が生成されていません',
    );
  });
  test('Direct BGRA ROI matches clamped boundaries', () {
    const width = 240;
    const height = 180;
    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red region near the image boundary.
    for (var y = 5; y < 45; y++) {
      for (var x = 5; x < 45; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: -20,
      minY: -15,
      maxX: 260,
      maxY: 195,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: -20,
      minY: -15,
      maxX: 260,
      maxY: 195,
    );

    expect(actual, isNotNull);
    expect(expected.redPixels, 1600);
    compareResults(expected, actual!);
  });
  test('Direct BGRA ROI matches padded bytesPerRow', () {
    const width = 240;
    const height = 180;
    const bytesPerRow = width * 4 + 32;

    final bytes = Uint8List(bytesPerRow * height);

    // Blue background with row padding.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * bytesPerRow + x * 4;
        bytes[i] = 255;
        bytes[i + 3] = 255;
      }
    }

    // Red ball region.
    for (var y = 50; y < 90; y++) {
      for (var x = 50; x < 90; x++) {
        final i = y * bytesPerRow + x * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: 20,
      minY: 15,
      maxX: 220,
      maxY: 165,
    );

    expect(actual, isNotNull);
    expect(expected.redPixels, 1600);
    compareResults(expected, actual!);
  });
  test('Direct BGRA ROI preserves center outside ROI', () {
    const width = 240;
    const height = 180;
    final bytes = Uint8List(width * height * 4);

    // Blue background.
    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 255;
      bytes[i + 3] = 255;
    }

    // Red ball inside ROI.
    for (var y = 30; y < 60; y++) {
      for (var x = 40; x < 70; x++) {
        final i = (y * width + x) * 4;
        bytes[i] = 0;
        bytes[i + 1] = 0;
        bytes[i + 2] = 255;
      }
    }

    // Yellow pixel at the full-frame center, outside ROI.
    final centerOffset = (90 * width + 120) * 4;
    bytes[centerOffset] = 0;
    bytes[centerOffset + 1] = 255;
    bytes[centerOffset + 2] = 255;

    final frame = ExtractedVideoFrame(
      position: const Duration(milliseconds: 100),
      frameIndex: 12,
      imageBytes: bytes,
      pixelFormat: 'BGRA8888',
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    final fullImage = FrameExtractor.decodeFrame(frame)!;

    final expected = ImageInspector.inspectDecoded(
      fullImage,
      minX: 20,
      minY: 15,
      maxX: 100,
      maxY: 80,
    );

    final actual = ImageInspector.inspectFrameRoi(
      frame,
      minX: 20,
      minY: 15,
      maxX: 100,
      maxY: 80,
    );

    expect(actual, isNotNull);
    expect(expected.centerRed, 255);
    expect(expected.centerGreen, 255);
    expect(expected.centerBlue, 0);
    expect(expected.centerIsYellow, isTrue);
    expect(expected.redPixels, 900);
    expect(expected.yellowPixels, 0);

    compareResults(expected, actual!);
  });
}
