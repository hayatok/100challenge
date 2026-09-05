# LOOP EATER — オフライン・アンコール

走った線を交差させ、囲んだ敵を回収して、その場所を短時間の陣地にするGodot 4.7.2製の2.5Dゲーム試作。こはくと「よふかしシグナル」の180秒のリハーサルを、macOSとデスクトップWebで遊べます。

## アート v0.2

こはくを曲面・衣服の厚み・毛束・顔・機材・靴まで作り直し、腕・脚・髪が移動に追従するようにしました。雨灯横丁には7店の看板、窓枠、庇、バルコニー、室外機、架線、街灯、店先の家具・自転車・植木、機材を配置。生成した舗装テクスチャと材質別の粗さ、目地、灯り、影で街を描きます。

macOSはForward+でSSAO・SSR・Glowを使用し、WebはCompatibilityで同じモデルと材質を使用します。初版より負荷・起動時間・ダウンロード量は増えています。

## 遊び方

- WASD / 矢印 / 左スティック / ドラッグで移動。攻撃は自動。
- 四角く回り、**自分が残した線を横切る**と囲みが成立します。同じ線をなぞって戻るだけでは成立しません。
- 線は6秒、陣地は8秒。囲み撃破は経験値1.3倍。陣地も敵を攻撃します。
- レベルアップでは時間が停止。クリック・1〜3キーで強化を選択。候補交換は2回。
- ホイールでカメラを拡大・縮小できます。
- Esc / 画面右上の停止ボタンで一時停止。BGM・効果音と演出量を変更できます。
- HPゼロで撤収。180秒生存でリハーサル完走。結果画面から再挑戦できます。

最初は小さく回って交差を覚え、敵が集まってから大きな囲みを狙ってください。横向き画面を使用します。最高同時回収数だけをGodotの`user://loop-eater.cfg`へ保存し、中断状態は保存しません。

## 起動・ビルド

Node.js 24、Godot **4.7.2 stable**、同じ版のExport Templatesを使用します。macOSでは公式Godotアプリを`/Applications/Godot.app`に置くか、実行ファイルを`GODOT_BIN`で指定してください。Linux x86_64のCI用エンジンとWeb/macOS用テンプレートはセットアップスクリプトで取得します。

```sh
npm ci
npm run setup
npm run check
npm run preview
```

Webプレビュー: http://127.0.0.1:4185/ 。ファイルを直接開かずHTTPで配信してください。通常のWebビルドは単一スレッド・Compatibilityで、WebGL 2が必要です。配信サーバーでは`.wasm`を`application/wasm`として返してください。

```sh
npm run dev          # Godotエディタ
npm test             # 幾何・時間停止・戦闘・再現性・通常ラン
npm run benchmark    # 600体のCPUシミュレーション計測
npm run build        # dist/ にWeb release
npm run build:mac    # builds/macos/LOOP EATER.app
```

macOS版はuniversal・ローカルテスト用のアドホック署名です。一般配布用の署名・公証は未実施。Windows/Linuxネイティブ、iOS/Android向け出力は未設定です。ルートのショーケース登録・公開デプロイもこの試作には含みません。

## 制作物と責務

- `game/core/`: 平面座標のシミュレーションと囲み判定。描画・入力・保存に依存しません。
- `game/main.gd`, `game/overlay.gd`: 3D描画、画面投影した線・陣地、UI、入力、音、記録。
- `art/source/amedori-v2.blend`: 現在のBlender正本。初版の`yofukashi-kit.blend`も保存しています。
- `game/assets/models/v2/`: キャラクター・敵・街のGLB。正本SHA-256と関節ノードを検証します。
- `art/PROMPTS.md`, `game/assets/yofukashi.png`: built-in ImageGenによる導入イラストと制作指示。
- `scripts/create_audio.py`: 外部音源を使用しない試作用シンセBGM・効果音。
- `game/assets/fonts/`: Noto Sans CJK JP Mediumと同梱ライセンス。
- `docs/PLAN.md`, `docs/SPEC.md`, `docs/VERIFICATION.md`: 範囲・仕様・検証結果。

モデルの編集はBlenderの保存済み正本に対して行います。`scripts/create_art_v2.py`は初回制作用で、既存正本を上書きしません。編集後の出力例:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/export_art_v2.py
```

画像はこの環境のImageGenで制作しました。Google Imagen APIは使用していません。モデルはBlenderで生成・GUI調整し、色とシルエットを確認しました。歩行は分割パーツのピボットで腕・脚・髪を動かす方式です。スキンウェイトを使う骨格リグ、布シミュレーション、表情アニメーションは未実装です。

## 次の開発

まず実プレイで囲みの成立感、被弾の分かりやすさ、180秒の難度を調整します。その後、ボスと製品版の時間設計、進化、3キャラ、章・会話、スキン付きアニメーション、対応OS拡大を進めます。企画書の12分ボス・14分敗北と今回の180秒リハーサルは別仕様です。
