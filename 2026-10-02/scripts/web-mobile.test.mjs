import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../game/web_mobile.js', import.meta.url), 'utf8');
const shell = readFileSync(new URL('../game/web_shell.html', import.meta.url), 'utf8');
const SENTINEL = '\u200b';

class Target {
  listeners = new Map();
  addEventListener(type, fn) {
    if (!this.listeners.has(type)) this.listeners.set(type, []);
    this.listeners.get(type).push(fn);
  }
  emit(type, properties = {}) {
    const event = {type, defaultPrevented: false, propagationStopped: false,
      preventDefault() { this.defaultPrevented = true; },
      stopPropagation() { this.propagationStopped = true; }, ...properties};
    for (const listener of this.listeners.get(type) || []) listener(event);
    return event;
  }
}
class Element extends Target {
  constructor(doc) {
    super(); this.doc = doc; this.children = []; this.hidden = false; this.disabled = false;
    this.textContent = ''; this.value = ''; this.className = ''; this.focusCalls = []; this.style = {};
  }
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
  function start() { update(); elements['mobile-keyboard'].emit('click'); calls.length = 0; }
  function insert(value, extra = {}) {
    input.value = SENTINEL + value;
    return input.emit('input', {data: value, inputType: 'insertText', isComposing: false, ...extra});
  }
  return {document, window, elements, bridge, input, calls, classes, css, update, start, insert,
    flush() { while (timers.length) timers.shift()(); },
    handle(fn) { handler = fn; }};
}

test('coarse pointer enables touch UI; desktop stays unchanged until opt-in', () => {
  const mobile = harness(); assert.equal(mobile.bridge.isEnabled(), true);
  assert.equal(mobile.elements['mobile-ui'].hidden, false); assert(mobile.classes.has('mobile-mode'));
  const desktop = harness({touch: false}); desktop.update();
  assert.equal(desktop.bridge.isEnabled(), false); assert.equal(desktop.elements['mobile-ui'].hidden, true);
  assert.equal(desktop.elements['mobile-toggle'].hidden, false); assert.equal(desktop.input.focusCalls.length, 0);
  desktop.elements['mobile-toggle'].emit('click');
  assert.equal(desktop.bridge.isEnabled(), true); assert.equal(desktop.bridge.ownsFocus(), true);
});

test('updates never autofocus, and keyboard tap focuses in the click stack', () => {
  const h = harness(); h.update(); h.update();
  assert.equal(h.input.focusCalls.length, 0);
  h.elements['mobile-keyboard'].emit('click');
  assert.equal(h.bridge.ownsFocus(), true); assert.equal(h.input.focusCalls[0].preventScroll, true);
  h.update(); assert.equal(h.input.focusCalls.length, 1);
});

test('start → briefing → begin and resume focus synchronously after game callback', () => {
  const h = harness(); h.update('title', {actions: [{label: 'START', enabled: true}, {label: 'SETTINGS', enabled: true}]});
  h.handle((action, value) => {
    if (action === 'menu' && value === '0') h.update(h.elements['mobile-heading'].textContent.includes('PAUSED') ? 'playing' : 'intermission');
    if (action === 'begin') h.update('playing');
  });
  h.elements['mobile-actions'].children[0].emit('click');
  assert.deepEqual(h.calls, [['menu', '0']]); assert.equal(h.bridge.ownsFocus(), false);
  assert.equal(h.elements['mobile-begin'].hidden, false);
  h.elements['mobile-begin'].emit('click'); assert.equal(h.bridge.ownsFocus(), true);
  h.update('paused', {actions: [{label: '再開 / RESUME', enabled: true}]});
  assert.equal(h.bridge.ownsFocus(), false);
  h.elements['mobile-actions'].children[0].emit('click'); assert.equal(h.bridge.ownsFocus(), true);
});

test('menu labels and disabled settings are rendered; stable updates retain buttons', () => {
  const h = harness(); const actions = [{label: '音量 72%', enabled: true}, {label: '難易度 LOCK', enabled: false}];
  h.update('settings', {actions}); const button = h.elements['mobile-actions'].children[0];
  assert.equal(button.textContent, '音量 72%');
  const locked = h.elements['mobile-actions'].children[1]; assert.equal(locked.disabled, true);
  locked.emit('click'); assert.equal(h.calls.length, 0);
  h.update('settings', {actions}); assert.equal(h.elements['mobile-actions'].children[0], button);
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
  assert.equal(h.calls.length, 0); assert.match(h.elements['mobile-input-hint'].textContent, /English keyboard/);
});

