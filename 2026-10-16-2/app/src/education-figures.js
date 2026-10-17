const INK = '#173746';
const VERMILION = '#B54832';
const PAPER = '#F5F1E8';
const TEAL = '#4C807B';
const BRASS = '#B28A4B';
const numberFormat = new Intl.NumberFormat('ja-JP', { maximumSignificantDigits: 21 });
const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const isNumber = value => typeof value === 'number' && Number.isFinite(value);
const numberText = value => isNumber(value) ? numberFormat.format(value) : '—';
const yearText = value => /^\d{4}$/.test(String(value)) ? `${value}年` : String(value ?? '');

// These motifs identify the subject. Their count and size encode no quantity.
function motif(kind, color) {
  const outline = `fill="${PAPER}" stroke="${INK}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"`;
  const art = {
    people: `<circle cx="155" cy="50" r="16" fill="${color}"/><path d="M130 116V91Q130 72 155 72Q180 72 180 91V116M144 92V119M167 92V119" fill="none" stroke="${INK}" stroke-width="3"/><path d="M187 90Q207 83 215 96V115H187Z" fill="${BRASS}"/><circle cx="200" cy="73" r="11" fill="${PAPER}" stroke="${INK}" stroke-width="2"/>`,
    rice: `<path d="M126 93H234Q229 125 180 127Q131 125 126 93Z" ${outline}/><path d="M135 92Q142 69 157 78Q168 60 180 75Q196 65 207 80Q219 77 225 92Z" fill="${color}"/><path d="M144 102H217M159 115H202" stroke="${INK}" stroke-width="1.5"/><path d="M206 49L241 30M207 56L243 38" stroke="${BRASS}" stroke-width="3" stroke-linecap="round"/><path d="M166 45Q159 53 167 62M184 39Q177 47 185 56" fill="none" stroke="${INK}" stroke-width="1.5"/>`,
    phones: `<rect x="151" y="29" width="58" height="100" rx="9" ${outline}/><rect x="158" y="44" width="44" height="63" rx="2" fill="${color}"/><path d="M171 37H189" stroke="${INK}" stroke-width="2" stroke-linecap="round"/><circle cx="180" cy="118" r="3.5" fill="${BRASS}"/><path d="M169 91L178 80L185 84L194 67" fill="none" stroke="${PAPER}" stroke-width="2.5"/>`,
    computers: `<rect x="124" y="31" width="112" height="74" rx="4" ${outline}/><rect x="131" y="38" width="98" height="55" rx="1" fill="${color}"/><path d="M144 78V51H181M151 56H174M151 64H169" fill="none" stroke="${PAPER}" stroke-width="2"/><circle cx="180" cy="99" r="2" fill="${INK}"/><path d="M172 105V113H159M188 105V113H201" fill="none" stroke="${INK}" stroke-width="2"/><path d="M123 117H237L247 130H113Z" ${outline}/><path d="M128 122H232M130 126H154M160 126H200M206 126H230M141 120V126M155 120V126M169 120V123M183 120V123M197 120V123M211 120V126M225 120V126" fill="none" stroke="${INK}" stroke-width="1"/>`,
    books: `<path d="M180 48Q151 35 125 48V115Q151 102 180 115Q209 102 235 115V48Q209 35 180 48Z" ${outline}/><path d="M180 49V115" stroke="${INK}" stroke-width="2"/><path d="M136 63Q152 58 168 64M136 76Q152 71 168 77M192 63Q208 58 224 64M192 76Q208 71 224 77" fill="none" stroke="${color}" stroke-width="3"/><path d="M200 45V91L207 84L214 88V42" fill="${BRASS}"/>`,
    homes: `<path d="M122 76L180 33L238 76" fill="none" stroke="${INK}" stroke-width="3"/><path d="M135 72V124H225V72L180 42Z" fill="${PAPER}" stroke="${INK}" stroke-width="2"/><path d="M124 76L180 33L236 76L227 82L180 46L133 82Z" fill="${color}"/><rect x="171" y="91" width="22" height="33" fill="${BRASS}"/><rect x="145" y="84" width="16" height="18" fill="${color}"/><path d="M153 84V102M145 93H161" stroke="${PAPER}" stroke-width="1.5"/><path d="M118 128H242" stroke="${INK}" stroke-width="2"/>`,
    prices: `<path d="M145 38H208L235 65L208 92H145Z" fill="${color}" stroke="${INK}" stroke-width="2"/><circle cx="215" cy="65" r="5" fill="${PAPER}"/><path d="M215 60Q237 38 247 47" fill="none" stroke="${INK}" stroke-width="1.5"/><path d="M164 52L176 66L188 52M176 66V81M164 68H188M164 74H188" fill="none" stroke="${PAPER}" stroke-width="2.5"/><ellipse cx="145" cy="114" rx="27" ry="9" fill="${BRASS}" stroke="${INK}" stroke-width="2"/><path d="M118 106V114M172 106V114" stroke="${INK}" stroke-width="2"/><ellipse cx="145" cy="106" rx="27" ry="9" fill="${PAPER}" stroke="${INK}" stroke-width="2"/>`
  };
  return `<g class="figure-motif" aria-hidden="true">${art[kind] || art.people}</g>`;
}

