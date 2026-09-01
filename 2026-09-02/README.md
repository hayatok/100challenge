# いのちの庭

768マスの大自然を、必要以上の設備で見守る8bitライフゲームです。

コンウェイのライフゲーム `B3/S23` を32×24のトーラス盤面で動かし、セルを芽、植物、花、土へ還るピクセルとして表示します。勝敗、スコア、外部通信はありません。

画面内の「庭のルール」では、誕生・生存・枯死の条件、芽から花までの成長段階、安定した花が残り続ける理由を確認できます。

## Development

```bash
npm install
npm run dev
npm run check
```

## Validation routes

- 通常: `/`
- 空の庭: `/?demo=empty`
- 自然再播種: `/?demo=reseeding`
- アセット失敗時の簡易表示: `/?fallback=1`

## Product decisions

- 通常世代の生命判定はConway `B3/S23`を変更しない
- 自然全滅だけ1.5秒後に新しい庭を開始する
- スコア、ゲームオーバー、音、外部通信を追加しない
- ジョークの対象は生命ではなく、用途に対して過剰な観測装置にする
- 盤面は保存せず、見守る速度と操作説明設定だけ端末内へ保存する

詳細仕様は [`docs/SPEC.md`](./docs/SPEC.md) を参照してください。

## Generated asset

`public/life-garden-sprites-v1.png` はOpenAIの組み込み画像生成機能で制作した8bitスプライト案です。`npm run assets` がチェッカー背景を除去し、ゲーム用の `life-garden-sprites-v1-alpha.png` を決定的に再生成します。
