import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../game/web_mobile.js', import.meta.url), 'utf8');
const shell = readFileSync(new URL('../game/web_shell.html', import.meta.url), 'utf8');
const SENTINEL = '\u200b';

class Target {
  listeners = new Map();
  addEventListener(type, fn, options) {
    if (!this.listeners.has(type)) this.listeners.set(type, []);
    this.listeners.get(type).push({fn, options});
  }
  emit(type, properties = {}) {
    const event = {type, defaultPrevented: false, propagationStopped: false,
      preventDefault() { this.defaultPrevented = true; },
      stopPropagation() { this.propagationStopped = true; },
      stopImmediatePropagation() { this.propagationStopped = true; this.immediateStopped = true; }, ...properties};
    for (const {fn} of this.listeners.get(type) || []) { fn(event); if (event.immediateStopped) break; }
    return event;
  }
}
class Element extends Target {
  constructor(doc) {
    super(); this.doc = doc; this.children = []; this.hidden = false; this.disabled = false;
    this.textContent = ''; this.value = ''; this.className = ''; this.focusCalls = []; this.style = {}; this.attributes = {};
  }
  setAttribute(name, value) { this.attributes[name] = value; }
  getBoundingClientRect() { return {left: 0, top: 0, width: 390, height: 800}; }
  appendChild(child) { this.children.push(child); }
  replaceChildren(...children) { this.children = children; }
  focus(options) {
    if (this.disabled) return;
    this.focusCalls.push(options);
    if (this.doc.activeElement && this.doc.activeElement !== this) this.doc.activeElement.blur();
    this.doc.activeElement = this; this.emit('focus');
  }
  blur() {
    if (this.doc.activeElement === this) {
      this.doc.activeElement = null; this.emit('blur');
    }
  }
}
function harness({touch = true, bind = true} = {}) {
  const document = new Target();
  document.activeElement = null; document.hidden = false;
  const ids = [...shell.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
  const elements = Object.fromEntries(ids.map((id) => [id, new Element(document)]));
  const classes = new Set(); const css = new Map(); const timers = [];
  document.body = {classList: {toggle(name, yes) { if (yes) classes.add(name); else classes.delete(name); }}};
  document.documentElement = {style: {setProperty(name, value) { css.set(name, value); }}};
  document.getElementById = (id) => elements[id];
  document.createElement = () => new Element(document);
  const window = new Target();
  window.innerHeight = 800; window.innerWidth = 390; window.devicePixelRatio = 2; window.navigator = {maxTouchPoints: touch ? 1 : 0};
  window.matchMedia = () => ({matches: touch});
  window.visualViewport = new Target(); window.visualViewport.height = 800; window.visualViewport.width = 390; window.visualViewport.offsetTop = 0;
  window.setTimeout = (callback) => { timers.push(callback); };
  vm.runInNewContext(source, {window, document}, {filename: 'web_mobile.js'});
  const bridge = window.BlackRelayMobile; const calls = [];
  let handler;
  if (bind) bridge.bindGame((action, value) => { calls.push([action, value]); handler?.(action, value); });
  const input = elements['mobile-input'];
  const update = (state = 'playing', extra = {}) => bridge.update(JSON.stringify({state, actions: [],
    target: '残響 / ざんきょう', typed: 'za', remaining: 'nkyou', cut: 'CUT: i | to', hp: 6, score: 20, ...extra}));
  function tap(x = 100, y = 200) {
    const point = {identifier: 1, clientX: x, clientY: y};
    const startEvent = elements.canvas.emit('touchstart', {touches: [point], changedTouches: [point]});
    const endEvent = elements.canvas.emit('touchend', {touches: [], changedTouches: [point]});
    return {startEvent, endEvent};
  }
  function start() { update(); tap(); calls.length = 0; }
  function insert(value, extra = {}) {
    input.value = SENTINEL + value;
    return input.emit('input', {data: value, inputType: 'insertText', isComposing: false, ...extra});
  }
  return {document, window, elements, bridge, input, calls, classes, css, update, start, insert, tap,
    flush() { while (timers.length) timers.shift()(); },
    handle(fn) { handler = fn; }};
}

test('touch detection enables only the keyboard bridge; desktop input stays unchanged', () => {
  const mobile = harness(); assert.equal(mobile.bridge.isEnabled(), true); assert(mobile.classes.has('mobile-mode'));
  const desktop = harness({touch: false}); desktop.update(); desktop.tap();
  assert.equal(desktop.bridge.isEnabled(), false); assert.equal(desktop.input.disabled, true);
  assert.equal(desktop.input.focusCalls.length, 0); assert.equal(desktop.calls.length, 0);
});

test('updates never autofocus; a canvas tap focuses synchronously and reopens a dismissed keyboard', () => {
  const h = harness(); h.update(); h.update(); assert.equal(h.input.focusCalls.length, 0);
  h.tap(); assert.equal(h.bridge.ownsFocus(), true); assert.equal(h.input.focusCalls[0].preventScroll, true);
  h.update(); assert.equal(h.input.focusCalls.length, 1);
  h.tap(); assert.equal(h.input.focusCalls.length, 2); // Dismissal can retain activeElement on iOS.
  h.input.blur(); h.tap(); assert.equal(h.bridge.ownsFocus(), true);
});

test('in-game start, briefing, pause and resume taps focus only after the synchronous game callback', () => {
  const h = harness(); h.update('title');
  let nextState = 'intermission';
  h.handle((action) => { if (action === 'tap') h.update(nextState); });
  h.tap(); assert.equal(h.bridge.ownsFocus(), false);
  nextState = 'playing'; h.tap(); assert.equal(h.bridge.ownsFocus(), true);
  nextState = 'paused'; h.tap(); assert.equal(h.bridge.ownsFocus(), false);
  const count = h.input.focusCalls.length;
  h.update('paused'); assert.equal(h.input.focusCalls.length, count);
  nextState = 'playing'; h.tap(); assert.equal(h.bridge.ownsFocus(), true);
});

test('touch is consumed once before Godot can queue an emulated mouse action', () => {
  const h = harness(); h.update(); let engineCalls = 0;
  for (const type of ['touchstart', 'touchend']) h.elements.canvas.addEventListener(type, () => engineCalls++);
  const {startEvent, endEvent} = h.tap();
  assert(startEvent.defaultPrevented && endEvent.defaultPrevented);
  assert(startEvent.immediateStopped && endEvent.immediateStopped);
  assert.equal(engineCalls, 0); assert.equal(h.calls.length, 1); assert.equal(h.calls[0][0], 'tap');
  const options = h.elements.canvas.listeners.get('touchstart')[0].options;
  assert.equal(options.capture, true); assert.equal(options.passive, false);
});

test('normal input forwards one lowercase letter; keydown does not duplicate it', () => {
  const h = harness(); h.start();
  const key = h.input.emit('keydown', {key: 'A'}); assert(key.propagationStopped);
  const event = h.insert('A'); assert(event.propagationStopped);
  assert.deepEqual(h.calls, [['text', 'a']]); assert.equal(h.input.value, SENTINEL);
  h.insert('a'); assert.deepEqual(h.calls, [['text', 'a'], ['text', 'a']]);
});

test('null input data uses the DOM value without the Backspace sentinel', () => {
  const h = harness(); h.start(); h.insert('B', {data: null}); assert.deepEqual(h.calls, [['text', 'b']]);
});

test('composition forwards its ASCII commit once, including trailing Safari input', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart');
  h.insert('s', {inputType: 'insertCompositionText', isComposing: true});
  h.insert('shi', {inputType: 'insertCompositionText', isComposing: true});
  assert.equal(h.calls.length, 0);
  h.input.emit('compositionend', {data: 'shi'});
  h.input.emit('input', {inputType: 'insertText', data: 'shi', isComposing: false});
  assert.deepEqual(h.calls, [['text', 'shi']]);
  h.input.emit('compositionend', {data: 'shi'}); assert.equal(h.calls.length, 1);
});

