# v0.13 実装契約

2026-09-30 / Astra。設計意図は [V13_DESIGN.md](V13_DESIGN.md)、完了条件は [V13_ACCEPTANCE.md](V13_ACCEPTANCE.md)。実装担当が解釈を変える場合は、主担当と調整し本契約も更新する。

## 担当と編集境界

| 担当 | 所有ファイル | 成果 |
|---|---|---|
| Sol A: 進行 | `src/stages.ts`（新規）、`src/game.ts`、`src/rail.ts`、`src/storage.ts`、進行/rail/storage/resultsのテスト | 面定義、43文、休息、チェックポイント、面別保存、経路 |
| Sol B: 環境 | `src/district.ts`、`src/station.ts`（新規）、`src/atmosphere.ts`、必要な環境テスト | 商店街の表通り延長、独立した立体駅、雨/反射/環境切替 |
| Luna: 日本語 | `src/stage-content.ts`（新規）のみ | 本契約の出題プール。既存content.tsは変更しない |
| 主担当: 統合 | `src/main.ts`、`src/scene.ts`、CSS、`src/audio.ts`、`src/results.ts`/`goals.ts`の必要な文言、README/記録/公開管理 | 面選択、進捗、休息UI、背景切替、実ブラウザ検証 |
| Astra | この3文書のみ | 設計/契約/受入基準 |

同じファイルを同時編集しない。Sol AはLunaファイルが未完成なら契約の型を前提にimportを書き、コピーした仮出題をgame.tsへ埋め込まない。Sol Bはscene.tsに手を入れず、主担当へ接続箇所を報告する。

## 公開型とデータ

`src/stages.ts` に以下を定義する。既存 `GameState.stage` は **内部区間0..3** のまま。画面のStage 1/2とは別。

```ts
export type StageId = 'shopping' | 'station';
export type JourneyRoute = 'store' | 'service' | 'waiting' | 'maintenance';
export type DistrictArea =
  | 'market' | 'alley' | 'store' | 'service' | 'court' | 'roof'
  | 'forecourt' | 'concourse' | 'waiting' | 'maintenance' | 'platform' | 'dawn';
export type NormalEnemyKind = 'runner' | 'office' | 'worker';
export type StageDefinition = {
  id: StageId;
  number: 1 | 2;
  title: string;
  subtitle: string;
  routes: readonly [
    { id: JourneyRoute; label: string; detail: string },
    { id: JourneyRoute; label: string; detail: string }
  ];
  bossName: string;
  requiredPrompts: number; // 43
  areaLabels: Partial<Record<DistrictArea, string>>;
  captions: Partial<Record<DistrictArea, string>>;
  rests: Record<'midpoint' | 'beforeBoss', { title: string; detail: string; action: string }>;
  vista: { title: string; detail: string };
};
export const STAGE_DEFINITIONS: Readonly<Record<StageId, StageDefinition>>;
export function isStageId(value: unknown): value is StageId;
```

固定値: shopping = `午前零時の商店街`、routes順はservice→store（1/2キーの既存順維持）、bossName=`居残り店長`。station = `終電後の黒猫駅`、routes順はmaintenance→waiting、bossName=`終電の駅長`。この順はUI・キー・テストで共有する。

`rail.ts`/`district.ts`にある別々のDistrictArea宣言は削除し、stages.tsの型をimport/re-exportする。型の唯一の定義元をstages.tsにする。ステージ定義モジュールはThree.jsやDOMをimportしない。

`GameOptions` に `stageId?: StageId` を追加し省略時shopping。`journey:false`の従来エンジンは保持する。無効なstageIdはconstructorでreject。`Game` に `readonly stageId: StageId`、`GameState`/`GameResults`に `stageId: StageId` を追加する。`GameResults`のstageIdは保存時に必ず転記する。

`GameState.journey` は次に拡張する。

```ts
journey?: {
  route: JourneyRoute | null;
  wave: number;
  travelProgress: number;
  area: DistrictArea;
  completedPrompts: number; // 通常34 + rush4 + boss5の解決数。Lucky/巻込を除く
  totalPrompts: number;     // 43
  rest: 'midpoint' | 'beforeBoss' | null;
};
```

`completedPrompts` は撃破だけでなく通常の敵が攻撃して去った場合も1解決として進む。ただしBoss失敗は再出題されるので成功時だけ進む。FEVER失敗は中央1文だけ解決。Lucky/左右support/複数の視覚killは加算しない。Boss中央カウンター3文は個別に加算。UIは「撃破数」でなく「区間進行 12 / 43文」と表示する。リトライ時はチェックポイント値に巻き戻る。

