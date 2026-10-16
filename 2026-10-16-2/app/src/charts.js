import { escapeHTML as esc } from './storage.js';
import { observationTime, readableResearchText, recordNotes } from './presentation.js';

const COLORS = ['#ad4938', '#376b72', '#667a44', '#866647', '#676ca0', '#986780'];
const fmt = new Intl.NumberFormat('ja-JP', { maximumFractionDigits: 3 });
const compact = new Intl.NumberFormat('ja-JP', { notation: 'compact', maximumFractionDigits: 1 });
const bindings = new WeakMap();
export const CHART_RANGES = Object.freeze([[1900,2026,'全期間'],[1900,1945,'1900–1945'],[1945,1975,'1945–1975'],[1975,2000,'1975–2000'],[2000,2026,'2000–現在']]);
const unitLabel = unit => /未取得|未確認|未確定/.test(unit || '') ? '単位の文字列は未確認' : unit || '単位は原表を参照';
export const cleanSeriesLabel = label => readableResearchText(label).replace(/\b[A-Z]\d{4,}_/g,'').replace(/\b\d{4}\s+(?=総合|食料)/g,'').replace(/\s*\/\s*観測値/g,'');
export const chartTime = p => observationTime(p)===null?null:observationTime(p)/12;
const timeOf=chartTime;
const isDated = p => Number.isInteger(p.year) && p.year >= 1900 && p.year <= 2026;
const isNumber = p => p.kind === 'number' && Number.isFinite(p.value);
const within = (p,t) => isDated(p) && timeOf(p) >= (t.from ?? 1900) && timeOf(p) <= (t.through ?? 2026.999);

export function statisticCatalogue(archive) {
  const stats = new Map(archive.statistics.map(s=>[s.id,s]));
  return archive.series.map(entry=>{
    const dated=entry.points.filter(isDated), numeric=dated.filter(isNumber), stat=stats.get(entry.statId);
    return {id:entry.id, entry, stat, label:cleanSeriesLabel(entry.label), title:stat?.title || entry.label,
      start:dated.length?Math.min(...dated.map(p=>p.year)):null,end:dated.length?Math.max(...dated.map(p=>p.year)):null,
      numericCount:numeric.length,search:`${stat?.title} ${entry.label} ${entry.geography} ${entry.unit}`.toLocaleLowerCase('ja')};
  });
}

export function presetTracks(archive, drivers, id) {
  const byId=new Map(archive.series.map(e=>[e.id,e]));
  const driver=drivers.drivers.find(d=>d.id===id);
  if(!driver) { const e=byId.get(id); return e?[{entry:e,label:cleanSeriesLabel(e.label),from:1900,through:2026.999}]:[]; }
  if(driver.segments?.length) return driver.segments.flatMap(s=>{
    const sid=s.seriesIds[0], entry=byId.get(sid); if(!entry)return [];
    const from=Number(s.from.slice(0,4))+(Number(s.from.slice(5,7))-1)/12;
    const through=Number(s.through.slice(0,4))+(Number(s.through.slice(5,7)))/12-1e-5;
    return [{entry,label:s.label || cleanSeriesLabel(entry.label),from,through,limitation:s.limitation,boundaries:driver.boundaries}];
  });
  return driver.seriesIds.slice(0,1).map(sid=>({entry:byId.get(sid),label:driver.label,from:1900,through:2026.999,boundaries:driver.boundaries})).filter(t=>t.entry);
}

