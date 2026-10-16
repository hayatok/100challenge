#!/bin/zsh
set -e
cd -- "$(dirname -- "$0")"
if ! command -v node >/dev/null 2>&1; then
  print "Node.js 22以降が必要です。Node.jsを用意してから、もう一度ひらいてください。"
  read "reply?Enterキーで閉じます。"
  exit 1
fi
exec node scripts/serve_app.mjs --open
