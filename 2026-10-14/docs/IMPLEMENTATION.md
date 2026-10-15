# 初期実装の担当と接続

Godot 4.6.3、Compatibility描画、単一スレッドWeb書き出し。`game/main.tscn` と `game/scripts/main.gd` が全体を統合する。最初の制作範囲は仕様の一面。

## 分担

- メイン：プロジェクト、書き出し・実行、ルールと記録、統合、ブラウザ検証、文書とPR。
- 移動担当：`game/scripts/player.gd`、`game/tests/player_checks.gd`。
- ワールド担当：`game/scripts/office.gd`。
- アート担当：`game/scripts/actor.gd`。
- HUD・演出担当：`game/scripts/hud.gd`、`game/scripts/effects.gd`。

同じファイルを複数担当で編集しない。以下のAPIは統合の基準。追加が必要なら担当間で連絡する。

## player.gd

`extends CharacterBody3D`。床面の移動、慣性、旋回、残圧、衝突・復旧を担当する。見た目はactorを子に付ける。進行方向はローカル-Z、初期yaw=0。

- signal `impacted(speed: float, at: Vector3, normal: Vector3)`。
- 公開変数 `pressure: float`（0〜100）、`boosting: bool`、`steering: float`、`active: bool`、`hit_stop: float`。
- `set_controls(turn: float, spray: bool)`、`reset_at(pos: Vector3, yaw: float = 0.0)`、`set_active(value: bool)`。
- `get_speed() -> float`。
- 残圧は毎秒25消費・50回復を初期値。旋回と推進を物理更新に置く。hit_stop中は移動だけ停止、残圧と入力状態は更新する。
- 衝突レイヤー1、mask2（固定世界）。壊せる物はofficeで判定する。最大速度候補9m/s。
- rootの高さは床面y=0、見た目とコライダーの高さは子で調整する。

## office.gd

`extends Node3D`。固定家具、床、出口と3種類の破壊物を生成する。主路はおおむね-Z、初期位置(0,0,42)、出口(0,0,-64)。長さ約106m、幅約16mを初期候補とし、二つの緩い曲がり角を作る。

- 公開変数 `spawn_position: Vector3`、`goal_position: Vector3`。
- `build()`：固定のオフィスと物体を生成。
- `reset_props()`：破壊物を元に戻す。
- `react_to_breaks(rewards: Array, player_at: Vector3, speed: float) -> Dictionary`：受理済みの新しい破壊地点から12m以内の近い最大2人を反応させる。同時に待機・反応する人数も2人まで。返り値はaccepted/upgraded/suppressed/selected。
- `set_feedback_quality(level: String)`、`debug_feedback_snapshot()`：社員の控えめ設定と、JSONで読める検証用状態。
- `try_break(at: Vector3, speed: float, direction: Vector3 = Vector3.FORWARD) -> Array[Dictionary]`：直接当たった未破壊・未予約の物だけを処理。id/base/progress/position/kind/textに加え、direction/impact_speed/depth/chain_root/source_idを返す。
- `advance_destruction(delta: float) -> Array[Dictionary]`：ポーズしていないプレイの物理更新から一度だけ呼ぶ。0.35秒で到達した次の接触を返す。24個を8組に分け、同じ組のワゴン→塔→箱に最大2段だけ伝える。
- `stop_propagation()`：ゴールで未確定の接触予約を消し、記録確定後の破壊を防ぐ。
- `is_goal(at: Vector3) -> bool`、`distance_to_goal(at: Vector3) -> float`。
- 家具はStaticBody3D、layer2、mask1。破壊物は通れる判定で、紙の大量の物理ボディを作らない。
- 色はクリーム床、青緑の家具、オレンジの夕日、緑の出口。小物の一部だけボクセル感を加える。

## breakable.gd / colleague.gd（v0.7）

`breakable.gd` は加点原点を動かさず、可動群を持つ3種類のGLBを崩す。`build(kind, index)`、`begin_break(direction, travel)`、`reset_visual()`、`set_feedback_quality(level)`、`debug_snapshot()` が接続面。ワゴンの移動と塔の曲がる向きは次の実接触へ合わせる。元の形と静止後は各1面へ合成し、崩壊中だけ複数の可動群を描く。非衝突・影なしで、静止後の時計を止める。

`colleague.gd` の `build(id, personality = "mug")` で猫マグ／承認役を選ぶ。承認役は元のマグ腕を隠し、共有の袖・手・印鑑を使い、机上の紙へ0.48秒で接触する。`react`、`reset_reaction` と既存の強化・再発生間隔を使う。近い最大2人だけをofficeが選び、JSONで読める役・接触・朱印の状態を返す。

