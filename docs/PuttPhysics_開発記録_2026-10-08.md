# PuttPhysics 開発記録 2026-10-08

## 今日の目的

実グリーンでの計測を2日後に予定しているため、動画解析時に大量に出力されていたデバッグLOGを整理し、解析時間を短縮する。

実グリーン計測に向けた優先順位：

1. 動画解析の高速化
2. パターヘッドのフレーム間追跡
3. インパクト直前のパターヘッドスピード算出
4. グリーンスピード・ヘッドスピード・実際の転がり距離を基準データとして収集

## 変更前の状況

`lib` 以下の `debugPrint` は合計88か所あった。

主な内訳：

- `lib/screens/camera_screen.dart`：49か所
- `lib/services/ball_tracker.dart`：11か所
- `pink_marker_diagnostic.dart`：5か所
- `green_marker_diagnostic.dart`：5か所
- `blue_marker_diagnostic.dart`：4か所

自動動画解析では、AUTO PUTTER DETECTION、INITIAL CANDIDATES、AutoTrackMiss、AutoTrackedBall、BALL SCALE、AutoTrackingMetrics、REAL SPEED、TRACKER PREDICTION、TRACKER CANDIDATE、PUTTER DETECTOR、PUTTER CANDIDATE などが大量に出力されていた。

## DebugLog の追加

新規ファイル `lib/services/debug_log.dart` を追加。

```dart
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
```

通常の実計測では `DebugLog.verbose = false` とし、必要なときだけ詳細LOGを有効にできるようにした。

## PutterDetector の変更

`lib/services/putter_detector.dart` の詳細LOGを `DebugLog` 経由に変更。パター検出処理そのものは変更していない。

`PUTTER DETECTOR`、`PUTTER CANDIDATE` などの詳細LOGを通常時には出力しないようにした。また `Uint8List` 用に `import 'dart:typed_data';` を明示的に追加した。

## BallTracker の変更

`lib/services/ball_tracker.dart` にあった11か所の `debugPrint` を `DebugLog.print` に変更した。

初期選択、予測、候補Reject、候補評価、最終選択などの診断LOGを抑制したが、ボール追跡ロジックそのものには変更を加えていない。

## camera_screen.dart の変更

自動動画解析 `_analyzeRecordedVideoFrames()` のフレーム単位LOGを抑制した。

`ImageInspector.inspect()` では、通常時に `debugFrameIndex` を渡さないよう変更した。

```dart
debugFrameIndex: DebugLog.verbose ? _frameAnalysisCount + 1 : null,
```

また、AUTO PUTTER DETECTION、INITIAL CANDIDATES、AutoTrackMiss、AutoTrackedBall、BALL SCALE、AutoTrackingMetrics、REAL SPEED、AutoTrackingSmoothed などを `DebugLog` 経由に変更した。

解析処理・追跡処理・速度計算自体は残している。

## 実機テスト

iPhoneをUSB接続し、60fpsの短いパッティング動画で実機テストを実施した。

一度FlutterがiPhoneをwireless接続として認識し、`Dart VM Service was not discovered after 75 seconds` となったが、USB接続後に `flutter devices` で有線接続を確認して再実行し、正常に起動した。

動画解析は最後まで正常に完了した。

以前大量に表示されていたフレーム単位LOGは停止した。解析終了時には次の最終速度結果も正常に出力された。

```text
RAW PEAK SPEED
previousFrame=7
frame=8
time=116ms
speed=929.98px/s

SMOOTHED PEAK SPEED
startFrame=7
frame=10
time=150ms
speed=767.09px/s
```

## 解析速度について

変更前は動画解析が非常に遅かった。今回の変更後、体感では「かなり速くなった」。ただし、まだ「サクサク動く」という速度には達していない。

残る主な処理負荷候補：

- 各フレームの画像デコード
- 720×1280画像の全画素色判定
- Blob抽出
- ボール候補検出
- PutterDetectorによるピンク領域の全画素走査

実グリーン計測まで2日のため、大規模な高速化は行わず、現在の安定した状態を優先する。

## 残っている診断LOG

BLUE / GREEN / PINK DIAGNOSTIC および MARKER BLOB DEBUG は一部残っている。ただし今回確認した範囲では、自動動画解析の全フレームではなく主に先頭フレーム等の診断処理で使用されているため、現時点では変更しない。

## Git

今回の変更をコミットした。

```text
155f920 Reduce verbose video analysis logging
```

GitHubへのpushも完了。

```text
502bdf7..155f920  main -> main
```

作業終了時に `git status --short` が表示なしとなり、working tree clean を確認した。

## 次回の最優先作業

1. `PutterTracker` を新規作成
2. `PutterDetector` の候補をフレーム間で追跡
3. パターヘッド中心位置の時間変化を取得
4. キャリブレーションを使って pixel → 実距離へ変換
5. インパクト直前のパターヘッドスピードを m/s で算出
6. iPhone画面に最低限「ヘッドスピード ○○ m/s」を表示

## 実グリーンで取得したい基準データ

最低限、以下を記録する。

- グリーンスピード
- パターヘッドスピード
- 実際のボールの転がり距離

将来的には、`グリーンスピード × ヘッドスピード → 実際の転がり距離` の関係をPuttPhysicsの基準データとして蓄積する。

さらにボール初速が安定して取得できれば、`ヘッドスピード → ボール初速 → 転がり距離` というモデルへ発展させる。

## 現在の状態

- 動画解析：動作確認済み
- 60fps動画：動作確認済み
- ボール追跡：既存機能あり
- PutterDetector：自動動画解析へ接続済み
- 詳細LOG抑制：実装・実機確認済み
- 動画解析速度：大幅改善。ただし追加高速化の余地あり
- PutterTracker：未実装
- パターヘッドスピード：未実装
- 実グリーン計測：2日後予定