`chooseRoute(route: JourneyRoute): boolean` は選択中の面に属するrouteだけ受理。`restart()` はstageId/difficulty/practice/seedを維持しrouteはnullに戻す。

`GameMode` に `rest` を追加し、`continueRest(): boolean` を公開する。後述の2箇所だけで使用。休止/resume/countdownはrestにも対応。敵ゼロ、打鍵は採点しない。Enterはmain.tsがcontinueRestへ渡す。連打はfalseで副作用なし。

## 出題モジュール: LunaとSol Aの境界

`src/stage-content.ts` は以下だけをexportする。`Phrase` は既存content.tsの型をimport type、型はstages.tsからimport type。`parse()`はローカル関数でよい。読みを `new TypingSession(reading)` へ通して不正文字を早期発見する。

```ts
export type StagePhraseSet = {
  areas: Partial<Record<DistrictArea,
    Record<NormalEnemyKind, readonly Phrase[]>>>;
  rush: readonly Phrase[];
  boss: readonly Phrase[];    // 12件。phase0用0..3、phase2用8..11
  counters: readonly Phrase[]; // 6件以上。phase1で3件
  lucky: readonly (readonly Phrase[])[]; // 3組、各3文
};
export const STAGE_PHRASES: Readonly<Record<StageId, StagePhraseSet>>;
```

shoppingに必要なareasはmarket/alley/store/service/court、stationはforecourt/concourse/waiting/maintenance/platform。各area×roleは8件以上、合計最低240通常文。全roleを各areaにそろえるため少し多いが、組合せの欠損・同時初期キー衝突を単純に防げる。表示文/読みは同面の通常文で重複させない。各poolに少なくとも6種類の初期キー集合を持たせ、`し`のs/cや`ち`のt/cなど複数許容キーの交差も考慮する。汎用命令ばかりにせず、その場の物/仕事/異変を短く言う。

文字数は読みの字数でなく `TypingSession.standardLength`。runner 6..14、office 12..24、worker 18..34、rush 7..14、boss 14..36、counter 10..20、lucky 10..20。通常文の平均は16..20キー付近。全体の実出題列は560..900キー、中央値650キー以上を目標に測定し、時間不足なら文を具体化する。制限時間を延ばして尺を稼がない。

Sol AはstageId→area→roleのpoolから選択する。候補順はseedで安定させ、使った文をまず避け、同時敵の許容初期キーが重なる候補を避ける。retry用usedに面の文を識別できる安定IDを入れる（配列順+面offset等で十分）。同seed/同面/同route/同難度で同順。Boss/rush/LuckyもSTAGE_PHRASESを参照。旧content.tsの303件+関連文はlegacy用として保持。

## 波・区間の固定構成

記号 O=office、R=runner、W=worker。同時3体を上限とする。

| 内部stage | 場所 | 波（各[]が1波） | 必須文 |
|---|---|---|---:|
| 0前半 | shopping market / station forecourt | [O], [R], [O,R], [W,O] | 6 |
| 0後半 | shopping alley / station concourse | [O], [R], [O,R], [W,O] | 6 |
| 1:店内/待合 | store / waiting | [W,O], [R,O], [W,R], [O,R], [W,O], [R,O] | 12 |
| 1:搬入/保守 | service / maintenance | [R,O], [R,O], [O,W], [R,O], [R,W], [O,R] | 12 |
| 2開始 | court / platform | 既存FEVER4群、中央1文+support2体 | 4 |
| 2通常 | court / platform | [O,R], [W,O], [R,W], [R,O,W], [O] | 10 |
| 3 | courtのboss stop / platformのboss stop | 既存phase0の1文→counter3文→phase2の1文 | 5 |
| 合計 | 両面・両route同じ | Luckyは別枠 | 43 |

Luckyは **stage1の最後の通常波を完了した後**。seed条件は既存の偶数seed、practiceでは必ず1回。成功なら3文追加で46。完了/見逃し後にmidpointへ進む。通常得点/正確率/入力速度に混ぜない。報酬は既存500点と上限3まで1回復。

通常deadlineは既存の累積作業量方式を維持（面全体の長さを理由に速度を上げない）。service/maintenanceは1.45、それ以外は1.6のwork係数を使える。新しい敵/武器/体力/自動回復/解除条件は追加しない。

## 休息とcheckpoint

1. stage1最終波とLuckyが解決→stage2へ進め、checkpointを保存→court/platformへ安全な移動→`rest='midpoint'`。Enter/ボタンでFEVER開始。体力とスコアを見直す、空間を眺める時間。自動制限時間なし。
2. stage2通常10文が解決→stage3へ進め、checkpoint保存→boss stopへ2秒移動→`rest='beforeBoss'`。Enter/ボタンでBoss開始。
3. Boss完了→従来のvistaへ。shoppingは屋上、stationはホーム端の夜明け。Enterで精算。vistaとrestの待機はclearTime/battleTimeに加算しない。

