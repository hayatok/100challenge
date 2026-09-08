# ゲーム開発用エージェントスキル

2026-09-08、Godot 2D物理パズルの開発準備として導入。プロジェクト共有の知識として `.agents/skills/` に置き、グローバル設定やゲームの実行時依存関係は追加しない。

## 使い分け

| スキル | 読む場面 | 今回の用途 |
| --- | --- | --- |
| [game-design](../.agents/skills/game-design/SKILL.md)（試験導入） | 遊びの核・選択の葛藤・失敗からの学習・面白さの批評 | 「どの接合部を、どの順で切るか」の判断、単調な必勝法、再挑戦で改善できる情報を検討 |
| [godot-gdscript-patterns](../.agents/skills/godot-gdscript-patterns/SKILL.md) | GDScript・シーン・状態・シグナルの設計 | 準備／シミュレーション／成功／失敗の責務分離、部材と面データの再利用 |
| [godot-physics](../.agents/skills/godot-physics/SKILL.md) | 剛体・衝突・検出・ジョイントの実装 | 柱・梁・花瓶の剛体、切断可能な接合部、梱包箱の検出 |
| [physics-tuning](../.agents/skills/physics-tuning/SKILL.md) | 物理の安定性・手触り・性能の調整 | 積み重ねと接合部の振動、すり抜け、固定刻み、休止状態の確認 |
| [level-design](../.agents/skills/level-design/SKILL.md) | 面の試作・導入順・難易度・視認性 | 簡単な形状で解法を検証し、切断→傾斜→橋→連鎖を段階的に教える |

全ファイルを毎回読み込まず、該当する `SKILL.md` と必要な参照資料だけを読む。
これらは開発ガイドであり、Godot用のアドオン、追加物理エンジン、自動テスト環境ではない。

## プランナースキルの試し方

`game-design` は、企画の仮説を立て、プレイで検証するために試験導入する。まず遊びの核と選択を設計し、`level-design` で小さな面に落とし込み、Godot系スキルで実装し、`physics-tuning` で安定性と手触りを確認する。

今回の「こわさず、壊す。」では、承認済みの「建物の接合部を切り、部材を経路に変えて壊れ物を救う」企画と2Dの方針を引き継ぐ。企画の承認を最初からやり直さない。

利用例: `$game-design この物理パズルのコアループを批評し、単調な必勝法と、失敗後に学べる情報を検討して。最小の試作で確認できる仮説を出して。`

- **選択**: 切る場所と順番に、結果を予測して悩む余地があるか。
- **学習**: 花瓶が割れた理由を読み取れ、次の試行で変える点がわかるか。
- **解法の幅**: 一つの手順を当てるだけでなく、物理を利用する工夫が成立するか。
- **検証**: 「面白そう」という評価と、実際のプレイで観察した判断・再挑戦・詰まりを分けて記録する。

試作で設計判断や改善に役立ったかを見て継続採用を判断する。現時点ではゲームでの効果は未検証。コアループの階層や報酬の一般論から、この有限ステージ型パズルに不要な育成・経済・インベントリを追加しない。

## このプロジェクトでの適用

