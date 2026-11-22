# v1.7 通しプレイ — 一冊の帳面で四つの決着と両方の翌朝

配布用 Windows ZIP（145,757,480 バイト）の SHA-256 は `cface9fdf1d3118bc153cbc95322b99fac8d415b4a62daf1a45be36f1562ac83`。独立展開した Windows Player と ZIP 内の 136 ファイルの相対パスと SHA-256 を全件照合した。ゲーム DLL の SHA-256 は `35a91262ec9644c06a8ce3fe39282b857073703f5c73f18d6474ae3c9cfeae65`。

通常夜の実機検証を空の試験専用フォルダーで始めた。通常夜の担当者から同じ保存先を引き継ぎ、共同の最終夜、共同の翌朝、専属の最終夜、専属の翌朝の順に遊んだ。各区間の間に Windows Player を終了して起動し直した。進行には Windows の通常キー・マウス操作を使い、帳面の記録はゲームが行った。時刻は Player ログのゲーム内経過時間。通常夜は和解が 1920×1080、追跡が 1280×720。以降は RTX 4070 Ti・Direct3D 12・1280×720 のウィンドウで確認した。

| 区間 | 実機での操作と結果 | 証跡 |
| --- | --- | --- |
| 第1夜・和解 | 左の中継卓を確保し、弟と梶を組員の中継でつないだ。31.56 秒に和解し、梶との約束を記帳。 | [和解までの実機動画](../hall-two-fronts.mp4)・[ログ](../player-relay.log)・[帳面](../ledger-after-relay.json) |
| 第2夜・追跡 | 右の通用口を組員に任せ、兄貴分の足止めから追跡に入った。20.63 秒に決着し、金星座長の約束も記帳。 | [追跡へ移る場面](../intercept-door.png)・[ログ](../player-door.log)・[帳面](../ledger-after-door.json) |
| 第3夜・共同放送 | F で最終夜を開始。針音堂で原盤を受け取り、千代を交換卓へ、源をロータスの客席へ送った。24.56 秒に放送開始、28.16 秒に「四十軒の朝」。 | [最終夜解放](night-cooperative-title.jpg)・[初放送](night-cooperative-broadcast.jpg)・[結果](night-cooperative-result.jpg)・[ログ](player-night-cooperative.log)・[帳面](ledger-cooperative.json) |
| 共同放送の翌朝 | 1 で翌朝を選び、ロータスで澄子に話して依頼を受けた。共同送像所の村瀬の卓で「堺の朝」を送出し、19.93 秒に依頼完了。 | [送出後](dawn-joint-complete.jpg)・[ログ](player-dawn-joint.log) |
| 第4夜・専属興行 | F でもう一度最終夜を開始。千代を交換卓へ送り、金星の座長へ原盤を渡し、源に開場を任せた。14.67 秒に発券の場面、18.27 秒に「金星の朝」。 | [発券](night-exclusive-broadcast.jpg)・[結果](night-exclusive-result.jpg)・[ログ](player-night-exclusive.log)・[帳面](ledger-exclusive.json) |
| 専属興行の翌朝 | 2 で翌朝を選び、金星の印字機から一番券を受け取った。針音堂の左端で兵藤に渡し、13.44 秒に前売りを開始。 | [券の受け取り](dawn-exclusive-ticket.jpg)・[引き渡し後](dawn-exclusive-complete.jpg)・[ログ](player-dawn-exclusive.log) |

どちらの翌朝も完了後に幕間から表題へ戻れた。各朝の前後で帳面の SHA-256 は一致した。共同の翌朝は `fcb0e51400c6d94bf276329886becadeac2789020e73ba1b88ebfeae79a828b0`。専属の翌朝と最後の再起動後は `071f369551c20a1b635c692534236168c5855b8a6ec463d7f7485a561fe9c01d`。最後の表題には出撃 4 回・帰還 4 回、両方の約束と決着、翌朝 1・2 の選択肢が出た。今回の通常夜は伝票回収を省いたため、累計売上は 0 円。[再起動後の表題](reload-title.jpg)・[再起動後の帳面](ledger-after-restart.json)・[起動ログ](player-reload.log)
