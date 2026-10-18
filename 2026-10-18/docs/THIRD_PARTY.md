# 同梱依存とライセンス

本体とMP3エンコーダーは固定したnpmパッケージを使う。AACエンコーダーはMediabunnyのwrapperソースを保ち、固定FFmpegソースからWASMとglueを再ビルドした。`public/licenses.html`からライセンス原文、対応ソース、ビルド手順へ進める。

| 依存 | 固定version | 役割 / ライセンス |
| --- | --- | --- |
| React / React DOM | 19.2.8 | 画面 / MIT |
| Mediabunny | 1.61.6 | 音声入力のメタ情報確認、出力コンテナ、PCMとエンコーダーの接続 / MPL-2.0 |
| @mediabunny/mp3-encoder | 1.61.6 | MP3のエンコード / wrapperはMPL-2.0、LAME 3.100はLGPL |
| @mediabunny/aac-encoder | 1.61.6-rebuild.1 | AAC-LCのエンコード / wrapperはMPL-2.0、FFmpegはLGPL-2.1-or-later |

## AACの再ビルド

- Mediabunny: `8dee3638fb1755e58b88d4432e344c5916027e76`。AACのwrapperとbridge.cは未改変。
- FFmpeg: n8.0.1、commit `894da5ca7d742e4429ffb2af534fcda0103ef593`。ソースは未改変。
- Emscripten: 4.0.21、commit `d6f42310010ddec0753a69bab01a4b33aae255b7`。
- 公開するWASM: 512,891 bytes、SHA-256 `5588e91d677997b5b73af97d51da10a9a26bfcde3315c5cde70fb2e6f8be418c`。
- ローカルパッケージは`vendor/aac-encoder/`。npm ci後もこの生成物を使用する。

AACだけをbundleする`bundle-aac.ts`は上流のESM設定とworkerプラグインを使う。上流の全体用bundle.tsで作ったAACのESMと、同じハッシュになることを確認した。

上流配布版のFFmpeg revisionを特定できなかったため、公開用には上記の入力から新しくビルドした。FFmpegの版名から旧バイナリの対応ソースを推測したものではない。旧WASMのSHA-256は`8488acb0bc9f43055b83600cc4c2c07d20f07675aa65671f91ac1d75515845d9`。

## 配布する資料

`public/licenses/aac-rebuild/`にFFmpegのソース、Mediabunnyのソースと生成glue、再ビルドscript、設定ファイル、provenance.jsonを置く。ソース一式にはMediabunnyのテスト用メディアと他codecの生成バイナリを含めていない。AACをビルドするためのソース、package.json、lockfile、workerプラグインを含む。

[再ビルド手順](../public/licenses/aac-rebuild/README.md)に、変更したソースからAACを組み直し、アプリへ反映する方法を記載した。`npm run verify:aac`は対応ソースとbundleのSHA-256、インストールされたパッケージ、同梱WASMを照合する。ソースとバイナリの対応を確かめる検査で、音質やブラウザ対応の合格判定ではない。

MP3のWASMは223,033 bytes、SHA-256 `d0b109db83c153b81ba0080fa2163664dff1e341b154edda6d40bc4b6fbc355e`。LAME 3.100の公式ソースも`public/licenses/lame-3.100.tar.gz`に同梱する。

公式資料: [AAC拡張](https://mediabunny.dev/guide/extensions/aac-encoder)、[FFmpegのライセンス](https://ffmpeg.org/legal.html)、[LAMEのライセンス](https://lame.sourceforge.io/license.txt)、[上流Issue #544](https://github.com/Vanilagy/mediabunny/issues/544)。
