# 金星の一夜　Windows実機記録

## v0.1.1 の再検証

2026年11月22日、Unity 6000.3.28f1でビルドしたWindows版をGeForce RTX 4070 Tiで操作した。両経路で真壁の肩越し視点から指揮に切り替え、辰を梶の卓へ送り、現場に戻って決着まで進めた。

| 経路 | 実機画像 | 実行ログ | フレーム数 | 中央値 / 95パーセンタイル |
| --- | --- | --- | ---: | ---: |
| 1920×1080・兄貴分を追跡 | [追跡の結末](v011/ending-pursuit.png) | [追跡](v011/player-pursuit.log) | 863 | 16.67 / 16.67 ms |
| 1280×720・弟を中継鏡へ護送 | [二階の受像機](v011/mirror-upstairs-720.png)、[和解の結末](v011/ending-accord.png) | [中継](v011/player-accord.log) | 1,546 | 16.67 / 16.67 ms |

二階へは通常の移動操作で右手の階段を上り、卓の手前まで進んだ。修正前後の真壁の座標はそれぞれ (-0.07, 3.24, 5.98) と (-0.07, 3.24, 5.97)。奥側の吊具をダンスフロア寄りに1.8 m移し、肩越しに辰と梶の顔、卓の受像機が同時に見えることを確認した。[修正前](v011/balcony-before-720.png)・[修正後](v011/balcony-conversation-720.png)・[移動ログ](v011/balcony-navigation.log)

辰の体力、弟の護送、交渉の成立、兄貴分の逃走の各2状態を組み合わせ、Unity Editorのプレイモードで実ゲームの進行処理を16通り実行した。辰が倒れた場合は交渉状態を解除し、兄貴分がすでに逃走していれば護送中にも敗北へ進むこと、逃走前は追跡できる段階を維持することを確認した。辰の戦闘不能はこの検査で直接設定した。[検査コード](../Game/Assets/Editor/KinseiChoiceRegression.cs)・[16通りの結果](v011/choice-regression.log)

検査を再実行するには、Unity Editorに `-batchmode -projectPath <Gameの絶対パス> -executeMethod KinseiChoiceRegression.Run -logFile <ログの保存先>` を渡す。検査が終了するとEditorは成否に応じた終了コードを返す。

配布ZIPは `Kinsei-Windows-v0.1.1.zip`（57,974,710バイト、SHA-256 `B951BBDC9D25014D7105BADDA2376CA2E880502111EFB4AC43A7875D217979B8`）。全135ファイルをビルド出力と照合した。ゲームアセンブリのSHA-256は `9808B9A7CD74F2D6A32777759B46252B97DD54C0F051F3C97A6BB1ECCBC432AC`。

## v0.1.0 の実機記録

2026年11月22日 04:22 JSTに出力したWindows版を、GeForce RTX 4070 Ti搭載機でウィンドウ表示にして操作した。ビルドのゲームアセンブリ `Assembly-CSharp.dll` のSHA-256は `1F2A79A54B740219313EB0555B98935741F4B7107202ADE93A6F6B0ECEB5E2B4`。

| 操作した経路 | 映像・画面 | 実行ログ | フレーム数 | 中央値 | 95パーセンタイル |
| --- | --- | --- | ---: | ---: | ---: |
| 1920×1080。指揮で辰を梶の席へ、千代を持ち場へ送り、真壁で入店・制圧して兄貴分を追跡 | [22.11秒](pursuit-1080.mp4) | [追跡](player-pursuit-1080.log) | 974 | 16.67 ms | 16.68 ms |
| 1280×720。梶の弟の降参後に肩を貸し、鏡の前で中継。梶たちが帰る結末まで操作 | [31.58秒](accord-720.mp4) | [中継](player-accord-720.log) | 1,573 | 16.67 ms | 16.67 ms |
| 1280×720。辰を席に送らずに時間切れになり、敗北画面から再試行して指揮に復帰 | [敗北画面](loss-720.png) | [敗北・再試行](player-navigation.log) | 2,649 | 16.67 ms | 16.67 ms |

映像はWindows Graphics Captureでプレイヤーウィンドウを24 fpsで収録した。音声はゲームのプロセスだけをWASAPIで収録し、48 kHzのステレオAACで保存した。フレーム時間はゲーム内の非スケール時間を計測した。60 fps制限下で、タイトル・結果・一時停止中と各フェーズ開始直後の0.2秒を計測から除く。表は各経路1回の結果で、起動や長時間プレイの負荷は含まない。1080pの測定中は画像生成用GPUサーバーを停止した。720pの測定中は同じGPUで別作業も実行していた。

同版の配布ZIPを任意のフォルダへ展開して、アプリの日付フォルダから次を実行する。最初の行には展開した実行ファイルのパスを指定する。実行中はプレイヤーにフォーカスを置く。[再生スクリプト](../tools/qa/Replay-Windows.ps1)は最後に測定結果と一時ログの保存先を表示する。

```powershell
$player = 'C:\Games\Kinsei-v0.1.0\Kinsei.exe'
.\tools\qa\Replay-Windows.ps1 -Player $player -Route pursuit -Height 1080
.\tools\qa\Replay-Windows.ps1 -Player $player -Route accord -Height 720
```

## 実画面で確認したこと

- [金星の外観](street-exterior-720.png)、[入口](street-pursuit-1080.png)、[ダンスホール](floor-pursuit-1080.png)、[降参](surrender-pursuit-1080.png)、[追跡中](chase-pursuit-1080.png)を実機で確認した。入力はキーボードとマウスの通常操作を使った。
- [二階の卓](balcony-conversation-720.png)へは真壁で右手の階段を上がり、手すり沿いを移動した。赤い上着の辰と梶が卓を挟んで座る。真壁と手すりが構図の手前に入る。[一階の受像機](mirror-accord-720.png)に梶の顔が映り、真壁の手と筐体の位置が分かる。カメラが二階へ切り替わると、[兄が見ている画面](mirror-upstairs-accord-720.png)に弟の顔と上げた手が映る。カメラを出口へ向け、[梶と弟が一行と退店する様子](departure-accord-720.png)も確認した。
- [初期の指揮画面](orders-pursuit-1080.png)に上段の卓が入り、地図を移動すると[二階の人員配置](balcony-rts-720.png)を確認できる。[ホールの床への右クリック](rts-ground-order-720.png)で指定位置への命令が二度通った。
- 別ウィンドウにフォーカスを移すと[幕間](focus-pause-720.png)に入り、ゲームに戻っても停止を維持した。再開のゲーム内時刻は停止時と同じ17.72秒だった。矢印とEnterで[設定を選択](keyboard-settings-720.png)し、揺れ・点滅とFPS表示の切替後に元の設定へ戻した。

人物の輪郭、表情、着席時の仕草は簡略化が目立つ。実写に近い人物表現、照明、演技の完成基準は未達。台詞は字幕で表示される。録画にゲーム音声が入っていることは、音声トラックの形式と信号レベルで確認した。
