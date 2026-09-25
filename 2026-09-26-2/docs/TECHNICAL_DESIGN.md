# 技術設計

## 1. 採用する構成

静的Webアプリ。編集UIはReact、映像は独立したCanvas 2Dレンダラー。実時間プレビュー・任意時刻PNG・オフライン動画・単体HTMLが同じプロジェクトと描画関数を使う。映像をCSSの再生状態に依存させない。

| 用途 | 初期採用 | 理由 |
| --- | --- | --- |
| UI / 型 / 開発 | React、TypeScript strict、Vite | 既存アプリと同じ開発基盤。UIの更新と映像フレームを分離できる。 |
| 描画 | Canvas 2D、Path2D、2.5Dの座標投影 | 評価された作例と同じ方式。文字マスク、粒子、帯状分割、円、奥行き移動を実装できる。 |
| 時間制御 | 独自の純粋関数・解析的spring/easing・seed付き乱数 | 任意シークとフレーム単位の出力を同じ状態にするため。GSAPやCSSの実時間再生への依存は不要。 |
| 動画 | Mediabunny + ブラウザのWebCodecs | 既存アプリに実ファイル出力の参考がある。CanvasSourceと音声ソースを明示的な時間でmuxする。 |
| 音声 | Web Audio + 決定的なPCM合成 | 既存scoreの表現を一般化し、プレビューと出力に同じPCMを使える。 |
| 入力検証 | Zod | JSON・保存復元・UI確定時の境界検証。 |
| 保存 | IndexedDB、idb | プロジェクト、revision、サムネイルをローカルで保持する。 |
| 履歴 / 編集状態 | React useReducer + Context | 50操作程度の履歴を単一の編集モデルで扱う。毎フレームReact stateを書き換えない。 |
| フォント | Space Grotesk + Noto Sans JP、ローカル同梱 | 英字作例の形を保ち、日本語にも対応する。配布ライセンスを同梱。 |
| UIアイコン | lucide-react | 既存のルール・依存と整合。 |
| 検証 | Vitest、Playwright、oxlint、TypeScript、実ファイルの復号検査 | 数式・状態と、実操作・映像出力を別々に検証する。 |

HyperFramesは使用しない。Remotion、p5.js、Three.js、ffmpeg.wasmも初期依存には加えない。現在の表現に不要であり、別の時計・フォント・レンダリング基盤を増やす理由がない。将来GPUが必要と測定された場合はRendererの内部だけを交換できる境界にする。

### バージョンの出発点

以下は2026-09-26に確認した[既存アプリのpackage.json](../../2026-09-25/package.json)の固定値であり、「最新」の保証ではない。新アプリでは実際のinstall・型・ビルドを確認して固定し、package-lock.jsonを作る。

| 依存 | 参考値 |
| --- | --- |
| Node | 24系（既存CIに合わせる） |
| react / react-dom | 19.2.8 |
| typescript / vite / @vitejs/plugin-react | 6.0.2 / 8.2.2 / 6.1.0 |
| mediabunny / zod / idb | 1.59.1 / 4.6.5 / 8.0.3 |
| @fontsource/noto-sans-jp / lucide-react | 5.3.0 / 1.48.0 |
| vitest / @playwright/test / oxlint | 4.1.11 / 1.63.0 / 1.79.0 |

必要な依存だけを採用し、既存のpackage.jsonを丸ごとコピーしない。特にMediabunnyはオンライン文書の版とローカルの型を照合する。調査時、最新文書はqualityを中心に説明し、既存コードはbitrateを使用していた。インストール済みの型を正とし、記憶だけでAPIを書かない。

## 2. 責務の境界

```text
文章と場面の入力
  → director（役割・文字量・選んだ構成から草案を作る）
  → ProjectV1 + Zod検証
  → prepare（フォント、文字レイアウト、字形マスク）
  → compile（開始時刻、重なり、演出cue、音声cue）
  → Renderer.render(time, size)
      ├ preview controller → 可視Canvas
      ├ still exporter → PNG
      ├ video exporter → 専用Canvas → Mediabunny → MP4 / WebM
      └ HTML package → 小さなplayer + renderer + data + fonts
```

推奨するアプリ内の分割:

