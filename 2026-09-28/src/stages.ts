/** Public identity of a shift; GameState.stage is its internal section (0..3). */
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
  requiredPrompts: number;
  areaLabels: Partial<Record<DistrictArea, string>>;
  captions: Partial<Record<DistrictArea, string>>;
  rests: Record<'midpoint' | 'beforeBoss', { title: string; detail: string; action: string }>;
  vista: { title: string; detail: string };
};

export const STAGE_DEFINITIONS: Readonly<Record<StageId, StageDefinition>> = {
  shopping: {
    id:'shopping', number:1, title:'午前零時の商店街', subtitle:'雨の表通りから、店の奥へ。',
    routes:[
      {id:'service',label:'搬入口',detail:'裏手の搬入路を抜ける'},
      {id:'store',label:'店内',detail:'閉店した店の中を抜ける'},
    ],
    bossName:'居残り店長', requiredPrompts:43,
    areaLabels:{market:'表通り',alley:'裏路地',service:'搬入口',store:'食料品店',court:'荷捌き広場',roof:'屋上'},
    captions:{market:'明かりの残る通りを、奥へ。',alley:'店の裏で、足音が重なった。',service:'配管の下に、抜け道がある。',store:'棚の向こうから、誰かが来る。',court:'空が開けた。広場へ出よう。',roof:'階段の先に、朝の気配。'},
    rests:{
      midpoint:{title:'広場へ出た。',detail:'ここからは、一語で三体。準備ができたら進もう。',action:'一掃を始める'},
      beforeBoss:{title:'最後に、店長が残っている。',detail:'この先を片づければ、屋上への道が開く。',action:'店長に立ち向かう'},
    },
    vista:{title:'夜明けまで、生き延びた。',detail:'商店街の勤務を終えて、帰ろう。'},
  },
  station: {
    id:'station', number:2, title:'終電後の黒猫駅', subtitle:'改札の向こうで、終電が待っている。',
    routes:[
      {id:'maintenance',label:'保守通路',detail:'駅の保守通路を抜ける'},
      {id:'waiting',label:'待合室',detail:'無人の待合室を抜ける'},
    ],
    bossName:'終電の駅長', requiredPrompts:43,
    areaLabels:{forecourt:'駅前',concourse:'改札',maintenance:'保守通路',waiting:'待合通路',platform:'無人ホーム',dawn:'始発の気配'},
    captions:{forecourt:'改札の明かりだけが残っている。',concourse:'誰もいない改札を、奥へ。',maintenance:'作業灯を頼りに、ホームへ。',waiting:'ガラスの向こうで、影が動いた。',platform:'止まった列車の横に、人影が並ぶ。',dawn:'線路の先が、少し明るい。'},
    rests:{
      midpoint:{title:'ホームに出た。',detail:'止まった列車の横に、人影が並んでいる。',action:'一掃を始める'},
      beforeBoss:{title:'終電の駅長が待っている。',detail:'始発の前に、この勤務を終わらせよう。',action:'駅長に立ち向かう'},
    },
    vista:{title:'始発の気配がした。',detail:'誰もいないホームに、朝が戻ってきた。'},
  },
};

export function isStageId(value: unknown): value is StageId {
  return value === 'shopping' || value === 'station';
}
