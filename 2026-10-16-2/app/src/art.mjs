// Original, deterministic miniature-town artwork. All interpolated values come
// from finite palettes or internal geometry; caller strings never enter markup.
const INK = '#343c34';
const line = `stroke="${INK}" stroke-width="1.35" stroke-linecap="round" stroke-linejoin="round"`;
const wrap = (content) => `<g ${line}>${content}</g>`;
const polygon = (points, fill, extra = '') => `<polygon points="${points}" fill="${fill}" ${extra}/>`;
const path = (d, stroke = INK, width = 1) => `<path d="${d}" fill="none" stroke="${stroke}" stroke-width="${width}"/>`;
const shadow = '<path d="M-27 0L0-13 31 2 5 15z" fill="#384839" opacity=".16" stroke="none"/>';

function ground(top, left = '#879765', right = '#738559') {
  return polygon('-40,0 0,20 0,30 -40,10', left)
    + polygon('0,20 40,0 40,10 0,30', right)
    + polygon('0,-20 40,0 0,20 -40,0', top);
}
const grass = '<g stroke="#6a8649" stroke-width="1.1" fill="none"><path d="M-24 2l-1-4m1 4l3-3M19 5l1-4m-1 4l-3-2M-5-11l-1-3m1 3l3-2"/></g>';
const water = () => ground('#74b7bd', '#538e98', '#3f7988')
  + '<g fill="none" stroke="#d4ece4" stroke-width="1.3" stroke-linecap="round"><path d="M-25-1q5 3 10 0m9-10q4 3 8 0M5 10q5 3 11 0M18-3q4 3 8 0"/></g>'
  + '<path d="M-9 1l7 3m-7 0l7 3" fill="none" stroke="#4b98a7" stroke-width="1"/>';

function road(connections) {
  const flags = Array.isArray(connections) ? connections.map((value) => value === true) : [];
  const strips = ['-6,-3 14,-13 26,-7 6,3', '6,-3 26,7 14,13 -6,3', '6,3 -14,13 -26,7 -6,-3', '-6,3 -26,-7 -14,-13 6,-3'];
  const sides = ['M-6-3L14-13M6 3L26-7', 'M6-3L26 7M-6 3L14 13', 'M6 3L-14 13M-6-3L-26 7', 'M-6 3L-26-7M6-3L-14-13'];
  return ground('#a7b77d') + '<g stroke="none" fill="#d6cbb1">'
    + polygon('0,-6 12,0 0,6 -12,0', '#d6cbb1')
    + strips.map((points, i) => flags[i] ? polygon(points, '#d6cbb1') : '').join('') + '</g>'
    + sides.map((d, i) => flags[i] ? path(d, '#a6997f', .8) : '').join('')
    + '<g stroke="#b8aa90" stroke-width=".8"><path d="M-4-1l3 1m3 3l3-1m2-4l2 1"/></g>';
}

function bridge(connections) {
  const horizontal = Array.isArray(connections) && (connections[1] === true || connections[3] === true) && !(connections[0] === true || connections[2] === true);
  const deck = '<g>'
    + polygon('-26,7 -14,13 26,-7 14,-13', '#d2ab70')
    + polygon('-26,7 -14,13 -14,17 -26,11', '#977347')
    + polygon('-14,13 26,-7 26,-3 -14,17', '#ae8452')
    + path('M-20 4l12 6m-6-9l12 6M-8-2l12 6M-2-5l12 6M4-8l12 6M10-11l12 6', '#997346', .8)
    + path('M-25 6V-4M-12 0V-10M1-7V-17M14-13V-23M-25-3L14-22', '#6a6046', 1.8)
    + path('M-13 12V2M0 5V-5M13-2V-12M26-8V-18M-13 3L26-17', '#6a6046', 1.8)
    + '</g>';
  return water() + (horizontal ? `<g transform="scale(-1 1)">${deck}</g>` : deck);
}

