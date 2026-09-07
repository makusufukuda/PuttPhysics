# PuttPhysics 開発記録 --- 2026-09-08

## 1. 本日の到達点

本日は、動画解析におけるフレーム取得時刻の精度確認、BallTracker
の初期候補選択の修正、テスト、Git 保存までを完了した。

最終状態：

-   `flutter analyze`：**No issues found!**
-   `flutter test`：**33件すべて成功（All tests passed!）**
-   Git commit：`514295f`
-   commit
    message：`Improve video frame tracking and perspective calibration`
-   GitHub `main` へ push 済み
-   `git status --short`：出力なし（working tree clean）

このコミット `514295f`
を、次回および新しいMacへ移行する際の基準点とする。

------------------------------------------------------------------------

## 2. ネイティブフレーム取得と実PTSの確認

録画動画について、VideoPlayer
の概算時刻だけに依存せず、ネイティブフレームをフレーム番号で取得し、そのフレームの実際の
PTS（Presentation Timestamp）を利用する処理を確認した。

確認した動画情報：

-   frameCount：105
-   firstPtsMs：0.0 ms
-   lastPtsMs：約 3466.67 ms
-   minimumStepMs：約 33.33 ms
-   maximumStepMs：約 33.33 ms
-   duplicateCount：0
-   nonIncreasingCount：0
-   動画サイズ：720 × 1280

実機で「画面取得」を使用して確認：

    フレーム   VideoPlayer時刻     実PTS 結果
  ---------- ----------------- --------- ------
          15            500 ms    500 ms 一致
          30           1000 ms   1000 ms 一致
          45           1500 ms   1500 ms 一致

3地点すべてで要求フレームと実PTSが一致した。

------------------------------------------------------------------------

## 3. camera_screen.dart の時刻処理

フレーム取得後に得られる `actualPosition` を使用するようにした。

BallTracker 呼び出しも、VideoPlayer側の概算 `position`
ではなく、ネイティブフレームの実PTSである `actualPosition`
を渡すよう変更した。

``` dart
final trackedBall = _ballTracker.track(
  frameIndex: _frameAnalysisCount,
  timestamp: actualPosition,
  candidates: imageInfo.ballCandidates,
);
```

これにより、追跡処理の時刻情報を実際に抽出されたフレームのPTSに合わせる。

------------------------------------------------------------------------

## 4. 実機でのボール・マーカー確認

フレーム15付近で確認したボール候補の例：

-   centerX：約 506.5
-   centerY：約 811.0
-   radius：約 17.3
-   confidence：約 0.898
-   motionBlur：false
-   redPixels：430
-   yellowPixels：508

4個の青色キャリブレーションマーカーも検出された。

概略位置：

-   topLeft：約 (128.5, 752.5)
-   topRight：約 (623, 767.5)
-   bottomLeft：約 (75.2, 871.5)
-   bottomRight：約 (666.2, 891)

------------------------------------------------------------------------

## 5. BallTracker 初期安定判定

実機確認では、初期候補について以下のように安定フレーム数が増加した。

-   1回目：`stableFrames=1`
-   2回目：`stableFrames=2`
-   3回目：`stableFrames=3`
-   3回目で `TRACKER INITIAL STABLE`
-   `missedFrames=0`

なお、このログの `frame=1,2,3` はネイティブ動画のフレーム番号 15,30,45
ではなく、`_frameAnalysisCount` の解析回数を示す。

------------------------------------------------------------------------

## 6. BallTracker の背景誤認識問題

`flutter test` 実行時、当初1件のテストが失敗した。

失敗したテスト：

`does not lock onto a stable background candidate before the ball`

テストでは、初期フレームに以下の2候補が存在していた。

-   安定した背景候補：radius=8、confidence=0.75、motionBlur=true
-   本来のボール候補：radius=15、confidence=0.48、motionBlur=true

従来処理では、非 motionBlur 候補がない場合に単純に `candidates.first`
を初期 seed
としていた。そのため、候補配列の先頭にある背景を選択し、背景が数フレーム安定していることで誤って追跡対象として固定していた。

------------------------------------------------------------------------

## 7. BallTracker の修正

既存テストには「motionBlur=true
の候補しか存在しない場合でも、3フレーム安定すれば初期追跡を開始する」という要件がある。

そのため motionBlur 候補そのものを除外するのではなく、非 motionBlur
候補がない場合の初期 seed 選択を変更した。

修正後：

``` dart
seed ??= candidates.reduce((a, b) => a.radius >= b.radius ? a : b);
```

これにより、すべてが motionBlur
候補の場合、単純に先頭候補を使うのではなく、半径が最大の候補を初期 seed
とする。

今回のテスト条件では：

-   背景：radius=8
-   ボール：radius=15

なので、本来のボール候補が選択される。

テストの期待値を変更したり、問題を検出したテストを削除したりする方法は採用していない。

------------------------------------------------------------------------

## 8. テスト結果

修正後：

``` text
flutter analyze
No issues found!
```

さらに：

``` text
flutter test
00:01 +33: All tests passed!
```

BallTracker を含む全33件のテストが成功した。

------------------------------------------------------------------------

## 9. Gitへの保存

バックアップ用の `.before_...`
ファイルはコミット対象から除外し、実コードとテストのみをステージした。

作成したコミット：

``` text
514295f Improve video frame tracking and perspective calibration
```

結果：

-   14 files changed
-   773 insertions
-   63 deletions

新規追加ファイル：

-   `lib/models/real_world_point.dart`
-   `lib/services/perspective_calibration.dart`
-   `test/marker_calibration_test.dart`
-   `test/perspective_calibration_test.dart`

GitHubへ push：

``` text
465255e..514295f  main -> main
```

push完了後、不要になった4個の作業用バックアップファイルを削除した。

最終的な：

``` bash
git status --short
```

は出力なし。

したがって、作業ツリーは clean の状態で終了した。

------------------------------------------------------------------------

## 10. 次回再開時の基準

次回の開発開始時は、まず以下を基準として確認する。

-   Branch：`main`
-   基準commit：`514295f`
-   GitHubへpush済み
-   `flutter analyze` 成功済み
-   `flutter test` 33件成功済み
-   旧Macで実機フレーム15 / 30 / 45の実PTS一致確認済み
-   working tree clean

新しいMacへの移行後に問題が発生した場合も、まず `514295f`
と旧Macでの上記正常動作結果を比較基準とする。

------------------------------------------------------------------------

## 11. 次回について

新しいMacへの環境移行が予定されている。

新Macへの具体的な移行手順は別のMarkdownとして後日作成する。旧Macは、新Mac上でPuttPhysicsの取得・解析・テスト・iPhone実機起動まで確認できるまでは消去しない。
