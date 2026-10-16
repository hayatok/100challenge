export const STORAGE_KEY = 'hakoniwa-japan-v1';
export function parseSaved(raw) {
  try {
    const value = JSON.parse(raw);
    if (value?.version !== 1 || !Number.isInteger(value.seed) || value.seed < 1 || value.seed > 4294967295 || !Number.isInteger(value.year) || value.year < 1900 || value.year > 2026 || !Number.isInteger(value.month) || value.month < 1 || value.month > 12 || (value.year === 2026 && value.month > 10)) return null;
    return { seed: value.seed, year: value.year, month: value.month, placeId: typeof value.placeId === 'string' && /^[a-z]+$/.test(value.placeId) ? value.placeId : 'kanto', personId: typeof value.personId === 'string' ? value.personId.slice(0, 100) : null, speed: [1, 4, 12, 48].includes(value.speed) ? value.speed : 1, reducedMotion: value.reducedMotion === true,
      ...(Number.isFinite(value.clockSeconds)&&value.clockSeconds>=0&&value.clockSeconds<=1e7?{clockSeconds:value.clockSeconds}:{}),
      ...(Number.isFinite(value.zoom)&&value.zoom>=1&&value.zoom<=1.7?{zoom:value.zoom}:{}),
    };
  } catch { return null; }
}
export function serializeSaved(sim, settings) {
  return JSON.stringify({ version: 1, seed: sim.seed, year: sim.year, month: sim.month, placeId: settings.placeId, personId: settings.personId, speed: settings.speed, reducedMotion: settings.reducedMotion,clockSeconds:settings.clockSeconds,zoom:settings.zoom });
}
export function safeURL(value) {
  try { const url = new URL(value); return ['https:', 'http:'].includes(url.protocol) ? url.href : null; } catch { return null; }
}
export function escapeHTML(value = '') { return String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]); }
