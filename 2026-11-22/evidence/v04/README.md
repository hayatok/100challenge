# v0.4　四十軒の朝　Windows実機記録

Windowsの実プレイヤーに対して、キーボードとマウスで出撃し、通常の店頭・帳場・組員指示で両方の終幕まで進んだ。短編は店、左手の原盤、歩行→走行→停止、送像所・帳場の初放送を約25秒で見られる。共同・専属の全編はタイトルから結果画面まで連続収録した。[短編](stage-and-street.mp4) ／ [共同の全編](final-joint.mp4) ／ [専属の全編](final-sole.mp4)

## 解放・移行・再起動

|実際の開始状態|通常入力での経過|精算の実ファイル|
|---|---|---|
|初版・新しい保存先|通常出撃で部下に帳場を指示、兄貴分を追跡。12,000円、座長の約束を得た。再起動し、次夜は帳場の16,000円を手で回収して兄弟の和解まで進めた。|[追跡結果](ending-fresh-one.png)・[台帳](ledger-fresh-one.json)・[入力ログ](player-fresh-one.log) ／ [和解結果](ending-fresh-two.png)・[両約束、28,000円](ledger-fresh-unlocked.json)・[入力ログ](player-fresh-two.log)|
|同じ新規帳面の3夜目|再起動してタイトルのFから最終夜へ。針音堂の左卓でE→Tab、2、Eで送像所へ→金星帳場でE→Tab、3、Eで開場。|[専属の印と3夜目](ledger-fresh-exclusive.json)・[入力ログ](player-exclusive.log)|
|v0.2で実際に獲得した旧帳面のコピー|両約束だけある状態でF。左卓で原盤を受け取り、2番に送像所の交換卓を指示、自分で送像所に戻りE、3番にロータスの客席を任せた。|[移行元](../v02/ledger-after-accord.json)・[共同の印](ledger-migrated-cooperative.json)・[入力ログ](player-migrated.log)|
|美術統合版・旧帳面の独立コピー|共同後にプロセスを再起動。同じ帳面で専属を選択し、さらに再起動してタイトルを撮影。残高28,000円を保持し、4夜・4完了で両印が立った。|[共同直後](ledger-release-cooperative.json)・[専属直後](ledger-release-both.json)・[再起動タイトル](title-portrait.png)|

## 結果画面での再記帳

再試行修正版に旧帳面の新しいコピーを渡し、Fで3夜目に入ったあと、別のPowerShellプロセスが専用保存先の `kinsei-ledger.json.lock` を `FileShare.None` で保持した。共同の結果で共有違反を発生させ、結果画面でRを押した。ロック中は保留表示が続き、解放後のRで `ledger-retry-finished` が記録された。どちらのRも結果時刻36.57秒。再出撃せず、3夜・2完了・共同なしから、3夜・3完了・共同ありへ移行し、28,000円は維持された。プロセスを終了し、同じディレクトリを指定して再起動したタイトルの印も確認した。[保留画面](still-locked-retry.png)・[成功画面](retry-saved-retry.png)・[再起動タイトル](title-cafe-front.png)・[保留時の台帳](ledger-retry-pending.json)・[成功後の台帳](ledger-retry-finished.json)・[共有違反と2回のRのログ](player-retry.log)

## 画面と音

- 針音堂の卓・棚とジャケットを背景に受け取る。店内の立ち姿では体が袖を隠す角度があり、通りを横切る走行では左手のカラー印刷が読める。[陳列](master-desk-final-joint.png)・[左手の袖](run-final-joint.png)
- 送像所の卓に原盤と袖を置くと、受像機は試験画面からロータスに切り替わる。指針は共同全編の30.250秒で左、31.625秒で右を向いた。比較画像は同じ原寸142×74ピクセルを2枚並べたもの。作中の印刷物は複数確認したが、全16種を独立に判読・照合してはいない。[送像所の卓](delivery-final-joint.png)・[VU針の実画素比較](vu-needle-detail.png)
- 初放送を共同で33.74～37.35秒、専属で31.22～34.83秒に観察。共同はCRTに澄子と最前列の組員、専属は金星帳場の役者・組員と字幕が出る。その後、専用の朝の結果絵に切り替わる。専属カットでは前景の組員が座長の一部を隠す。[ロータスからの放送](first-broadcast-joint.png)・[金星の開場](closing-1-final-sole.png)・[共同の朝](ending-final-joint.png)・[専属の朝](ending-final-sole.png)
- 店内へ歩いて会話し、澄子の盆・サイフォンと村瀬の調整卓、両者の横顔と仕事中の腕を撮影した。通常の肩越しカメラでは真壁や受像機と手が重なる角度があり、特に村瀬の頬・手元は暗い。[澄子の店内](barista-working-cafe-art.png)・[村瀬の店内](operator-working-relay-art.png)
- 専属全編28.35～32.70秒は金星の床で立位→歩行→Shift走行→停止。腕と膝の動きが連続して見える。通常の肩越し視点では足先が下端のHUDに隠れる瞬間がある。[走行中の1フレーム](run-final-sole.png)

## 計測・再現条件

NVIDIA GeForce RTX 4070 Ti、D3D12。各表の値は `-kinsei-metrics` のゲーム内フレーム時間。録画はWindows Graphics Captureのプレイヤーウィンドウだけを対象にクライアント領域を収録し、対象プロセスのWASAPI音声を48 kHzステレオで合成した。動画の24 fpsは保存側のフレームレート。時間は1経路1回の値で、初版の720p和解では95パーセンタイルが16.7 msを超えた。

|ビルド・経路|解像度|フレーム数|中央値 ms|95%点 ms|
|---|---:|---:|---:|---:|
|初版・通常追跡|1280×720|967|16.67|16.68|
|初版・通常和解|1280×720|1,672|16.67|20.16|
|初版・共同／専属|1920×1080|2,038／1,965|16.67／16.67|16.68／16.68|
|美術統合・[共同](player-final-joint.log)／[専属](player-final-sole.log)|1920×1080|2,203／2,056|16.67／16.67|16.68／16.68|
|再試行修正・共同|1280×720|2,156|16.67|16.67|

実行は各版の独立コピー、`KINSEI_SAVE_DIRECTORY` はQA専用の一時ディレクトリ、`-screen-fullscreen 0 -screen-width <幅> -screen-height <高さ> -kinsei-metrics -logFile <ログ>` を使用した。座標ログは移動結果の観測に使用した。プレイヤーと仲間の移動、会話、精算はすべてゲーム本来の操作を通した。

|収録時の版|Assembly-CSharp.dll SHA-256|
|---|---|
|初版・新規解放および旧版移行|`e54dbbee4ac804bd68ff562c45430a88a0d67a6daa877fee689292bad7d996e6`|
|美術・初放送統合版、FHD最終ルート収録|`6c3cb8acddfbb956ec4c74783e9fe64d0cf2c703476d42d8101372330ec303b7`|
|再試行修正版、720p故障注入と再起動|`8cffe8296bca1c48fd7a3a14547e9c869af1c929a161dfa36b6ab6534f658606`|

配布ZIP SHA-256は `775e3671bf06d22d685c4db4d8832b1bf08b62b15b12f676f70df5270a07abed`。全135ファイルのSHA-256を、再記帳を検証した独立プレイヤーと照合し、一致した。
