# 素材の品質向上の検証

基準は56d7aa8。タイトルと戦闘の絵の密度を揃えるため、「月明かりのゴシック絵本」を指針にした。人物と魔物の原画、三章の床と障害物、装備・報酬・図鑑の絵を更新した。今回の仕様は[ART_UPGRADE.md](../ART_UPGRADE.md)、出典は[ASSETS.md](../ASSETS.md)。

## 画面と素材

魔女、通常敵6種、ボス3種は、各1枚の原画に部位ごとの変形を付ける。36姿勢分のメッシュを保持し、毎フレーム画像やメッシュを作らない。アイコン40種は同じ原画と切り出しを共有する。ドットの火花と破片は残した。

床と障害物は章ごとに保持し、モデルの衝突矩形と前後関係を使う。障害物のアトラスは従来の1024×2048以内、保持する章は3件まで。キャラクターとアイコンには縮小用のmipmapを用意した。画像の寸法・透過・SHA-256は[art-source.json](art-upgrade/art-source.json)、検査対象のソースとWeb出力は[tested-source.json](art-upgrade/tested-source.json)に記録する。

変更前の画面は、同じ基準コミットで採取した既存のWeb記録からコピーした。[before-source.json](art-upgrade/before-source.json)に出典とハッシュを残す。生成画像、配置見本、実入力の画面を同じ証拠として扱わない。

| 証拠 | 確認した内容 |
| --- | --- |
| [人物の配置見本](art-upgrade/native/actors/echo-painted-actors-contact.png) | 10種と9つの動作状態。別のネイティブ描画検査で部位の画素変化、向き、足元、180回の再描画時の資源保持も確認 |
| [庭園](art-upgrade/native/environment/chapter-1-all-props.png)・[書庫](art-upgrade/native/environment/chapter-2-all-props.png)・[塔](art-upgrade/native/environment/chapter-3-all-props.png) | 全ての障害物を並べたネイティブ見本。切り出し、接地、占有範囲、章の再入場とアトラス予算 |
| [アイコンの配置見本](art-upgrade/native/icons/painted-icons-contact-sheet.png) | 40種を明暗両面へ36px・72pxで配置。空欄・進化・未発見の状態も別に描画 |
| [原画を使った序盤](art-upgrade/full-browser/echo.png)・[庭園のボス](art-upgrade/full-browser/boss-0-battle.png)・[書庫のボス](art-upgrade/full-browser/boss-1-battle.png)・[塔のボス](art-upgrade/full-browser/boss-2-battle.png) | 通常ルールのWebで、時刻やHPを変更せずに行った自動キー入力の画面 |
| [強化の頁](art-upgrade/full-browser/upgrade.png)・[勝利](art-upgrade/full-browser/final-victory.png) | 同じ三章通しの実入力から採取した画面 |

ネイティブの見本は状態を配置しており、通常の進行を遊んだ証拠ではない。背景ウィンドウで同期待ちが止まった再実行では、`--disable-vsync --fixed-fps 60`を指定した。実際の描画を検査しているが、処理速度の測定には使わない。

## 検査と実入力

アプリの`npm run check`でインポート、戦闘・成長・保存・GUI・音声・描画・素材の検査とWeb出力が成功した。共通テストは38件が成功した。新しい環境とアイコンの検査も通常の実行対象に加えた。詳細は[check.log](art-upgrade/check.log)と[validation.json](art-upgrade/validation.json)。

WebはChromeの独立した検証用ブラウザで、自動キー入力とクリックを行った。通常速度で三章・3体のボスを完走し、ゲーム内時刻623.95秒、HP68、討伐1671、Lv.12で勝利した。30秒の休止、章間の装備引継ぎ、同じページでの再挑戦35.23秒、解放と設定の再読み込みを含む18項目が成功した。予期しない実行エラーと外部通信は0件だった。

別の実入力では、動作と残像・詠唱・演出軽減の10項目、敗北・フォーカス喪失・再挑戦・960×540／1920×1080・読み込み失敗からの復帰の9項目、保存の6条件90項目を確認した。結果は[motion](art-upgrade/motion-browser/results.json)、[edge](art-upgrade/edge-browser/results.json)、[storage](art-upgrade/storage-browser/results.json)に分けている。

最終PCKは`82cbad3177dfc14444803980bddd7613aa580002e70b73e1bb54d0536aeec9ff`。検証の前後でハッシュは一致した。PCKは51,025,196 bytesで、基準より17,310,644 bytes増えた。

## メモリと限界

通常の三章通しは音楽を有効にし、ゲーム状態を変更する機能や強制GCを使っていない。24回の採取で、JSヒープの最大は279.17MiB、単一rendererのRSS最大は958.16MiB、全rendererの合計RSS最大は1168.70MiBだった。採取したFPSは55〜61、リソース数は45で一定だった。[results.json](art-upgrade/full-browser/results.json)に条件と採取値を残す。

ソフトウェアWebGLを含む検証環境の値であり、物理GPUの性能保証ではない。前回は他の検証ブラウザが動いた時間もあるため、前回の数値から性能向上を主張しない。一回の通しと短い再挑戦から、無制限の連続周回でメモリが増えないとも判断しない。実機Safari／Firefox、低性能PC、人間の初見の面白さは未確認。

## レビューと日本語

独立した6.1 Solの画面レビューで、新規画像の縮小時の粗さと、庭園床の目立つ小石・花びらを指摘された。mipmapを有効にし、床をimagegenで編集して再描画した。再確認では両点への対応と、隣の素材の混入がないことを確認した。石目の反復は残るが、視認性の追加修正を要する指摘はない。

必須のAI Slopレビューはgpt-6-astraが担当し、結論と確認範囲は[review.json](art-upgrade/review.json)に記録する。日本語は原文と資料を保存して候補と全文差分を読み、yomiyasuのrunと実ファイルのverifyを行った。説明の「ます」の反復と、参照を促す文は役割を確認して残し、古い検証結果と現在の結果を区別する。私的な原文と検査記録は`.yomiyasu/art-upgrade/`へ置き、公開対象に含めない。

PR #197とIssue #196へ反映する。ProjectはIn Progressを維持する。今回の対象はローカル版と既存PRの更新までで、公開済みの3分版とは区別する。
