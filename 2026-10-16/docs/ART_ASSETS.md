# 生活史の情景イラスト

作成日: 2026-10-16 (Asia/Tokyo)

## 制作方法と使用範囲

- 使用ツール: builtin `image_gen.imagegen`。各画像を別々の tool call で新規生成した。
- 生成元から原画像をそのままプロジェクトへコピーした。CLI fallback、Pythonによる画像編集、史料画像の描き写しや流用は行っていない。
- 共通画風: 精細で柔らかな木版/リソグラフ風の書籍挿絵。暖紙 #F4F0E8、墨 #20201E、控えめな朱 #B73529、灰緑 #61766A。全画面に情景が広がる横長構図で、大きな白余白を設けない。
- すべて架空の生活の情景。写真・史料・特定個人/世帯/地域/年の忠実な復元として提示しない。人物や道具の細部を歴史的事実の根拠に使わない。
- Web作品内で、時代の暮らしを想像するための挿絵として使用する。本文、年表、数値、出典などの事実情報は別途検証した資料に基づく。
- 情景の上には本文を重ねず、画像と文章を分離して使う。
- 保存後の3枚を `view_image` で目視確認した。被写体、画風、横長の全画面構図、読める本文やロゴ等がないことを確認。実アプリ内の表示・レスポンシブ確認は実装側で行う。

## teacher-desk.png

- 保存先: `/Users/hayatok/Documents/dev/100challenge/2026-10-16/app/assets/art/teacher-desk.png`
- 生成元: `/Users/hayatok/.codex/generated_images/01a14479-4181-7411-a8ee-1babeb562aab/exec-3d1508e6-02b9-41a2-b022-f6ec8c04c5a4.png`
- 寸法: 1672 × 941 px
- SHA-256: `06d16b892799052af3a6f19dca8a7452732659afbc8c50f121869cf1d9b555e6`
- 性格・用途: 大正頃を広くイメージした机・家計簿・葉書・豆腐と野菜・窓外の木造の町。家計や食生活を読む章の情景挿絵。
- Tool: builtin `image_gen.imagegen`
- `transparent_background`: `false`

### Prompt 全文

```text
Use case: illustration-story
Asset type: full-bleed landscape editorial illustration for a Japanese history reading experience, around 16:9 or 1536x1024 landscape.
Primary request: An invented everyday domestic scene loosely evoking the Taisho era in Japan: a wooden desk near a window, an open plain household account book and a few plain postcards with NO legible writing, tofu on a simple dish and fresh vegetables on the table. Through the window, a quiet wooden neighborhood and a few small distant people.
Style/medium: Refined Japanese book illustration with hand-printed woodblock and risograph qualities, detailed but soft; precise ink hatching, layered restrained pigments, warm fibrous paper visible inside the image. Calm, observant and quietly beautiful. Natural human proportions, not cute or caricatured, not photographic.
Composition/framing: Landscape full-bleed illustration, scene fills the entire image and center. Foreground table objects connect to the window view as a unified composition. No white outer border, no empty panel, no large blank area for UI. Modest human presence far away, no identifiable individual.
Lighting/mood: Gentle daylight, intimate domestic warmth, a lived-in place rather than an exhibition.
Color palette: Warm paper #F4F0E8, dark ink #20201E, very restrained vermilion #B73529, muted gray green #61766A.
Constraints: Entirely fictional scene, not a reproduction of any historical source or photograph. No text, letters, numbers, logos, flags, watermark, military imagery, Mount Fuji, torii gates, or iconic shorthand for Japan. The open book and postcards must have blank or indistinct non-character marks only. Avoid excessive empty white margins.
```

## rural-day.png

- 保存先: `/Users/hayatok/Documents/dev/100challenge/2026-10-16/app/assets/art/rural-day.png`
- 生成元: `/Users/hayatok/.codex/generated_images/01a14479-4181-7411-a8ee-1babeb562aab/exec-14170ae1-85de-4d7f-a59a-dd72ecf03705.png`
- 寸法: 1672 × 940 px
- SHA-256: `8640f81dac606040ad487f9fbbcf1d0eed1e5898a101814a879d6abba33c0a75`
- 性格・用途: 昭和初期を広くイメージした東北の農村。畑・木造の家・食卓・家族の仕事をつなぐ情景挿絵。O/K家など実在世帯の再現ではない。
- Tool: builtin `image_gen.imagegen`
- `transparent_background`: `false`

