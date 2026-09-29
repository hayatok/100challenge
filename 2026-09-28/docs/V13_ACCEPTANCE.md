# v0.13 受入基準

2026-09-30 / Astra。以下は実施予定のチェックであり、実施済みの記録ではない。実際のコマンド・結果・画面は `docs/RESULTS.md` に追記する。仕様の正は [V13_CONTRACTS.md](V13_CONTRACTS.md)。

## 自動検証: Sol A

現行npm run check（test/lint/型/build）を通す。legacyのjourney:falseのテストは保つ。現在journey.test.ts/rail.test.tsにある2波でstage1へ進む前提、17文、area=alley開始、seen.size=8、短文上限は新しい43文の仕様に更新する。assertを削除して通すのではなく、以下へ置き換える。

1. 両面×両route×seed0..31の練習通しでvistaへ到達、通常34文、FEVER4中央文、Boss5文、任意Lucky3文、completedPrompts=43、chainKills=8、rushes=1、敵なし、まだresultなし。continueVista後にclearを一度だけ発行。種列はseed0/1/12/0xffffffffも含め、無限ループguardを付ける。
2. practice=falseの偶数seedはLucky1、奇数seedはLucky0。practice=trueは奇数seedでもLucky1。Lucky誤打/timeoutで通常のhealth/combo/correct/mistakesが変わらず、完走で500点と最大1回復。左右supportを直接狙えず、中央失敗のdamageは1だけ。supportの表示文/キーは空。
3. 正確な43/46文はenemy id数やkillイベント総数で数えない。Luckyは同idの3ステップ、Boss counterも成功ごと、supportは別idなので、成功したtyping sessionを記録して検証する。
4. 同面/同seed/同routeの全出題列が一致。同seedでもstationの文はshoppingへ漏れない。新しいseedは少なくとも一部の文を変える。各同時波の全 `enemy.keys` に重複がない。標準入力をTypingSessionへ最後まで通せる。表記揺れの既存typingテストを保持。
5. 全poolの読み/表示非空、語長範囲、通常文の重複なし、各area/roleの最低8件。通し列の必須標準キー合計を記録し、seed0..31×両routeで各面中央値650以上を目指す。最小560を下回る、または最大900を大幅超過したら文の配分を見直す。時間計算はキー数/KPM+固定移動時間を別々に出す。休息・Lucky・誤打・読解を混ぜた架空の実測値を書かない。
6. stage0のarea切替前/後、stage1/2/3それぞれで通常敗北を発生させる。retry後のstageId/route/area/wave/score/used/progress/正確率/時間/chain/rush/Lucky状態がcheckpointに一致。stage0後半で負けてもmarket/forecourtから6文+6文をやり直す。attemptsだけ増え、health3、combo/effect0。
7. Lucky後のstage2/3でretryしてもLuckyは再出現しない。FEVERを途中まで成功してから敗北/retryして、失敗試行のscore/chain/入力が加算されたままにならない。再度clearした最終状態でLucky<=1、bonus<=500、rushes=1、chain<=8、progress43。
8. midpoint/rest・beforeBoss/rest・vistaを100秒放置してもhealth/score/progress/battleTime/clearTimeを増やさない。continueRestを2度呼んでも二重spawnなし。pause/resume/countdownはrestへ正しく戻る。travel中のキーで敵や進行を飛ばせない。Enterは通常打鍵として採点しない。
9. 面に属さないrouteをchooseRouteしてfalse、constructor無効面/seedはreject。restartはstageId/seed/difficulty/practice保持、route未選択。result replayは正しいrouteまで復元し同出題列。普通の再出勤はrouteを選び直せる。
10. v6以前のsave/settings/history/bestを読み込み、旧keyと旧記録を保持。v7の面別・難度別・練習別bestが分離。旧版またはstageId/route/seed不正のresultに「同じ出題」ボタンを出さない。v7欠損stageIdの履歴がshoppingのbestへ混ざらない。previousComparableも面をまたがない。履歴10件から落ちても面別bestが残る。

## 日本語の照合（統合時の発見を反映）

語長とparse成功だけで完了にしない。全表示文を読みと一対一で照合し、漢字語の読み抜け・短文化による意味の欠落を確認する。長すぎる場合は表示文も短くし、読みだけを省略しない。実環境は食品店であり、衣料品店の試着室や服の棚を前提にしない。各areaの物・業務と出題を照合する。

## 経路と空間の検証

railは両面×全routeの各stopへの到着、pause/countdownで不動、render delta cap時のcombat到着、同areaの波間で移動再発しないことをテストする。stageId変更とreset直後に前面のstopが残らない。タイトルstate=nullでも選択面のentranceを保持。retryの波とカメラstopを同期。