- ユーザーの指示、`AGENTS.md`、共通設計文書、対象アプリの仕様を優先する。スキル内の関連スキル一覧は追加インストールの要求ではない。
- `game-design` の `/game-design` は上流のモード表記。Codexでは `$game-design` と自然文で依頼する。上流の `wire` と `INTEGRATION.md` はClaude向けの任意設定であり、自動実行しない。今回、フックやグローバル設定は追加していない。
- Godot 4.7.2 / 型付きGDScriptを既存の基準とする。WebはCompatibility・シングルスレッドを基準とし、上流のスレッド読込例を無条件に採用しない。
- サンプルは設計の例。必要な部分だけを実装し、Godotでimport・型チェック・実行を確認する。状態機械やAutoloadを規模に関係なく増やさない。
- `physics-tuning` の「両側のマスクが必要」という一般論をすべてのGodotノードへ当てはめない。剛体の衝突とAreaの片方向検出を区別し、利用するノードのマスク・monitoring・monitorableを公式仕様と小さな再現シーンで確認する。
- 剛体の位置や速度の直接書換えは通常の移動方法にしない。必要な物理状態操作には `_integrate_forces()` を使う。固定刻みだけで端末間の完全な決定性を保証したことにしない。
- サンプルの固定文字列によるセーブ暗号化をセキュリティ対策とみなさない。保存データは読み込み時に型・範囲・バージョンを検証する。
- `level-design` のジャンプ距離や戦闘例は、今回なら梁の回転範囲、花瓶の移動経路、安全な衝突、切断順の検証へ読み替える。物理パズルのために操作キャラクターや戦闘を追加しない。
- 実際のGUI・ブラウザでの操作確認と375 / 768 / 1024 / 1440pxでの確認を残す。スキル導入だけでプレイ検証済みとは扱わない。

公式資料: [Godotの物理概要](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html)、[Web出力](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。

## 選定と出典

- [wshobson/agents](https://github.com/wshobson/agents): MIT。GDScriptスキルの利用数約15K、リポジトリ39,488 starsを調査時に確認。実装の基本パターンを選択した。
- [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills): Apache-2.0。Godot Physicsの利用数約2.2K、リポジトリ885 starsを調査時に確認。内容と適用範囲を読んで物理・調整・面設計を選択した。
- [saschb2b/skills の game-design](https://github.com/saschb2b/skills/tree/91187b37de762ec19155895a691fc34a4d994f58/skills/productivity/game-design): MIT。本文と主要参照を読み、コアループ・選択の葛藤・単調な必勝法・失敗の学習を扱うプランナー用として試験導入した。
- 利用数はskills CLI / skills.sh、starsはGitHub APIの2026-09-08時点の値。品質や将来の互換性を保証する値ではない。
- 同リポジトリの `puzzle` はマッチ3・倉庫番など離散盤面向けだったため、今回の連続物理には採用しない。包括的なスキル一式やC#・マルチプレイ用スキルも追加しない。

各スキルの本文・参照資料は上流の固定コミットから導入した。GDScriptスキルはLICENSE末尾の空白とSKILL.md末尾の余分な空行を正規化した。`game-design` はCodex向けにdescriptionを短縮し、上流固有のfrontmatterをmetadataへ移動して適用上の補足を加えた。参照本文は保持し、配布用のCARD一式・署名・permissions.yamlは除外した。改変後のコピーに上流署名が有効であるとは扱わない。上流LICENSEを各フォルダに同梱し、Apache-2.0のNOTICEも保持する。

固定コミット、上流パス、導入前後の全ファイルのSHA-256は [.agents/skills/sources.json](../.agents/skills/sources.json) に記録する。更新時は上流差分をレビューし、参照資料とライセンスも含めて更新する。無条件の一括最新版更新はしない。

## 配置と検証

[OpenAIの公式仕様](https://learn.chatgpt.com/docs/build-skills) に従い、リポジトリルートの `.agents/skills/<name>/SKILL.md` へ配置した。SKILL.mdの参照はスキルのルート、入れ子の文書のMarkdownリンクはリンク元文書を基準として読む。上流が明示するルート相対表記は、その説明に従う。

導入時に実施する確認:

1. `SKILL.md` のfrontmatterに有効なnameとdescriptionがある。
2. 同梱された参照資料が存在し、実行スクリプトや未確認の依存ファイルが含まれていない。
3. 本文・参照資料を上流固定コミットのGit blobと照合し、LICENSE / NOTICEも同じ版から取得する。
4. `sources.json` のSHA-256と実ファイルの一致を確認する。
5. `git diff --check` と既存の `npm test` を実行する。

ゲーム本体・UIはこの導入では変更しない。ゲームの物理動作検証は実装後に行う。
