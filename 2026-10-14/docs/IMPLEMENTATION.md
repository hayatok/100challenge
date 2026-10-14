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
- `try_break(at: Vector3, speed: float) -> Array[Dictionary]`：接触した未破壊の物を処理してイベントを返す。id/base/progress/position/kind/textキーを含める。見た目の破壊済み状態はoffice内で管理。speedがほぼ0なら破壊しない。
- `is_goal(at: Vector3) -> bool`、`distance_to_goal(at: Vector3) -> float`。
- 家具はStaticBody3D、layer2、mask1。破壊物は通れる判定で、紙の大量の物理ボディを作らない。
- 色はクリーム床、青緑の家具、オレンジの夕日、緑の出口。小物の一部だけボクセル感を加える。

## actor.gd

`extends Node3D`。丸い会社員、青緑の椅子、赤い消火器をメッシュで作る。頭・髪・表情・手足・ネクタイ・ホース・キャスターが読める形にする。

- `build()`。
- `update_pose(delta: float, speed: float, turn: float, spray: bool, impact: float, rush: bool, won: bool)`。
- rootの原点は床面、前方向は-Z。体と椅子の揺れ、丸い大きな表情、衝突と勝利のポーズを担当する。標準的な斜め上カメラでも顔が見えるように頭の向きと姿勢を工夫する。

## hud.gd

`extends CanvasLayer`。

- signal `start_requested`、`restart_requested`、`resume_requested`、`title_requested`。
- signal `settings_changed(effect_level: String, music_volume: float, sfx_volume: float)`。
- `build()`。
- `present(mode: String, data: Dictionary)`。modeはtitle/playing/paused/result。
- data：elapsed/damage/combo/multiplier/pressure/distance/max_combo/rank/rank_text/best_time/new_best/save_error。
- `burst(text: String, bonus: String = "", kind: String = "impact")`。
- 字体は`res://assets/fonts/NotoSansCJKjp-Medium.otf`。1920×1080基準でscale対応、1280×720でも読めること。
- 結果は主記録のタイム、時間ランク、被害総額、最大連鎖。「もう一度」を主操作。

## effects.gd

`extends Node3D`。紙・粉・小さな立方体、短い音、ラッシュの演出。

- `setup()`、`set_quality(level: String)`、`set_volumes(music: float, sfx: float)`。
- `set_exhaust(at: Vector3, backward: Vector3, spraying: bool, rush: bool)`。
- `burst(at: Vector3, strength: float = 1.0)`、`play_combo(count: int)`、`celebrate(at: Vector3)`。
- 主役と前方を塞がない量。通常は80程度を目安に同時粒子へ上限、控えめは約25%。音声は生成した短い音でよい。ゲーム時間の止め方はmainが管理する。

## メイン側

`rules.gd`は時間、同時破壊の安定した順序、有限加点、倍率、ラッシュ、ランクを管理し、頭なしテストで確認する。`main.gd`が入力・プレイヤー・ワールド・アート・UI・演出・記録を接続する。プレイとブラウザの非アクティブ化では正しくポーズする。

描画の監視とブラウザQAのため、開発時だけ使う状態出力を用意する。製品の画面へ実装用のログやテスト項目を置かない。