function percentageGrid(value, color) {
  return Array.from({ length: 100 }, (_, index) => {
    const x = 107 + (index % 10) * 15;
    const y = 148 + Math.floor(index / 10) * 12;
    const part = Math.max(0, Math.min(1, value - index));
    return `<rect x="${x}" y="${y}" width="11" height="8" fill="${PAPER}" stroke="${INK}" stroke-width=".6"/>${part > 0 ? `<rect class="figure-grid-fill" x="${x}" y="${y}" width="${part * 11}" height="8" fill="${color}"/>` : ''}`;
  }).join('');
}

/** Two records in the same unit. Missing values stay missing; icons are not units. */
export function comparisonFigure({ kind = 'people', a = {}, b = {}, unit = '', title = '' } = {}) {
  const chosenKind = ['people', 'rice', 'phones', 'computers', 'books', 'homes', 'prices'].includes(kind) ? kind : 'people';
  const records = [a, b];
  const values = records.map(record => record.value).filter(isNumber);
  const percent = /^(?:%|％|パーセント)$/.test(String(unit).trim());
  const useGrid = percent && values.length > 0 && values.every(value => value >= 0 && value <= 100);
  // Normalize before subtracting: even opposite, very large finite values
  // retain a usable common scale without overflowing the range to Infinity.
  const magnitude = Math.max(...values.map(Math.abs), 1);
  const minimum = Math.min(0, ...values.map(value => value / magnitude));
  const maximum = Math.max(0, ...values.map(value => value / magnitude));
  const span = maximum - minimum || 1;
  const x = value => 30 + (value / magnitude - minimum) / span * 300;
  const zero = x(0);
  const sides = records.map((record, index) => {
    const { value, year, label = '' } = record;
    const known = isNumber(value);
    const color = index === 0 ? TEAL : VERMILION;
    const state = !known ? 'missing' : value === 0 ? 'zero' : value < 0 ? 'negative' : 'positive';
    let drawing;
    if (!known) {
      drawing = `<text class="figure-missing" x="180" y="191" text-anchor="middle" fill="${INK}" font-size="28">—</text>`;
    } else if (useGrid) {
      drawing = percentageGrid(value, color);
    } else {
      const end = x(value);
      drawing = `<line x1="30" x2="330" y1="182" y2="182" stroke="${INK}" stroke-width="1"/><rect class="figure-bar" x="${Math.min(zero, end)}" y="161" width="${Math.abs(end - zero)}" height="21" fill="${color}"/><line class="figure-origin" x1="${zero}" x2="${zero}" y1="151" y2="192" stroke="${INK}" stroke-width="1.5"/><text x="${zero}" y="211" text-anchor="middle" fill="${INK}" font-size="13">0</text>`;
    }
    const text = `${yearText(year)}、${label}、${numberText(value)}${known ? ` ${unit}` : ''}`;
    return `<div class="figure-side figure-${state}" data-state="${state}"${known ? ` data-value="${value}"` : ''}><p class="figure-year">${escapeHTML(yearText(year))}</p><p class="figure-label">${escapeHTML(label)}</p><p class="figure-value">${escapeHTML(numberText(value))}${known ? ` <span class="figure-unit">${escapeHTML(unit)}</span>` : ''}</p><svg class="figure-svg" viewBox="0 0 360 ${useGrid ? 280 : 224}" role="img" aria-label="${escapeHTML(text)}">${motif(chosenKind, color)}${drawing}</svg></div>`;
  }).join('');
  return `<figure class="edu-figure comparison-figure" data-kind="${chosenKind}" data-scale="${useGrid ? 'percent-grid' : 'shared-bar'}"><figcaption class="figure-title">${escapeHTML(title)}</figcaption><div class="figure-pair">${sides}</div><p class="figure-caption">${useGrid ? '100マスで100%。1マスが1%を表します。' : '棒の長さは共通の目盛りで表しています。'}</p></figure>`;
}

