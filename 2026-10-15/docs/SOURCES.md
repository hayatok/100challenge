# OCRと配布物の出典

2026-10-15確認。画像の文字を読み取る実処理に、公式のPaddleOCR.jsを使う。表構造は別処理で罫線とOCR座標から復元する。SDKに表認識機能があるとは扱わない。

| 配布物 | 固定版・用途 | ライセンス・出典 |
| --- | --- | --- |
| `@paddleocr/paddleocr-js` | 0.4.2。日本語の文字検出・認識 | Apache-2.0。[公式ソース](https://github.com/PaddlePaddle/PaddleOCR/tree/main/paddleocr-js)、[ブラウザAPI](https://www.paddleocr.ai/latest/version3.x/inference_deployment/cross_platform/browser.html) |
| `PP-OCRv6_small_det` / `PP-OCRv6_small_rec` | 公式ONNXモデル。smallは日本語を含む50言語。tiny認識モデルは日本語対象外 | PaddleOCRのApache-2.0。[モデル説明](https://www.paddleocr.ai/latest/version3.x/algorithm/PP-OCRv6/PP-OCRv6.html)、[公式ライセンス](https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE) |
| `onnxruntime-web` | 1.24.3。WebGPUまたはWASMによる推論 | MIT。[公式WebGPU API](https://onnxruntime.ai/docs/tutorials/web/ep-webgpu.html)、[ライセンス](https://github.com/microsoft/onnxruntime/blob/v1.24.3/LICENSE) |
| `@techstark/opencv-js` | 4.10.0-release.1。画像の前処理・座標処理。WASM | Apache-2.0。[配布元](https://github.com/TechStark/opencv-js) |
| `react` / `react-dom` / `scheduler` | UIと描画。固定版はpackage-lock.json | MIT。配布パッケージのLICENSEを`public/licenses/`へ保存 |
| `js-yaml` / `clipper-lib` | SDK依存。モデル設定の解析・多角形処理 | MIT / Boost-1.0。配布パッケージのライセンス・著作権表示を`public/licenses/`へ保存。Clipperに含まれるJSBNは[Tom Wuの原ライセンス](https://www-cs-faculty.stanford.edu/~tjw/jsbn/LICENSE)も保存 |

モデルURLは`https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv6_small_{det,rec}_onnx_infer.tar`。未圧縮tarに`inference.onnx`と`inference.yml`が含まれる。recの設定内の字書にはひらがな・カタカナ・漢字が含まれる。

`scripts/prepare-assets.mjs`がSHA-256とサイズを検証して`public/ocr-models/`へ保存する。detは9,891,840 bytes、recは21,319,680 bytes。WebGPU対応ORTのJSEP wasm/mjsは計25,061,349 bytes。モデルとランタイムだけで約56.3 MBとなる。ビルド済みコードとモデルは同じ配信元から読み込み、OCR実行時に外部モデルサーバーや外部OCR APIへ接続しない。初回はこれらのダウンロードが必要で、ブラウザキャッシュは容量制約等により消える場合がある。

アセット準備は再実行可能。既存ファイルのハッシュが一致すれば再取得しない。取得失敗やハッシュ不一致は処理を中断する。開発時だけ`OCR_ASSET_SEED_DIR`に検証済みファイルを指定できるが、同じチェックサムを必ず検証する。新規CIは公式URLから取得する。モデル更新時は固定版・ハッシュ・実画像の検証結果を一緒に更新する。

## 実行境界

専用のアプリWorker内で`PaddleOCR.create({worker:false, lang:'japan', ocrVersion:'PP-OCRv6'})`を実行する。SDKのDOM変換を避け、Blob→ImageBitmap→OffscreenCanvas→OpenCV Matを入力する。固定した`onnxruntime-web@1.24.3`の通常バンドルに含まれるWebGPU / WASM実装とJSEPランタイムを使い、Workerの形式はES moduleとする。この版の`/webgpu`別バンドルはasyncifyランタイムを要求するため、JSEP配布構成ではエイリアスを設定しない。WASMは単一スレッドで動かすため、COOP/COEPに依存しない。WebGPUは利用可能なアダプタと対応演算子に依存し、自動選択では初期化できない段階をWASMへフォールバックする。

表示に使う実行環境は認識結果の`runtime.detProvider`と`runtime.recProvider`。WebGPU対応検出だけでGPU実行済みと表示しない。文字の前後処理・罫線解析等をWebGPU処理とは呼ばない。ブラウザ・GPUにより実行時間は変わり、常にWebGPUが速いとは限らない。

SDKには進捗率・AbortSignalのAPIがないため、表示は実際の工程名と不定進捗にする。キャンセル時はアプリWorkerを終了し、PromiseをAbortErrorで終了する。再試行は新しいWorkerを作る。

## 技術プローブ

実装前の一時プローブでは、Chromeで生成した1000×400の日本語4×4罫線表を、同じ公式v6 smallモデルとアプリWorker方式で認識した。13個の非空セル（商品名、数量、単価、金額、りんご、3、120、360、ノート、250、500、合計、860）をWASM・WebGPUの両方で一致して認識。3個の空セルからOCR文字は生成されなかった。空セルの行列位置は別途罫線から復元する必要がある。強制WASMではdet/recともwasm、強制WebGPUではともにwebgpuを返した。これは生成した実画像を使う技術プローブであり、完成アプリの操作・外部画像・全端末の検証を代替しない。

## 統合時の修正

別名`onnxruntime-web/webgpu`のバンドルと通常版では、この固定版でも要求するWASMファイルが異なる。別名のasyncifyコードへJSEPファイルだけを配ると初期化に失敗する。通常版1.24.3とJSEPへ統一し、Viteの依存キャッシュを再構築した。完成アプリの日本語5行×4列表で、自動選択時は検出・文字認識ともwebgpu、強制WASMではともにwasmとなることを確認した。開発時はWorker内の依存も事前最適化し、初回認識時の依存追加によるページ再読み込みを避ける。