export function observationsAt(tracks, year) {
  return tracks.flatMap(track=>track.entry.points.filter(p=>within(p,track)&&p.year===year).map(point=>({point,track})));
}
export function nearestObservation(tracks, time, {range=[1900,2026],unit=null,yRatio=null}={}) {
  let nearest=null, distance=Infinity;
  const candidates=tracks.filter(t=>unit===null||t.entry.unit===unit).flatMap(track=>track.entry.points.filter(p=>within(p,track)&&p.year>=range[0]&&p.year<=range[1]).map(point=>({point,track})));
  const values=candidates.filter(({point})=>isNumber(point)).map(({point})=>point.value),rawMax=values.length?Math.max(...values):1,max=rawMax===0?1:rawMax,min=Math.min(...values,0);
  for(const {point,track} of candidates) {
    const dx=(timeOf(point)-time)/Math.max(1,range[1]-range[0]+.9),dy=yRatio===null||!isNumber(point)?0:(1-(point.value-min)/(max-min||1)-yRatio);
    const d=yRatio===null?Math.abs(dx):dx*dx+dy*dy*.18;if(d<distance){nearest={point,track};distance=d;}
  }
  return nearest;
}
export function chartData(tracks, range=[1900,2026]) {
  const units=[...new Set(tracks.map(t=>t.entry.unit))];
  const panels=units.map(unit=>{
    const segments=tracks.filter(t=>t.entry.unit===unit).map(track=>{
      const points=track.entry.points.filter(p=>within(p,track)&&p.year>=range[0]&&p.year<=range[1]).sort((a,b)=>timeOf(a)-timeOf(b));
      const paths=[]; let path=[];
      for(const p of points) {
        const previous=path.at(-1), boundary=previous&&(track.boundaries||[]).some(b=>b.year>previous.year&&b.year<=p.year);
        // Separate scope changes, missing symbols and unobserved years. Never fill them.
        if(!isNumber(p)||boundary||(previous&&timeOf(p)-timeOf(previous)>1.01)){if(path.length)paths.push(path);path=[];}
        if(isNumber(p))path.push(p);
      }
      if(path.length)paths.push(path);
      return {...track,points,paths};
    });
    const values=segments.flatMap(s=>s.points.filter(isNumber).map(p=>p.value));
    const min=values.length?Math.min(...values):0,max=values.length?Math.max(...values):1;
    return {unit,segments,min:Math.min(0,min),max:max===0?1:max};
  });
  return {range,panels};
}

function chartMarkup(tracks,range,year) {
  const model=chartData(tracks,range), left=74, right=950, top=28, bottom=225;
  const x=t=>left+(t-range[0])/(Math.max(1,range[1]-range[0]+.9))*(right-left);
  const ticks=[...new Set([range[0],...Array.from({length:14},(_,i)=>1900+i*10).filter(y=>y>range[0]&&y<range[1]),range[1]])];
  const seriesIds=[...new Set(tracks.map(t=>t.entry.id))];
  return model.panels.map(panel=>{
    const y=v=>bottom-(v-panel.min)/(panel.max-panel.min||1)*(bottom-top);
    const points=panel.segments.flatMap(s=>s.points.filter(isNumber));
    return `<div class="chart-panel"><div class="chart-unit">${esc(unitLabel(panel.unit))}${model.panels.length>1?' ／ 単位が異なる記録は別の目盛りです':''}</div><svg class="interactive-chart" data-chart-surface="true" data-chart-unit="${esc(panel.unit||'')}" viewBox="0 0 980 272" role="img" aria-label="${range[0]}年から${range[1]}年の原観測。下の年の操作でも数字を読めます。">${Array.from({length:5},(_,i)=>{
      const v=panel.min+(panel.max-panel.min)*i/4;return `<line x1="${left}" x2="${right}" y1="${y(v)}" y2="${y(v)}" class="chart-grid"/><text x="${left-12}" y="${y(v)+4}" text-anchor="end" class="chart-axis">${esc(compact.format(v))}</text>`;
    }).join('')}${ticks.map(t=>`<text x="${x(t)}" y="251" text-anchor="middle" class="chart-axis">${t}</text>`).join('')}${panel.segments.map(segment=>{
      const color=COLORS[seriesIds.indexOf(segment.entry.id)%COLORS.length];
      const bandLeft=x(segment.from??1900),bandRight=x(Math.min(range[1]+.9,segment.through??2026.9));
      return `${segment.from>range[0]&&segment.from<range[1]?`<line x1="${bandLeft}" x2="${bandLeft}" y1="${top}" y2="${bottom}" class="chart-boundary"/>`:''}${segment.paths.filter(p=>p.length>1).map(path=>`<path d="${path.map((p,i)=>`${i?'L':'M'}${x(timeOf(p)).toFixed(2)},${y(p.value).toFixed(2)}`).join(' ')}" fill="none" stroke="${color}" stroke-width="2" opacity=".78"/>`).join('')}${segment.points.filter(isNumber).map(p=>`<circle cx="${x(timeOf(p)).toFixed(2)}" cy="${y(p.value).toFixed(2)}" r="${p.year===year?4.3:2.8}" fill="${color}" stroke="var(--ui-surface)" stroke-width=".7"><title>${esc(p.timeLabel||p.time_label)}：${esc(p.raw)} ${esc(unitLabel(p.unit||segment.entry.unit))}</title></circle>`).join('')}`;
    }).join('')}${!points.length?`<text x="510" y="128" text-anchor="middle" class="chart-empty">この期間の原観測はありません。期間や記録を選び直せます。</text>`:''}<line class="chart-cursor" x1="${x(year)}" x2="${x(year)}" y1="${top}" y2="${bottom}"/><rect x="${left}" y="${top}" width="${right-left}" height="${bottom-top}" fill="transparent" class="chart-hit"/></svg></div>`;
  }).join('')+`<div class="chart-legend">${seriesIds.map((id,i)=>{const related=tracks.filter(t=>t.entry.id===id),t=related[0],dates=related.flatMap(track=>track.entry.points.filter(p=>within(p,track))).map(p=>p.year);return `<span><i data-series-color="${COLORS[i%COLORS.length]}"></i>${esc(cleanSeriesLabel(t.entry.label))}${dates.length?` ／ ${Math.min(...dates)}–${Math.max(...dates)}`:''}</span>`;}).join('')}</div>`;
}

