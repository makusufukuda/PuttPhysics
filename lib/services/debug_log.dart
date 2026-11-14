import 'package:flutter/foundation.dart';

class DebugLog {
  const DebugLog._();

  // 実グリーン計測時は false。
  // 詳細な解析ログを調査するときだけ true にする。
  static const bool verbose = false;

  static void print(String message) {
    if (verbose) {
      debugPrint(message);
    }
  }
}