/** Tile centered on (0,0), top diamond ±40 × ±20, soil depth 10. */
export function terrainSVG(kind, connections = []) {
  if (kind === 'river') return wrap(water());
  if (kind === 'road') return wrap(road(connections));
  if (kind === 'bridge') return wrap(bridge(connections));
  if (kind === 'mountain') return wrap(ground('#94a97a') + shadow
    + polygon('-33,5 -11,-46 11,7', '#7d9479')
    + polygon('-11,-46 11,7 30,-3 8,-29', '#627d70')
    + polygon('-17,-33 -11,-46 -3,-36 1,-23 -8,-29 -12,-26', '#d6dac4')
    + path('M-27 2l7-12m25 13l3-13', '#a7b498', 1.2)
    + polygon('18,8 23,4 29,6 25,10', '#a0aa8e') + grass);
  return wrap(ground('#a9bb7c') + grass
    + '<ellipse cx="25" cy="-2" rx="3.2" ry="1.6" fill="#c4c7a1" stroke="#859266" stroke-width=".7"/>');
}

const palettes = [
  { wall: '#f2dfb4', side: '#d6bc8c', roof: '#ba5841', roofLight: '#d37552', trim: '#785d40' },
  { wall: '#f0e0c0', side: '#d5c4a1', roof: '#905e4d', roofLight: '#b57959', trim: '#6e614d' },
  { wall: '#f6ebd5', side: '#ddd3b9', roof: '#5d7c78', roofLight: '#789991', trim: '#606d5e' },
];
function palette(era) { return palettes[era === 2 ? 2 : era === 1 ? 1 : 0]; }
function houseBody(p) {
  return polygon('-26,-30 0,-17 0,10 -26,-3', p.side)
    + polygon('0,-17 26,-30 26,-3 0,10', p.wall)
    + polygon('0,-17 26,-30 13,-48', p.wall);
}
function gableRoof(p) {
  return polygon('-30,-31 -15,-62 17,-46 2,-15', p.roof)
    + polygon('-15,-62 0,-47 30,-32 17,-46', p.roofLight)
    + path('M-25-32L-12-57M-18-28L-5-53M-11-25L2-49M-4-21L9-46', '#743f35', .65)
    + path('M-15-62L17-46', p.trim, 2);
}
function home(p, era) {
  return shadow + houseBody(p)
    + polygon('7,-16 15,-20 15,2 7,6', p.trim)
    + '<circle cx="13" cy="-7" r=".7" fill="#e6d29e" stroke="none"/>'
    + polygon('18,-20 23,-22.5 23,-12 18,-9.5', '#8bb7b2')
    + path('M20.5-21.2v10.5M18-15l5-2.5', p.trim, .8)
    + polygon('-21,-23 -7,-16 -7,-6 -21,-13', '#a8c5bb')
    + path('M-14-19.5v10M-21-18l14 7', p.trim, .9)
    + path('M-25-5L-1 7', p.trim, .8) + gableRoof(p)
    + (era === 2 ? polygon('-18,-42 -12,-54 2,-47 -4,-35', '#416b7b') + path('M-15-44l13 6m-9-11l13 6M-8-51l-6 12', '#a1bdc3', .6) : '')
    + '<path d="M-27 1l4 2 4-2v-5l-8-2z" fill="#ac714b"/>'
    + '<path d="M-24-4v-7m0 6l-3-4m3 3l4-5" fill="none" stroke="#487648" stroke-width="2"/>';
}
function shop(p, era) {
  const awning = era === 2 ? '#4e817b' : '#c65943';
  return shadow + polygon('-27,-30 0,-16 0,10 -27,-4', p.side)
    + polygon('0,-16 27,-30 27,-4 0,10', p.wall)
    + polygon('-29,-31 0,-46 30,-31 0,-16', p.roof)
    + path('M-24-31L0-43 25-31M-18-28L5-40', p.roofLight, 1.6)
    + polygon('4,-15 11,-18.5 11,3 4,6.5', '#55756e')
    + polygon('14,-19 25,-24.5 25,-8 14,-2.5', '#385d5b')
    + polygon('-24,-25 -3,-14 -3,-3 -24,-14', '#527773')
    + polygon('1,-17 27,-30 33,-19 7,-6', '#f7e6bb')
    + polygon('1,-17 6,-19.5 12,-8.5 7,-6', awning)
    + polygon('11,-22 16,-24.5 22,-13.5 17,-11', awning)
    + polygon('21,-27 27,-30 33,-19 27,-16', awning)
    + polygon('7,-6 33,-19 33,-15 7,-2', '#f6e5bd')
    + path('M12-8.5v4m10-9v4m5-6.5v4', awning, 3)
    + polygon('12,2 29,-6.5 29,-1 12,7.5', '#b78a53')
    + polygon('12,2 23,-3.5 29,-.5 18,5', '#dfbd7b')
    + '<g stroke="#65754c" stroke-width=".7"><circle cx="17" cy="1" r="2" fill="#d69042"/><circle cx="21" cy="-1" r="2" fill="#d65b40"/><circle cx="25" cy="-3" r="2" fill="#88a459"/></g>'
    + polygon('-19,-33 -5,-26 -5,-20 -19,-27', '#f7e9c5')
    + path('M-16-29l8 4', p.trim, 1.2);
}
function workshop(p, era) {
  return shadow + polygon('-29,-25 0,-10 0,10 -29,-5', '#b2ab87')
    + polygon('0,-10 28,-24 28,-4 0,10', '#d5cfac')
    + polygon('-31,-26 -7,-43 30,-25 1,-10', era === 2 ? '#799493' : '#697d79')
    + path('M-24-27L-5-40M-16-23L3-36M-8-19L11-32M0-15L19-28', '#a2b5a8', 1)
    + polygon('-21,-36 -13,-32 -13,-59 -21,-63', '#8d694f')
    + polygon('-13,-32 -7,-35 -7,-62 -13,-59', '#b28660')
    + polygon('-22,-63 -15,-67 -6,-62 -13,-58', '#c0a07a')
    + polygon('-19,-63 -15,-65 -10,-62 -13,-60', '#4c5047')
    + path('M-20-50l7 3m-7-12l7 3m0 12l6-3', '#634f40', .8)
    + polygon('7,-10 22,-17.5 22,-1 7,6.5', '#69746c')
    + path('M10-10v15m4-17v15m4-17v15', '#a1aa8d', .9)
    + polygon('-24,-21 -7,-12.5 -7,-7 -24,-15.5', '#a9c1b0')
    + path('M-18-18v5.5m6-2.5v5.5', '#5b6c5c', .8)
    + polygon('-27,1 -19,-3 -10,1.5 -18,5.5', '#c59b62')
    + polygon('-27,1 -18,5.5 -18,10 -27,5.5', '#987245')
    + polygon('-18,5.5 -10,1.5 -10,6 -18,10', '#b08650');
}
function clinic(p, era) {
  return shadow + polygon('-27,-29 0,-15 0,10 -27,-4', p.side)
    + polygon('0,-15 27,-29 27,-4 0,10', p.wall)
    + polygon('-30,-30 0,-45 30,-30 0,-15', era === 0 ? '#667e75' : '#76968b')
    + polygon('0,-15 30,-30 30,-26 0,-11', '#496f66')
    + polygon('4,-12 14,-17 14,3 4,8', '#719f9a')
    + path('M9-14.5v20', '#edf1d6', .8)
    + polygon('18,-19 25,-22.5 25,-10 18,-6.5', '#a3cbc0')
    + polygon('-23,-23 -6,-14.5 -6,-5 -23,-13.5', '#aad0bf')
    + path('M-14.5-19v9.5M-23-18l17 8.5', '#677a62', .8)
    + polygon('12,-29 23,-34.5 23,-24 12,-18.5', '#347d77')
    // A cream leaf on a teal sign denotes care; no red-cross emblem.
    + '<path d="M15-24q-1-5 5-7 2 5-3 7z" fill="#f6e9c6" stroke="none"/>'
    + path('M16-23l3-6', '#b4d0ad', .8)
    + polygon('-5,9 5,14 18,7.5 8,2.5', '#c4c3a2')
    + path('M0 11l13-6.5', '#8c967c', .8);
}
function tree(x, y, scale = 1) {
  return `<g transform="translate(${x} ${y}) scale(${scale})">`
    + '<path d="M0 1v-23m0 11l-7-7m7 4l8-9" fill="none" stroke="#795e3d" stroke-width="3"/>'
    + '<path d="M-13-20q-7-10 3-16 0-13 13-12 12-1 13 11 10 7 5 17-5 7-15 5-12 5-19-5z" fill="#618b51"/>'
    + '<path d="M-9-30q0-8 8-10m6 5q8 1 10 7" fill="none" stroke="#8fa967" stroke-width="2"/>'
    + '</g>';
}
function park() {
  return shadow + polygon('-31,-1 0,-16 31,0 0,16', '#91ad6a', 'stroke="#647b4e"')
    + polygon('-9,-11 0,-15 25,-2 16,2', '#dbcfaa', 'stroke="none"')
    + polygon('16,2 25,-2 4,9 -5,5', '#dbcfaa', 'stroke="none"')
    + tree(-14, -1, .96) + tree(17, -8, .68)
    + '<g fill="none" stroke="#6b6045" stroke-width="1.8"><path d="M-3 5v8M12-2v8M-3 0v-6M12-7v-6"/></g>'
    + polygon('-6,3 9,-4 15,-1 0,6', '#bc8d53')
    + polygon('-5,-4 10,-11 10,-6 -5,1', '#d1a266')
    + path('M-3-2l11-5', '#8c6943', .8)
    + '<g stroke="#648645" stroke-width=".9"><path d="M-23 4v-4m5 7V3m4 6V5"/><circle cx="-23" cy="-1" r="1.8" fill="#d5864b"/><circle cx="-18" cy="2" r="1.8" fill="#eee0a4"/><circle cx="-14" cy="4" r="1.8" fill="#d5864b"/></g>';
}

