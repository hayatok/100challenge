#!/usr/bin/env bash
set -euo pipefail

# Use fresh source trees at the revisions recorded in provenance.json.
: "${FFMPEG_PATH:?Set FFMPEG_PATH to the extracted FFmpeg source}"
: "${MEDIABUNNY_ROOT:?Set MEDIABUNNY_ROOT to the extracted Mediabunny source}"
emcc --version
cd "$FFMPEG_PATH"
emconfigure ./configure \
  --target-os=none --arch=x86_32 --enable-cross-compile \
  --disable-asm --disable-x86asm --disable-inline-asm \
  --disable-programs --disable-doc --disable-debug \
  --disable-all --disable-everything --disable-autodetect \
  --disable-pthreads --disable-runtime-cpudetect \
  --enable-avcodec --enable-encoder=aac \
  --cc=emcc --cxx=em++ --ar=emar --ranlib=emranlib \
  --extra-cflags='-DNDEBUG -Oz -flto -msimd128' \
  --extra-ldflags='-Oz -flto'
emmake make -j "${AAC_BUILD_JOBS:-2}"
cd "$MEDIABUNNY_ROOT/packages/aac-encoder"
mkdir -p build
emcc src/bridge.c \
  "$FFMPEG_PATH/libavcodec/libavcodec.a" \
  "$FFMPEG_PATH/libavutil/libavutil.a" \
  -I"$FFMPEG_PATH" \
  -s MODULARIZE=1 -s EXPORT_ES6=1 -s SINGLE_FILE=1 \
  -s ALLOW_MEMORY_GROWTH=1 -s ENVIRONMENT=web,worker \
  -s FILESYSTEM=0 -s MALLOC=emmalloc -s SUPPORT_LONGJMP=0 \
  -s EXPORTED_RUNTIME_METHODS=cwrap,HEAPU8 \
  -s EXPORTED_FUNCTIONS=_malloc,_free \
  -msimd128 -flto -Oz -o build/aac.js
cd "$MEDIABUNNY_ROOT"
# Dependencies must already be installed using the upstream package-lock.json.
./node_modules/.bin/tsx scripts/bundle-aac.ts