固定経路の線分/stopに対して、壁/柱/ゲート/棚の大きな箱の位置を確認する。できれば環境担当が大きなsolidのAABBを小さな配列として保持し、経路tubeとの交差をテストする。テスト用に全シーンの一般衝突エンジンを導入する必要はない。数値確認だけで視点の安全性を完了扱いにせず、移動途中のスクリーンショットで開口部を確認する。

特に見る交差点はshopping market→alley、alley→store/service、store奥からcourt、service→court、station concourse→左右、左右→platform、platform→Boss。既存storeの棚や天井をcamera通過のため削って品質を下げない。

## 実ブラウザの完走: 主担当

本物のUIからStage選択→勤務開始→go→route→43文→休息Enter×2→vista→精算まで通す。DevTools内でstateを差し替えて撮った画面は完走の証拠にしない。実キー/キーイベントによる操作自動化は使えるが、人間のプレイスキルや自然な所要時間の証拠とは区別する。

必須の4周:

| 面 | route | 設定 | 主に見ること |
|---|---|---|---|
| shopping | store | 練習・低モーション | v12店内の維持、棚/衣装/銃、文の長さ、Lucky、屋上 |
| shopping | service | 通常モーション、可能なら通常難度 | 既存壁/移動、deadline、3体、FEVERとBoss |
| station | waiting | 練習・低モーション | 改札/ガラス/ベンチ/ホーム/車両、雨が屋内に落ちない |
| station | maintenance | 通常モーション、可能なら通常難度 | 別ルート景色、角で壁抜けなし、照明、Boss→夜明け |

通常モードを完走できなければ練習へ切り替えて残りの経路を検証し、通常難度の完走を未確認と明記する。設定の保存値を試験前に控え、最後に戻す。テスト結果が実ユーザーの通常bestを汚さないよう練習のrecordを基本にする。

各周回で実際に確認すること:

- 休止→再開後、途中の文章の入力が残る。フォーカス喪失/IME警告の既存挙動を保持。
- restで銃が落ち着き、敵/攻撃がなく、明確なEnterボタンと次の行先がある。戻ってきたとき急に攻撃されない。
- 新しい面名・Boss名・route・area・caption・結果票が一致。「駅なのに店長/屋上/時計台」の旧文言が残らない。
- 最大演出/3体/Luckyでも頭上文、狙い、HUDに文字欠け・重なりなし。長いworker文が画面端で切れない。
- 低モーションでrain/flicker/大きな揺れを抑え、移動先と出題順が通常と変わらない。
- FEVER4群の実shotgun切替、終了後拳銃に戻りBoss3段階を完了。supportに別文が出ない。
- 音を聴ける場合は休息/戦闘の音量差、pause、Lucky終了、FEVER→Bossの切替を聴取。聴けなければ「audioコード経路確認のみ、実聴取なし」と記録する。
- browser consoleに新規error/未処理rejection/404なし。面切替で暗転したまま、灯の累積、前面の建築の混入なし。

## 画面証拠

主対象1280×720または1440×900。最低限1024×768と375×812でもtitle/設定/休息/結果の操作不能や横溢れがないことを確認。375pxはPC専用案内が読めればよく、スマホタイピング対応を追加しない。

`art/verification/v13-*.png` に以下を保存:

- title-shopping / title-station: 2面が選べて背景が変わる。
- shopping-market / shopping-store / shopping-service / shopping-rest / shopping-boss / shopping-roof / shopping-result。
- station-concourse / station-waiting / station-maintenance / station-platform / station-fever / station-boss / station-dawn / station-result。
- 移動の中間点2枚以上、最大3体/長文を含む1枚、狭幅title/result各1枚。

1枚で複数条件を満たしてよい。生成画像/設計イメージは実ゲーム証拠へ混ぜない。ファイル数を満たすだけで良しとせず、画面を開いて頭上文、構図、開口部、床、車両の側面厚みを目視する。

## 統合の停止条件と報告

未実装の面をタイトルで選べるまま完了にしない。駅の背景が床と箱だけ、カメラが壁を通る、文がキー衝突で選べない、43文に到達しない、retryでrewardが増える場合は修正してから完了を報告する。build成功だけで「遊びやすい」「3〜5分遊べる」「駅完成」と言わない。

主担当は変更ファイル・自動検証・実画面で通過した4route・標準キー数と計算時間・実聴取/物理IMEの実施範囲・残る制約を簡潔に報告する。公開/PR/Actionsの権限と実施は主担当がユーザーの依頼範囲に従って判断し、この設計文書を追加承認の根拠にしない。
