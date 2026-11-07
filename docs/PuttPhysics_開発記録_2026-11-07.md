# PuttPhysics 開発記録 — 2026-11-07

## 作業概要
動画 `IMG_2812.MOV` のフレーム370（約3.084秒）で、赤色ボールが検出されず、赤・黄の結合候補が異常に大きくなる問題を調査・修正した。

## 原因
- 赤色単独マスクから抽出したBlobは正常だったが、従来の正式候補生成は赤・黄の混合マスクに依存していた。
- 混合マスクでは色領域が連結し、幅181px・高さ540pxのBlobが最大直径条件で除外された。
- 別途作成する赤・黄結合候補には大きさの上限がなく、中心 `(539.5, 714.5)`、半径627.5pxの誤候補が採用されていた。

## 修正内容
- `lib/services/image_inspector.dart` で、混合マスクの候補に加え、赤色単独・黄色単独のBlobを `BlobFilter.filter` に通して正式候補一覧に追加。
- 赤・黄結合候補の幅または高さが300pxを超える場合は除外。
- 候補一覧を信頼度順にソート。
- `lib/screens/camera_screen.dart`、`lib/services/blob_filter.dart`、`lib/services/image_inspector.dart` に診断ログを追加・維持。

## 検証結果
対象：`IMG_2812.MOV`、フレーム370（動画全体の解析は実施せず）。

| 項目 | 値 |
|---|---|
| 手動確認したボール中心 | (511.4, 1324.0) |
| 修正後の正式検出中心 | (515.5, 1337.5) |
| 推定半径 | 54.5px |
| 信頼度 | 0.795（79.5%） |
| 正式候補数 | 1 |
| 中心位置の差 | 約14.1px |

ログ：
```text
CAPTURE BALL CANDIDATES frame=370 count=1
CAPTURE BALL CANDIDATE frame=370 index=0 x=515.5 y=1337.5 r=54.5 confidence=0.795 combined=false
```
※ `combined=false` は、ログの末尾が途中で切れていたため、コード上の赤色単独候補であることからの推定。実ログでは `combined=fa` まで確認。

`flutter analyze lib/services/image_inspector.dart`：`No issues found!`。

## 注意事項・未検証
- フレーム370以外での安定性は未確認。
- ピンク色の領域は**パターに貼ったシール**であり、赤色ボールではない。色相が一部重なるため誤認識に注意。
- 色別候補と混合候補の重複除去は未実装。
- 連続フレームのボール追跡、ヘッドスピード算出への影響は未検証。
- バックアップファイル（`*.before_*`）はGit管理対象に含めず保持。

## Git保存
- コミット：`af53ec0` — `Fix red ball detection and reject oversized candidates`
- ブランチ：`main`
- GitHub：`makusufukuda/PuttPhysics`
- `git push origin main` 成功（`28c92b3..af53ec0`）。

## 次回の再開手順
1. `IMG_2812.MOV` の**フレーム350のみ**を画像取得し、正式なボール候補ログを確認。
2. 続いて別フレーム（例：390）で同様に検証。動画全体の解析はまだ行わない。
3. ピンク色のパターシールとの混同や候補重複があれば対策を検討。
4. 複数フレームで安定した後に連続追跡・速度計測を検証。

作業方針：一度に一操作ずつ進め、結果を確認してから次へ進む。
