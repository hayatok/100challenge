# 技術設計 v1

## 1. 技術スタック

2026-09-25時点の採用基準。既存アプリの構成を継承し、新規依存は下記の責務に限定する。初回導入時はexact versionとpackage-lock.jsonを保存し、異なるバージョンへの変更は理由を記録する。

| 層 | 採用 | 理由 |
| --- | --- | --- |
| UI | React / React DOM 19.2.8 | 既存アプリと一致。フォームと選択状態を担当 |
| 言語・ビルド | TypeScript 6.0.2、Vite 8.2.2、plugin-react 6.1.0、Node 24 | 既存の静的配信・検証に適合 |
| 描画 | p5 2.3.3、instance mode、P2D | 幾何・文字・クリップをブラウザで描画。組み込み型を使用し@types/p5は追加しない |
| 動画 | Mediabunny 1.59.1 + ブラウザWebCodecs | フレーム時刻を指定して端末内でエンコード・コンテナ化 |
| 保存 | IndexedDB + idb 8.0.3 | 履歴とお気に入りをtransactionで保存。非同期処理の簡素化 |
| 境界検証 | Zod 4.6.5 | JSON/永続化データのschemaと範囲を一元化 |
| 書体 | @fontsource/noto-sans-jp / noto-serif-jp 5.3.0 | 日本語字体をアプリと同じ配信元へ同梱 |
| アイコン | lucide-react 1.48.0 | 規約に沿う一貫した操作アイコン |
| 検証 | Vitest 4.1.11、Playwright Test 1.63.0、oxlint 1.79.0 | 純粋ロジック、実Canvas/ブラウザ、lintを分担 |

@types/react 19.2.18、@types/react-dom 19.2.4、@types/node 24.13.3も既存アプリに合わせる。CSSは通常のCSSと変数。状態管理はuseReducer + Context、アニメーションフレームはReact stateに入れない。Router、UIキット、Three.js、GSAP、動画サーバーは導入しない。