test('composition handles final input arriving before compositionend', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart');
  h.insert('si', {isComposing: false, inputType: 'insertFromComposition'});
  h.input.emit('compositionend', {data: 'si'}); assert.deepEqual(h.calls, [['text', 'si']]);
});

test('composition dedup does not swallow a deliberately repeated next letter', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.input.emit('compositionend', {data: 'a'});
  h.flush(); h.insert('a'); assert.deepEqual(h.calls, [['text', 'a'], ['text', 'a']]);
});

test('Japanese composition is ignored and clearly asks for an English keyboard', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.insert('ざ', {isComposing: true});
  h.input.emit('compositionend', {data: 'ざんきょう'});
  h.input.emit('input', {inputType: 'insertFromComposition', data: 'ざんきょう'});
  assert.equal(h.calls.length, 0); assert.match(h.input.attributes['aria-description'], /English keyboard/);
});

test('paste, drop, replacement and fallback transfer input cannot submit a free word', () => {
  const h = harness(); h.start();
  for (const type of ['paste', 'drop']) assert(h.input.emit(type).defaultPrevented);
  for (const inputType of ['insertFromPaste', 'insertFromDrop', 'insertReplacementText', 'historyUndo']) {
    const event = h.input.emit('beforeinput', {inputType}); assert(event.defaultPrevented);
    h.insert('zankyou', {inputType});
  }
  h.insert('zankyou'); assert.equal(h.calls.length, 0);
  assert.match(h.input.attributes['aria-description'], /no paste or prediction/);
});

