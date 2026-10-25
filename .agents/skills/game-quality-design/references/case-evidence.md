# 出典付きケース要旨

2026-10-25の14作品の資料調査を要約したもの。Eは資料の記述、Fは提供静止画の観察、Hはそこから作った設計仮説を表す。公式文書、開発者の意図、コミュニティの記述は同じ確度で扱わない。ゲーム本体の操作、人間の試遊、動画の全編視聴は行っていない。以下の仮説は楽しさの因果を実証したものではない。

元の調査ではSteamの米国向けタグ別売上上位から著名作品を選定した。人気は選定条件であり、ルールの良さの証拠ではない。数値や細かな攻略を新作へ移すための資料ではなく、どの関係を試せるかを参照するための要旨である。

## C01 Stardew Valley

- 資料の記述：作物と多様な活動、日々の予定を持つ住民がいる（E01～E03）。コミュニティWikiは、未灌水の日は作物が枯れず成長が止まること、じょうろがエナジーを使うこと、時刻による住民位置の変化、会話の関係値への効果を説明する（E04～E07）。
- 出典：[Steam紹介](https://store.steampowered.com/app/413150/Stardew_Valley/)、[公式1.6更新記録](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/)、Stardew Valley Wikiの[Crops / Grow Times](https://stardewvalleywiki.com/Crops)、[Tools / Proficiency](https://stardewvalleywiki.com/Tools)、[Day Cycle](https://stardewvalleywiki.com/Day_Cycle)、[Friendship / Point system, Decay](https://stardewvalleywiki.com/Friendship)。Wikiは公式サイトから案内されるがコミュニティ編集であり、実機の対象バージョンとの一致は未確認。
- 観察と限界：Steam編集トレーラーの15、30、45、60、75、90秒を観察。30/45秒には畑と作物がある。時計、作業や訪問の前後、予定のUI表示は確認できない。
- 設計仮説H01：仕事を見送る結果と交流機会を理解できれば、本人の目標に沿って一日の配分を選びやすくなる。特定住民への訪問経路や、締切との競合を実際に観察したものではない。

## C02 Slay the Spire

- 資料の記述：カードを加えてデッキを構成する（E01）。開発者は多様な戦略と経路の計画を意図したと語る（E02）。コミュニティWikiは通常のカード報酬で取得かSkipを選べること、戦闘開始時にデッキがドロー山札になることを説明する（E03）。
- 出典：[Steam紹介](https://store.steampowered.com/app/646570/Slay_the_Spire/)、[Game DeveloperのAnthony Giovannettiへの取材](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-mega-crit-games-i-slay-the-spire-i-)、コミュニティWikiの[Card Rewards](https://slay-the-spire.fandom.com/wiki/Card_Rewards)、[Draw Pile](https://slay-the-spire.fandom.com/wiki/Draw_Pile)。Wikiの対象パッチ版は未確認。
- 観察と限界：Steam Launch Trailerの12秒にカード3枚とSkip、24秒に所持金と店の価格を確認。他に36、48、60、72秒を観察した。取得後の山札や実際の引き順は未観察。
- 設計仮説H01：追加の能力と今ある構成を保つ価値を比べられれば、取得が自動的な正解にならない。既存カードの抽選への影響は同じ抽選条件で考える数学的推論であり、すべての取得が構成を弱めるという意味ではない。

## C03 Balatro

- 資料の記述：役とJoker等を組み合わせ、店で構成を変える（E01～E02）。コミュニティWikiは、ラウンド終了時に手持ち$5ごとに$1の利息を得ること、Strengthがカードのランクを上げ、SunがHeartsへ変えることを説明する（E03～E04）。
- 出典：[公式FAQ](https://www.playbalatro.com/faq)、[Steam紹介](https://store.steampowered.com/app/2379780/Balatro/)、Balatro Wikiの[Gameplay rules / Actual Run](https://balatrogame.fandom.com/wiki/Gameplay_rules?oldid=11443)、[Tarot Cards / List of Tarot Cards](https://balatrogame.fandom.com/wiki/Tarot_Cards?oldid=11787)。Wiki本文の改訂はそれぞれ2025-07-08、2026-02-25で、ゲームのパッチ版は不明。利息上限と報酬・利息の厳密な処理順、実機との一致は未確認。同じWikiの別記事であり、独立した複数の裏付けとは数えない。
- 観察と限界：Steam編集映像の19.30秒にStrength、Sun、パック、再抽選の価格が見える。所持金は読めない。30.88秒の得点や所持金を購入後の結果として結べない。他に7.72、13.51、25.09秒を観察。
- 設計仮説H01：現在の構成に効く購入と、現金保持による次ラウンドの利息の両方が分かれば、今の不足を補うか残すかを考えられる。未確認の上限や処理順を前提にせず、常に同額まで貯めることを勧める仮説ではない。

## C04 Factorio

- 資料の記述：ベルトに搬送上限があり、下流の空きがなければ上流へ詰まりが伝わる。長い輸送では、供給不足が下流へ伝わるまで遅れる（E01～E02）。開発者は圧縮のための同じ対処を各所で繰り返す手間を避ける変更を説明した（E03）。
- 出典：コミュニティ編集のOfficial Factorio Wikiの[Transport belts / Physics](https://wiki.factorio.com/Transport_belts/Physics)、[Transport use cases](https://wiki.factorio.com/Tutorial:Transport_use_cases)、開発者の[Friday Facts #231 / Belt compression](https://factorio.com/blog/post/fff-231)。FFFは2018年の0.16当時の経緯。Wikiと対象ビルド、拡張固有の例外は未照合。
- 観察と限界：Steam Gameplay Trailerの28.46、49.80、71.15、92.50、113.84秒を観察。49.80秒に炉UI、71.15秒にベルトと設備の配置が見える。実際の詰まり、流量、改善前後は未観察。
- 設計仮説H01：停止の原因候補を追い、変更後に流れを照合できれば、設備を増やすだけでなく因果を学べる。映像が原因追跡UIの有効性を実証しているわけではない。

## C05 RimWorld

- 資料の記述：人物の欲求や環境が稼働に関わる（E01）。コミュニティWikiでは仕事の優先度と予定を区別し、Workでは一部欲求の充足が後回しになると説明する。Needsは現在値と気分の見込みを区別する（E02～E04）。
- 出典：[Steam紹介](https://store.steampowered.com/app/294100/RimWorld/)、RimWorld Wikiの[Work](https://rimworldwiki.com/wiki/Work)、[Schedule](https://rimworldwiki.com/wiki/Schedule)、[Needs](https://rimworldwiki.com/wiki/Needs)、[Mood](https://rimworldwiki.com/wiki/Mood)。コミュニティ記述で、数値の対象パッチ版は未照合。
- 観察と限界：Steam Launch Trailerの26.66、46.66、66.65、86.65、106.64秒を観察。室内、人物、拠点の例は見えるが、予定・欲求・気分のHUDや変化は見えない。
- 設計仮説H01：仕事を急いだ後の負担と、人物の不調の原因を分けて読めれば、進捗と生活を調整できる。人物を単一の効率値とせず、欲求や出来事を原因として扱う例である。

## C06 Hades II

- 資料の記述：失敗を含む反復と交流がある（E01）。非公式資料は帰還後に準備し、Nectarの初回贈答で通常Keepsakeを得ること、NemesisのEvil Eyeが最後に自分を倒した敵への攻撃を強化することを説明する（E02～E05）。贈り先はNemesisであり、効果対象の敗北相手とは別である。
- 出典：[公式FAQ](https://www.supergiantgames.com/blog/hades2-faq/)、コミュニティWikiの[The Crossroads](https://hades-2.game-vault.net/wiki/The_Crossroads)、[Nectar](https://hades-2.game-vault.net/wiki/Nectar)、[Keepsakes](https://hades-2.game-vault.net/wiki/Keepsakes)、非公式ガイド[Gamepressure](https://www.gamepressure.com/hades-2/tips-and-tricks/za11413)。公式FAQはv1.0発売を説明するが、補助資料の多くはEarly Access期で、v1.0と未照合。倍率は使わない。
- 観察と限界：v1.0 Showcaseの31.96、55.93、79.90、103.87、127.84秒を観察。拠点らしき場所などの別カットで、敗北→贈答→次の挑戦は見えない。
- 設計仮説H01：敗北に合わせて次の準備を変えられれば、再挑戦を選ぶ手掛かりになる。交流全般を戦術的な返礼の取得と見なすものではなく、贈答が解放作業に見える危険も残る。

## C07 Oxygen Not Included

- 資料の記述：酸素・温度・食料が関係する（E01）。コミュニティWikiは、Oxygen Diffuserが藻と電力を使って酸素と熱を出し、局所圧で停止すること、水系への移行には別の設備と資源が必要なことを説明する（E02～E03）。
- 出典：[Steam紹介](https://store.steampowered.com/app/457140/)、Wiki.ggの[Oxygen Diffuser](https://oxygennotincluded.wiki.gg/wiki/Oxygen_Diffuser)、[Guide/Oxygen](https://oxygennotincluded.wiki.gg/wiki/Guide/Oxygen)。Wiki本文をブラウザで確認した記録による。ページ最終編集表示はそれぞれ2026-07-10、2024-09-28。公式仕様書ではない。
- 観察と限界：Steam Early Access 2の12.70、22.22、31.75、41.27、50.80秒を観察。基地と設備は見えるが、酸素・温度・停止理由は読めない。2017年ごろの映像へ現在のWiki数値を当てはめない。
- 設計仮説H01：入力の消費速度、副作用、停止条件を追えれば、今の改善が後の危機を生む理由を調べやすい。ただし一定消費が続く前提の残り時間を確定予報とせず、情報過多も試す。

## C08 DAVE THE DIVER

- 資料の記述：昼の収集が夜の営業へつながり、利益や資源が装備改良へ渡る。酸素切れは獲物を持ち帰る上で不利益になる（E01）。非公式資料は積載と収集の計画、料理に必要な食材の関係を説明する（E02～E03）。
- 出典：[Steam紹介](https://store.steampowered.com/app/1868140/DAVETHEDIVER/?l=english)、非公式の[Beginner Guide](https://davethediver.net/en/guides/newcomer-guide/)、プレイヤーa small rabbitによる[Steamコミュニティガイド](https://steamcommunity.com/sharedfiles/filedetails/?id=2998778318)。後者は2023-07-04掲載。現行版との一致、酸素切れ時の残存品数、食材の具体的な処理は未照合。
- 観察と限界：Steamトレーラーの5、10、25、55、65、80秒を観察。別資料の公式ストア画像1には店のHUDがある。潜水HUD、帰還から調理への連続は未観察。
- 設計仮説H01：持ち帰った物が次の営業で何になるか見通せれば、帰還を収集の中断だけでなく準備として選べる。常に危険や損失を重くすべきとはしない。

## C09 Cult of the Lamb

- 資料の記述：遠征と拠点の生活・信仰がある（E01）。コミュニティWikiは、Ritual Fastが信仰を下げる代わりに3日間空腹を止めること、食事を怠ると飢え・信仰低下・死亡につながること、Kitchenで調理する食事を出発前にキューへ入れることを説明する（E02～E03）。別のデータ整理では3日効果の文字列だけを照合できる（E04）。
- 出典：[Steam紹介](https://store.steampowered.com/app/1313140/Cult_of_the_Lamb/)、コミュニティWikiの[Ritual Fast / Description](https://cult-of-the-lamb.fandom.com/wiki/Ritual_Fast?oldid=17297)、[Followers / Hunger](https://cult-of-the-lamb.fandom.com/wiki/Followers?oldid=28278)。ページ改訂はそれぞれ2025-05-05、2026-09-07で、ゲーム版は不明。非公式Wikiの[Rituals](https://cultofthelamb.wiki/wiki/entry/rituals/)はv1.5.26の3日効果だけを照合し、信仰コストは確認しない。[Buildings & stations](https://cultofthelamb.wiki/wiki/entry/buildings/)のKitchen記述を、E03と独立した裏付けには数えない。実機照合はない。
- 観察と限界：Launch Trailerの5枚は演出カット。公式ストア画像1/4に戦闘と拠点はあるが、空腹・信仰・準備のHUDや結果は読めない。
- 設計仮説H01：出発前の準備が不在中の生活へどう効くか分かれば、拠点状態に応じて準備できる。遠征長の見込みと食事の持続日数は実機未確認で、予告する案は新作への提案である。

## C10 Baldur's Gate 3

- 資料の記述：コミュニティWikiは会話の能力判定と補正、Save Arabellaの救出経路、共有Inspirationによる対象判定の振り直しを説明する（E02～E04）。資料が示す将来の結果を、プレイヤーが事前に知る情報とは扱わない。
- 出典：[Larian公式紹介](https://baldursgate3.game/)、BG3 Wikiの[Ability Check](https://bg3.wiki/wiki/Ability_Check)、[Save Arabella](https://bg3.wiki/wiki/Save_Arabella)、[Inspiration](https://bg3.wiki/wiki/Inspiration)。具体的な判定や分岐は非公式の現行記述に依存し、本体・対象パッチとの完全一致は未確認。
- 観察と限界：Steam Launch Trailerの21.04、36.82、52.60、68.38、84.16秒に判定UIはない。別の公開ゲーム画像にDC、d20、補正、操作案内は見えるが、Arabellaの場面や判定結果ではない。
- 設計仮説H01：選ぶ台詞の意図、判定に使える手段、結果後の人物の反応がつながれば、自分の主人公像に沿った関与になりうる。好感度や生存結果だけを正解にせず、失敗を受け入れる遊び方も強制しない。

## C11 Sid Meier's Civilization VI

- 資料の記述：都市の生産枠、建設変更後の進捗保留、配置レンズの見込み、地形による隣接ボーナス、地区から建物への接続が説明される（公式マニュアル、調査時E02）。
- 出典：[公式英語マニュアルPDF](https://steamcdn-a.akamaihd.net/steam/apps/289070/manuals/CIV_VI_25TH_ONLINE_MANUAL_ENG.pdf?t=1590082071)、PDF p.94～99のCity Screen、Production Menu、Construction、Districts。2016年初期版由来の資料で、拡張や現行数値の保証には使わない。
- 観察と限界：公式ストア画像2には都市と建物の完成までのターン数、画像3には都市・山岳・河川がある。配置レンズや建設後の成果は未観察。
- 設計仮説H01：配置の効果と生産中に見送るものが分かれば、一手を都市の長期目標へ結びつけやすい。特定タイルが常に最良という仮説ではない。

## C12 ELDEN RING

- 資料の記述：所持ルーンと死亡地点の手掛かりを表示し、死亡時に落としたルーンは回収できるが、回収前の再死亡で失う。祝福の休息は回復と敵の大半の復活を伴う（E01～E04）。
- 出典：Bandai Namcoの[Starter Guide](https://en.bandainamcoent.eu/elden-ring/news/elden-ring-starter-guide-tips-know-playing-the-game)、Game Interface、Site of Grace、Death、Stakes of Marika。発売前ガイドで、現行版の全例外を説明するものではない。
- 観察と限界：Steam編集トレーラーの15、30、45、60、75、90秒と、[公式Gameplay Preview](https://www.youtube.com/watch?v=JldMvQMO_5U)の2:39/7:27を観察。死亡・回収・再死亡・休息の前後は見えない。
- 設計仮説H01：失敗後に回収という目標が残り、危険や準備を変えられれば、再挑戦を自分で組み立てられる。長い往復や過大な損失を全ジャンルへ要求するものではない。

## C13 The Walking Dead: The Telltale Definitive Series

- 資料の記述：初代シーズン第1話のDoug/Carley救出では、片方を選ぶともう片方を失うと攻略は記す（E03）。制作者は選択比率の偏りを振り返り、危機前に人物を知り関係を作る機会の差を指摘したと報じられる（E02）。
- 出典：[Steam紹介](https://store.steampowered.com/app/1449690/The_Walking_Dead_The_Telltale_Definitive_Series/)、[Game InformerのGDCパネル報告](https://gameinformer.com/b/news/archive/2013/03/28/telltale-why-fewer-people-saved-doug-in-the-walking-dead)、[GDC公式セッション紹介](https://gdcvault.com/play/1017807/Saving-Doug-Empathy-Character-and)、[GameFAQsのChapter 7攻略](https://gamefaqs.gamespot.com/ps4/786050-the-walking-dead-a-telltale-games-series-the-complete-first/faqs/64439)。講演映像は未視聴。報告は2013年、攻略は別収録版由来で、Definitive版の実機照合はない。
- 観察と限界：Steamトレーラーの6.64、11.62、16.60、21.58、26.56秒を観察。選択UIや救出場面の連続は映らない。
- 設計仮説H01：決断前に相手固有の振る舞いや関わりがあり、決断後にもその関係に応じた反応があれば、人物として関与しやすくなる。出番や選択比率の均等化を品質目標にしない。

## C14 Phoenix Wright: Ace Attorney Trilogy

- 資料の記述：Capcom担当者はPressで説明が加わること、証言を読み直せることを説明する。第2話3日目の攻略では、左右の証言を位置・向きと図で照合し、解釈を改める。誤提示の罰は別版攻略による補足で、Steam版の回数は未確認。
- 出典：Capcom担当者による[PlayStation Blog / 2019-04-08、節5](https://blog.playstation.com/archive/2019/04/08/phoenix-wright-ace-attorney-trilogys-new-features-detailed-ahead-of-tomorrows-ps4-release)、[Wikibooks / Turnabout Sisters, Day 3](https://en.wikibooks.org/wiki/Phoenix_Wright:_Ace_Attorney/Episode_2:_Turnabout_Sisters/Day_3_-_Trial)、TIDQの[GameFAQs DS版攻略 / 3.1 In Court](https://gamefaqs.gamespot.com/ds/925589-phoenix-wright-ace-attorney/faqs/41606)。具体手順は非公式資料で、2005年DS版の罰則を2019年Steam版の保証にしない。
- 観察と限界：Steam編集トレーラーの38、44、50、65、80、90秒を観察。台詞枠、証拠品、Testimonyは見えるが、該当場面のPress→Present→図の操作は未観察。
- 設計仮説：同じ正答へ進んでも、語句と証拠の関係を解釈し直し、自分で説明できる過程は評価できる。誤答の種類を短く返す案は本作で観察した仕様ではなく、新しい推理試作への提案である。
