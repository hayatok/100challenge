# Sandbox objects browser check (2026-09-27)

対象: Desktop Chrome の Mouse Mode。Camera による実手の接触はこの変更では再検証していない。

| 操作 | 結果 |
| --- | --- |
| 初期表示 | ボール 20 個、操作パネルも 20/100 |
| + BOX、+ DOMINO | 22/100、異なる形状と色で表示 |
| LOAD 100 | 混合物体 100/100、追加ボタン disabled |
| 100 個へポインターを移動 | 物体の位置・姿勢が変化し、Debug 表示は 60 FPS、物理 step 平均 0.3〜0.5 ms |
| CLEAR ALL | 0/100、描画物体なし、CLEAR ALL disabled |
| + BALL | 1/100、空状態から生成 |
| RESET 20 | ボール 20 個へ復元 |
| 375×812、768×900 | 主操作に欠落なし。Debug はステータスバーの下へ展開し、操作パネルを隠さない |
| Pages 静的成果物 | `/2026-09-27/`、JS、同一オリジンのモデルが HTTP 200。Chrome で Mouse Mode を開始できた |

`npm run check` は lint・型検査・build が成功。ルート `npm test` は共通スクリプトの 38 テストが成功。

数値は今回のブラウザ・端末の観測値で、他端末の保証ではない。Tracking FPS は Mouse Mode のため対象外。実カメラの認識・衝突、Safari・Firefox・Mobile は未確認。
