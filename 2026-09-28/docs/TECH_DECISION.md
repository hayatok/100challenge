# 技術選定 ADR-001

2026-09-28 / 状態：推薦案。性能比較試作は未実施。

## 結論

**TypeScript + Three.js + Web Audio API + HTML/CSS を推薦する。**

PCブラウザでの配布と、日本語入力の調整を重視する。一方でオマージュの魅力である奥から迫る敵、自動カメラ移動、立体的な街は残すため、Three.jsで3D舞台を描く。
2Dの語カードを並べるだけでは、この作品の品質目標を満たさない。

Webだから絵が良くなるという判断ではない。シーン制作の容易さはGodotの利点であり、Web案には舞台・アニメーションを組む作業が必要になる。
素材・構図・ライティング・敵の演技は別途制作する。方式だけで品質を保証しない。

## 比較

以下の制作工数・適性は要件に対する設計判断。ベンチマーク結果ではない。

| 軸 | Godot native | Godot Web export | Web + Three.js | Web + PixiJS |
| --- | --- | --- | --- | --- |
| 配布 | ダウンロード/OS別成果物 | URLで遊べる。WASM・PCK等を配信 | URLで遊べる。JSと素材を配信 | 同左 |
| 立体の街とカメラ | エディタで場面を組みやすい | nativeと同じ制作資産を使えるがWeb向け制約確認が必要 | 3Dカメラ・モデルを扱える。シーン制作手順は自前で整える | 2D/疑似奥行きに適する。立体の回り込みは追加作業 |
| 入力・日本語ガイド | 入力イベントと独自判定。Controlで文字表示 | 同様。ブラウザのIME/フォーカスを別途確認 | DOMの入力イベントとガイドを直接制御 | 同左 |
| 音 | エンジンのミキサー・演出環境を利用 | Sample/Streamで機能と遅延条件が異なる | Web Audioのスケジュールとミックスを直接設計 | 同左 |
| 調整作業 | Inspector/AnimationPlayer等のGUIが強み | 制作はGUI、検証は実ブラウザも必要 | 舞台データ・調整画面・素材制作ツールが必要 | 2Dのレイヤー・粒子等を組みやすい |
| 今回の適性 | PC向け配布アプリを主にするなら有力 | GUI制作優先かつ配信条件が合うなら有力 | ブラウザ＋ローマ字＋3Dの今回の推薦 | 正面固定の2.5D劇場へ変更するなら小さく作れる |

## Godot Webの扱い

公式stable文書では、Web向けSample再生はWeb Audioを使い、非スレッドでも低遅延を狙える。一方、AudioEffectsや手続き的音生成などに制約がある。
Streamでは利用可能な音機能が増えるが、特に非スレッド時の遅延と負荷を確認する必要がある。
スレッド有効時はcross-origin isolationと配信ヘッダー等の条件が加わる。したがって「Godot Webは常に音が遅い」という比較はしない。
Godot Webを再検討する際は、録音済みステムと短い効果音をSampleで扱えるかから試す。
参照：[Godot公式 Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)。

Godotを選ぶ場合、GDScriptとWeb向けレンダラー条件で構成し、使用する安定版とexport templateを揃える。nativeの描画や音を、そのままWeb版の検証結果にはしない。

## Web案の責務

- `typing/`：読みの受理グラフ、正誤、ガイド生成。描画に依存しない。
- `game/`：セッション状態、敵の期限、ターゲット、コンボ、得点、難度、ウェーブ。
- `scene/`：Three.jsの場面、カメラ、敵アニメ、光、装飾。gameのイベントを受け取る。
- `audio/`：1つのAudioContext、ステムの位置、効果音、音量、ポーズ。
- `ui/`：タイトル、固定の入力帯、敵ラベル、設定、結果。日本語のレイアウトを担当。
- `content/`：表示文/読み、ウェーブ、敵、アセットmanifest、出所台帳。
- `storage/`：バージョン付き設定と結果。検証後のデータのみ使用。