checkpointは内部stage 0/1/2/3の開始。初期stage0は新しい開始area=market/forecourtでwave0、stage1は選択route、stage2は休息後FEVERから、stage3はBoss前休息からやり直す。区間内の最大巻戻しは12文。stage0途中のarea切替をやり直す際、必ず初期areaへ戻す。

checkpointには既存値に加えて completedPrompts と再開位置を含める。失敗区間のscore/correct/mistakes/time/used/rush/chain/Lucky状態をすべて戻す。体力3・combo0・effects0は従来仕様。stage1内でLuckyまで進めば直後にcheckpoint確定するので、後のretryでLuckyを再出現/再加算しない。stage2 retryはFEVERを再演するがスコアとchainも巻戻すため二重報酬にならない。全再挑戦は新しい1勤務なのでLucky1回の機会を持つ。

## 経路・敵原点

worldは右手系。yaw=0は-Z向き、yaw=-π/2は+X向き。床は全戦闘stopでy=0、目線y=1.65。敵は現在の**到着済みstop**を原点に `local(x,0,-distance)` をyaw回転して置く。scene.tsの現在の方式を継承し、移動中に敵をspawnしない。新駅に戦闘用の高低差を入れない。これで既存の倒れ/影/ラッキー床のy=0固定を壊さない。

| 面 | stop/area | camera (x,y,z,yaw) | 敵の中央出現点 (通常7.8m) |
|---|---|---|---|
| shopping | entrance（選択画面） | (0,1.65,22,0) | 敵なし |
| shopping | market | (0,1.65,14,0) | (0,0,6.2) |
| shopping | alley | (0,1.65,0,0) | (0,0,-7.8) |
| shopping | store | (10,1.65,-12,-π/2) | (15.1,0,-12), close=5.1 |
| shopping | service | (-6,1.65,-16,0) | (-6,0,-23.8) |
| shopping | court | (24,1.65,-32,0) | (24,0,-39.8) |
| shopping | boss | (24,1.65,-36,0) | (24,0,-43.2), boss=7.2 |
| shopping | roof | (24,8.65,-50,0) | 敵なし |
| station | entrance | (100,1.65,18,0) | 敵なし |
| station | forecourt | (100,1.65,10,0) | (100,0,2.2) |
| station | concourse | (100,1.65,-6,0) | (100,0,-13.8) |
| station | waiting | (112,1.65,-18,0) | (112,0,-23.1), close=5.1 |
| station | maintenance | (88,1.65,-18,0) | (88,0,-23.1), close=5.1 |
| station | platform | (100,1.65,-36,0) | (100,0,-43.8) |
| station | boss | (100,1.65,-48,0) | (100,0,-55.2), boss=7.2 |
| station | dawn | (100,1.65,-61,-.45) | 敵なし |

駅と商店街は異なるrootで、選択面だけvisible。駅rootはworld座標100近辺。rootにさらに100のoffsetを二重加算しない。

遷移のwaypoint、秒数:

- entrance→first: 2秒。first→second（stage0 wave4時）: 3秒。直線。market→alleyで新しい立体表通りを通過。
- alley→store/service: 現行3.8秒と中間点を維持。
- store/service→court: 現行4秒と中間点を維持。移動後midpoint休息。
- concourse→waiting: (100,1.65,-12,0)→(112,1.65,-12,-.35)→waiting、3.8秒。
- concourse→maintenance: (100,1.65,-12,0)→(88,1.65,-12,.35)→maintenance、3.8秒。
- waiting→platform: (112,1.65,-28,0)→(100,1.65,-28,.35)→platform、4秒。
- maintenance→platform: (88,1.65,-28,0)→(100,1.65,-28,-.35)→platform、4秒。
- court/platform→boss: 2秒直線。stationの12m移動は最大6m/sの短い移動として許容、低モーションではbob/rollなし。
- shopping boss→roof: 現行5秒/waypointを維持。
- station boss→dawn: 3秒直線。vista中の演出時計で移動し、戦闘時計を進めない。

`RailDirector.reset(stageId: StageId = 'shopping')` で選択面のentranceへ戻す。`update` はstate.stageIdが変わったらresetし、sceneが前フレームの別面座標を使わない。areaの遷移キーにstageIdを含める。stage===3のboss keyを維持する。休息では到着済み位置を保持、通常波間のtravelで経路を繰返さない。