/** L3-M008: one Hiroshima teacher household, not an average or a full budget. */
export function budgetFigure() {
  const salary = 40;
  const rent = 3.5;
  const rentPercent = rent / salary * 100;
  const rentWidth = rent / salary * 560;
  return `<figure class="edu-figure budget-figure"><figcaption class="figure-title">1904年、広島のある教員世帯</figcaption><div class="budget-values"><p><span>月給</span><strong class="figure-value">40 <span class="figure-unit">円</span></strong></p><p><span>月額家賃</span><strong class="figure-value">3円50銭</strong></p></div><svg class="figure-svg budget-svg" viewBox="0 0 700 270" role="img" aria-label="月給40円の幅のうち、家賃3円50銭は${rentPercent}%。"><g transform="translate(-10 3)">${motif('homes', VERMILION)}</g><g class="budget-ledger" fill="${PAPER}" stroke="${INK}" stroke-width="2"><path d="M292 42Q321 33 350 43Q379 33 408 42V142Q379 134 350 143Q321 134 292 142Z"/><path d="M350 43V143"/><path d="M304 62H338M304 76H338M304 90H338M362 62H396M362 76H396M362 90H396" stroke="${TEAL}"/><path d="M366 40V113L375 105L383 110V38" fill="${BRASS}" stroke="none"/></g><g class="budget-coins" stroke="${INK}" stroke-width="2"><path d="M500 113V125Q532 142 564 125V113" fill="${BRASS}"/><ellipse cx="532" cy="113" rx="32" ry="12" fill="${PAPER}"/><circle cx="588" cy="92" r="29" fill="${BRASS}"/><circle cx="588" cy="92" r="21" fill="none"/><path d="M579 81L588 93L597 81M588 93V108M578 96H598M578 102H598" fill="none" stroke-width="2.5"/></g><path d="M70 176V166H630V176" fill="none" stroke="${INK}" stroke-width="1.5"/><rect class="budget-salary-bar" x="70" y="185" width="560" height="34" fill="${TEAL}"/><rect class="budget-rent-bar" x="70" y="185" width="${rentWidth}" height="34" fill="${VERMILION}"/><path d="M70 225V235H${70 + rentWidth}V225" fill="none" stroke="${VERMILION}" stroke-width="2"/><text x="350" y="157" text-anchor="middle" fill="${INK}" font-size="17">月給 40円</text><text x="70" y="257" fill="${VERMILION}" font-size="17">家賃 3円50銭</text></svg><p class="budget-equation">3.5 ÷ 40 × 100 ＝ <strong>${rentPercent}%</strong></p><p class="figure-caption">月給を一つの帯にすると、家賃はその${rentPercent}%。</p><p class="figure-source">宮下美智子「<a href="https://osaka-kyoiku.repo.nii.ac.jp/record/2079513/files/seibuk_18_087.pdf" target="_blank" rel="noopener noreferrer">明治期における一勤労者世帯の家計</a>」pp.88–91</p></figure>`;
}
