/** Kana-to-romaji input graph. Each live state retains a possible route. */
const KANA: Record<string, readonly string[]> = {
  あ:['a'],い:['i'],う:['u'],え:['e'],お:['o'],
  か:['ka'],き:['ki'],く:['ku'],け:['ke'],こ:['ko'],
  さ:['sa'],し:['si','shi'],す:['su'],せ:['se'],そ:['so'],
  た:['ta'],ち:['ti','chi'],つ:['tu','tsu'],て:['te'],と:['to'],
  な:['na'],に:['ni'],ぬ:['nu'],ね:['ne'],の:['no'],
  は:['ha'],ひ:['hi'],ふ:['hu','fu'],へ:['he'],ほ:['ho'],
  ま:['ma'],み:['mi'],む:['mu'],め:['me'],も:['mo'],
  や:['ya'],ゆ:['yu'],よ:['yo'],
  ら:['ra'],り:['ri'],る:['ru'],れ:['re'],ろ:['ro'],
  わ:['wa'],を:['wo'],
  が:['ga'],ぎ:['gi'],ぐ:['gu'],げ:['ge'],ご:['go'],
  ざ:['za'],じ:['zi','ji'],ず:['zu'],ぜ:['ze'],ぞ:['zo'],
  だ:['da'],ぢ:['di','ji'],づ:['du','zu'],で:['de'],ど:['do'],
  ば:['ba'],び:['bi'],ぶ:['bu'],べ:['be'],ぼ:['bo'],
  ぱ:['pa'],ぴ:['pi'],ぷ:['pu'],ぺ:['pe'],ぽ:['po'],
  ゔ:['vu'],
  ぁ:['la','xa'],ぃ:['li','xi'],ぅ:['lu','xu'],ぇ:['le','xe'],ぉ:['lo','xo'],
  ゃ:['lya','xya'],ゅ:['lyu','xyu'],ょ:['lyo','xyo'],ゎ:['lwa','xwa'],
  ゕ:['lka','xka'],ゖ:['lke','xke'],
  ー:['-'],
};

const YOON: Record<string, readonly string[]> = {
  きゃ:['kya'],きゅ:['kyu'],きょ:['kyo'],
  しゃ:['sya','sha'],しゅ:['syu','shu'],しょ:['syo','sho'],
  ちゃ:['tya','cha'],ちゅ:['tyu','chu'],ちょ:['tyo','cho'],
  にゃ:['nya'],にゅ:['nyu'],にょ:['nyo'],
  ひゃ:['hya'],ひゅ:['hyu'],ひょ:['hyo'],
  みゃ:['mya'],みゅ:['myu'],みょ:['myo'],
  りゃ:['rya'],りゅ:['ryu'],りょ:['ryo'],
  ぎゃ:['gya'],ぎゅ:['gyu'],ぎょ:['gyo'],
  じゃ:['zya','ja','jya'],じゅ:['zyu','ju','jyu'],じょ:['zyo','jo','jyo'],
  ぢゃ:['dya','ja'],ぢゅ:['dyu','ju'],ぢょ:['dyo','jo'],
  びゃ:['bya'],びゅ:['byu'],びょ:['byo'],
  ぴゃ:['pya'],ぴゅ:['pyu'],ぴょ:['pyo'],
  ふぁ:['fa'],ふぃ:['fi'],ふぇ:['fe'],ふぉ:['fo'],
  てぃ:['thi'],でぃ:['dhi'],とぅ:['twu'],どぅ:['dwu'],
};

type Edge = { end: number; roman: string };
type State = { at: number; roman: string; end: number; offset: number };
const SKIP = /[\s、。・！？!?.,]/u;

export function validateReading(reading: string): boolean {
  try { new TypingSession(reading); return true; } catch { return false; }
}

export class TypingSession {
  readonly reading: string;
  typed = '';
  private readonly chars: string[];
  private states: State[] = [{at:0, roman:'', end:0, offset:0}];
  private readonly edgeCache = new Map<number, Edge[]>();
  private readonly shortestCache = new Map<number, string>();

