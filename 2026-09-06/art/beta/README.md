# ベータ版アート制作

`direction-reference.png` はbuilt-in image_genで作成した参考ボード。実ゲーム画像・完成素材ではない。設備の密度と日常の小さな物語の参考とし、画像内のピクセル密度の不統一は採用しない。

実ゲームの人物ソースは `game/pixel_people.gd`。16×24の各ピクセル、輪郭、服、持ち物、方向、歩行、ポーズをコード内に保持する。`game/tools/render_sprite_board.gd` は12人の原寸ボードを出力する制作ツール。ランタイムも同じデータを使う。

世界の描画は `game/store_scene.gd`、整数倍表示と文字・入力変換は `game/store_view.gd`。滑らかな画像を粗く縮小して実ゲーム素材にする工程は使わない。

## image_gen prompt（参考用、built-in）

Create a production art-direction reference board for an original Japanese convenience store management videogame, Machiakari Mart. This is a reference board, not a screenshot of a working game. Authentic charming early-console pixel art: deliberate 1-pixel clusters, very limited palette, hard crisp stepped edges, absolutely no smooth shading, no painterly textures, no antialiasing or pseudo-pixel noise. Main panel is an orthographic 2:1 isometric cutaway convenience store at tile scale 32x16 source pixels, scaled up with perfectly square pixels: teal and cream commercial metal gondola shelves full of distinctly readable onigiri, colorful bottles, bread bags, boxed sweets; wall refrigerators; separate till cashier side and customer side; 3 distinct customers queue along a marked clear aisle; open door at left facade connecting sidewalk and road. Warm amber light, coral store stripe, dark navy outlines. Make the little everyday world playful and memorable with silhouette humor: a tiny tired office worker carrying a comically long baguette, a confident school kid with spicy noodles, an elderly shopper with newspaper and oversized bread. Lower panel character design lineup of 8 visually distinct original townspeople with 2-3-head-tall 16x24-pixel proportions; varied outfits, hairstyles, bags; expressive clear silhouettes, front and back views. Small inset of same store at night with warm flat pools of light and indigo road. Keep commercial convenience-store identity, no rustic wooden market or fantasy setting. No UI mock dashboard, no claim of implementation, no copied characters or trademarks. Layout clearly labels REFERENCE only. Bold readable graphic shapes, economical harmonious 24-color palette, navy #20283f, jade #378c78, mint #9bc59d, cream #f7e6bc, coral #d65b54, amber #e7ab53. Prioritize genuine crafted pixel-art character, visual storytelling and clarity.


商品は `game/product_icon.gd` に20×20の原寸ピクセル形状を持ち、商品一覧と `game/tools/render_product_board.gd` が同じControlを使う。`product-board.png` は全80品の内容確認用ボードであり、店内のスクリーンショットではない。おにぎり・弁当・食パン・長いパン・紙カップ・ボトル・肉まん・傘など、実際の商品名に対応させる。

設備は金属棚の支柱・値札、冷蔵ケースの暗い庫内と照明、保温ケース、レジ端末と釣銭トレーを別々に描く。世界の床は淡い目地、屋外は歩道の舗装線とし、大きな市松模様で商品より床が目立つ状態を避ける。全設備の固有作画・季節・夜景の監査はB1として継続中。
