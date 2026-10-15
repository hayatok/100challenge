# 全力退勤：実装の検証

各版の確認環境と実画面を以下へ記録する。PCキーボードと横画面が対象。生成モック、固定モデル描画、実キーの通し操作を区別する。

## 破壊連鎖と同僚の個性 v0.7 の検証

2026-10-15（Asia/Tokyo）。[生成した画面イメージ](../art/screens/v0.7/01-chain-reaction.png) をユーザーが確認してから実装した。変更前は公開v0.6をアプリ内ブラウザで開始・噴射・破壊・Escで操作し、物体が消える既存の表現を確認した。現在の仕様は [CHAIN_REACTION_DESIGN.md](CHAIN_REACTION_DESIGN.md)。以下はローカル検証の結果。続くユーザーの追加依頼でコミットとPages公開を進め、公開版のSHA・CI・Pages・配信物と実操作の確認結果を [Issue #159](https://github.com/hayatok/100challenge/issues/159) へ記録する。

`npm run check` はGodot 4.6.3で成功。20モデル、import、ルール13件、共有メッシュと日本語字形、実物理・通路、時間差の伝播と一度だけの加点、崩壊・残骸、猫マグと承認印、ポーズ・成功・再挑戦の統合、Webビルドを通過。ルートの `npm test` は38件成功。差分の空白検査とPython構文も通過。[チェック一覧](verification/v0.7/checks.json) と [モデル測定](verification/v0.7/model-report.json) に保存する。

最終のブラウザ試験はmacOS、Chromium 153.0.8010.12、ANGLE Metal / Apple M5、headlessで実行。`scripts/browser-qa.py --headless --out docs/verification/v0.7` が、実際のキー・メニューのみで以下を確認した。QA状態は読み取り専用で、テレポートや破壊状態の書き換えは使わない。

- 最初のワゴンは物理時計1.7667秒、塔は2.1167秒、箱は2.4667秒で受理。sourceはワゴン→塔→箱、深さは0／1／2。各0.35秒で、最初の一連は¥230,000・3連鎖。
- 近い猫マグ役と承認役が同時に反応し、承認印は1回。残り3人は通常業務。崩壊と床の残骸、二人の顔・手元・文字と次の進路を実画像で確認。
- ポーズで公式タイマー、残圧、位置、HUD・粒子・伝播予約・崩壊と社員の時計が停止。Rと結果の再挑戦で24個の元の形と予約・残骸・反応を初期化。
- 実キーで出口へ到達し、23.733秒・SSS・被害総額¥1,320,000・最大6連鎖・14個破壊。ゴール後は予約0件で、ページ再読み込み後も自己ベストを保持。これは検証操作の記録で、熟練プレイヤーの記録ではない。
- 1280×720、1920×1080、960×540で同じ最初の連鎖を実キーから再現し、文字・枠・主操作の欠けや重なりを確認。結果画面も3サイズで確認。960×540は縮小時の最低限の確認。
- 実メニューから控えめ・BGMと効果音0%を設定。控えめでも同じ接触時刻と記録、承認動作、20粒子以下を維持。Chromiumの別ページへの切替で自動ポーズし、明示的な再開を確認。

ブラウザエラー0件。通しプレイの採取点は60fps・66〜140描画。M5でのこの試験の観測値で、全フレームの最低fpsや他のGPUの保証ではない。状態と比較値は [browser-report.json](verification/v0.7/browser-report.json) を参照。

| v0.7の実ブラウザ画像 | 内容 |
| --- | --- |
| [ワゴンに接触](verification/v0.7/local-wagon-contact.png) | 直接の破壊と動き始めたワゴン |
| [塔へ伝わる](verification/v0.7/local-tower-contact.png) | 次の接触、曲がる塔と紙の扇 |
| [箱と二人の反応 720p](verification/v0.7/local-reaction.png) | マグ死守・承認印・3連鎖、残る形 |
| [同じ場面 1080p](verification/v0.7/local-reaction-1920.png)・[960×540](verification/v0.7/local-reaction-960.png) | 同じ実操作で画面幅を比較 |
| [結果](verification/v0.7/local-result.png)・[1080p](verification/v0.7/local-result-1080.png)・[960×540](verification/v0.7/local-result-compact.png) | 実際に出口へ到達した記録 |
| [ポーズ](verification/v0.7/local-pause.png)・[設定](verification/v0.7/local-settings.png)・[控えめ](verification/v0.7/local-subdued.png) | 実メニュー、停止と低演出 |

アプリ内ブラウザでも同じローカルビルドを手動操作し、噴射→3連鎖・二人の反応→R→Esc→タイトル復帰を確認した。アプリ内ブラウザの新規パネル作成は通常のタブ非アクティブ化を判定できなかったため、フォーカス喪失の証拠には使わず、上記のChromium試験を正とする。

単体モデルの正面確認だけでは、プレイカメラで社員の顔や手元が画面外へ出ることを見逃す。実キーの画面を見て最初の机を通路横へ寄せ、承認役の机を半回転し、最初の連鎖を通路の右へ振った。経路検査を再実行し、演出用の紙を減らして動く荷物を読めるようにした。控えめの見た目だけ接触が早まる問題も、接触前の時計を通常と共通にして修正・検査した。

破壊物3種のGLBとBlender原本だけを再制作し、他17モデルは保持。箱1,260三角形／8面、塔2,624／5面、ワゴン3,996／6面。全20モデルは67,369三角形・1,943,988バイト。未破壊と静止後は各1面、崩壊中だけ可動群を描き、影と物理ボディは増やしていない。初見の面白さ、他のブラウザ・GPU、スマホ操作、実スピーカーでの音質は未確認。

以下は過去のクラウドLinux・Mesa llvmpipeによる各版の記録。

## 操作に応える職場 v0.6 の検証

変更前の [プレイ](verification/v0.6/before-play.png) と [タイトル](verification/v0.6/before-title.png) を保存し、[操作と社員の反応の見本](../art/screens/v0.6/01-action-reaction.png) を先に生成・共有してから実装した。発生条件は [INTERACTION_DESIGN.md](INTERACTION_DESIGN.md)。生成画像、固定場面の実行レンダー、実キーの通しプレイを分けて保存している。

`npm run check` は20モデル、Godot import、ルール13件、日本語表示と共有メッシュ、実物理・経路・破壊、社員の反応、噴射と方向別の破壊、演出の容量と寿命、実シーンの統合、Web出力を通過。ルート38件も通過した。新しい検証は次のとおり。

- 実際の最初の破壊位置から近い1人が反応し、遠い4人は眠そうな姿勢を保つ。半径12m、同時最大2人、遅延・クールダウン、破壊IDの再通知防止、強い破壊による姿勢の強化と開始時計の維持を確認。
- 顔・椅子・頭・マグの変化と元の姿勢への復帰、控えめの振り向きと「！」、ポーズでの遅延・経過時間・クールダウンの停止、再挑戦での全初期化を確認。
- 後方につながる噴射の開始、実速度・ラッシュ・旋回への追従、150ms以内の解除、移動したノズル間の補間、不連続移動時に古い尾を残さないことを確認。斜めの拡縮で形が歪まないことも検査。
- 紙の塔・箱・ワゴンの方向、紙と金色片の比率、強さによる星形の大きさ、低fpsで短いピークを一度描くこと、7バッチと1噴射ノード、80／52／20と予約枠を確認。
- 噴射を押したままゴールし、キーのリピートと解除が結果の再挑戦へ流れないことを確認。到着方向にかかわらず成功の顔を見せ、確定した位置・向き・記録は保持し、フォーカス喪失で見た目の旋回も止まることを確認。

最終Web版を実キー・メニューで操作し、31.229秒・SS「定時の覇者」・被害総額¥1,710,000・最大6連鎖・17個の破壊で退勤した。最初の反応の読み取りでは7.94m先の1人が驚き、他4人は開始0回。通しプレイでは社員の開始回数が順に1／1／0／2／1で、同時に2人を超えない。ラッシュは世界内とHUDが各2回、成功は1回。ポーズで社員・噴射・粒子・HUDも停止し、Rと結果ボタンは前の反応を初期化した。記録の再読み込み、控えめと消音、別タブへの移動と明示的な再開も通過。ブラウザエラーは0件。[browser-report.json](verification/v0.6/browser-report.json) に各状態を保存する。状態変更やテレポートは使っていない。

| v0.6の実ブラウザ画面 | 確認した内容 |
| --- | --- |
| [タイトル](verification/v0.6/cloud-title.png) | 既存の漫画調の文字と枠、開始・設定 |
| [噴射](verification/v0.6/cloud-boost.png) | 連続した白い形と青緑の縁、主役と進路 |
| [破壊と社員の反応](verification/v0.6/cloud-reaction.png) | 方向のある紙と星形、近くの社員の表情とマグ |
| [ラッシュ](verification/v0.6/cloud-play.png) | 一回の通知と局所演出、反応する社員と眠そうな社員 |
| [ポーズ](verification/v0.6/cloud-pause.png) | 操作と全演出の時計の停止 |
| [成功直後](verification/v0.6/cloud-success.png) | 判子と祝い、押し続けた噴射を離しても結果を維持 |
| [結果720p](verification/v0.6/cloud-result.png)・[1080p](verification/v0.6/cloud-result-1080.png)・[960×540](verification/v0.6/cloud-result-compact.png) | 成功の顔、記録、文字の欠け・重なり、再挑戦 |
| [設定](verification/v0.6/cloud-settings.png)・[控えめ](verification/v0.6/cloud-subdued.png) | 実部品の操作、低演出でも残る小さい噴射と情報 |

同僚の造形は4可動グループへ分け、8,696三角形・4面・1共有素材。20モデル合計67,305三角形・1,930,264バイトで、他19モデルは変更していない。[モデル測定](verification/v0.6/model-report.json) と更新後の [正面](verification/v0.6/models/colleague-front.png)・[側面](verification/v0.6/models/colleague-side.png)・[背面](verification/v0.6/models/colleague-back.png) を保存。動く社員は静的背景の合成から除外し、椅子と一言を含め最大6つの表示ノード、影と物理ボディは増やしていない。

姿勢を比較する固定場面も保存した。[通常の顔](verification/v0.6/staged-colleagues/closeup-sleepy.png)・[驚きとマグ](verification/v0.6/staged-colleagues/closeup-startled.png)・[控えめ](verification/v0.6/staged-colleagues/closeup-subdued.png)、[通常カメラの前](verification/v0.6/staged-colleagues/normal-before.png)・[反応後](verification/v0.6/staged-colleagues/normal-reaction.png) と [条件・状態](verification/v0.6/staged-colleagues/report.json)。`godot --audio-driver Dummy --path game --script res://tools/render_reactions.gd` で再生成できる。これらは実行したモデルの固定場面で、実キー操作の証拠とは分ける。

噴射と破壊の固定時刻の診断は [後方噴射](verification/v0.6/staged-fx/rear-jet.png)・[旋回した噴射](verification/v0.6/staged-fx/turning-jet.png)・[接触の星形と扇](verification/v0.6/staged-fx/impact.png)。[条件](verification/v0.6/staged-fx/capture.json) に記したとおり、独立コピーのv0.5背景に新しい演出と現在のカメラを置いた画像。全要素を統合した確認は上の実ブラウザ記録を使う。

最終の通しプレイのサンプルは65〜125回の描画、5〜13fps。ソフトウェア描画と検証操作の遅れを含むため、熟練者のタイムや実PCの性能ではない。実GPUでの60fpsと初見の操作感は未確認。移動・残圧・衝突形状・得点・時間ランクは従来の値を維持している。CIと公開の完了記録は [Issue #159](https://github.com/hayatok/100challenge/issues/159) に置く。

## 演出・HUD v0.5 の検証

エフェクトの見本とラッシュ・衝突・結果・タイトルの4画面を先に生成して共有し、画像を確認してから実装した。仕様と対応は [FX_DESIGN.md](FX_DESIGN.md)。生成モックと実画面を分けて保存している。

`npm run check` は20モデルの検査、Godot import、ルール13件、共有メッシュと日本語表示、実物理、オフィスの経路・破壊、演出の容量と寿命、統合テスト、Web出力を通過。ルートの38件も通過した。追加した確認は、噴射中でも衝突と祝いへ容量を残すこと、80／52／20の上限、低fpsでも短い衝突を一描画すること、粒子の消滅、同時破壊の最終連鎖音、ラッシュ突入の一回だけの通知、結果の判子の発火と重複防止、時計の停止、再挑戦時の初期化。結果のフォーカス喪失でも判子と祝いを止め、復帰時は結果のまま再開する。

最終Web版を実際のキーとメニューで通しプレイし、53.745秒・S「見事な退勤」・被害総額¥1,490,000・最大6連鎖で退勤した。世界内とHUDのラッシュ突入はともに2回、成功の判子は1回。ポーズ中は公式時計・残圧・位置に加えてHUDと粒子の時計・寿命も停止した。Rと結果ボタンで再挑戦すると、前回のラッシュ・成功・紙吹雪が消える。ページ再読み込み後も記録が残り、控えめ・BGMと効果音の0%設定・別タブへの移動と明示的な再開も通過。ブラウザのエラーは0件。詳細は [browser-report.json](verification/v0.5/browser-report.json)。

| v0.5の実画面 | 確認した内容 |
| --- | --- |
| [タイトル](verification/v0.5/cloud-title.png) | 太いロゴ、操作札、開始・設定と大きい主役 |
| [噴射と破壊](verification/v0.5/cloud-boost.png) | 白い後方噴射、紙の縁と判子、被害明細 |
| [ラッシュ](verification/v0.5/cloud-play.png) | 一回の見出し、連鎖数字と加算札、速線 |
| [ポーズ](verification/v0.5/cloud-pause.png) | 新しい演出の停止と再開メニュー |
| [成功の直後](verification/v0.5/cloud-success.png) | 判子と祝い、即使える再挑戦 |
| [結果 720p](verification/v0.5/cloud-result.png) | 実際の退勤値、時間ランク、顔と出口 |
| [結果 1080p](verification/v0.5/cloud-result-1080.png) | 大きい画面の文字と枠 |
| [結果 960×540](verification/v0.5/cloud-result-compact.png) | 縮小時の欠け・重なり・操作面 |
| [設定](verification/v0.5/cloud-settings.png) | 実際のOptionButtonと独立した音量 |
| [控えめ](verification/v0.5/cloud-subdued.png) | 20粒子以下、軌跡と数字の跳ねを止めても情報を保持 |

タイトル・プレイ・結果・ポーズ・設定と、1280×720／1920×1080／960×540の文字、枠、主操作を確認した。再挑戦のブラウザ操作では、リサイズの描画を待ってからCSS座標をGodotの論理画面へ対応させる。通しプレイの状態変更やテレポートは行っていない。

最初の装飾の描画方法は全体で474〜616回の描画があり、見た目を保ったまま色付きの三角形へ集約した。HUD単体はタイトル549→27、プレイ576→39、結果472→30、ポーズ747→48へ削減。模様・輪郭を保持した比較と条件は [hud-render-report.json](verification/v0.5/hud-render-report.json)。最終の一面のサンプルは63〜98回の描画、2〜14fps。単体HUDの速度を一面のfpsとして扱わない。

このクラウドには実GPUがない。上のタイムと速度はソフトウェア描画とフィードバック操作の遅れを含み、熟練者の記録や実PCの性能ではない。実GPUでの60fpsと初見の操作感は未確認。3Dモデル、物理、加点と時間ランクはv0.4の値を維持した。

## 自動チェック

以下は初期実装とv0.4の検証記録。

リポジトリの `npm test` は38件通過。対象アプリへの `ci:apps` と `check:apps` も通過し、GodotのimportとWeb出力を確認した。

`npm run check` のテストは以下の振る舞いを確認する。

- 13件のルール確認：最初の入力から計時、同時破壊の順序、一度だけの加点、前進連鎖、最大×3、期限とランク、ゴール後の確定、リトライ。
- 実際の物理空間：噴射と慣性、方向変更、残圧、薄い壁を含む衝突、復旧とショートカット防止。
- オフィス：24個の小道具、近隣への連鎖、再加点禁止、リセット、ゴールの境界、椅子の半径を含む入口から出口への経路。
- 統合：本物のmainシーンでポーズし、残圧・位置・公式時計の停止、再開、リトライとタイトルへの復帰。

## 実ブラウザ

`scripts/browser-qa.py` は書き出したWeb版を開き、実際のキーとメニューで操作する。QA用の読み取り専用状態を `?qa=1` で参照し、状態の書き換えやゴールへのテレポートを使わない。

確認した範囲：タイトルから開始、噴射・旋回・惰性・回復、破壊と3連鎖以上、ポーズ中の停止、再開、Rによる初期化、エレベーターへの到達、ランク・被害総額・最大連鎖の結果、ページ再読み込み後のベストタイム、控えめの演出・消音、フォーカスを外した際の自動ポーズ。

最終の通しプレイは28.517秒・SSS・被害総額¥1,200,000・最大6連鎖。ページ再読み込み後も28.517秒が残り、ブラウザのエラーは0件。ソフトウェア描画上の操作確認であり、熟練プレイヤーのタイムとして扱わない。実行値と各状態の比較は [browser-report.json](verification/browser-report.json) に保存する。

画面は1280×720、1920×1080、960×540で確認。結果の文字・主ボタンの欠けや重なりは見つからなかった。960×540は縮小時の最低限の確認で、推奨は1280×720以上。

| 実画面 | 内容 |
| --- | --- |
| [タイトル](verification/cloud-title.png) | 操作案、開始、設定、主役 |
| [プレイ](verification/cloud-play.png) | 退勤タイム、金額、連鎖、残圧、漫画通知 |
| [ポーズ](verification/cloud-pause.png) | 再開・最初から・設定・タイトル |
| [結果 720p](verification/cloud-result.png) | 実際にゴールした試行の結果 |
| [結果 1080p](verification/cloud-result-1080.png) | 対象の大きい画面 |
| [結果 960×540](verification/cloud-result-compact.png) | 縮小時の確認 |
| [設定](verification/cloud-settings.png) | 演出とBGM・効果音の独立した音量 |

## 修正と限界

ポーズ中にmainのALWAYSを子が継承し、残圧が回復する不具合を修正した。player・office・effectsへPAUSABLEを明示し、headlessと実ブラウザで停止を検証した。Webではblurとvisibilitychangeも明示的に受け取る。Playwrightのフォーカス固定を解除してから実際に別ページへ移り、自動ポーズを確認する。headlessテストでは音声の再生を開始せず、描画・音声出力の確認は実行画面で行う。

固定背景は614個から190個の描画ノードへまとめ、主役は131個から76個、影を描く主役のノードは7個へ絞った。演出粒子は最大80個で、物理ボディを持たない。

このクラウドには実GPUがない。Chromium 154のMesa llvmpipeでは通しプレイのサンプルが9〜12fpsだった。ソフトウェア描画と検証操作の影響を受けるため、実PCの速度や60fpsの確認を完了扱いにしない。初見プレイヤーの遊びやすさ、Chrome以外、実GPU、タッチ操作は未確認。造形・背景の密度と破壊物の崩れ方は、モックへ近づける今後の仕上げ項目。

## アセット v0.4 の検証

2026-10-15（Asia/Tokyo）。参考画像は各オブジェクトについて正面・側面・背面を先に生成し、9枚のシートに20種類を収めた。Blender原本、GLB、制作スクリプトと、Godotから描画した全60枚の3視点を保存。対応は [ASSET_REWORK.md](ASSET_REWORK.md)。

`npm run assets:check` は20モデルの位置・法線・linear頂点色・素材・可動ノード・三角形上限を確認し通過。全GLB合計は67,405三角形、1,928,716バイト。`npm run check` のimport、色と共有メッシュ、ルール13件、実物理、オフィスの破壊と通路、ポーズ・再挑戦の統合テスト、Web書き出しも通過。ルートの38件のテストも通過した。

Compatibilityでlinear頂点色が暗くなる問題を修正し、読み込み時にsRGBへ一度だけ変換したメッシュを共有する。影は主役の大きな4グループへ限定。背景の描画ノードは旧190個から35個（静的な11区画＋個別の破壊物24個）、主役は旧76個から16個になった。細部が増えたため全背景は318,676三角形。配置数と描画量は [office-report.json](verification/v0.4/office-report.json)、モデルは [model-report.json](verification/v0.4/model-report.json) に保存する。

更新したWeb版は、Chromium154とMesa llvmpipeで実キー・メニューから通しプレイした。28.946秒・SSS・被害総額¥1,470,000・最大4連鎖で退勤。記録の再読み込み、演出の控えめ設定、消音、再挑戦、ポーズと実際に別ページへ移った際の自動ポーズも通過。ブラウザのエラーは0件。実行値は [browser-report.json](verification/v0.4/browser-report.json)。

| 更新後の実ブラウザ画面 | 内容 |
| --- | --- |
| [タイトル](verification/v0.4/cloud-title.png) | 新しい会社員・椅子・消火器と玩具の職場 |
| [通常プレイ](verification/v0.4/cloud-play.png) | 書類の層、CRT、猫マグ、曲がった案内帯と連鎖 |
| [ポーズ](verification/v0.4/cloud-pause.png) | 停止状態と再開メニュー |
| [結果 720p](verification/v0.4/cloud-result.png) | 顔を隠さない成功ポーズと出口 |
| [結果 1080p](verification/v0.4/cloud-result-1080.png) | 大きい画面の文字と主操作 |
| [結果 960×540](verification/v0.4/cloud-result-compact.png) | 縮小時の表示確認 |
| [設定](verification/v0.4/cloud-settings.png) | 演出と音量の操作 |

新しいモデルの3方向、主役の顔と出口、遊ぶ画面の文字の欠け・重なり・はみ出しを確認した。ゲームではMSAAを既定で使わず、モデル単体の確認レンダーに2×MSAAを使う。Webのフィードバック操作はソフトウェア描画による遅れで柱の外側に進んだため、QAの出口への接近と引き返しを実キーで行うよう調整した。状態の書き換えやテレポートは使っていない。

このクラウドに実GPUはなく、通しプレイのサンプルは6〜15fps。実PCでの速度と60fpsは未確認。破壊時は本体を隠して紙と破片を散らす既存の方式で、家具の細かな崩壊と残留破片は追加していない。