p5のnoLoop/redrawで描画タイミングを外から管理でき、pixelDensityで描画密度を明示できる。[noLoop](https://p5js.org/reference/p5/noLoop/)、[redraw](https://p5js.org/reference/p5/redraw/)、[pixelDensity](https://p5js.org/reference/p5/pixelDensity/)

Mediabunnyは固定Canvasから時刻とdurationを指定してフレームを追加できる。addのPromiseを待って出力側の処理量を制御する。[CanvasSource](https://mediabunny.dev/api/CanvasSource)

## 2. モジュール境界

以下はSolが作成する構成。設計時点でsrcやpackage.jsonは作成していない。

```text
2026-09-25/
  README.md / IMPLEMENTATION_PLAN.md / docs/
  package.json / package-lock.json / vite.config.ts / tsconfig*.json
  index.html / playwright.config.ts
  src/
    app/             App、reducer、非同期controller
    components/      BriefForm、CandidateBoard、Preview、Inspector、各Dialog
    domain/          schema、recipe、seed、generate、refine、history
    render/          RendererHost、scheduler、compile、layoutText、fonts
      families/      weave、fold、tile
    export/          capabilities、png、video、projectJson
    storage/         database、repository、conflict
    fixtures/        固定recipe、文字入力ケース
    styles/          tokens.css、global.css、各部品のCSS
  tests/             unit/、e2e/、visual/
  public/licenses/   フォント・依存の配布に必要な告知
  docs/verification/ 検証記録と小さな代表画像
```

domainはReact/p5/DOM/IndexedDBをimportしない。renderはDOMとp5を使えるがUI状態を更新しない。exportは凍結recipeとrender APIだけを受け取る。reducer内で乱数取得、日時取得、保存、描画をしない。

## 3. データ契約

Zod schemaを正とし、TypeScript型はinferで生成する。以下は責務を示す型表現。

```ts
type Recipe = {
  schemaVersion: 1;
  rendererVersion: '1';
  id: string;                         // UUID、描画乱数と無関係
  brief: { title: string; subtitle: string };
  format: 'square' | 'portrait';
  family: 'weave' | 'fold' | 'tile' | 'slice' | 'orbit' | 'echo';
  color: { paletteId: string; bg: string; ink: string; surface: string; accent: string };
  type: {
    fontId: 'noto-sans-jp-700' | 'noto-serif-jp-600';
    align: 'left' | 'center'; size: 'small' | 'medium' | 'large';
    lineHeight: number; letterSpacing: number;
  };
  shape: {
    composition: string; density: 'low' | 'medium' | 'high';
    tilt: number; seed: number;
  };
  motion: { amount: 'calm' | 'normal' | 'bold'; cycles: 1 | 2; seed: number };
};
type Locks = { color: boolean; type: boolean; shape: boolean; motion: boolean };
type Board = {
  id: string; parentBoardId: string | null; sourceRecipeId: string | null;
  candidates: Recipe[];               // 1〜4、空配列禁止
  selectedId: string; locks: Locks;
  filter: 'all' | Recipe['family'];
  operation: 'initial' | 'explore' | 'refine' | 'edit' | 'import' | 'favorite';
  createdAt: string;
};
```

- compositionはfamily別の3値に限定し、union/refineで不正な組合せを拒否。shape.tiltは-12〜12度、seedはuint32、文字数・配列長・ID長にも上限。
- lineHeightは初版1.15、letterSpacingは0だけを許可。将来のUI拡張に備える名目で未対応値を受け入れない。
- tiltは構図の基準角に加える補助角。foldのタイトル面へは適用せず後ろの面だけ、tileは0固定。familyごとの検証を行う。
- 配色の実色値を保存する。recipeはseedだけでなく全設定を持つ。プリセットの将来変更で昔の作品が変わらないようrendererVersionを管理。
- 色は6桁のhexだけを許可し、paletteIdは11の既知IDに限定。JSON読込は実色値の可読性も検証する。読込時はローカルの新しいUUIDを割り当て、埋め込まれたIDによる既存作品の上書きを防ぐ。
- v1ではrendererVersion 1だけを受け付ける。描画規則・フォントファイルを変えて旧作品の見え方が変わる場合は、バージョンを上げ旧版対応または明示的な移行を設計する。黙って読み替えない。
- derivedな文字レイアウト、図形座標、canvas、ImageBitmap、font objectはJSON/DBへ入れない。compile結果をキャッシュする。
- JSONは1作品、最大256KiB。未知キーを拒否し、URLや関数を許可しない。構文解析後のObject.assignによる任意プロパティの混入を避け、schema出力から構築。
- 保存DBのrootはversion、revision、boards（最大50）、favorites（最大50）、activeBoardId、exploreCounterを持つ。参照整合性を検証してからUIへ渡す。破損時に黙って全削除せず、読める作品のJSON退避と「新しく始める」を提示する。

## 4. 決定的な生成・近傍探索

新しい探索のmaster seedだけ `crypto.getRandomValues` から取得。初回は固定seed。ドメイン内のPRNGはMulberry32を固定実装し、既知出力列をテストする。seed派生はFNV-1a（UTF-8 bytes、32bit）でnamespaceを分ける。暗号用途には使用しない。

```text
生成seed → candidate番号 → color / type / shape / motion の独立seed
shape.seed → 形状のパラメータ列
motion.seed → 各要素の位相列
```

固定項目は親のオブジェクトをそのままコピーし、他項目からseedを取り直さない。レイアウト等の派生キャッシュは更新してよい。IDとcreatedAtを除いたcanonical JSONで重複を判定する。

近傍探索は「変更項目集合」を先に選び、次に値を変える。数値の10〜25%変更に加え、palette/font/構図/density/motion amountの列挙値変更を認める。familyは不変。文字のサイズ変更と配置変更など同じdomain内の変更は1項目として数える。

候補距離は変更domain数と構図・パレット等の明確な違いで評価する。seedだけの変更では、compile後の図形中心/角度の変化が短辺の2%相当未満なら棄却。最大32試行。0件なら状態不変、1〜3件なら件数を明示する。

## 5. 描画と文字

中核APIは `compile(recipe, fontMetrics) -> CompiledScene` と `renderFrame(host, scene, timeSeconds, outputSize) -> canvas`。同じブラウザ・フォント・rendererVersionでは同じ入力のフレームを再現する。別OS間のアンチエイリアスまでバイト一致させる約束はしない。

### RendererHost

- 非表示のp5 instanceを通常1個だけ作る。P2D、pixelDensity(1)、noLoop。setup完了をPromiseで公開。初回drawに描画内容を依存させない。
- renderFrameは描画jobをhostへ渡し、完了を待ってcanvasを返す。p5 drawから共通描画関数を呼ぶ。p5のmillis、frameCount、deltaTime、mouse座標を作品描画で参照しない。
- 各フレームでtransform、clip、alpha、blend、text設定を初期化し、背景で全面消去。push/popとCanvas save/restoreを必ず対応させる。前作品の状態が漏れないようテストする。
- 作品ごとにp5 instanceを増やさない。共有hostで順に描き、可視HTMLCanvasへdrawImageして転送する。転送前に次の作品を描かない。可視canvasはReactのre-renderで作り直さない。
- プレビューは短辺480pxを基本とする。幅767px以下の候補だけ320pxで描いて480pxの可視canvasへ拡大し、動きを維持したまま負荷を抑える。選択作品は480pxのまま描く。
- 動画/PNG出力時だけ2個目の専用hostを作り、終了/失敗/キャンセルでremove。React StrictModeのmount/unmountでもRAF・instance・observerが残らないようcleanup。

### フォントとlayout

Fontsourceのsans 400/700、serif 600の日本語bundle CSSをアプリにimportし、各weightの全文字ファイルを同じoriginから取得する。CDNやGoogle Fontsへのruntimeリクエストを作らない。パッケージのローカルCSS方式を採用する。[Fontsource公式](https://fontsource.org/docs/getting-started/install) 当初のsubset方式からの変更理由は第10節に記録した。

入力確定ごとに `document.fonts.load(fontSpec, title + subtitle)` を必要なfont/weightごとに待つ。既にロード済みの文字だけを前提にしない。15秒で遅延表示と再試行を提供し、generation tokenで古いPromiseの完了を無視する。ロード失敗時は旧作品を保持し、代替字体での無言の生成・出力はしない。

Canvas2Dでフォント計測とテキスト描画を共通化し、p5描画のdrawingContextから使う。文字のclip用マスクも同じレイアウトを使用する。p5のtextToPointsやフォント輪郭変換は初版では使わない。

タイトルレイアウトは1080基準の論理座標で1回確定し、描画時に等比拡縮。プレビューの画面幅から折り返しを計算し直さない。clip用マスクは出力解像度別に作り、書き出しで480pxマスクを拡大しない。

フォントの正規配布元と同梱ライセンスは導入時に確認・保存する。[Noto CJK公式](https://github.com/notofonts/noto-cjk)を起点にし、採用ファイルのライセンスを配布物へ含める。p5/Mediabunny等も各packageの告知条件に従い `THIRD_PARTY_NOTICES.md` と配信物から読める告知を作る。

### プレビューscheduler

- requestAnimationFrameの時計は1個。候補4枚と選択作品は同じ位相で再生する。候補は描画回数を間引き、選択作品は最大30fpsを目指す。実際の処理が遅くても描画回数を時刻とみなさず、単調時計の経過秒を6秒周期へ加えるため、動画の速度が伸びない。
- IntersectionObserverで画面外のcanvasを更新しない。タブ非表示・dialog表示・出力中は停止。再開時は停止位置から続ける。
- reduced-motion初期は全停止。再生/停止の明示操作を提供し、DOM aria-liveで毎フレーム通知しない。
- 候補の描画負荷が高いときも表示中の候補を静止画へ落とさず、更新頻度だけを下げる。書き出しのフレーム時刻と解像度は変えない。
- compile結果キャッシュは現在4案と親・お気に入り閲覧中の最大8作品まで。履歴全件分の高解像度maskを保持しない。

## 6. 非同期・永続化

controllerでgenerationIdとAbortControllerを管理。フォント、compile、サムネイルが全件完了してからセットをatomicにcommitする。入力変更・再試行・unmount後の古い完了で最新状態を上書きしない。進行中は旧作品を表示しbusy状態を付ける。

DB名は `moving-cover-2026-09-25`。readwrite transaction内でrevisionを比較し、成功時だけrevision+1。保存要求を直列化し、後続更新は最新snapshotへまとめてよいが、失敗時のdirty状態を落とさない。BroadcastChannelは更新通知にだけ使い、競合の判定はtransactionで行う。API非対応でもrevision比較で保護する。

保存失敗・容量不足・private modeでもメモリ上で制作を継続可能。JSONへ退避できる。画像や動画BlobはDBに保存せず、サムネイルも再描画可能なキャッシュ扱い。お気に入りと履歴の削除操作は別にし、全消去ボタンは初版には置かない。

## 7. 動画・PNG出力

実寸・30fps・品質設定を渡してcodecを検査する。`canEncodeVideo`は設定を含むエンコード可否を調べられる。[公式API](https://mediabunny.dev/api/canEncodeVideo)

1. recipeを凍結し、必要フォントを確認。出力専用host/sceneを用意。
2. codec選択肢はAVC+MP4、VP9+WebM、VP8+WebMの順。形式を表示し、利用者が開始する前に選択を確定。
3. 品質の初期値は720px=6Mbps、1080px=12Mbps。線や文字の実出力にブロックノイズがあれば調整して記録。
4. Output + BufferTargetと選択したコンテナを作り、CanvasSourceのvideo trackを30fpsで追加。音声trackは作らない。
5. start後、i=0〜179で `renderFrame(i / 30)` → `await source.add(i / 30, 1 / 30)` を逐次実行。frame 180（時刻6秒）は追加しない。
6. 各フレームでキャンセルを確認。約50msごとにUIへ実行機会を返す。可視でない間は次フレームへの進行を一時停止し、キャンセルは有効にする。
7. finalize完了後にBlobとダウンロードURLを作る。最終化前のbufferを完成品として出さない。
8. finallyでencoder/host/キャッシュを解放。キャンセルはoutput.cancelを使い、処理中のadd/finalizeと競合しないよう同じjob内で直列化する。キャンセル要求はflagで記録し、最終化完了後に届いた場合もダウンロードを抑止する。

MediabunnyのOutputはstart/finalize/cancelを持つ。バッファ型などの細部は固定した版のTypeScript定義に従い、推測したAPIをanyで通さない。[書き出しガイド](https://mediabunny.dev/guide/writing-media-files)

PNGは同じrendererでframe index/30を描画しtoBlob。動画・PNGとも背景を塗り透明部分を残さない。オブジェクトURLは同じ出力ダイアログを閉じた後または新出力への置換でrevokeし、クリック直後に破棄して保存を壊さない。

実行時に処理が止まる場合は30秒で「処理に時間がかかっています」とキャンセル導線を表示。失敗後は標準サイズ・別形式を利用者が選んで再試行できる。MediaRecorderの実時間録画やffmpeg.wasmへの隠れたフォールバックは設けない。

## 8. 静的配信・性能・対応範囲

- `base: './'`。資産URLにドメインルートからの絶対パスを使わない。`/2026-09-25/`配下で動作。サーバー側API、外部テレメトリ、URLへのタイトル埋め込みは不要。
- Mediabunnyは出力ダイアログ初回表示時にdynamic import。フォントは同梱した日本語bundleを初回表示時に取得する。ライブラリ全体をservice workerで先読みする設計は初版に含めない。
- 主対象は現行デスクトップChrome/Edge。Safari/FirefoxとiOS/Androidは生成・PNG・JSONを基本とし、動画は実能力検査で提供。Playwright WebKitだけでiOS実機対応済みと宣言しない。
- 目標: 初回フォント取得後4候補1秒以内、選択反映100ms以内、選択作品30fps、720pxの6秒動画30秒以内。実装時のMac/Chromeの機種・版・計測結果を記録し、全端末保証にしない。
- フレーム全件の画像をメモリに貯めない。1080縦長のRGBA1枚は約8MiB。2個のhostと少数maskに制限し、長時間の探索でcanvasやencoderが増え続けないことを検証する。

## 9. 採用しない方式と理由

- サーバー動画生成: ブラウザ完結という条件と合わない。
- WebGL/Three.js: 現行の12表現はCanvas2Dで作れ、shader・context喪失対応の追加コストが不要。
- DOM/CSSだけで作品を描画: 出力用Canvasとの2重実装になり、文字組みと動きがずれやすい。
- p5の自律drawループ: 複数候補と書き出しの時刻が一致しなくなるため、描画時計はアプリが所有する。
- seedだけ保存: プリセット更新の影響を受けるため、設定値と描画版も保存する。

## 10. 実装時に確認した差異（2026-09-25）

- **p5 2.3.3 の型:** 配布パッケージに `types/p5.d.ts` の参照はあるが、そのファイルは実際のnpm成果物に入っていなかった。`@types/p5`を追加せず、今回使うinstance mode APIだけを `src/render/p5.d.ts` に宣言した。描画ランタイムは引き続きp5/P2Dで、作品・JSON・出力形式への影響はない。
- **画面状態:** 画面内でしか使わない操作状態はReact `useState` と純粋なドメイン関数で保持した。設計時の `useReducer + Context` を採らなかった理由は単一画面で共用先がなく、余分な状態複製を避けられるため。recipeと履歴の不変更新、保存境界の検証は維持した。
- **生成の非同期制御:** 入力と生成要求には `generation` 番号を使い、遅れて完了した結果を破棄する。フォント取得自体を `AbortController` で中止できないため、設計時の文言から制御方法を変更した。既存の候補は完了まで表示し続ける。
- **実動画の再生確認:** ファイルのダウンロードに加えて、出力ダイアログに完成Blobを再生する `<video controls>` を追加した。OSのファイルURL制約があっても同じ成果物をブラウザで確認できる。これは動画生成の代替ではなく、ダウンロードされるBlobそのものを再生する。
- **フォントとオフライン:** 当初はFontsourceのunicode subset CSSを使ったが、744資産・約25MBの出力で、ローカルの複数ビルド後にCSSが参照するフォント41件が欠ける実問題を確認した。フォントファイルは同じFontsource 5.3.0の日本語bundle各1ファイルへ変更し、配信資産6件・約10MBにした。日本語と英字の18構図、実PNG/MP4を再検証する。`document.fonts.load` は書体別の取得済み文字を記録し、改行だけを追加読込しない。同梱字体の未使用文字もオフラインで描ける。未知の字体や読込失敗時はフォントエラーを表示する。描画API、recipe、JSON形式は変えない。
- **動画能力判定:** 解像度切替時は旧サイズの候補形式をすぐ消し、最新の判定要求だけを反映する。遅い能力判定が新しい選択を上書きしない。
- **動きの可視性:** 実画面で「静止画に見える」という問題があり、特に切る・響く・張るは動画フレームの変化が小さかった。6秒周期と主文字の可読性を維持したまま切片・残像・線群の振幅を増し、環状の反復文字を交互に揺らした。スマホ候補の静止画化は作品の選択体験と合わないため取りやめ、候補だけ320pxで描く。previewの位相は実時間で進め、タブ非表示・dialog・出力・明示停止中は凍結する。recipe・JSON・描画APIは変えない。[実測と動画](verification/RESULTS.md)。
- **字形の粒子化:** 新しい「散る」は`compile()`したSceneごとに最初の書記素を一度だけ小さな2D canvasへ描き、その不透明画素を粒子座標へ変換する。WeakMapでSceneの寿命にキャッシュを合わせ、動画の各フレームでは座標を6秒周期の式で更新する。画像素材や新依存を増やさず、PNG・プレビュー・MP4に同じ`drawScene()`を使う。既存recipeのフィールドとrendererVersionは変更せず、family/構図の列挙のみ増やす。実装と参照は[追加表現計画](EDITORIAL_MOTION_EXPANSION.md)。
