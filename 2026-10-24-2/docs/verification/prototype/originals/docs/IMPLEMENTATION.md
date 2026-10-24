# 90秒試作の実装計画

## 目的と範囲

仕様v0.1の滑走、旋回、跳躍、着地、ブースト、カメラを実際に操作して確かめる。第1コースの冒頭を基に、約90秒の区間、敵1種、タイトル、HUD、落下復帰、ポーズ、結果、再挑戦を作る。3分の完成見本と本編は次の段階に分ける。

Godot 4.7.2を使い、まずMac上で実行する。3Dの制作アセットはTripoで生成する。コースの実寸、ジャンプ用の開口、衝突、危険範囲の図形は、調整できるブロックアウトとして実装する。新しい外部ライブラリは追加しない。

## 制作順

1. Godotのシーンと入力、タイトルから結果までの状態遷移を用意する。
2. 常時前進、左右旋回、ブレーキ、ジャンプ、ブーストと追従カメラを実装する。
3. 緩い曲線、バンク、下り、短いジャンプ経路と広い完走路を作る。
4. Tripoの認証と費用確認後、主人公、ボード、照準灯機、遺跡の部品を生成し、プレビューを確認して取り込む。
5. 実画面で走行、落下、予告、ポーズ、再挑戦を確認し、必要な修正を行う。
6. 日本語の推敲、検証記録、Astraレビュー、PRとActionsの確認を行う。公開、マージ、リリースは行わない。

## 完了条件

- 主な操作でコースを走り、停止しない滑走と次の着地点を画面上で確かめられる。
- ゲージ0でも完走路を進める。落下から復帰でき、ポーズとフォーカス喪失で時計・敵・入力が止まる。
- 生成アート、実モデル、実画面の差を記録する。Tripoの未生成アセットを制作済みとして扱わない。
- 主対象1280×720と小さい960×540で文字と操作を確認し、未確認の機器や面白さを報告する。

## モジュールの契約

以下は並行実装で用いる接続仕様。実装が固まったら実コードを正とし、差があれば記録する。

- `course.gd` はNode3D。`center_at(s: float) -> Vector3`、`tangent_at(s: float) -> Vector3`、`half_width_at(s: float) -> float`、`checkpoint_at(s: float) -> float` を持つ。前進座標はワールドの `-z`、コース長は約1650m。上方向は `+y`。
- `rider.gd` はCharacterBody3D。`course: Node3D`、`progress`、`lateral`、`speed`、`wind_energy`、`boosting` を公開し、`set_active(value)` と `reset_to(s, energy)` を持つ。`fell` と `landed` を引数なしで通知する。Tripoモデルは `Visual/Avatar` 以下、ボードは `Visual/Board` 以下に置く。
- `follow_camera.gd` はCamera3D。`rider` と `course` を設定し、進路と着地点を映す。`reduced_motion` を公開する。
- `interface.gd` はCanvasLayer。`set_screen(name, data = {})` と `update_hud(data)` を持つ。画面名は `title/countdown/run/pause/results/settings/error`。`start_requested`、`resume_requested`、`retry_requested`、`title_requested`、`settings_changed(values)` を通知する。
- HUDのdataは `time/speed/energy/score/flow/progress/section/notice`。結果は `time/score/falls/best_time/best_score/saved`。設定は `reduced_motion/master_volume`。
- 入力アクションは `steer_left/steer_right/brake/jump/boost/pause`。キーボードA/D/S/Space/Shift/Escと、左スティック/LT/A/RT/Menuを対応させる。
- `main.gd` が開始カウント、走行時計、チェックポイント、イベントID、得点、記録保存、状態遷移と入力設定を担当する。物理ノードはPAUSABLE、UIと状態管理はALWAYSで処理する。
