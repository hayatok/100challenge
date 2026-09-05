# Product Design Principles

このファイルは、このプロダクトが「何らしい見た目と体験を持つべきか」を定義する。
実装方法ではなく、ユーザーに提供する体験と判断基準を記録する。

## Project identity

以下をプロジェクトごとに埋める。

- Product name: 100日チャレンジ
- Target users: 私
- Primary job: [ユーザーが達成したいこと]
- Main usage frequency: [毎日 / 毎週 / 一度だけ / その他]
- Primary platform: [Web / macOS / iOS / Android / その他]
- Product category: [業務ツール / エディタ / ダッシュボード / 消費者向けアプリ / その他]

## Product feeling

このプロダクトを使ったとき、ユーザーには以下のように感じてほしい。

- [例: 落ち着いている]
- [例: 信頼できる]
- [例: 素早く判断できる]
- [例: 自分でコントロールできる]

避ける印象:

- [例: 派手すぎる]
- [例: 広告のように見える]
- [例: AIが自動生成したテンプレートに見える]
- [例: 何を操作すればよいか分からない]

## Design principles

### 1. Purpose over decoration

見た目を目立たせることより、ユーザーの目的達成を優先する。
装飾は、意味、階層、状態、ブランドのいずれかに貢献する場合だけ使う。

### 2. One coherent product

各画面は、別々の作品ではなく、同じプロダクトの一部に見える必要がある。

- 色の使い方を統一する
- 余白の基準を統一する
- コンポーネントの振る舞いを統一する
- 同じ意味の操作は同じ見た目にする
- 画面ごとに新しいデザイン言語を作らない

### 3. Clear hierarchy

すべてを目立たせない。

- 最重要の情報を1つ決める
- 主操作を1つ決める
- 補助情報は視覚的に抑える
- 重要度が同じものは同じ強さで扱う
- 見出し、本文、補助文、状態の階層を明確にする

### 4. Appropriate density

画面の密度は、プロダクトの用途に合わせる。

業務ツール、管理画面、編集画面では、装飾的な余白よりも、
比較、検索、スキャン、反復操作のしやすさを優先する。

一方、ゲーム、作品紹介、ブランドサイトでは、必要に応じて
表現性、没入感、アニメーションを高めてもよい。

### 5. Concrete over generic

具体的なプロダクト、データ、ユーザー、状態を見せる。

- 実際のデータを使う
- 実際の操作に合ったラベルを使う
- 実際のブランド素材を使う
- 意味のないLorem ipsumやダミー装飾を残さない
- 抽象的なカードの集合だけで画面を構成しない

## Visual language

以下をプロジェクトごとに決める。

### Color

- Primary background: [色]
- Secondary background: [色]
- Primary text: [色]
- Secondary text: [色]
- Border: [色]
- Accent: [色]
- Success: [色]
- Warning: [色]
- Error: [色]
- Information: [色]

基本方針:

- アクセントカラーは、本当に重要な要素に限定して使う
- 画面全体を単一色相で覆わない
- グラデーションは、意味と目的がある場合だけ使う
- 状態を色だけで伝えない
- 本文と背景のコントラストを確認する

### Typography

- Font family: [フォント]
- Body size: [サイズ]
- Small text size: [サイズ]
- Heading scale: [サイズ階層]
- Numeric style: [必要なら指定]
- Line height: [値]
- Letter spacing: [値]

基本方針:

- 画面の役割に合った文字サイズを使う
- 小さなUI要素に大きすぎる見出しを使わない
- 日本語の改行と可読性を優先する
- 長いラベルが収まることを確認する

### Spacing

- Base unit: [例: 4px / 8px]
- Page padding: [値]
- Section gap: [値]
- Component gap: [値]
- Inline gap: [値]

基本方針:

- 余白は感覚で毎回決めず、既存の間隔体系から選ぶ
- 重要なグループには十分な余白を与える
- 近い意味の要素は近く、異なる意味の要素は離す

### Shape and surface

