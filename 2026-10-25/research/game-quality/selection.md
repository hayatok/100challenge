# 調査対象と選定記録

Steam公式のタグ別売上一覧の上位20件から、著名な既発売作品を選んだ。米国ストア・英語表示の取得時点の位置であり、総合売上順位ではない。総合Most Playedは別の指標として併記する。順位は現在も同じとは限らない。

3作品の試行後に11作品を追加し、計14作品とした。最後の2作品は、資源の配分や戦闘の最適化だけに知見が偏ることを避け、人物への感情と推理の比較に使う。

| 作品 | Steamのタグ | 一覧での位置 | 総合Most Played | 取得日時（日本時間） | 調査 |
| --- | --- | --- | --- | --- | --- |
| Stardew Valley | farming-sim | [3位](https://store.steampowered.com/search/?tags=87918&filter=topsellers&category1=998&cc=us&l=english) | 24 | 2026-10-25 20:36:08 | [記録](cases/413150-stardew.md) |
| Slay the Spire | deckbuilding | [7位](https://store.steampowered.com/search/?tags=32322&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/646570-spire.md) |
| ELDEN RING | soulslike | [5位](https://store.steampowered.com/search/?tags=29482&filter=topsellers&category1=998&cc=us&l=english) | 59 | 2026-10-25 20:36:08 | [記録](cases/1245620-elden.md) |
| Balatro | deckbuilding | [5位](https://store.steampowered.com/search/?tags=32322&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/2379780-balatro.md) |
| Hades II | action-roguelike | [20位](https://store.steampowered.com/search/?tags=42804&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/1145350-hades2.md) |
| RimWorld | colony-sim | [1位](https://store.steampowered.com/search/?tags=220585&filter=topsellers&category1=998&cc=us&l=english) | 72 | 2026-10-25 20:36:08 | [記録](cases/294100-rimworld.md) |
| Factorio | automation | [3位](https://store.steampowered.com/search/?tags=255534&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/427520-factorio.md) |
| Oxygen Not Included | colony-sim | [18位](https://store.steampowered.com/search/?tags=220585&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/457140-oxygen.md) |
| Baldur's Gate 3 | story-rich | [17位](https://store.steampowered.com/search/?tags=1742&filter=topsellers&category1=998&cc=us&l=english) | 47 | 2026-10-25 20:36:08 | [記録](cases/1086940-bg3.md) |
| Sid Meier’s Civilization VI | turn-based-strategy | [8位](https://store.steampowered.com/search/?tags=1741&filter=topsellers&category1=998&cc=us&l=english) | 65 | 2026-10-25 20:36:08 | [記録](cases/289070-civ6.md) |
| DAVE THE DIVER | farming-sim | [19位](https://store.steampowered.com/search/?tags=87918&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/1868140-dave.md) |
| Cult of the Lamb | colony-sim | [4位](https://store.steampowered.com/search/?tags=220585&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 20:36:08 | [記録](cases/1313140-cult.md) |
| The Walking Dead: The Telltale Definitive Series | visual-novel | [1位](https://store.steampowered.com/search/?tags=3799&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 21:02:50 | [記録](cases/1449690-walkingdead.md) |
| Phoenix Wright: Ace Attorney Trilogy | visual-novel | [17位](https://store.steampowered.com/search/?tags=3799&filter=topsellers&category1=998&cc=us&l=english) | — | 2026-10-25 21:02:50 | [記録](cases/787480-aceattorney.md) |

「—」は取得した総合100件の一覧に記載がなく、全体での順位は分からないことを示す。総合集計日はAPIのrollup_date、取得日時はretrieved_atに保存している。原本は[selection.json](selection.json)、[rankings.json](rankings.json)、[追加タグの記録](rankings-additional.json)である。

知名度の選定は、既に知られた作品・シリーズを調査責任者が選び、[Steam公式APIの作品情報](catalog.json)で補助的に確認した。今回の14作品ではrecommendations.totalが全件3万を超えている。この値を購入者数や面白さの証明には使わない。

事前の可否確認で読んだPizza Expressは今回の研究対象に含めない。Portal 2とSTEINS;GATEも、今回取得した対応タグの上位20件にはなかったため採用しなかった。