  constructor(reading: string) {
    this.reading = reading;
    this.chars = [...reading.normalize('NFC')].filter(char => !SKIP.test(char));
    if (!this.chars.length || !this.reachable(0, new Set())) throw new Error(`Unsupported reading: ${reading}`);
  }

  private edges(at: number): Edge[] {
    const cached = this.edgeCache.get(at);
    if (cached) return cached;
    const char = this.chars[at];
    const next = this.chars[at + 1];
    const edges: Edge[] = [];
    if (char === 'っ') {
      for (const roman of ['ltu','xtu','ltsu','xtsu']) edges.push({end:at+1, roman});
      if (next) for (const following of this.edges(at + 1)) {
        const first = following.roman[0];
        if (first && /[bcdfghjklmpqrstvwxyz]/.test(first)) {
          edges.push({end:following.end, roman:first + following.roman});
        }
      }
    } else if (char === 'ん') {
      edges.push({end:at+1, roman:'nn'}, {end:at+1, roman:"n'"});
      if (next && !/[あいうえおやゆよなにぬねの]/u.test(next)) edges.push({end:at+1, roman:'n'});
    } else {
      for (const roman of KANA[char] ?? []) edges.push({end:at+1, roman});
      if (next) for (const roman of YOON[char+next] ?? []) edges.push({end:at+2, roman});
    }
    const unique = [...new Map(edges.map(edge => [`${edge.end}:${edge.roman}`, edge])).values()];
    this.edgeCache.set(at, unique);
    return unique;
  }

  private reachable(at: number, visiting: Set<number>): boolean {
    if (at === this.chars.length) return true;
    if (visiting.has(at)) return false;
    visiting.add(at);
    const valid = this.edges(at).some(edge => this.reachable(edge.end, visiting));
    visiting.delete(at);
    return valid;
  }

  private nextStates(key: string): State[] {
    const found: State[] = [];
    for (const state of this.states) {
      if (state.roman) {
        if (state.roman[state.offset] === key) {
          const offset = state.offset + 1;
          found.push(offset === state.roman.length
            ? {at:state.end, roman:'', end:state.end, offset:0}
            : {...state, offset});
        }
      } else if (state.at < this.chars.length) {
        for (const edge of this.edges(state.at)) if (edge.roman[0] === key) {
          found.push(edge.roman.length === 1
            ? {at:edge.end, roman:'', end:edge.end, offset:0}
            : {at:state.at, roman:edge.roman, end:edge.end, offset:1});
        }
      }
    }
    return [...new Map(found.map(s => [`${s.at}:${s.end}:${s.roman}:${s.offset}`, s])).values()];
  }

  type(key: string): boolean {
    if (this.complete || !/^[a-z'-]$/i.test(key)) return false;
    const normalized = key.toLowerCase();
    const found = this.nextStates(normalized);
    if (!found.length) return false;
    this.states = found;
    this.typed += normalized;
    return true;
  }

  get complete(): boolean { return this.states.some(s => !s.roman && s.at === this.chars.length); }
  get keys(): string[] {
    if (this.complete) return [];
    const keys = new Set<string>();
    for (const state of this.states) {
      if (state.roman) keys.add(state.roman[state.offset]);
      else for (const edge of this.edges(state.at)) keys.add(edge.roman[0]);
    }
    return [...keys].sort();
  }
  get progress(): number {
    if (this.complete) return 1;
    return Math.max(...this.states.map(s => (s.at + (s.roman ? (s.end-s.at)*s.offset/s.roman.length : 0)) / this.chars.length));
  }
  get guide(): string {
    if (this.complete) return '';
    const best = this.states.map(s => (s.roman ? s.roman.slice(s.offset) : '') + this.shortest(s.roman ? s.end : s.at))
      .sort((a,b) => a.length-b.length || a.localeCompare(b))[0];
    return best ?? '';
  }
  private shortest(at: number): string {
    if (at === this.chars.length) return '';
    const cached = this.shortestCache.get(at);
    if (cached !== undefined) return cached;
    const options = this.edges(at).map(edge => edge.roman + this.shortest(edge.end));
    const best = options.sort((a,b) => a.length-b.length || a.localeCompare(b))[0] ?? '';
    this.shortestCache.set(at,best);
    return best;
  }
  get standardLength(): number { return this.shortest(0).length; }
}