移動進捗はGameのtravelProgressを唯一の時計にする。render dtがcapされてもcombat開始時にstopへ必ず到着。pause/countdown中は同値。屋上/夜明けのvista移動だけ従来どおり演出時計。区間retry後は正しい開始stopへsnapしてからspawnを描く（逆再生の壁抜けを見せない）。

全waypoint間の線分を中心とする半径0.65m、高さy=0.2..2.7mを空ける。戦闘は通常local x=±3.6m、z=-1..-8.4m、室内はx=±2.6m、z=-1..-5.7mを背の高いpropから空ける。lane最大±1.3m+入場横ずれがあるため、棚の端へ敵を重ねない。室内はsceneのentry offsetを1.2mへ統一。看板は上端だけでなく下端がy>=2.8m。

## 環境とsceneの接続

`District`に `setStage(stageId: StageId): void` を追加。他のupdate/strike/reset/disposeは互換維持。`createDistrict(scene)` は商店街と駅を構築し、setStageでactive rootを切替。updateは現在areaに適した背景/fog/4灯を更新する。未選択面の灯が照らさない。setStageはasyncにしない。初期ロードで両方準備し、開始時の連打でload競合を作らない。station.ts内部の生成関数はSol Bが決めてよい。外部公開はDistrict経由だけ。

`StreetAtmosphere.update(dt,area,view,motion)` のsignatureを維持。駅では反射面中心をview.x側へ移し、ホームの線路上まで同一の濡れ床を広げない。屋内concourse/waiting/maintenanceには降雨を出さない。platformは庇の外だけ雨、最低限は雨OFFでよい。低モーションは雨/点滅/カメラbob/roll/強い反動を抑え、移動の終点とゲーム時間は同じ。

主担当のscene.ts:

- 既存引数を保持して `world.reset(checkpointStage = 0, stageId: StageId = 'shopping')` に拡張しrail.reset(stageId)、environment.setStage(stageId)へ接続。追加 `world.setStage(stageId: StageId)` は選択面を保持し、背景とrailを切替える。titleの2枚の勤務票でsetStage、開始はreset(0,id)、checkpoint retryはreset(game.state.stage,id)。state=nullのupdateは保持した選択面のentranceを使い、shoppingへ勝手に戻さない。state変更検知によるsetStageは冪等。
- close判定はstore/waiting/maintenance。key/fill/ambientの屋内判定も同じ＋concourse。roof/dawnの空と眺望を対応。
- 敵/銃/衣装/既存postprocessを維持。新しいmaterial typeや全面shader再構成は不要。
- court限定のstrikeは駅platformでも呼べるが、駅に破壊物を作らないならfalseでよい。ボーナスや進行条件にしない。
- scene.tsの影、死体着地、Lucky床y=0固定は戦闘床全箇所y=0の契約で保持。

主担当のaudio.ts/main.ts: 既存の `setSceneMood(explore|combat|fever|vista)` を再利用。restはexploreまたはvistaの弱い床音、station屋内は雨成分を下げる。新録音/ダウンロード不要。area文字列に依存した商店街専用のナレーションはSTAGE_DEFINITIONSとareaラベルへ変更。`stage===3`はBoss判定として残してよい。面番号にはstageId→definition.numberを使う。

## 保存と互換

`RESULT_RULES_VERSION=7`。保存キー`nightshift-typing:v1`、設定、直近10件上限、旧personalBestsは保持。`SavedResult.stageId?: StageId` と `route?: JourneyRoute` を追加する（旧行にないためoptional）。新規journey結果には両方保存。

v7の有効resultKeyは `7:shopping:normal:standard` のように `rulesVersion:stageId:difficulty:practice/standard`。v6以前でstageIdが無いものは従来keyを保つ。旧行を新しいshopping43文のスコアへ混ぜない。v7でstageId不正/欠損の読み込みは履歴として保持してもよいが、`7:legacy:...` 隔離keyとしcurrent best/replayに使わない。古いv6以下の種をv7の「同じ出題」として再生しない。

同じ出題再挑戦に必要なのは seed + stageId + route + difficulty + practice + rulesVersion。結果からのreplayは現行versionと有効面/route/seedがそろった場合だけ可能にする。replay時はrouteを自動選択して同じ列へ進む、通常の「もう一度」はroute選択を戻してよい。UI上の説明を区別する。routeが不正/他面のrouteならreplayしない。共有のpractice/normal設定は維持し、面ごとに不要な設定複製を作らない。

`resultKey`を使う `previousComparable`/`compareResults`/best見出しの全呼出しでstageIdが欠落しないか確認する。Stage1/2の得点の多寡をランキング比較しない。routeは同文数/近い文字負荷のためbestキーには含めず、結果で表示する。