起動 → 必須素材ロード → 入力確認 → 遊ぶ → ポーズ/区間移動 → 結果の状態遷移を一本化する。
GLBモデルのアニメーション・ポーズに入力判定を置かない。イベントIDで二重ヒット/二重撃破/二重発音を防ぐ。
プレイ中の動的ロードを避け、1ステージの必須モデル・文字・音源を開始前に用意する。
Three.jsは描画/モデル/カメラのための依存。ViteとTypeScriptは開発・ビルド用途。初版は物理エンジンと汎用状態管理、React、音ライブラリを必須にしない。
実装開始時に安定版を確認してバージョンを固定する。この文書は依存を追加していない。

## 入力の境界

判定は`KeyboardEvent.key`の文字で行い、物理キー位置の`code`をローマ字に変換しない。
`repeat`、修飾キー、`isComposing`、compositionstart/end、フォーカスを統合して制御する。
IME/Dead/Processの判定はブラウザ差があるため、英数モード確認と実機テストを省略しない。
入力確認にはフォーカス可能なDOM要素を使う。IME組成イベントがどこで届くかを実測し、隠れたtextareaだけで解決したとみなさない。
参照：[MDN key](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key)、[MDN isComposing](https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/isComposing)。

## 時計と音

戦闘はポーズを除いた単調増加時計で期限を判定する。描画速度で敵の猶予が変わらないようにする。
大きなフレーム落ち/非表示復帰は時間を一気に追いつかせて被弾させず、ポーズに移す。
BGMのスケジュールはAudioContextの時計を使い、描画側のsetTimeoutのみで拍を決めない。
正打音は即再生、ステム切替だけを拍に合わせる。低遅延指定は希望値で、保証ではない。
参照：[AudioContext constructor](https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/AudioContext)、[Godotの音同期設計](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)。

## 性能と復旧

- WebGL2を初期要件とし、利用不可は説明画面へ。白画面にしない。
- 目標は指定した基準PCの1280×720で60fps。端末は未指定なので達成済みとは扱わない。
- 解像度スケール、影、粒子数、装飾数を下げられる構成にする。入力文字と危険表示は常に保持する。
- モデル/音のロード失敗は再試行と戻る。無音で続ける選択肢を用意する。
- GPUコンテキスト喪失はポーズと復旧案内。復旧できなければ区間再開/タイトルへ戻る。
- 初期配信量は暫定15MB圧縮以下を目標。素材品質を無理に下げず、実データで見直す。
- 初回起動時間、最高演出のフレーム時間、キー→画面反映、音の聞こえる遅れは別々に記録する。

## 選定を見直す条件

1. ダウンロードして遊ぶPC作品を主とし、複数の3Dステージ/敵アニメ/GUI調整が主作業になるならGodot nativeを優先する。
2. Web案で場面編集の負担が大きい場合、同じ一区画をGodotで試す。試作なしにUI調整ツールの大規模開発を始めない。
3. 正面固定・紙芝居的な画風が選ばれたらPixiJSを検討する。
4. 音または描画の測定で品質目標に届かなければ、まず負荷/素材/スケジュールを診断する。原因を確かめずエンジンを全面移行しない。

最初から3方式を全部実装しない。推薦案の一場面を試し、未達の原因に関係する比較だけ行う。

## 参照

- [Three.js docs](https://threejs.org/docs/)：3D描画・カメラ・モデルのAPI。
- [PixiJS renderers](https://pixijs.com/8.x/guides/components/renderers)：2D案を選ぶ場合の描画方式。
- [ドパドリル仕様](https://github.com/grmchn/dopa-drill/blob/main/docs/SPEC.md)：即時入力、段階演出、演出と操作の分離の参考。作者の初期プロンプトとはみなさない。
- [SEGA配布のOverkillマニュアル](https://cdn.akamai.steamstatic.com/steam/apps/246580/manuals/TOTDO_STEAM_MANUAL_ENG.PDF?t=1603130707)：シリーズの入力戦闘の参考。ユーザーが遊んだ版と同じとは断定せず、版固有のルールを今回の仕様として転記しない。

閲覧日：2026-09-28。stableドキュメントの内容は更新され得る。実装時には採用版で再確認する。