## actor.gd

`extends Node3D`。画像の3視点に沿ったBlender製の会社員、青緑の椅子、赤い消火器をGLBから読み込む。頭・髪・表情・手足・ネクタイ・ホース・キャスターが読める形にする。

- `build()`。
- `update_pose(delta: float, speed: float, turn: float, spray: bool, impact: float, rush: bool, won: bool)`。
- rootの原点は床面、前方向は-Z。体と椅子の揺れ、丸い大きな表情、衝突と勝利のポーズを担当する。標準的な斜め上カメラでも顔が見えるように頭の向きと姿勢を工夫する。

## hud.gd

`extends CanvasLayer`。

- signal `start_requested`、`restart_requested`、`resume_requested`、`title_requested`。
- signal `settings_changed(effect_level: String, music_volume: float, sfx_volume: float)`。
- `build()`。
- `reset_run()`。playingからplayingへの再挑戦でも通知・数字の跳ね・ラッシュと成功の時計を初期化する。
- `present(mode: String, data: Dictionary)`。modeはtitle/playing/paused/result。
- data：elapsed/damage/combo/multiplier/pressure/distance/max_combo/rank/rank_text/best_time/new_best/save_error。
- `burst(text: String, bonus: String = "", kind: String = "impact")`。
- 本文は `NotoSansCJKjp-Medium.otf`、大きい文字は改名・サブセット化した `TaikinComic-Black.otf`。`scripts/ui/comic_surface.gd` が紙の切れ込み、クリップ、二重線、金の印、メーターなどをCanvasへ描く。1920×1080基準でscale対応。
- 装飾は色付きの三角形を部品ごとのArrayMeshへまとめる。静的な枠をキャッシュし、色・寸法・メーターの段・低残圧の色、速線と祝いの位相が変わる際だけ更新する。文字・Button・OptionButton・SliderはGodotの実部品で保持する。
- 点・罫線・バーコード・輪郭を一つの頂点色付きArrayMeshへまとめ、静的な飾りをキャッシュする。形・色・寸法・メーターの段階、動く速線と祝いの状態が変わったときだけ更新する。文字とボタンはGodotの実際のControlのまま保つ。
- 結果は主記録のタイム、時間ランク、被害総額、最大連鎖。「もう一度」を主操作。
- resultへの遷移で判子の時計を一度だけ始める。successの通知や毎フレームのpresentで入口をやり直さない。通知・数字・判子と速線の時計はポーズとフォーカス喪失で止める。控えめは跳ねと速線を止め、文字と記録を残す。

## effects.gd

`extends Node3D`。紙・粉・小さな立方体、短い音、ラッシュの演出。

- `setup()`、`set_quality(level: String)`、`set_volumes(music: float, sfx: float)`。
- `set_exhaust(at: Vector3, backward: Vector3, spraying: bool, rush: bool, speed: float = 0.0)`。
- `burst(at: Vector3, strength: float = 1.0, forward: Vector3 = Vector3.ZERO, kind: String = "paper")`、`play_combo(count: int)`、`celebrate(at: Vector3)`。小道具はtower/box/wagonを渡す。
- `impact(at: Vector3, normal: Vector3, strength: float = 1.0)`、`start_rush(at: Vector3)`。
- 主役と前方を塞がない量。通常は80程度を目安に同時粒子へ上限、控えめは約25%。音声は生成した短い音でよい。ゲーム時間の止め方はmainが管理する。
- 7種類の共有MultiMeshで粉・紙・立方体・星形・輪・軌跡・リボンを描く。粉と小道具はGLB、星形などは `scripts/fx/graphic_meshes.gd` の共有メッシュ。上限80／52／20のうち28／20／6をイベント用に予約し、重要なイベントは古い噴射から置き換える。
- 発生直後の一描画を保持し、低いfpsでも短い星形のピークを一度表示する。紙の輪郭は薄い専用縁として合成し、モデルの文字・罫線へinverted hullを使わない。

## メイン側

`rules.gd`は時間、同時破壊の安定した順序、有限加点、倍率、ラッシュ、ランクを管理し、頭なしテストで確認する。`main.gd`が入力・プレイヤー・ワールド・アート・UI・演出・記録を接続する。プレイとブラウザの非アクティブ化では正しくポーズする。

`_present_breaks` は各小道具の破裂を残し、同時破壊の連鎖音を最後の値へまとめる。ラッシュ通知と音は `reward.rush_started` にだけ反応する。successはresultへpresentしてから送る。固定家具への衝突には、playerが返した接触位置と法線を使う。