test('Backspace resets once via beforeinput; uncancelable fallback does not duplicate', () => {
  const h = harness(); h.start();
  const event = h.input.emit('beforeinput', {inputType: 'deleteContentBackward', isComposing: false});
  assert(event.defaultPrevented); assert.deepEqual(h.calls, [['reset', '']]);
  h.input.emit('input', {inputType: 'deleteContentBackward', data: null});
  assert.deepEqual(h.calls, [['reset', '']]); assert.equal(h.input.value, SENTINEL);
  h.flush(); h.input.emit('input', {inputType: 'deleteContentBackward', data: null});
  assert.deepEqual(h.calls, [['reset', ''], ['reset', '']]);
});

test('deleting uncommitted composition does not erase actual target progress', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart');
  const event = h.input.emit('beforeinput', {inputType: 'deleteContentBackward', isComposing: true});
  assert.equal(event.defaultPrevented, false); assert.equal(h.calls.length, 0);
  h.input.emit('compositionend', {data: ''}); assert.equal(h.calls.length, 0);
});

test('text is gated by playing state and real input focus', () => {
  const h = harness();
  for (const state of ['title', 'settings', 'intermission', 'paused', 'ending', 'victory', 'defeat']) {
    h.update(state); h.insert('a'); h.input.emit('beforeinput', {inputType: 'deleteContentBackward'});
  }
  assert.equal(h.calls.length, 0); h.update(); h.insert('a'); assert.equal(h.calls.length, 0);
  h.start(); h.insert('a'); assert.deepEqual(h.calls, [['text', 'a']]);
  h.update('defeat'); assert.equal(h.bridge.ownsFocus(), false); assert.equal(h.input.disabled, true);
});

test('canvas tap maps actual bounds and viewport offsets without an input touch overlay', () => {
  const h = harness(); h.update();
  h.elements.canvas.getBoundingClientRect = () => ({left: 12, top: 24, width: 780, height: 325});
  h.tap(402, 186.5); assert.deepEqual(JSON.parse(h.calls[0][1]), {x: 0.5, y: 0.5});
  assert.equal(h.bridge.ownsFocus(), true);
  h.tap(2, 10); assert.equal(h.calls.length, 1);
});