export function mountChart(root,tracks,{year=1900,onYear=()=>{},onSeries=()=>{},range=[1900,2026]}={}) {
  bindings.get(root)?.abort();
  const controller=new AbortController();bindings.set(root,controller);const signal=controller.signal;
  let selectedYear=year, chosen=null, dragStart=null;
  root.innerHTML=`<div class="chart-ranges" aria-label="グラフの表示期間">${CHART_RANGES.map(([a,b,label])=>`<button type="button" data-range="${a},${b}" aria-pressed="${a===range[0]&&b===range[1]}">${label}</button>`).join('')}</div><div class="chart-drawing"></div><div class="chart-controls"><label>グラフの年 <input type="range" class="chart-year" min="1900" max="2026" value="${year}" step="1"></label><output class="chart-selected-year">${year}年</output><button type="button" class="chart-visit">この年の町へ ↗</button></div><div class="chart-readout" aria-live="polite"></div><p class="chart-caption">点に触れて原値を読む。クリックでその年の町へ。ドラッグで期間を拡大。空白は収録した数字がない期間です。</p>`;
  const drawing=root.querySelector('.chart-drawing'),readout=root.querySelector('.chart-readout'),slider=root.querySelector('.chart-year');
  drawing.before(readout);
  function show(records,requestedYear) {
    selectedYear=requestedYear;slider.value=requestedYear;
    root.querySelector('.chart-selected-year').textContent=`${requestedYear}年`;
    root.querySelectorAll('.chart-cursor').forEach(line=>{const pos=74+(requestedYear-range[0])/Math.max(1,range[1]-range[0]+.9)*876;line.setAttribute('x1',pos);line.setAttribute('x2',pos);line.style.display=requestedYear>=range[0]&&requestedYear<=range[1]?'':'none';});
    if(!records.length){readout.innerHTML=`<strong>${requestedYear}年の原観測はありません</strong><span>数字を補わず空白として残しています。点を選ぶと収録された年の原値を読めます。</span>`;chosen=null;return;}
    chosen=records[0];
    readout.innerHTML=records.slice(0,5).map(({point,track})=>`<article><div><span class="small">${esc(point.timeLabel||point.time_label||`${point.year}年`)} ／ ${esc(track.label)}</span><strong>${isNumber(point)?esc(fmt.format(point.value)):esc(point.raw||'記録なし')} <small>${esc(unitLabel(point.unit||track.entry.unit))}</small></strong></div><p>${esc(readableResearchText(track.limitation||track.entry.geography||''))}${!isNumber(point)?' 原表の欠測記号です。0ではありません。':''}</p><button type="button" data-chart-series="${esc(track.entry.id)}">原表・対象・出典 ↗</button></article>`).join('')+(records.length>5?`<span class="small">この年には${records.length}件あります。すべては原表から確認できます。</span>`:'');
  }
  function draw() {drawing.innerHTML=chartMarkup(tracks,range,selectedYear);drawing.querySelectorAll('[data-series-color]').forEach(i=>i.style.setProperty('--series-color',i.dataset.seriesColor));show(observationsAt(tracks,selectedYear),selectedYear);root.querySelectorAll('[data-range]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.range===range.join(','))));}
  function coordinates(e) {const p=e.currentTarget.createSVGPoint();p.x=e.clientX;p.y=e.clientY;const v=p.matrixTransform(e.currentTarget.getScreenCTM().inverse());return {time:range[0]+Math.max(0,Math.min(1,(v.x-74)/876))*(range[1]-range[0]+.9),yRatio:(v.y-28)/197};}
  function timeFromEvent(e) {return coordinates(e).time;}
  function foundFromEvent(e) {const {time,yRatio}=coordinates(e);return nearestObservation(tracks,time,{range,unit:e.currentTarget.dataset.chartUnit||null,yRatio});}
  function showFound(found){const others=observationsAt(tracks,found.point.year).filter(item=>item.point.id!==found.point.id);show([found,...others],found.point.year);}
  function bindSurfaces() {drawing.querySelectorAll('[data-chart-surface]').forEach(surface=>{
    surface.addEventListener('pointermove',e=>{if(dragStart!==null)return;const found=foundFromEvent(e);if(found)showFound(found);});
    surface.addEventListener('pointerdown',e=>{dragStart=timeFromEvent(e);surface.setPointerCapture(e.pointerId);});
    surface.addEventListener('pointerup',e=>{if(dragStart===null)return;const end=timeFromEvent(e),start=dragStart;dragStart=null;if(Math.abs(start-end)>3){range=[Math.max(1900,Math.floor(Math.min(start,end))),Math.min(2026,Math.ceil(Math.max(start,end)))];draw();bindSurfaces();}else{const found=foundFromEvent(e);if(found){showFound(found);onYear(found.point.year);}}});
    surface.addEventListener('pointercancel',()=>{dragStart=null;});
  });}
  root.addEventListener('click',e=>{const b=e.target.closest('button');if(!b)return;
    if(b.dataset.range){range=b.dataset.range.split(',').map(Number);draw();bindSurfaces();}
    if(b.dataset.chartSeries)onSeries(b.dataset.chartSeries);
    if(b.classList.contains('chart-visit'))onYear(selectedYear);
  },{signal});
  slider.addEventListener('input',()=>show(observationsAt(tracks,Number(slider.value)),Number(slider.value)));
  draw();bindSurfaces();
  return {syncYear(next){year=next;show(observationsAt(tracks,next),next);}, selected(){return {year:selectedYear,chosen,range:[...range]};}};
}

export function createStatisticsExplorer(root,archive,drivers,{year=1900,onYear,onSeries}={}) {
  const catalogue=statisticCatalogue(archive),byId=new Map(catalogue.map(e=>[e.id,e]));
  let active='population',comparison='',chart;
  const presets=[['population','人口'],['SD-STAT001:cat01=00110','出生'],['SD-STAT001:cat01=00150','死亡'],['industry','仕事'],['education','学び'],['rice','食'],['prices','物価'],['housing','住まい'],['communication','通信'],['rail','鉄道']];
  root.innerHTML=`<div class="explorer-heading"><div><p class="eyebrow">一世紀の数字を、自分の手で。</p><h2>日本の変化をたどる</h2></div><p>${archive.statistics.length}表・${catalogue.length}区分・${fmt.format(archive.series.reduce((n,s)=>n+s.points.length,0))}観測</p></div><div class="chart-presets" aria-label="気になる数字">${presets.map(([id,label])=>`<button type="button" data-preset="${esc(id)}" aria-pressed="${id===active}">${label}</button>`).join('')}</div><div class="series-finder"><label>記録を探す<input type="search" class="series-search" placeholder="例：1920、沖縄、婚姻、小学校、家賃"></label><label>すべての記録から選ぶ<select class="explorer-series" aria-label="グラフにする記録"></select></label></div><details class="comparison-picker"><summary>もう一つの記録と見比べる</summary><label>比べる記録<select class="explorer-comparison" aria-label="比べる記録"></select></label><p>異なる単位は別の目盛りで表示します。対象や分類が異なる数字を、同じ集団の増減としては比べられません。</p></details><p class="series-description"></p><div class="explorer-chart"></div><details class="chart-qualifications"><summary>数字を比べるときの注意</summary><div></div></details>`;
  const selector=root.querySelector('.explorer-series'),description=root.querySelector('.series-description');
  function options(query='') {
    const words=query.normalize('NFKC').toLocaleLowerCase('ja').split(/\s+/).filter(Boolean);
    const matches=catalogue.filter(e=>words.every(word=>e.search.normalize('NFKC').includes(word)||(/^\d{4}$/.test(word)&&e.entry.points.some(p=>p.year===Number(word)))));
    const groups=new Map();for(const e of matches){if(!groups.has(e.stat.id))groups.set(e.stat.id,[]);groups.get(e.stat.id).push(e);}
    const markup=[...groups.values()].map(es=>`<optgroup label="${esc(es[0].title)}">${es.map(e=>`<option value="${esc(e.id)}">${esc(e.label)}${e.start!==null?` ／ ${e.start}–${e.end}`:' ／ 年代の確認が残る記録'}</option>`).join('')}</optgroup>`).join('');
    selector.innerHTML=`<option value="">${matches.length}区分から選ぶ</option>`+markup;
    root.querySelector('.explorer-comparison').innerHTML='<option value="">見比べない</option>'+markup;
    if(byId.has(active))selector.value=active;root.querySelector('.explorer-comparison').value=comparison;
  }
  function select(id) {
    let tracks=presetTracks(archive,drivers,id);if(!tracks.length)return;
    if(comparison&&!tracks.some(t=>t.entry.id===comparison))tracks.push(...presetTracks(archive,drivers,comparison));
    active=id;const driver=drivers.drivers.find(d=>d.id===id),entry=byId.get(id),stat=entry?.stat;
    root.querySelectorAll('[data-preset]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.preset===id)));
    if(entry)selector.value=id;else selector.value='';
    description.textContent=driver?`${driver.label}の記録。対象や分類が変わる境目で分けて表示しています。`: `${stat?.title || ''} ／ ${entry?.label || ''}`;
    root.querySelector('.chart-qualifications>div').innerHTML=driver?`<p>${esc(readableResearchText(driver.limitation||''))}</p><ul>${(driver.boundaries||[]).map(b=>`<li>${b.year}年：${esc(readableResearchText(b.reason))}</li>`).join('')}</ul>`:`<p>${esc(readableResearchText(stat?.population_definition||stat?.acquisition_scope||''))}</p>${[...recordNotes(stat?.comparability_breaks),...recordNotes(stat?.missing_periods),...(entry?.entry.notes||[])].map(note=>`<p>${esc(readableResearchText(note))}</p>`).join('')}`;
    chart=mountChart(root.querySelector('.explorer-chart'),tracks,{year,onYear,onSeries});
  }
  root.querySelector('.series-search').addEventListener('input',e=>options(e.target.value.trim()));
  selector.addEventListener('change',()=>{if(selector.value)select(selector.value);});
  root.querySelector('.explorer-comparison').addEventListener('change',e=>{comparison=e.target.value;select(active);});
  root.querySelector('.chart-presets').addEventListener('click',e=>{const b=e.target.closest('[data-preset]');if(b)select(b.dataset.preset);});
  options();select(active);
  return {select,syncYear(next){year=next;chart?.syncYear(next);}};
}
