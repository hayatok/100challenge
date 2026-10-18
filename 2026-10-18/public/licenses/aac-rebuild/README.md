# AACエンコーダーの再ビルド

FFmpeg n8.0.1（894da5ca7d742e4429ffb2af534fcda0103ef593）、Mediabunny 1.61.6（8dee3638fb1755e58b88d4432e344c5916027e76）、Emscripten 4.0.21を使う。ソースと生成物のSHA-256は、同じフォルダのprovenance.jsonに記録している。

## 準備

新しい作業用フォルダを作り、このページと同じ配信先からffmpeg-894da5ca.tar.gz、mediabunny-aac-source.tar.gzを保存する。アーカイブのSHA-256がprovenance.jsonと一致することを確認する。

公式手順に従い、Emscripten SDKを準備する。既存のシェル設定を書き換える必要はない。

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 4.0.21
./emsdk activate 4.0.21
source ./emsdk_env.sh
cd ..

tar -xzf ffmpeg-894da5ca.tar.gz
tar -xzf mediabunny-aac-source.tar.gz
cd mediabunny-aac
npm ci --ignore-scripts
cd ..
```

## ビルド

必要ならFFmpegやbridge.c、wrapperのソースを変更し、次のコマンドを実行する。

```bash
export FFMPEG_PATH="$PWD/FFmpeg-894da5ca7d742e4429ffb2af534fcda0103ef593"
export MEDIABUNNY_ROOT="$PWD/mediabunny-aac"
bash "$MEDIABUNNY_ROOT/build-aac.sh"
```

FFmpegのlibavcodec/libavutilとAACのglueをビルドし、wrapperとworkerをbundleする。生成物は`mediabunny-aac/packages/aac-encoder/dist/bundles/mediabunny-aac-encoder.mjs`。configureの指定はbuild-aac.shに記載し、公開時に生成したconfig.h、config_components.h、config.makもこの配信先に置いている。

## アプリへの反映

生成したmjsをアプリの`vendor/aac-encoder/index.mjs`へコピーする。ソースを変更した場合は、公開するソース一式とprovenance.jsonも更新する。アプリで`npm ci`と`npm run check`を実行し、AACの照合と実エンコードを確認してから公開する。

Mediabunnyのwrapperとbridge.cはMPL-2.0、FFmpegはLGPL-2.1-or-later。各ソースにライセンス原文を含む。