test('window loss and backgrounding pause once; return never reopens the keyboard', () => {
  const h = harness(); h.start(); h.handle((action) => { if (action === 'focus_lost') h.update('paused'); });
  h.window.emit('blur'); h.document.hidden = true; h.document.emit('visibilitychange');
  assert.deepEqual(h.calls, [['focus_lost', '']]); assert.equal(h.bridge.ownsFocus(), false);
  const focusCount = h.input.focusCalls.length;
  h.document.hidden = false; h.document.emit('visibilitychange'); h.window.emit('focus');
  assert.equal(h.input.focusCalls.length, focusCount);
  h.update(); h.tap(); assert.equal(h.bridge.ownsFocus(), true);
});

test('desktop backgrounding also reaches the Godot focus-loss handler', () => {
  const h = harness({touch: false}); h.document.hidden = true; h.document.emit('visibilitychange');
  assert.deepEqual(h.calls, [['focus_lost', '']]);
});

test('visualViewport keyboard resize and scroll set height and offset CSS variables', () => {
  const h = harness(); assert.equal(h.css.get('--br-visual-height'), '800px');
  h.window.visualViewport.height = 325; h.window.visualViewport.offsetTop = 24; h.window.visualViewport.offsetLeft = 12;
  h.window.visualViewport.emit('resize'); h.window.visualViewport.emit('scroll');
  assert.equal(h.css.get('--br-visual-height'), '325px'); assert.equal(h.css.get('--br-visual-top'), '24px');
  assert.equal(h.elements.canvas.width, 780); assert.equal(h.elements.canvas.height, 650);
  assert.equal(h.elements.canvas.style.height, '325px');
  assert.equal(h.elements.canvas.style.top, '24px'); assert.equal(h.elements.canvas.style.left, '12px');
  assert.equal(h.elements.canvas.style.position, 'absolute');
  assert.equal(h.css.get('--br-visual-left'), '12px'); assert.equal(h.css.get('--br-visual-width'), '390px');
});

test('invalid snapshots are rejected and browser DOM never mirrors game readouts', () => {
  const h = harness(); h.update(); assert.equal(h.bridge.update('{'), false);
  assert.equal(h.bridge.update('{"state":"invalid"}'), false);
  assert.equal(h.input.focusCalls.length, 0);
  assert.deepEqual(Object.keys(h.elements).filter((id) => id.startsWith('mobile-')), ['mobile-input']);
});

test('HTML keeps a tiny focusable input with zero visible panels or hit-test area', () => {
  assert.match(shell, /<canvas id="canvas" tabindex="0"/); assert.match(shell, /src="web_mobile\.js"/);
  assert.doesNotMatch(shell, /mobile-(ui|play|menu|toggle|actions|word|keyboard|begin|cycle|reset|pause|target)/);
  const style = shell.match(/#mobile-input\{([^}]+)\}/)[1];
  for (const declaration of ['width:1px', 'height:1px', 'opacity:0', 'pointer-events:none', 'font-size:16px', 'border:0', 'padding:0']) assert(style.includes(declaration));
  assert.doesNotMatch(style, /display:none|visibility:hidden|inset:0/);
  assert.match(shell, /autocorrect="off" autocapitalize="none" spellcheck="false"/);
  assert.match(shell, /tabindex="-1" aria-label="ローマ字入力 \/ Use an English keyboard/);
  assert.doesNotMatch(shell, /\bautofocus\b/);
  assert.match(shell, /if\(!window\.BlackRelayMobile \|\| !window\.BlackRelayMobile\.isEnabled\(\)\)/);
});

test('composition trailing insertText that reapplies the DOM value is consumed once', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.input.emit('compositionend', {data: 'a'});
  h.insert('a'); assert.deepEqual(h.calls, [['text', 'a']]);
  h.flush(); h.insert('a'); assert.deepEqual(h.calls, [['text', 'a'], ['text', 'a']]);
});

test('independent physical key clears composition dedup; held repeat is prevented', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.input.emit('compositionend', {data: 'a'});
  h.input.emit('keydown', {key: 'a', repeat: false}); h.insert('a');
  assert.deepEqual(h.calls, [['text', 'a'], ['text', 'a']]);
  const repeat = h.input.emit('keydown', {key: 'a', repeat: true}); assert(repeat.defaultPrevented);
});