プレイのフォーカス喪失は明示的な再開を要するポーズ。結果の短い判子・祝いは非アクティブ時に停止し、フォーカスが戻るとその続きから再開する。タイトルと結果のカメラは、紙のUIの右に主役が大きく見える距離へ寄せる。v0.6のプレイカメラは主役との距離を少し縮め、向きは固定して進路と近隣の反応を見せる。移動・ルールは維持する。

描画の監視とブラウザQAのため、開発時だけ使う状態出力を用意する。製品の画面へ実装用のログやテスト項目を置かない。

## モデルの読み込みと描画 v0.4

`asset_library.gd` がGLBのシーンをキャッシュし、白いアルベドに頂点色を使う素材を共有する。glTFのlinear頂点色を一度sRGBへ変換し、Compatibilityでの二重変換による暗い色を避ける。変換済みメッシュもモデルごとに共有する。GLBには衝突形状を含めず、家具・壁・ゴールの衝突はofficeの元の寸法を使う。主役の13グループは表情・手足・ネクタイの動きに残し、大きい体・頭と椅子の4グループだけ影を出す。

静的な背景は素材と16mの区画ごとにまとめ、画面外の区画をカリングできるようにする。破壊物は各一面のメッシュを24個保持し、個別に隠す。床モデルは `BaseTiles` と `Wayfinding` を分け、床面は繰り返し、案内だけを実際の曲がる経路に配置する。法線は合成変換の逆転置行列で変換し、頂点色と丸みを保持する。

粒子は曲がった紙、つながった4つの膨らみを持つ粉、角を丸めた金色の立方体をGLBから一度読み込む。メッシュを共有し、頂点色のunshaded素材・影なし・物理ボディなしで既存の上限80個を維持する。

`npm run assets:build` はBlenderから全モデルを再生成する任意の制作コマンド。出力GLBを追跡するため、通常の起動とCIにBlenderは不要。`npm run assets:check` はPythonの標準ライブラリだけで20モデルの属性、法線、有限座標、色、素材、可動ノードとポリゴン上限を検査する。

## 操作に応える職場 v0.6

`colleague.gd` は既存の眠そうな同僚を、Body、Head、ArmMug、FaceNeutralの4グループで読み込む。頭とマグの腕は上体の子。通常の顔を広い目と開いた口の共有メッシュへ切り替え、椅子の旋回、上体の反動、猫マグの持ち上げを破壊位置に向けて動かす。固定椅子は元の2面を一度だけ1つの共有メッシュへ合成。反応中も椅子と短いLabel3Dを含め最大6描画ノード、影・物理ボディは追加しない。officeの静的背景合成は同僚の枝全体を除外する。

officeは破壊IDを記憶し、近い社員を距離順に選ぶ。遅延は0.05〜0.26秒、動作は1.4秒、個人のクールダウンは2.8秒。速度7m/s以上、10万円以上、3連鎖以上かラッシュ開始で強い反応になる。進行中の反応を強めても経過時間と開始回数を戻さない。`reset_props()` が姿勢・顔・一言・全時計・破壊IDを初期化する。

噴射は7つの粒子バッチに加え、1つの閉じた白い連続メッシュを作成時から保持する。小さいノズル口から丸い尾へ広げ、実速度・ラッシュ・開始時の短い脈動で長さと幅を変える。変換の各軸をローカル方向へ拡縮し、旋回中の斜めの形が歪むのを防ぐ。前後のノズル位置を補間して粉を出し、開始・解除・6m以上の不連続移動で古い尾を切る。解除後150ms以内に形を引き、成功・再挑戦で消す。

破壊はルールが受理した各小道具の種類・位置と実速度・移動方向を使う。接触の後ろの星形と輪、前へ曲がる紙の扇、箱の金色片の比率を変え、80／52／20とイベント予約枠を維持する。社員・噴射・粒子の全時計はPAUSABLEで停止する。検証は単体の反応・実シーンの統合・実キーのブラウザ操作を分ける。

結果ではactorの見た目だけを短く旋回し、どの到着方向でも既存の勝利の顔をカメラへ向ける。物理のplayerの座標・向きと確定したタイムを変えない。ゴールをまたいでSpaceが押されていた場合は、そのリピートと最初の解除をmainの `_input` でGUIより先に消費し、新しくフォーカスした再挑戦ボタンの誤作動を防ぐ。新たなクリック・Enter・Rはそのまま使える。