- Default radius: [値]
- Small radius: [値]
- Large radius: [値]
- Border style: [指定]
- Shadow style: [指定]

基本方針:

- すべてを過剰に丸くしない
- ページ全体をカード化しない
- カードの入れ子を避ける
- 影は階層や浮遊状態を示す場合だけ使う
- 装飾的な光球、ぼかし、過剰な影を使わない

### Iconography

- Icon library: [ライブラリ名]
- Default size: [値]
- Stroke width: [値]
- Icon color: [色]

基本方針:

- 同じ意味の操作には同じアイコンを使う
- アイコンだけでは意味が分からない場合はツールチップを付ける
- アイコンのためにボタンのサイズやレイアウトを不安定にしない
- 絵文字をUIアイコンとして使わない

### Motion

- Motion tone: [静か / 軽快 / 遊び心 / その他]
- Default duration: [値]
- Easing: [指定]
- Reduced motion behavior: [指定]

基本方針:

- アニメーションは状態変化や空間関係を理解する助けとして使う
- 目的のない動きや常時点滅を避ける
- 操作の完了を遅らせるためにアニメーションを使わない
- reduced motionの設定を尊重する

## Information architecture

各主要画面について、以下を定義する。

### [画面名]

- User goal: [この画面で何を達成するか]
- Primary action: [最重要操作]
- Secondary actions: [補助操作]
- Main content: [中心となる情報]
- Navigation: [前後の移動方法]
- Important states: [loading / empty / error / success]
- Mobile behavior: [モバイル時の変更]
- Reference screen: [既存画面や画像へのリンク]

## Required states

主要画面では、少なくとも以下を設計する。

- 初回表示
- データが存在する状態
- データが空の状態
- 読み込み中
- 読み込み失敗
- 保存成功
- 入力エラー
- 権限不足
- 操作不能状態
- 長いデータや大量データ

空状態やエラー状態も、通常状態と同じプロダクト品質で設計する。

## Visual references

このプロジェクトの視覚的な正解を、以下に記録する。

- Approved screenshots: [パスまたはURL]
- Existing screens to follow: [パス]
- Component examples: [パス]
- Brand assets: [パス]
- Rejected examples: [パス]
- Figma or design source: [URL]

参考画像がある場合は、単に似せるのではなく、以下を読み取る。

- 情報の密度
- 余白のリズム
- 文字の階層
- 操作の優先順位
- 色の役割
- 状態の表現
- 画面幅による変化

## Anti-patterns

以下は、明確な理由がない限り避ける。

- 画面全体をカードで囲む
- カードをカードの中に入れる
- すべての操作を大きな丸角ボタンにする
- 意味のないグラデーションを使う
- 装飾的な光球やぼかしを背景に置く
- 紫や青のグラデーションだけでブランド感を出す
- 重要な操作よりヒーローや装飾を目立たせる
- 画面の目的を説明する文章だけを表示する
- 実際の機能より先にマーケティング風のランディング画面を作る
- 画面ごとに異なる余白、角丸、ボタンを作る
- ローディング、空、エラー状態を省略する
- スクリーンショットを確認せずにUIを完成扱いにする

## UI quality rubric

実装後、以下を確認する。

- [ ] 3秒以内に画面の目的が分かる
- [ ] 主操作が明確である
- [ ] 情報の重要度が視覚的に伝わる
- [ ] 繰り返し操作が疲れにくい
- [ ] 既存画面と同じプロダクトに見える
- [ ] loading、empty、error、successが設計されている
- [ ] 375px幅で崩れない
- [ ] 1440px幅で間延びしない
- [ ] 文字の欠落や重なりがない
- [ ] キーボード操作とfocus状態が機能する
- [ ] 装飾が目的達成の邪魔をしていない
- [ ] 実際のブラウザで確認されている

## Design decisions

重要な判断はここに記録する。

### [YYYY-MM-DD] [Decision title]

- Decision: [決定内容]
- Reason: [理由]
- Alternatives considered: [検討した代替案]
- Affected screens: [影響画面]
- Revisit when: [見直す条件]