test('cancelled gestures, drags and multi-touch never activate the game or focus the input', () => {
  const h = harness(); h.update(); const point = {identifier: 1, clientX: 100, clientY: 200};
  const canvas = h.elements.canvas;
  canvas.emit('touchstart', {touches: [point]}); canvas.emit('touchcancel');
  canvas.emit('touchend', {touches: [], changedTouches: [point]});
  canvas.emit('touchstart', {touches: [point]});
  canvas.emit('touchmove', {touches: [{...point, clientX: 160}]});
  canvas.emit('touchend', {touches: [], changedTouches: [point]});
  canvas.emit('touchstart', {touches: [point, {...point, identifier: 2}]});
  canvas.emit('touchend', {touches: [], changedTouches: [point]});
  assert.equal(h.calls.length, 0); assert.equal(h.input.focusCalls.length, 0);
});

test('desktop adaptive canvas dimensions are not overwritten by visualViewport changes', () => {
  const h = harness({touch: false}); h.elements.canvas.width = 1280; h.elements.canvas.height = 720;
  h.window.visualViewport.height = 400; h.window.visualViewport.emit('resize');
  assert.equal(h.elements.canvas.width, 1280); assert.equal(h.elements.canvas.height, 720);
});


test('romaji apostrophe and prolonged-mark hyphen remain legitimate single input', () => {
  const h = harness(); h.start(); h.insert("'"); h.insert('-');
  assert.deepEqual(h.calls, [['text', "'"], ['text', '-']]);
});


test('cancelled ASCII composition never submits its abandoned preedit', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.insert('s', {isComposing: true});
  h.input.emit('compositionend', {data: ''}); assert.equal(h.calls.length, 0);
});

test('switching targets while composing cancels the pending commit safely', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.insert('a', {isComposing: true});
  h.tap(); h.input.emit('compositionend', {data: 'a'}); h.insert('a');
  assert.equal(h.calls.length, 1); assert.equal(h.calls[0][0], 'tap'); h.flush(); h.insert('b');
  assert.deepEqual(h.calls[1], ['text', 'b']);
});

test('loading or missing-WebGL state leaves input disabled and canvas events untouched', () => {
  const h = harness({bind: false}); assert.equal(h.input.disabled, true);
  assert.equal(h.elements.status.hidden, false); const {startEvent, endEvent} = h.tap();
  assert.equal(startEvent.defaultPrevented, false); assert.equal(endEvent.defaultPrevented, false);
  assert.equal(h.calls.length, 0); assert.equal(h.input.focusCalls.length, 0);
});


test('touch gesture across event-loop turns cancels the old IME commit when the target changes', () => {
  const h = harness(); h.start(); h.input.emit('compositionstart'); h.insert('a', {isComposing: true});
  const point = {identifier: 1, clientX: 100, clientY: 200};
  h.elements.canvas.emit('touchstart', {touches: [point]}); h.flush();
  h.elements.canvas.emit('touchend', {touches: [], changedTouches: [point]});
  h.input.emit('compositionend', {data: 'a'}); h.insert('a', {inputType: 'insertFromComposition'});
  assert.equal(h.calls.length, 1); assert.equal(h.calls[0][0], 'tap');
  h.flush(); h.insert('b'); assert.deepEqual(h.calls[1], ['text', 'b']);
});
