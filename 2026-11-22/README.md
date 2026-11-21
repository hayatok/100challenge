# 金星の一夜

2026年、大阪・宵待町。若頭の真壁は六人の組員とキャバレー金星へ戻る。一階で兄貴分を追うか、二階の梶に弟の無事を知らせるかを、店内を移動しながら決める。

## Windowsで遊ぶ

配布フォルダの `Kinsei.exe` を実行する。UnityPlayer.dll と Kinsei_Data は実行ファイルの隣に置く。タイトルで Enter を押すと表通りから始まる。

|場面|操作|
|---|---|
|真壁を操作|WASDで移動、Shiftで走る。右ドラッグまたは左右の矢印で視点を回す。Qで注視する相手を変える。|
|争いの最中|相手に左クリック、またはSpaceで照準に向けて射撃。近い相手にはFで打撃。|
|現場で話す・追う|相手または鏡の近くで、表示された行動をEで実行。|
|指揮|Tabで切替。1～6または顔札で組員を選び、地面を右クリックして移動。WASDで地図を動かし、ホイールで拡縮。|
|組員への指示|Eで辰を梶の席へ、Fで随行、Gでホールの持ち場、Rで表通りに下げて休息。|
|幕間|Escで一時停止・設定。再開、やり直し、タイトル、終了を選べる。F12で実機の写真を撮影する。|

初めてなら、表通りで指揮に切り替え、辰に二階を任せてから入店するとよい。弟が降参した後も時計は進む。梶は相手の顔を自分で見るまで席を立たない。

## ソースからビルド

Unity 6000.3.28f1・Windows Standalone。PowerShell でこのフォルダの `./Build-Windows.ps1` を実行する。プレイヤーは `Builds/Windows/`、Editor のログは `Builds/editor.log` に出力する。画面解像度は標準の `-screen-width`、`-screen-height`、`-screen-fullscreen 0` で指定できる。計測用に `-kinsei-metrics` を付けると、決着時に描画間隔の中央値と95パーセンタイルがプレイヤーログに記録される。

## 美術と制作資料

[16点の設定画と店内原画](art-source/atelier/README.md)、[GPT Imageの原画](art-source/GPT-Image.md)、[ComfyUIの実行記録](art-source/moss/README.md)、[人物素材](Game/Assets/Kinsei/Cast/README.md)、[建築の表面](art-source/Surfaces.md)、[制作条件と各版の範囲](docs/PRODUCTION.md)。

