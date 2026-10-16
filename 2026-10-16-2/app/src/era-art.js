// Art direction, not observations, reconstruction, or a prevalence estimate.
// These authored silhouettes make a fictional town's era readable at a glance.
const ERAS = [
  {from:1900,id:'wood',label:'木の町と、手の仕事',roof:'#666c64',roofLight:'#909386',wall:'#ddc49c',side:'#b49b75',road:'#cdb991',trim:'#644b3c',floors:1,transport:'cart',rail:'steam',sign:'米・雑貨',skyline:'roofs'},
  {from:1920,id:'brick',label:'瓦屋根と、洋風の店',roof:'#49656b',roofLight:'#789090',wall:'#e5d4af',side:'#bfab85',road:'#c9c0a5',trim:'#814b3f',floors:2,transport:'tram',rail:'steam',sign:'商店',skyline:'brick'},
  {from:1940,id:'lowwood',label:'低い軒と、小さな商い',roof:'#817463',roofLight:'#a5987b',wall:'#cbb58c',side:'#a48c68',road:'#c8b799',trim:'#76634b',floors:1,transport:'bicycle',rail:'dark',sign:'日用品',skyline:'lowwood'},
  {from:1955,id:'concrete',label:'団地と、広がる道路',roof:'#738e8e',roofLight:'#a1b4a9',wall:'#eee3bd',side:'#c6c5ad',road:'#929b92',trim:'#497c83',floors:3,transport:'sedan',rail:'local',sign:'マーケット',skyline:'housing'},
  {from:1978,id:'neon',label:'看板の街と、四角いビル',roof:'#717f8e',roofLight:'#a6b1b6',wall:'#f0d6bb',side:'#b4aea2',road:'#7e8c88',trim:'#b95946',floors:4,transport:'sedan',rail:'express',sign:'スーパー',skyline:'towers'},
  {from:1998,id:'glass',label:'ガラスの駅前と、身近な店',roof:'#587c85',roofLight:'#83a6ab',wall:'#e7e8d7',side:'#b8c8bd',road:'#829490',trim:'#548b7b',floors:3,transport:'compact',rail:'silver',sign:'コンビニ',skyline:'glass'},
  {from:2018,id:'green',label:'屋上の緑と、いまの暮らし',roof:'#4c6e78',roofLight:'#8eabae',wall:'#e8e6d5',side:'#b2c5b7',road:'#8b9d96',trim:'#427c64',floors:3,transport:'electric',rail:'silver',sign:'まちの店',skyline:'green'},
];
export const ERA_PROFILES=Object.freeze(ERAS.map(p=>Object.freeze(p)));
export function eraProfile(year=1900){return ERA_PROFILES.findLast(p=>Number(year)>=p.from)||ERA_PROFILES[0];}
export function buildingArt(year,seed=0,kind='house',placeId='kanto'){
  const era=eraProfile(year), urban=['kanto','kinki','tokai'].includes(placeId);
  const tall=kind==='house'&&era.from>=1955&&seed>(urban?.58:.78);
  return {era:era.id,form:kind==='shop'?(era.from>=1998?'retail':era.from>=1978?'signshop':era.from>=1920&&era.from<1940?'brickshop':'woodshop'):tall?(era.from>=1998&&seed>.72?'glass':era.from>=1978?'tower':'danchi'):era.from>=1955?'suburban':era.from>=1920&&era.from<1940&&seed>.65?'brick':'wood',floors:tall?era.floors+(seed>.8?1:0):1,solar:era.id==='green'&&seed>.45,balcony:tall||era.id==='neon',roof:placeId==='okinawa'?'#b66c50':placeId==='hokkaido'?'#7b8f8d':era.roof};
}
export function dailyLight(hour=10){const h=((Number(hour)||0)%24+24)%24;return {hour:h,night:h<5.5||h>=19.5,dusk:h>=17&&h<19.5,dawn:h>=5.5&&h<7,phase:h<5.5||h>=19.5?'夜':h<7?'朝':h<12?'午前':h<17?'午後':h<19.5?'夕方':'夜'};}
