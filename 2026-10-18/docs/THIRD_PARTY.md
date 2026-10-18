# 同梱依存とライセンス

本体とエンコーダーはnpmの固定バージョンを使用し、改変せずbundleする。`public/licenses.html`からライセンス原文、上流ソース、同梱の公式ビルド手順へ到達できる。

| 依存 | 固定version | 役割 / ライセンス |
| --- | --- | --- |
| React / React DOM | 19.2.8 | 画面 / MIT |
| Mediabunny | 1.61.6 | 音声入力のメタ情報確認、出力コンテナ、PCM→エンコーダー接続 / MPL-2.0 |
| @mediabunny/mp3-encoder | 1.61.6 | MP3の実エンコード / wrapperはMPL-2.0、LAME 3.100はLGPL |
| @mediabunny/aac-encoder | 1.61.6 | AAC-LCの実エンコード / wrapperはMPL-2.0、FFmpegはLGPL-2.1-or-later |

Mediabunnyの対応上流commit: `8dee3638fb1755e58b88d4432e344c5916027e76`。バイナリを含むwrapperソースとビルド手順は[固定commit](https://github.com/Vanilagy/mediabunny/tree/8dee3638fb1755e58b88d4432e344c5916027e76)で参照可能。

調査時に確認したWASMのSHA-256:

- MP3 / 223,033 bytes: `d0b109db83c153b81ba0080fa2163664dff1e341b154edda6d40bc4b6fbc355e`
- AAC / 509,386 bytes: `8488acb0bc9f43055b83600cc4c2c07d20f07675aa65671f91ac1d75515845d9`

AAC binaryには`Lavc62.23.103`の表示があるが、正確なFFmpeg revisionは上流で記録されていない。[上流Issue #544](https://github.com/Vanilagy/mediabunny/issues/544)の対象binaryと上のdigestが一致している。バージョン表記から特定releaseの対応ソースだと推測しない。外部向けbinary公開の前に、上流の対応ソースを確認するか、固定FFmpeg sourceから再ビルドして対応source/build資料をそろえる。このタスクは実装・ローカル検証とPRまでで、サイト公開・タグ作成は行わない。

公式資料: [MP3拡張](https://mediabunny.dev/guide/extensions/mp3-encoder)、[AAC拡張](https://mediabunny.dev/guide/extensions/aac-encoder)、[FFmpegのライセンス](https://ffmpeg.org/legal.html)、[LAMEのライセンス](https://lame.sourceforge.io/license.txt)。
