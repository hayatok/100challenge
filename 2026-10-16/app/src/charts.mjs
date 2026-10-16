export function createCharts({ statisticsNode, timelineNode, tooltipNode, onYear, data }) {
  const d3 = globalThis.d3;
  if (!d3) throw new Error('Chart library unavailable');
  let current = null;
  let previous = null;
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const format = n => n.toLocaleString('ja-JP', { maximumFractionDigits: 2 });
  const text = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function drawStatistics() {
    if (!current) return;
    const {state, view, visible} = current;
    const m = view.metric;
    const width = statisticsNode.parentElement.clientWidth;
    if (width < 150) return;
    const height = 282, left = 64, right = width - 16, top = 34, bottom = height - 48;
    const svg = d3.select(statisticsNode).attr('viewBox', `0 0 ${width} ${height}`).attr('height', height);
    svg.selectAll('*').remove();
    svg.append('title').text(`${state.year}年・${m.title}`);
    svg.append('desc').text(`${m.unit}。${view.scopeNote} ${view.status} 年を動かすには「見る年」の入力も使えます。`);
    const points = m.series.flatMap(s => s.points);
    const domainX = d3.extent([...points.map(p => p.year), state.year]);
    const extentY = d3.extent([0, ...points.map(p => p.value / m.divisor)]);
    const x = d3.scaleLinear().domain(domainX).range([left + 6, right - 6]);
    const y = d3.scaleLinear().domain([extentY[0], extentY[1] * 1.08]).nice().range([bottom - 6, top + 6]);
    svg.append('rect').attr('class', 'chart-frame').attr('data-chart-frame', '').attr('x', left).attr('y', top).attr('width', right-left).attr('height', bottom-top);
    svg.append('text').attr('data-axis','y').attr('x',left).attr('y',17).text(m.unit);
    svg.append('text').attr('data-axis','x').attr('x',(left+right)/2).attr('y',height-4).attr('text-anchor','middle').text('暦年（年）');
    const interior = width < 400 ? [Math.round((domainX[0]+domainX[1])/2)] : x.ticks(4);
    const ticks = [domainX[0], ...interior.filter(v => v>domainX[0] && v<domainX[1] && x(v)-x(domainX[0])>50 && x(domainX[1])-x(v)>50), domainX[1]];
    svg.append('g').attr('class','chart-axis').attr('transform',`translate(0,${bottom})`).call(d3.axisBottom(x).tickValues(ticks).tickFormat(d3.format('d')).tickSizeOuter(0)).selectAll('.tick text').attr('text-anchor',v=>v===domainX[0]?'start':v===domainX[1]?'end':'middle');
    svg.append('g').attr('class','chart-axis').attr('transform',`translate(${left},0)`).call(d3.axisLeft(y).ticks(4).tickSizeOuter(0));
    const clipId = 'history-statistics-clip';
    svg.append('defs').append('clipPath').attr('id',clipId).append('rect').attr('x',left).attr('y',top).attr('width',right-left).attr('height',bottom-top);
    const plot = svg.append('g').attr('clip-path',`url(#${clipId})`);
    if (state.metric === 'vital') {
      plot.append('rect').attr('class','chart-gap').attr('x',x(1943.5)).attr('y',top+1).attr('width',x(1946.5)-x(1943.5)).attr('height',bottom-top-2);
      [1947,1973].forEach(year=>plot.append('line').attr('class','chart-break').attr('x1',x(year)).attr('x2',x(year)).attr('y1',top).attr('y2',bottom));
    }
    m.series.forEach((series,index)=>{
      if (!visible[index]) return;
      if (state.metric !== 'vital') plot.append('path').datum(series.points).attr('class',`series-line ${index?'secondary':'primary'}`).attr('d',d3.line().x(p=>x(p.year)).y(p=>y(p.value/m.divisor)));
      const group = plot.append('g').attr('data-stat-series',series.code);
      if (!index) group.selectAll('circle').data(series.points).join('circle').attr('class','chart-primary').attr('cx',p=>x(p.year)).attr('cy',p=>y(p.value/m.divisor)).attr('r',p=>p.year===state.year?4.4:2.5).attr('data-observation-year',p=>p.year);
      else group.selectAll('rect').data(series.points).join('rect').attr('class','chart-secondary').attr('x',p=>x(p.year)-(p.year===state.year?4:2.4)).attr('y',p=>y(p.value/m.divisor)-(p.year===state.year?4:2.4)).attr('width',p=>p.year===state.year?8:4.8).attr('height',p=>p.year===state.year?8:4.8).attr('data-observation-year',p=>p.year);
    });
    if (!m.series.some((_,i)=>visible[i])) {
      svg.append('text').attr('x',(left+right)/2).attr('y',top+76).attr('text-anchor','middle').text('上の項目を押すと、');
      svg.append('text').attr('x',(left+right)/2).attr('y',top+98).attr('text-anchor','middle').text('グラフが見られます。');
    }
    const cursor = plot.append('line').attr('class','chart-current').attr('y1',top).attr('y2',bottom);
    const animate = previous?.metric===state.metric && previous.year!==state.year && previous.year>=domainX[0] && previous.year<=domainX[1] && !reducedMotion.matches;
    cursor.attr('x1',x(animate?previous.year:state.year)).attr('x2',x(animate?previous.year:state.year));
    if (animate) cursor.transition().duration(160).attr('x1',x(state.year)).attr('x2',x(state.year));
    previous = {...state};
    const guide = plot.append('line').attr('class','chart-hover').attr('data-chart-hover-guide','').attr('y1',top).attr('y2',bottom).attr('visibility','hidden');
    const marks = plot.append('g');
    const hit = svg.append('rect').attr('data-chart-hit','').attr('x',left).attr('y',top).attr('width',right-left).attr('height',bottom-top).attr('fill','transparent').style('cursor','crosshair');
    const hoveredYear = event=>Math.max(1900,Math.min(2026,Math.round(x.invert(d3.pointer(event,statisticsNode)[0]))));
    tooltipNode.hidden = true;
    hit.on('pointermove',event=>{
      if (event.pointerType==='touch') return;
      const year = hoveredYear(event);
      guide.attr('x1',x(year)).attr('x2',x(year)).attr('visibility','visible');
      const found = m.series.map((s,index)=>({s,index,p:s.points.find(p=>p.year===year)})).filter(r=>visible[r.index]&&r.p);
      marks.selectAll('*').remove();
      found.forEach(r=>marks.append('circle').attr('class',`chart-highlight chart-${r.index?'secondary':'primary'}`).attr('cx',x(year)).attr('cy',y(r.p.value/m.divisor)).attr('r',4.5));
      tooltipNode.innerHTML = `<strong>${year}年</strong><br>${found.map(r=>`${text(r.s.label)} ${format(r.p.value/m.divisor)} ${text(m.unit)}`).join('<br>') || '表示できる数値がありません。'}`;
      tooltipNode.hidden=false;
      tooltipNode.style.top='24px';
      tooltipNode.style.left=`${Math.max(0,Math.min(width-tooltipNode.offsetWidth,x(year)+9))}px`;
    }).on('pointerleave',()=>{tooltipNode.hidden=true;guide.attr('visibility','hidden');marks.selectAll('*').remove();}).on('click',event=>onYear(hoveredYear(event)));
  }

  function drawTimeline() {
    if (!current) return;
    const {state} = current;
    const width = timelineNode.parentElement.clientWidth;
    if (width < 150) return;
    const left=64,right=width-14,height=98;
    const svg=d3.select(timelineNode).attr('viewBox',`0 0 ${width} ${height}`).attr('height',height);
    svg.selectAll('*').remove();
    svg.append('title').text('出来事と暮らしの記録のある年');
    svg.append('desc').text(`1900〜2026年。朱色の実線は読む年${state.year}年、点線は生まれ年${state.birthYear}年。年のスライダーからも移動できます。`);
    const x=d3.scaleLinear().domain([1900,2026]).range([left+4,right-4]);
    const eventYears=[...new Set(data.events.flatMap(e=>{const start=Number(String(e.date_start).slice(0,4));return e.date_precision==='range'&&e.date_end!==null?d3.range(start,Number(String(e.date_end).slice(0,4))+1):[start];}))];
    const lifeYears=[...new Set(data.living.filter(r=>r.start!==null&&r.end!==null).flatMap(r=>{const a=Number(String(r.start).slice(0,4)),b=Number(String(r.end).slice(0,4));return d3.range(a,b+1);}))];
    [['出来事',eventYears,24,'timeline-event'],['暮らし',lifeYears,50,'timeline-life']].forEach(([label,years,y,klass])=>{
      svg.append('text').attr('x',0).attr('y',y+4).text(label);
      svg.append('line').attr('class','timeline-rule').attr('x1',left).attr('x2',right).attr('y1',y).attr('y2',y);
      svg.append('g').selectAll('circle').data(years).join('circle').attr('class',klass).attr('cx',d=>x(d)).attr('cy',y).attr('r',width<400?2.2:3).attr('data-record-year',d=>d);
    });
    svg.append('line').attr('class','timeline-birth').attr('x1',x(state.birthYear)).attr('x2',x(state.birthYear)).attr('y1',7).attr('y2',62);
    svg.append('line').attr('class','timeline-current').attr('x1',x(state.year)).attr('x2',x(state.year)).attr('y1',7).attr('y2',62);
    const ticks = width<480 ? [1900,1960,2026] : [1900,1920,1940,1960,1980,2000,2026];
    ticks.forEach(year=>svg.append('text').attr('x',x(year)).attr('y',86).attr('text-anchor',year===1900?'start':year===2026?'end':'middle').text(year));
    svg.append('rect').attr('data-timeline-hit','').attr('x',left).attr('y',0).attr('width',right-left).attr('height',65).attr('fill','transparent').style('cursor','crosshair').on('click',event=>onYear(Math.max(1900,Math.min(2026,Math.round(x.invert(d3.pointer(event,timelineNode)[0]))))));
  }

  const observer = new ResizeObserver(()=>{drawStatistics();drawTimeline();});
  observer.observe(statisticsNode.parentElement);
  observer.observe(timelineNode.parentElement);
  return {
    render(state,view,visible){current={state:{...state},view,visible:[...visible]};drawStatistics();drawTimeline();},
    destroy(){observer.disconnect();d3.select(statisticsNode).selectAll('*').remove();d3.select(timelineNode).selectAll('*').remove();},
  };
}
