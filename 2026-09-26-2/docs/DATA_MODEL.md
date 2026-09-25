# データ契約 v1（実装前の設計）

この文書と[サンプルJSON](../examples/celestial.project.json)を、最初のZodスキーマとテスト入力の基にする。現時点でスキーマ実装や互換性保証はない。実装時に契約を変更したら両方を更新する。

## 1. 保存するデータ

```ts
type ProjectV1 = {
  schemaVersion: 1;
  rendererVersion: '1';
  id: string;                    // UUID
  name: string;                  // 1〜80 graphemes
  seed: number;                  // uint32
  aspect: 'landscape' | 'portrait';
  bpm: number;                   // 整数60〜180
  palette: { paper: string; ink: string; accent: string; secondary: string; muted: string };
  fontSet: 'space-noto-v1';       // アプリが同梱するフォントセットのみ
  audio: { mode: 'none' | 'synth-v1'; gain: number }; // gain 0〜1
  scenes: SceneV1[];             // 2〜12個、id重複禁止
};

type SceneV1 = {
  id: string;
  role: 'hook' | 'feature' | 'summary' | 'outro';
  content: {
    headline: string;            // 1〜40 graphemes、改行は最大1個
    secondary: string;           // 0〜100 graphemes、最大2行
    items: string[];             // 最大3個、各1〜12 graphemes
  };
  durationTicks: number;         // 1拍=480 ticks。960〜15360、240の倍数
  motion: MotionV1;
  typography: { scale: number; align: 'left' | 'center' }; // scale 0.75〜1.2
  outgoing: { kind: 'cut' | 'circle-match'; durationTicks: number };
};

type CommonMotion = { intensity: number; motif: 'celestial' | 'geometric' };
// intensityは0〜1。係数であり速度や尺を直接変更するものではない。
type MotionV1 = CommonMotion & (
  | { kind: 'impact-type'; direction: 'up' | 'left'; anticipateNext: boolean }
  | { kind: 'particle-flight'; depth: number }             // depth 0〜1
  | { kind: 'radial-pulse'; focusGrapheme: number | null } // nullなら円は独立配置
  | { kind: 'slice-orbit'; slices: number }                // 整数4〜12
  | { kind: 'three-up'; layout: 'adaptive' }
  | { kind: 'particle-lockup'; focusGrapheme: number }
);
```

パレットは `#RRGGBB` 形式。CSS式、URL、HTML、フォントURL、実行コードはデータとして受け付けない。Zodは境界でstrictに検証し、未知フィールドを黙って実行・解釈しない。単なる値の誤りをスキーマバージョン変更で逃げない。

`rendererVersion` は見た目の再現性に関わる演出実装の版。既存の作品の見え方が変わる変更では移行方針を明示する。初期版では未知の版を拒否し、勝手に最新版で描き直さない。保存日時・保存revision・サムネイルはIndexedDBの外側のレコードに持ち、可搬JSONに端末情報を混ぜない。

## 2. 文字と意味の検証

- 文字数と強調位置は `Intl.Segmenter` のgrapheme単位。改行を除いた見出しの順序を強調位置のインデックスとする。絵文字のコードポイント数で数えない。[MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter)
- `impact-type` のitemsは1〜3個、`three-up` はちょうど3個。これらではheadlineを編集リスト・プレイヤーの場面名としても使い、描画の主文字列はitems。その他はheadlineを描く。
- items型の編集UIでは、itemsを「映像に出す言葉」、headlineを「場面名」と明示する。表示されないheadlineだけを見出し編集として提示しない。
- `particle-lockup` のfocusGraphemeは必須で範囲内。`radial-pulse` は範囲内またはnull。入力文を変えて無効になった場合は編集箇所にエラーを出す。
- `anticipateNext` は次場面の見出しを粒子で予告する。コンパイル時に次場面のデータから解決し、ASTRAという固定文字を描画コードに埋めない。最終場面ではfalseのみ。
- 構造検証の後に、文字の実測サイズ、フォントのグリフ、コントラスト、読みの時間を検査する。警告と出力を阻止するエラーを区別する。文字欠け・範囲外インデックス・未ロードの必須フォントは出力エラー。
- secondaryは全文を描く。収まらなければエラーを示し、内部で省略しない。itemsを使う演出も補足文用の領域を持つ。

## 3. 時間の一意な計算

保存値は整数ticks。`seconds = ticks / 480 * 60 / bpm`。場面長 `D[i]`、前から次への重なり `O[i]`、開始 `S[i]` とする。

```text
S[0] = 0
S[i + 1] = S[i] + D[i] - O[i]
totalTicks = sum(D) - sum(O)
```

`cut` の `O` は必ず0。`circle-match` の `O` は240〜960 ticks、240の倍数かつ前後の場面長のそれぞれ1/3以下。最後のoutgoingはcut/0。各場面で入側と出側の重なりの合計が場面長未満であること。三場面同時の重なりを許可しない。全体は4〜60秒。

重なり区間は `[S[i+1], S[i]+D[i])`。この間は両場面を各自のローカル時刻で描き、つなぎの進度 `u` で合成する。incoming側も時間は進む。前場面終了後にincomingの時刻を0へ戻さない。通常は半開区間で描画対象を決め、全体終端だけ最後の終止画を表示する。

尺やBPMが変わったら開始位置・実尺・読みの警告・音のcueを一度に再計算する。モジュール内のcueはローカル尺に対する比率または拍の規則からコンパイルし、保存した秒とticksを二重管理しない。基準作例は全outgoing=cut/0、48拍、120BPMで24秒。

## 4. ランタイムの契約

```ts
type RenderRequest = {
  timeSeconds: number;
  width: number;
  height: number;
  quality: 'preview' | 'export';
};

// 以下は責務を示す擬似インターフェイス。同期/非同期の境界を維持する。
prepare(project: ProjectV1): Promise<PreparedProject>;
compile(prepared: PreparedProject): CompiledTimeline;
createRenderer(targetCanvas, compiled: CompiledTimeline): Renderer;
// renderer.render(request) は準備済み資産だけで同期描画。内部でfetchしない。
// renderer.dispose() はキャッシュと所有リソースを解放する。
```

`PreparedProject` はロード済みフォント・実測レイアウト・glyphマスク・seed付き粒子などを持つ。`CompiledTimeline` は開始/終了ticks、読みの区間、音声cue、つなぎのアンカーを持つ。どちらも保存JSONには含めない。

rendererはインスタンスごとにCanvas/context/cacheを所有する。既存作品のグローバル変数 `g` をそのまま持ち込むとプレビューと書き出しが競合するため、必ず切り離す。別プロジェクトの同時準備でも混線させない。

描画値はproject・seed・time・sizeから決まる。フレーム差分の積算、描画中のMath.random、CSSアニメーションの経過時間、Date.nowを作品の状態に使わない。プレビュー時計だけはRAFを使用し、その時刻をrendererへ渡す。

## 5. 入出力の上限

JSONはUTF-8、1MiB以下。画像や音声のbase64を入れない。初期版の全資産は同梱フォントとコード生成なので、JSONだけで別端末に作品を復元できる。読み込みは全検証が終わってから新しい作品として追加し、既存idとの衝突は新UUIDを振る。失敗時に現在の編集を置き換えない。

サンプルJSONは構造を示す**仕様のfixture**であり、現在再生できるアプリデータではない。これを読み込んで描画・動画出力・再読み込みができるようになった時点で実装済みと扱う。