```text
src/domain/        schema、編集操作、履歴、制約
src/director/      三つの構成レシピ、演出選択、草案の生成
src/engine/        compile、clock、layout、fonts、seed、Renderer
src/engine/scenes/ 六つのモジュール
src/engine/transitions/ circle-match、cut
src/audio/         cueからPCMへの合成、プレビュー再生
src/export/        capabilities、video、html、png、project-json
src/storage/       IndexedDB、自動保存、復元
src/ui/            入力、場面リスト、設定、プレビュー操作、出力ダイアログ
src/player/        HTML出力専用の小さな操作UIとエントリ
tests/             domain、engine、export、E2E
docs/verification/ 検証結果と必要な証拠
```

公開済みCELESTIALから必要なアルゴリズムを新アプリ内へ移植し、作品専用の定数・グローバル状態を除く。実行時に `../2026-09-26/` や別の日付アプリをimportしない。アプリ単体で `npm ci` とbuildができるようにする。

## 3. 描画と文字

- rendererはCanvas/context/cacheを専有。プレビューと動画出力で同じCanvasを使い回さない。各描画でtransform、alpha、composite、clipを確実に初期化する。
- ランダムな値はscene idとproject seedから準備時に作る。物理シミュレーションを前フレームから積算せず、時間の式で位置を得る。
- 文字列を全文で描いた透明Canvasからアルファを採り、粒子の目標点にする。文字単位で切り離してkerningや日本語の結合文字を壊さない。必要なときだけgrapheme単位の位置情報を追加する。[Canvas getImageData](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getImageData)
- 配置は比率別のレイアウト関数で決め、モジュールが共通のtext metrics・safe areaを受け取る。フォントサイズを毎フレーム測り直さない。
- フォントを読み込み、対象文字列を指定してロードを待ってから字形を確定する。変更後に初めて現れる日本語も再確認する。`document.fonts.check` だけで全文字の字形が存在すると断言しない。[FontFace](https://developer.mozilla.org/en-US/docs/Web/API/FontFace)
- 対応文字範囲は同梱フォントに紐づくmanifestで管理し、範囲外や絵文字を含む場合は警告する。実際の欠字検証を行い、判定しきれない文字をサイレントに代替しない。
- 字形キャッシュにはサイズ上限を設ける。初期の目安は合計64MiB、超過時はLRUで破棄。全文字・全解像度・全フレームを保持しない。

既存Moving Cover Studioでは日本語フォントの多数のsubset参照で欠落が起き、バンドルの見直しが必要になった。CSSを読み込めたことだけで済ませず、dist内の実ファイル・参照先・新しい文字の描画を確認する。単体HTMLのサイズも記録する。

## 4. プレビューと音

音OFFではperformanceベースの時計、音ONではAudioContextの時計を基準に映像時刻を決める。pause・seek・再開時は現在時刻を保存し、音声sourceを停止・再作成してoffsetを揃える。Reactには再生状態や粗い進捗だけを通知する。

音源は編成済みcueから48kHz stereo PCMを生成する。BPM、場面境界、見せ場のcueが変われば波形を再作成する。既存score.jsの24秒用の固定時刻を、新しい作品へそのまま流用しない。ピーク、NaN、先頭末尾のフェードを検査し、実際に聴いて不快なクリック・音割れ・過大な音量がないことを確認する。

合成の負荷が高い場合は処理を分割し、必要と判明してからWorkerへ移す。最初からOffscreenCanvas/Workerを必須にして、フォント準備やブラウザ互換性を複雑にしない。

## 5. 動画出力

### 対応判定

実際に出す幅・高さ・fpsでvideoのencode可否を、音声ありならaudioも別に判定する。MP4はH.264/AVC + AAC、WebM代替はVP9またはVP8 + Opus。判定通過だけで成功を保証しない。実際の開始・追加・finalizeの失敗も処理する。WebCodecsの利用はsecure contextやブラウザ実装に依存する。[VideoEncoder](https://developer.mozilla.org/en-US/docs/Web/API/VideoEncoder)、[Mediabunnyの対応形式](https://mediabunny.dev/guide/supported-formats-and-codecs)

AACが使えない場合に勝手に無音MP4へ変えない。利用可能な「無音MP4」「音付きWebM」「HTML」を説明して選ばせる。MP4という拡張子を付けたWebMを生成しない。MediaRecorderの実時間録画は標準経路にしない。

### 手順

1. Projectをsnapshotとして固定し、描画準備と対応判定を済ませる。作業中に編集されても出力内容は変えない。
2. 専用renderer・Canvas・Outputを作成。描画サイズは出力の実ピクセル寸法。UIのdevicePixelRatioを動画の解像度へ乗算しない。
3. `T = totalTicks / 480 * 60 / bpm`、`N = ceil(T * fps)`、出力長を `N / fps` とする。端数は最後の状態を1フレーム未満延長し、音声も同じ長さにpad/trimする。ユーザーには確定した出力尺を表示する。
4. フレームnは時刻 `n / fps`、長さ `1 / fps` で追加する。CanvasSourceのaddはawaitし、encoderのbackpressureを守る。
5. 音声を同時に扱う場合はboundedな音声・映像producerを進める。一方の全量をawaitして他方が進めず停止する構成を避け、採用版のソース終了APIとmuxの挙動を統合テストで確認する。
6. 数フレームごとにイベントループへ制御を戻し、進捗・キャンセルを処理する。非表示タブでの継続を保証しない。必要なら一時停止状態を明示し、復帰後の時刻を壁時計で飛ばさない。
7. 各sourceを正常終了させ、Output.finalize完了後に初めてファイルを成功扱いする。キャンセル・例外ではOutput.cancel等で解放し、二重finalizeを防ぐ。
8. finallyでCanvas、encoder、音声、URL等の所有リソースを解放。キャンセル後に新しい出力を開始できることを確認する。

基本APIは[ファイル出力](https://mediabunny.dev/guide/writing-media-files)、[メディアソース](https://mediabunny.dev/guide/media-sources)、[CanvasSource](https://mediabunny.dev/api/CanvasSource)、[AudioBufferSource](https://mediabunny.dev/api/AudioBufferSource)を参照。既存の無音出力は[files.ts](../../2026-09-25/src/export/files.ts)を読む。インストール版の型定義で引数・終了方法を確認する。

初期はBufferTargetでメモリ内にmuxする。全フレームのImageDataは保持しない。60秒・1080pではPCMやencoderも含めて測定し、出力容量に上限を設ける。失敗時は720pを提案する。モバイルの長尺1080p出力を未測定のまま保証しない。

## 6. 単体HTML出力

HTMLは優先度の高い成果物。Reactエディタを丸ごと入れず、別エントリの小さなplayer・同じrenderer・Project・必要なフォント・合成音声コードを一ファイルに束ねる。外部CDN、フォントAPI、サーバーAPIへアクセスしない。プレイヤーは再生/停止・シーク・最初から・音ON/OFF・全画面を持ち、既定は静止・無音。

build時にプレイヤーを単一IIFE等へ束ね、その文字列をHTML書き出し側が利用する。動的importや相対asset URLを残さない。ユーザーのJSONは安全にシリアライズして `application/json` ブロックに格納し、`<` やscript終端等をエスケープする。読出しはtextContent + JSON.parse。ユーザー文字列をHTMLやコードとして補間しない。

フォントはライセンスとともに埋め込む。作品を開いた端末で使われるフォントが変わる外部依存を残さない。外部ファイルの取り込みを初期範囲から外すことで、JSONもHTMLも可搬性を保つ。

検証はローカルHTTP・ネットワークを切った状態・可能な実ブラウザでのfile://起動。ツール側でfile://が禁止されている場合は迂回せず、未確認として記録する。既存作品のfile://起動は、この作業環境では未検証である。

## 7. 保存・履歴

専用DB名 `type-motion-studio` を使い、既存アプリのDBを共有しない。Projectとrevisionを保存。500ms程度のdebounceで自動保存し、保存の直列化またはrevision比較により遅い古い書き込みが新しい内容を上書きしないようにする。

復元できないレコードは勝手に削除しない。JSON退避・別作品として開始を用意する。同じ作品を複数タブで開いた場合はrevisionの競合を検知して警告し、無言のlast-write-winsで編集を失わない。削除には対象の名前を示す確認と、Undoまたは復旧手段を設ける。

## 8. 配布と互換性

開発の基準環境はデスクトップChromium。Safari・Firefox・モバイルはプレビュー、保存、HTML、PNGを実測し、動画の可否は機能判定と実ファイルで記録する。対応を確認していないブラウザを対応済みと表示しない。

Pages用buildではproject pathを考慮したbaseを使う。[ViteのPages設定](https://vite.dev/guide/static-deploy.html#github-pages)。ただし本資料の段階では登録・デプロイをしない。将来公開するときは `apps.json` とこのリポジトリのrelease-*タグによる既存手順を確認し、作品CELESTIALの配布物を上書きしない。