/** Building footprint remains inside a tile; roof height is approximately 62. */
export function buildingSVG(type, era = 0) {
  const p = palette(era);
  const draw = { home, shop, workshop, clinic, park };
  return Object.hasOwn(draw, type) ? wrap(draw[type](p, era)) : '';
}

/** Resident's feet are at (0,0); compact, roughly 2.5-head figure. */
export function residentSVG(tone = 0) {
  const index = Number.isFinite(tone) ? Math.abs(Math.trunc(tone)) % 6 : 0;
  const clothes = ['#bd6045', '#497f8b', '#e0ae50', '#697e55', '#8d6982', '#d2c9aa'];
  const skin = ['#e6b88c', '#c88f65', '#efcba6'][index % 3];
  return `<g stroke="${INK}" stroke-width=".65" stroke-linecap="round" stroke-linejoin="round">`
    + '<ellipse cx=".4" cy=".2" rx="3.7" ry="1.4" fill="#34463b" opacity=".18" stroke="none"/>'
    + '<path d="M-1.3-3.4l-1 3M1-3.4l1.5 3" fill="none" stroke="#40504b" stroke-width="1.5"/>'
    + `<path d="M-2-8q2-1 4 0l.5 4.8h-5z" fill="${clothes[index]}"/>`
    + `<path d="M-2.3-7.5l-1.4 3M2.3-7.5l1.2 2.8" fill="none" stroke="${skin}" stroke-width="1.3"/>`
    + `<circle cx="0" cy="-10.2" r="2.3" fill="${skin}"/>`
    + '<path d="M-2.2-10.6q-.2-3 2.4-2 2.1-.2 2.1 2.4l-1.4-1-2 .2z" fill="#4c493a" stroke="none"/>'
    + '<circle cx="1" cy="-10" r=".35" fill="#343c34" stroke="none"/></g>';
}

/** Self-contained decorative toolbar icon. Accessible name belongs to its button. */
export function toolIconSVG(type) {
  const content = type === 'road' ? terrainSVG('road', [true, false, true, false])
    : type === 'bridge' ? terrainSVG('bridge', [true, false, true, false])
      : type === 'erase' ? wrap(ground('#a9bb7c') + '<g transform="rotate(-27 0 -22)"><path d="M-20-29l25-17 18 16-25 17z" fill="#d8bc8a"/><path d="M-20-29l18 16-8 6-18-16z" fill="#c56d57"/><path d="M-28-23l18 16v5l-18-16z" fill="#a75342"/></g>' + path('M-21 5l10-5m7 4l8-4', '#8b8e6f', 1.8))
        : terrainSVG('land') + buildingSVG(type);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-44 -76 88 108" aria-hidden="true" focusable="false">${content}</svg>`;
}
