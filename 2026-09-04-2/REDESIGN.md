# Precision commute redesign

- Goal: 停止線と皿の端を読み、止める・立て直す操作に手応えを作る。
- Context: issue #58、既存 simulation/input、ユーザー承認の2026-09-04画面案。
- Constraints: ワンボタン、同一URL、再挑戦は同じseed、他アプリとdocs/DESIGN.mdは変更しない。新規依存なし。
- Done when: 押しっぱなしは失敗。早い/適切/遅い操作で異なる結果。転倒は表示と同じ物理値。生成コースが攻略可能。375/768/1024/1440pxと成功/失敗/中断確認。CI→PR→タグ→Pages。

## Plan

1. 短い駅間と減速・揺り戻しの物理を作り、操作別の結果を数値で比較。
2. 承認済み画面をSVGの可変輪郭で再構成。背景・停止線・主操作以外を簡潔にする。
3. 即再挑戦、前回停止位置、3駅、生成コース、音と短い反応を接続。
4. ブラウザ/テスト/全体build、GitHubレビューと公開確認。

## Visual decision

白 #faf9f6、墨 #302d29、黄 #f5d77d、カラメル #85451f、停止線 #d64b3b。
承認済み画面に従い、旧ポスター/乗車券/ラスター素材は使用しない。物理に追従するゲーム本体の描画でありUIアイコンではないためSVGパスを使用。余白8px基準、線3px、影なし。装飾的な移動はreduced-motionで停止するが、危険を読む必須のプリン変形と停止線は保持する。

## Verification log

- Local root `npm run check`: 73 tests (app 11), lint/type/build/site passed. Existing CNN large-chunk notice only.
- 100 seeds: hold => overshoot loss, recovery => all 3 stops complete. One pulse 80/120/160ms succeeds on first station.
- Browser: 375/768/1024/1440px checked. Actual input replay reached 3-stop finish; braking-only replay fell 4.7m before line. Retry immediately restarted same station. Esc froze state, help and sound toggle worked.
- Production build: showcase link opened new game, Space down/up and Escape worked, browser console had no warnings/errors. No raster loading dependency remains.
- Screenshots: design/desktop-success.png, design/desktop-fall.png, design/mobile-ready.png. Developer replay screenshots are labelled as such.
- Limits: physical touchscreen full run and subjective fun evaluation remain unverified. Essential gameplay motion is retained under reduced-motion; optional flourishes are disabled by CSS.


## Color restoration (issue #60)

- Goal: 既存の色合いとポップさを戻す。
- Context: ユーザーの「デザインが貧相」「既存の色合いやポップさは踏襲して良かった」という修正指示。
- Constraints: 物理・ルール・操作配置は維持。ポスター風のコピーは増やさない。
- Done when: クリーム背景、ミントの車内とボタン、カラメルの輪郭、木の棚と色付きの皿が見え、停止線とプリンの危険を読める。レスポンシブ確認後Pagesに公開。
- この指示は上記「白中心・影なし」の方向を更新する。AI感への対処で元の配色・楽しさまで削りすぎた。今後は残す色・モチーフと削る要素を分けて判断する。
- 検証: 全73テスト、lint、型チェック、全アプリbuild、サイト生成成功。375/768/1024/1440pxと停車成功のスクリーンショット確認。公開用一覧→ゲームの遷移確認。色修正版の記録は design/color-restored.png。
