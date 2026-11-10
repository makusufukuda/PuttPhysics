# PuttPhysics 開発引き継ぎメモ — ROI最適化の実機比較

作成日：2026-11-10

## 目的

パターヘッド検出のROI（関心領域）制限によって、120fps動画の解析速度と追跡結果がどう変わるかを、同一動画で比較する。

## Git・作業環境

| 区分 | フォルダー | コミット | 内容 |
|---|---|---|---|
| ROI導入後 | `~/Developer/putt_physics_build_test` | `a77ee79` | `Limit putter detection to ball-relative ROI` |
| ROI導入前 | `~/Developer/putt_physics_roi_before` | `d5764a5` | `Stop putter analysis after ball movement starts` |

- 開発ブランチ：`feature/native-analysis-speedup`（ROI導入後の作業側）。
- ROI導入前の比較用フォルダーは `git worktree add --detach ../putt_physics_roi_before d5764a5` で作成した detached HEAD。
- 最適化コードはコミット・push済み。今回の実機測定に伴う追加コード変更はないため、追加コミット・pushは不要。
- 比較用フォルダーで `flutter pub get`、`flutter analyze`（`No issues found!`）、`flutter build ios --debug`（成功）を確認。
- 同じアプリID `com.chainaflower.puttphysics` を使用するため、iPhone上では比較用アプリが既存アプリを置き換える。元動画はiPhoneの「写真」アプリに保存済み。

## 実装内容（ROI導入後）

- ボール移動開始後はパター検出を停止し、ボール追跡を継続（`d5764a5`）。
- パター検出を、ボール位置のY座標から200px上を起点とする画像下側の範囲に制限（`a77ee79`）。X方向は全幅。
- `BlobAnalyzer.extractBlobs` および `PutterDetector.detectDecoded` にROI境界を指定できるよう変更。
- 追加テストあり。ROI導入後の `flutter analyze` は問題なし、`flutter test` は69件成功。

## 実機比較条件

- iPhoneで同一の120fps動画を解析。
- 両条件とも703フレーム。
- ROI導入後を先に測定し、続いてROI導入前の比較用アプリを実行。
- 測定は各条件1回。処理時間は実行環境やばらつきの影響を受けるため、差の再現性は未確認。

## 処理時間

| 項目 | ROI導入前 | ROI導入後 | 差（導入後−導入前） |
|---|---:|---:|---:|
| 動画解析全体 | 144.805秒 | 144.536秒 | −0.269秒（約0.19%短縮） |
| パター検出累計 | 12,847.9ms | 7,093.8ms | −5,754.1ms（約44.8%短縮） |
| 画像解析累計 | 92,020.9ms | 91,407.9ms | −613.0ms（約0.7%短縮） |
| 画像デコード累計 | 27,590.8ms | 34,371.2ms | ＋6,780.4ms（約24.6%増加） |
| フレーム読み込み累計 | 11,792.6ms | 11,281.2ms | −511.4ms（約4.3%短縮） |

### ROI導入前の原ログ

```text
FRAME READ TIMING frames=703 totalMs=11792.6 averageMs=16.77
IMAGE DECODE TIMING totalMs=27590.8 averageMs=39.25
PUTTER DETECT TIMING totalMs=12847.9 averageMs=18.28
IMAGE INSPECT TIMING totalMs=92020.9 averageMs=130.90
VIDEO ANALYSIS TIMING frames=703 elapsedMs=144805 elapsedSeconds=144.81
AutoTracking finished frames=703 tracked=388
PUTTER TRACKING SUMMARY detected=196 tracked=11 total=703 longest=2 gaps=7 first=15 last=153
```

### ROI導入後の原ログ

```text
FRAME READ TIMING frames=703 totalMs=11281.2 averageMs=16.05
IMAGE DECODE TIMING totalMs=34371.2 averageMs=48.89
PUTTER DETECT TIMING totalMs=7093.8 averageMs=10.09
IMAGE INSPECT TIMING totalMs=91407.9 averageMs=130.03
VIDEO ANALYSIS TIMING frames=703 elapsedMs=144536 elapsedSeconds=144.54
AutoTracking finished frames=703 tracked=388
PUTTER TRACKING SUMMARY detected=194 tracked=194 total=703 longest=186 gaps=1 first=56 last=250
```

**注意：** `PUTTER DETECT TIMING averageMs` は総フレーム数703で割った表示値。実際にパター検出を実行したフレームだけの平均処理時間とは限らない。また、各処理の累計は重複や計測範囲の違いがあり得るため、単純合計して全体時間と一致すると解釈しない。

## 追跡・速度結果

| 項目 | ROI導入前 | ROI導入後 |
|---|---:|---:|
| ボール追跡数 | 388 | 388 |
| パター検出数 | 196 | 194 |
| パター追跡数 | 11 | 194 |
| パター追跡最長連続数 | 2 | 186 |
| パター最高速度 | 242.39px/s（138→139） | 990.68px/s（70→71） |
| ボールRAW最高速度 | 7,720.76px/s（377→378） | 7,720.76px/s（377→378） |
| ボール平滑化後最高速度 | 6,078.32px/s（377→380） | 6,078.32px/s（377→380） |

ボール最高速度は一致した。パター追跡数と最高速度には大きな差があるが、原因がROIそのものか、追跡候補の選択や別の条件によるものかは未確認。

## 暫定結論

1. 同一動画の1回ずつの比較では、パター検出の累計処理時間が約44.8%減少。
2. 動画解析全体の時間は約0.27秒（約0.19%）しか短縮しておらず、全体高速化の効果は未確定。
3. パター追跡結果は大幅に異なる。単純に「速くなった」と評価する前に追跡の妥当性を確認する。
4. ボール最高速度・平滑化後最高速度は一致。

## 次回の作業

1. ROI導入前後でパター追跡数が11対194になった原因を、検出・追跡ログとコードから確認。
2. パター速度のピーク値（242.39対990.68px/s）が実際の動作を反映しているか検証。
3. 画像解析（約91秒）が大きな処理時間を占めるため、全体高速化の次の候補として計測内訳を調べる。
4. 必要なら同一動画を複数回解析し、計測ばらつきを評価。
5. 通常開発へ戻るときは `~/Developer/putt_physics_build_test` を使用する。比較用 `putt_physics_roi_before` は検証が終わるまで保持。

## 終了時の注意

- 比較用フォルダーから `flutter run` を実行している場合は、ターミナルで `q` を押して終了。
- 今日の測定結果はこのMDに保存。追加のGitコミット・pushは不要。
- 次回は、iPhoneに入っているアプリがROI導入前の比較版である可能性に注意する。
