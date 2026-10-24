# 再設計版の実装資料

## 目的と範囲

現在の方針は [REWORK.md](REWORK.md) を参照する。旧90秒試作の自動操舵と連続する下段の道を、900mの短いコース、自分で決める進行方向、風をためて解放する操作、3か所の切れ目へ作り直している。本書は実装の接続を説明する。旧仕様の全項目や、実際に遊んだときの面白さを確認済みとするものではない。

Godot 4.7.2、`game/project.godot` を使う。主対象はmacOSとChromeのキーボード操作で、1280×720と960×540を確認する。コース、衝突、危険範囲は調整できるブロックアウトで、3Dの制作アセットはTripoを使う。外部ライブラリは追加していない。新人物の制作・導入状況と承認済みクレジット枠は [REWORK.mdの人物方針](REWORK.md#人物と反応) を参照する。

## 操作とコース

- A / Dは実際の進行方向を回す。入力を離すと向きを保ち、道の接線へ自動で向けない。
- 接地中にSと旋回を続けると速度を落として風をためる。十分ためてSを離すと加速する。短い連打や左右の切り返しだけでため続けられないよう、継続時間・前進距離・旋回方向を判定する。加速中はためられない。
- Shiftは風力を消費する加速。Sだけを押して直進すると減速する。Spaceは接地直後の猶予と入力予約を持つジャンプである。
- 進路に合った着地、コース上の通過、近接通過などで風力を回復する。直線を走った距離による回復はない。各閾値と報酬は、`rider.gd` と `main.gd` の実装を参照する。
- 900mのコースに245–257m、530–546m、825–849mの切れ目を置く。切れ目に路面や衝突を残さない。黄色い離陸・着地の印、5区間の操作表示と復帰地点を持つ。走行時間は試遊で計測する。

## モジュールの契約

- `course.gd` はNode3D。`center_at(s)`、`tangent_at(s)`、`heading_at(s)`、`curvature_at(s)`、`half_width_at(s)`、`surface_at(s, offset, lift)`、`checkpoint_at(s)`、`gap_at(s)`、`next_gap_at(s)`、`beat_at(s)` を持つ。前進座標はワールドの `-z`、上方向は `+y`。路面と敵の危険範囲には同じ前進断面のワールドX方向のoffsetを使う。
- `rider.gd` はCharacterBody3D。既存の `progress/lateral/speed/wind_energy/boosting` に加え、`heading/steer_amount/carving/carve_amount/carve_charge/charge_rate/charge_requires_press/burst_left/airborne_time/landing_strength/fall_reason` を公開する。`set_active(value)`、`reset_run()`、`reset_to(s, energy)` で操作と復帰を管理する。通知は `fell/jumped/landed`、`carve_released(charge)`、`burst_started(strength)`、`clean_landed(strength)`。
- `rider_pose.gd` は、骨格と足の接地を基に姿勢を更新する。`set_motion_context(state)`、`trigger_motion(event, strength)`、`reset_motion()` を使う。離陸、空中、着地、加速、被弾、終了のキーフレームは `animations/rider_motion_keys.gd` に定義する。Tripo人物は `Visual/Avatar`、ボードは `Visual/Board` 以下に置く。新人物も同じ骨名で適用し、元のGLBは変えずにゲーム用Toon材質を複製する。
- `follow_camera.gd` はCamera3D。人物のheadingへ追従し、コースの先を視線へ混ぜて着地点を映す。描画時の移動量を先に反映し、速度によって実追従距離が伸びる遅延を防ぐ。地面と空中の高さを分け、着地時もボードをHUDから離す。`cue(kind, strength)` と `reset_camera()` を持つ。`reduced_motion` では画角を固定し、ロールと衝撃移動を止める。
- `effects.gd` は後流54、スパーク24、空中の風切り10と着地リング1を固定プールで扱う。`set_active(value)`、`cue(kind, strength)`、`reset_effects()` を持つ。`reduced_motion` は速度線を止め、後流を短くして粒子を減らし、接地の輪などの意味は残す。
- `soundscape.gd` は風、カーブの擦過音、ためる音、BGMと4つの効果音ボイスを、計8つの固定AudioStreamPlayerで扱う。`set_speed(speed, boosting)`、`set_motion(carve, charge, airborne)`、`cue(kind)`、`reset_audio()` を持つ。生成した波形の動作確認と、実際に聴いた印象の確認は分ける。
- `asset_loader.gd` は既存Tripoモデルを取り込む。コース装飾は路面下の支持アーチ9、通過する門2、庭園18の29インスタンス。門の開口と路面を避ける配置にし、装飾に衝突を持たせない。人物の多方向比較と本番カメラでの確認は、取り込み成功とは別に行う。
- `interface.gd` はCanvasLayer。`set_screen(name, data)` と `update_hud(data)` を持つ。画面名は `title/countdown/run/pause/results/settings/error`。HUDには時刻・速度・風力・得点・FLOW・進捗・通知のほか、ためた量、加速の残り時間、区間名と操作のヒントを渡す。設定は `reduced_motion/master_volume`。
- `main.gd` は開始カウント、時計、チェックポイント、得点、保存、状態遷移、入力と各反応の接続を担当する。物理ノードはPAUSABLE、UIと状態管理はALWAYSで処理する。再挑戦、タイトル、復帰で身体・カメラ・描画・音の状態を戻す。

## 記録と確認

入力アクションは `steer_left/steer_right/brake/jump/boost/pause`。キーボードA/D/S/Space/Shift/Escと、左スティック/LT/A/RT/Menuを割り当てる。パッドの実機確認は別に必要である。

新コースの記録は `user://cloudsea-carve-v2.json` に保存する。旧 `cloudsea-records.json` からは設定だけを読み、旧コースのタイムと得点を新しい自己ベストにはしない。WebではGodotのユーザーデータをブラウザの保存領域に置く。

実行と検査はREADMEの `npm run play`、`npm test`、`npm run build`、`npm run check` を使う。テストの通過は実際の操作、姿勢の静止画は動きのつながり、波形の生成は音の聴感をそれぞれ確認したことにはならない。人による一連の操作、人物の比較、音、面白さ、最終レビュー、CIの結果を記録してから、確認できた範囲を報告する。

## 停止・得点・復帰

ポーズと再開の合図中は身体の姿勢、加速の残り時間、ためた風を保持する。再開後に保存した風を使う場合はSを押して離す。再挑戦とチェックポイント復帰では走行資源を初期化する。旧記録から設定だけを引き継ぎ、900mコースの記録は別のファイルへ保存する。

CARVEとCLEANの加点は前進の最高地点と20mごとの報酬IDで管理し、同じ区間への復帰で繰り返し加点しない。技の加速や風力の回復は使える。ゴールは路面内に接地して通過したときに成立する。着地できない軌道は早めに検出して人物を隠し、石の路面を身体が突き抜ける表示を避ける。復帰すると再び表示する。