test('paste, drop, replacement and fallback transfer input cannot submit a free word', () => {
  const h = harness(); h.start();
  for (const type of ['paste', 'drop']) assert(h.input.emit(type).defaultPrevented);
  for (const inputType of ['insertFromPaste', 'insertFromDrop', 'insertReplacementText', 'historyUndo']) {
    const event = h.input.emit('beforeinput', {inputType}); assert(event.defaultPrevented);
    h.insert('zankyou', {inputType});
  }
  h.insert('zankyou'); assert.equal(h.calls.length, 0);
  assert.match(h.elements['mobile-input-hint'].textContent, /no paste or prediction/);
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

test('combat tap controls preserve focus and use the same game actions', () => {
  const h = harness(); h.start();
  const cycle = h.elements['mobile-cycle']; assert(cycle.emit('pointerdown').defaultPrevented);
  cycle.emit('click'); h.elements['mobile-reset'].emit('click');
  assert.deepEqual(h.calls, [['cycle', ''], ['reset', '']]); assert.equal(h.bridge.ownsFocus(), true);
  h.handle((action) => { if (action === 'pause') h.update('paused'); });
  h.elements['mobile-pause'].emit('click'); assert.equal(h.bridge.ownsFocus(), false);
  assert.deepEqual(h.calls.at(-1), ['pause', '']);
});

test('window loss and backgrounding pause once; return never reopens the keyboard', () => {
  const h = harness(); h.start(); h.handle((action) => { if (action === 'focus_lost') h.update('paused'); });
  h.window.emit('blur'); h.document.hidden = true; h.document.emit('visibilitychange');
  assert.deepEqual(h.calls, [['focus_lost', '']]); assert.equal(h.bridge.ownsFocus(), false);
  const focusCount = h.input.focusCalls.length;
  h.document.hidden = false; h.document.emit('visibilitychange'); h.window.emit('focus');
  assert.equal(h.input.focusCalls.length, focusCount);
  h.update(); h.elements['mobile-keyboard'].emit('click'); assert.equal(h.bridge.ownsFocus(), true);
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

test('payload shows typed target, optional cut, hp and score; invalid payload is ignored', () => {
  const h = harness(); h.update(); assert.equal(h.elements['mobile-typed'].textContent, 'za');
  assert.equal(h.elements['mobile-remaining'].textContent, 'nkyou');
  assert.equal(h.elements['mobile-cut'].textContent, 'CUT: i | to');
  assert.equal(h.elements['mobile-hp'].textContent, 'HP 6'); assert.equal(h.elements['mobile-score'].textContent, 'SCORE 20');
  assert.equal(h.bridge.update('{'), false); assert.equal(h.bridge.update('{"state":"invalid"}'), false);
  h.update('playing', {target: '', typed: '', remaining: '', cut: ''});
  assert.equal(h.elements['mobile-cut'].hidden, true); assert.match(h.elements['mobile-target'].textContent, /Keep moving/);
});

test('HTML preserves desktop controls and accessible mobile input essentials', () => {
  assert.match(shell, /<canvas id="canvas" tabindex="0"/);
  assert.match(shell, /src="web_mobile\.js"/);
  assert.match(shell, /font-size:16px/); assert.match(shell, /min-height:44px/);
  assert.match(shell, /autocorrect="off" autocapitalize="none" spellcheck="false"/);
  assert.match(shell, /aria-describedby="mobile-input-hint"/);
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

test('intermission exposes one accessible begin button despite the canvas action list', () => {
  const h = harness(); h.update('intermission', {actions: [{label: '街へ出る / START', enabled: true}]});
  assert.equal(h.elements['mobile-actions'].children.length, 0); assert.equal(h.elements['mobile-begin'].hidden, false);
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
  h.elements['mobile-cycle'].emit('click'); h.input.emit('compositionend', {data: 'a'}); h.insert('a');
  assert.deepEqual(h.calls, [['cycle', '']]); h.flush(); h.insert('b');
  assert.deepEqual(h.calls, [['cycle', ''], ['text', 'b']]);
});

test('loading or missing-WebGL state exposes no playable touch controls', () => {
  const h = harness({bind: false}); assert.equal(h.elements['mobile-ui'].hidden, true);
  assert.equal(h.elements['mobile-toggle'].hidden, true); assert.equal(h.input.disabled, true);
  assert.equal(h.elements.status.hidden, false);
  assert.match(shell, /#status\{[^}]*z-index:3/);
  assert.match(shell, /#mobile-ui\{[^}]*z-index:2/);
});
