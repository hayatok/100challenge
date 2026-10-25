# Phoenix Wright: Ace Attorney Trilogy — 証言の視点を証拠で照合する

**対象**: Steam app 787480、Capcom、2019年版を含む三部作。米国「visual-novel」タグ売上一覧17位（2026-10-25取得）。順位は選定条件。

## 主要判断：左と右は食い違いか

『Phoenix Wright: Ace Attorney』第2話「Turnabout Sisters」3日目。Redd Whiteは「被害者は逃げた」と述べる。Pressで問い返すと「左へ逃げた」と具体化する。Court RecordにはApril Mayの証言「右へ逃げた」がある。更新後のWhiteの発言にMay TestimonyをPresentし、法廷図でWhiteの立ち位置を示すと、彼はホテルの窓の外でなく事務所内から見ていたことが示唆される。左右は各人の向きに対する表現なので、当初の不一致だけでは片方の嘘と決められない。Whiteは後に両証言が正しかったと修正する。これは次の推理へ進む一手で、容疑を解く結論ではない。

## 根拠の区分

- **E — ルール**: Capcom担当者の公式記事は、Pressで証人が説明を補う場合があり、証言を前後して読み直せると説明する（PlayStation Blog、節5）。罰則の仕様書ではない。本作のCapcomオンラインマニュアルは確認できなかった。
- **E — 具体的手順**: Wikibooksの第2話3日目攻略（StrategyWiki由来）「Witness's Account: Cross-examination」は、Whiteの8番目をPressして「left」に更新し、May TestimonyをPresent、法廷図のK地点を示す順を記載する。両証言は視点の違いで両立するとの説明もある。開発者資料ではない。
- **E — 代償**: Capcom記事に不正解の罰則はない。初代DS版GameFAQs攻略（TIDQ、「3.1 In Court」）ではPressは無罰、違う証拠または発言への提示はstrike、1日5回でゲームオーバーとされる。2005年DS版のコミュニティ資料で、Steam Trilogyの正確なstrike数は未確認。ここでは法廷リソースを失いうる、とだけ扱う。
- **F — 見た画面**: 編集済みSteam予告映像の静止画6枚を確認。`787480@38.00`は人物と台詞枠、`@50.00`はMayaの台詞と「9」、`@80.00`はThinker状の証拠品、`@90.00`はナイフを持つ証人と「Testimony」。`@44.00`と`@65.00`は人物紹介・演出カットで、操作結果とは扱わない。全て別場面の例で、上記の第2話の連続操作を示さない（[フレーム記録](../frames/787480.json)）。全編視聴・入力観察なし。
- **H — 仮説**: この判断の価値は、違いを見つけるだけでなく、証人の位置・向きから語句の基準を解釈し直し、図で説明する点にある。Pressは低リスクの追加質問、Presentは証拠を特定の発言に結び付ける高リスクの主張となる。誤提示後に理由が返らなければ、推論を修正できず全証拠の総当たりへ流れる可能性がある。いずれもプレイ試験前の仮説。

## 判断鎖と転用案

| 段階 | 根拠から言えること |
| --- | --- |
| 情報・行動 | Whiteの曖昧な発言をPressし、Mayの右方向の記録を更新後の「左」発言へ提示する。 |
| 代償・直後 | 誤提示はDS版攻略上strike。法廷図のK地点を示すとWhiteが証言を修正し、視点が争点になる。対象版の罰数は不明。 |
| 次への影響 | 左右の違いは解消するが、Whiteが事務所内を見た説明は後続の証拠でさらに調べる。攻略資料による手順であり実機操作は未確認。 |

**変更案**: 推理試作に、同じ移動を別位置から見た証言、観察位置つき証拠カード、見取り図を用意する。証拠提示後、誤りの種類（例「証拠は関係するが視点が違う」）を短く返し、正解を明かさず根拠の再確認を促す。

**試験と棄却条件**: ①二人が同じ向きから見た状態、②位置・向きが異なる状態を比べる。どの語句と位置情報を根拠にしたか、提示後に解釈を修正できたか、納得したかを観察する。視点表示を読んでも矛盾の成否を説明できない、または図を見ず正答できるなら仮説を見直す。正答が同じでも根拠を説明できれば失敗とはしない。**適用条件・失敗候補**: 証人の位置で方向・順序の意味が変わる推理に向く。単一視点の課題には不要。毎回地図を説明させてテンポを損なう、罰則が弱すぎ総当たりになる、強すぎて試行を避ける可能性がある。ペナルティ数だけでなく誤答後の理解を観察する。

## 出典と未確認

1. **公式・開発元担当者の記事**: [PlayStation Blog](https://blog.playstation.com/archive/2019/04/08/phoenix-wright-ace-attorney-trilogys-new-features-detailed-ahead-of-tomorrows-ps4-release)、Capcom担当者、2019-04-08、節「5. Point your way to victory」。Press、証言の再読を説明するPS4版紹介。
2. **コミュニティ攻略**: [Wikibooks: Turnabout Sisters / Day 3 - Trial](https://en.wikibooks.org/wiki/Phoenix_Wright:_Ace_Attorney/Episode_2:_Turnabout_Sisters/Day_3_-_Trial)、2021-07-14、節「Witness's Account: Cross-examination」「She Ran to the 'Left': Cross-examination」。StrategyWiki由来。手順、K地点、視点解釈。
3. **別版のコミュニティ攻略**: [GameFAQs: Phoenix Wright: Ace Attorney (DS) Guide](https://gamefaqs.gamespot.com/ds/925589-phoenix-wright-ace-attorney/faqs/41606)、TIDQ、2005年DS版、節「3.1 In Court: Pressing / Presenting」。Pressとstrikeの補足。本作Steam版の罰則保証には使わない。
4. **観察**: [Steam取得フレーム記録](../frames/787480.json)と6静止画。時刻・ハッシュは記録内。編集カットを連続操作と見なしていない。

**未確認**: Steam Trilogyの入力・罰則数、Press後のヒント文、誤答後の反応、台詞履歴の有無。公式記事の読み返し案内も現行版で照合していない。