### Prompt 全文

```text
Use case: illustration-story
Asset type: full-bleed landscape editorial illustration for a Japanese history reading experience, around 16:9 or 1536x1024 landscape.
Primary request: An invented everyday scene loosely evoking an early Showa farming village in northeastern Japan: cultivated vegetable fields, modest wooden homes, a low domestic dining table visible in an open home, and a working family seen at a small distance. Food, household work and cultivation are visually connected in a warm but unsentimental lived-in landscape.
Style/medium: Refined Japanese book illustration with hand-printed woodblock and risograph qualities, detailed but soft; precise dark ink hatching, layered restrained pigments, warm fibrous paper visible inside the image. Calm, observant and quietly beautiful. Natural human proportions, not cute or caricatured, not photographic.
Composition/framing: Landscape full-bleed scene with fields and household details filling the whole frame and center; a thoughtful gently elevated viewpoint connecting the home and field. People are modest small figures rather than portraits. No white outer border, empty panel or large blank area for UI.
Lighting/mood: Soft mild daylight, generous sense of human work and daily continuity, tactile countryside.
Color palette: Warm paper #F4F0E8, dark ink #20201E, very restrained vermilion #B73529, muted gray green #61766A.
Constraints: Entirely fictional scene, not any actual family or historical household, not a reproduction of a historical source or photograph. No text, letters, numbers, logos, flags, watermark, military imagery, Mount Fuji, torii gates, or iconic shorthand for Japan. Avoid excessive empty white margins.
```

## city-home.png

- 保存先: `/Users/hayatok/Documents/dev/100challenge/2026-10-16/app/assets/art/city-home.png`
- 生成元: `/Users/hayatok/.codex/generated_images/01a14479-4181-7411-a8ee-1babeb562aab/exec-770d8bd1-c65d-4827-b62e-6c56a54b6564.png`
- 寸法: 1672 × 941 px
- SHA-256: `fb8a0eb991ac535fa1f269213b2468c3767375e86007fdd5e98c6c23e8698892`
- 性格・用途: 1980〜2000年代を広くイメージした街の住まい。台所・洗濯物・自転車・鉄道をつなぐ近現代の日常の挿絵。具体的な地域や年の再現ではない。
- Tool: builtin `image_gen.imagegen`
- `transparent_background`: `false`

### Prompt 全文

```text
Use case: illustration-story
Asset type: full-bleed landscape editorial illustration for a Japanese history reading experience, around 16:9 or 1536x1024 landscape.
Primary request: An invented scene of everyday urban living in Japan broadly evoking the 1980s through 2000s, without representing a specific city or year. A lived-in city home with a modest kitchen visible by an open window, everyday laundry drying on a balcony, bicycles near the narrow residential street, and a commuter railway gently passing in the neighborhood background. A few natural small distant figures can be present.
Style/medium: Refined Japanese book illustration with hand-printed woodblock and risograph qualities, detailed but soft; precise dark ink hatching, layered restrained pigments, warm fibrous paper visible inside the image. Calm, observant and quietly beautiful. Natural human proportions, not cute or caricatured, not photographic.
Composition/framing: Landscape full-bleed scene filling the entire frame and center. Use a coherent gently elevated neighborhood view with the kitchen and laundry in the foreground and the railway woven into the distance; home, street and rail form one lived-in setting. No white outer border, empty panel or large blank area for UI.
Lighting/mood: Gentle afternoon daylight, quiet ordinary domestic continuity, warm but unsentimental.
Color palette: Warm paper #F4F0E8, dark ink #20201E, very restrained vermilion #B73529, muted gray green #61766A.
Constraints: Entirely fictional scene, not a reproduction of a historical source or photograph. No text, letters, numbers, logos, flags, watermark, military imagery, Mount Fuji, torii gates, or iconic shorthand for Japan. No readable station signs, labels or markings on the train. Avoid excessive empty white margins.
```
