# ぼんやりマート24

客・店員・仕入れ・収支・設備投資が自動で循環する、眺めるドット絵コンビニ経営ゲームです。

## Development

```bash
npm install
npm run dev
npm run check
```

## Game loop

- ゲーム内3分ごとに客、移動、購買、在庫、レジを更新
- 商品は在庫基準と経営方針に沿って自動発注
- 日付変更時に人件費、家賃、電気代、廃棄を精算
- 評判と資金が条件を満たすと、店長が確率的に増築を決定
- 増築後も次の運転資金を残せない場合は必ず見送り

## Validation routes

- 通常: `/`
- seed固定: `/?seed=20260904`
- 方針指定: `/?policy=profit` または `/?policy=popular`

## Controls

- `Space`: 停止・再開
- `1` / `2` / `4`: 観察速度
