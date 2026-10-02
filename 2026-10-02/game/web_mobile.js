/* BLACK RELAY touch controls. Godot owns gameplay; this bridge owns DOM text input. */
(function (window, document) {
  'use strict';

  const input = document.getElementById('mobile-input');
  const root = document.getElementById('mobile-ui');
  if (!input || !root) return;
  const byId = (id) => document.getElementById(id);
  const menu = byId('mobile-menu');
  const play = byId('mobile-play');
  const actions = byId('mobile-actions');
  const begin = byId('mobile-begin');
  const keyboard = byId('mobile-keyboard');
  const toggle = byId('mobile-toggle');
  const hint = byId('mobile-input-hint');
  const SENTINEL = '\u200b'; // Lets soft-keyboard Backspace work even after a consumed letter.
  const ENGLISH_HINT = '英字キーボードで入力 / Use an English keyboard (a–z).';
  const SINGLE_HINT = '1文字ずつ入力。貼り付け・予測変換は使えません / Type letters; no paste or prediction.';
  const states = new Set(['title', 'settings', 'intermission', 'playing', 'paused', 'ending', 'victory', 'defeat']);
  const headings = {
    title: 'BLACK RELAY', settings: '設定 / SETTINGS', intermission: '街へ出る / BEGIN',
    paused: '一時停止 / PAUSED', ending: '避難路、確保 / STREET CLEARED',
    victory: '脱出成功 / ESCAPED', defeat: '脱出失敗 / RUN ENDED'
  };
  let enabled = Boolean((window.matchMedia && window.matchMedia('(any-pointer: coarse)').matches) ||
    (window.navigator && window.navigator.maxTouchPoints > 0));
  const manualCanvasSize = enabled; // Desktop opt-in keeps Godot's adaptive resize policy.
  let callback = null;
  let model = {state: 'title', actions: []};
  let composing = false;
  let compositionCommit = null;
  let cancelledComposition = false;
  let resetPending = false;
  let lostFocus = false;
  let actionSignature = '';
  let notice = '';

  function text(id, value) {
    const element = byId(id);
    const next = String(value == null ? '' : value);
    if (element.textContent !== next) element.textContent = next;
  }

  function stop(event) { event.stopPropagation(); }
  function clearInput() { input.value = SENTINEL; }
  function cancelComposition() {
    if (composing) {
      cancelledComposition = true;
      window.setTimeout(() => { cancelledComposition = false; }, 0);
    }
    composing = false;
    compositionCommit = null;
    clearInput();
  }
  function ownsFocus() { return document.activeElement === input; }
  function acceptsText() { return enabled && callback && model.state === 'playing' && ownsFocus(); }
  function send(action, value) { if (callback) callback(action, value || ''); }
  function showNotice(value) { notice = value; refreshHint(); }
  function refreshHint() {
    hint.textContent = notice || (ownsFocus() ? ENGLISH_HINT : '入力欄か「キーボード」をタップ / Tap the input or Keyboard to type.');
    keyboard.textContent = ownsFocus() ? 'キーボード / Keyboard' : '入力する / Keyboard';
  }

  // Only call from click/tap handlers. Synchronous focus is required by iOS WebKit.
  function focusFromGesture() {
    if (!enabled || !callback || model.state !== 'playing') return;
    clearInput();
    input.focus({preventScroll: true});
    refreshHint();
  }

  function actFromGesture(action, value) {
    cancelComposition();
    notice = '';
    send(action, value);
    // The retained Godot callback synchronously publishes its new state via update().
    if (model.state === 'playing') focusFromGesture();
  }

  function bindButton(button, action, value) {
    button.addEventListener('pointerdown', (event) => {
      stop(event);
      // Keep the text field active when switching/resetting a live target.
      if (ownsFocus() && model.state === 'playing') event.preventDefault();
    });
    button.addEventListener('click', (event) => {
      stop(event);
      if (!button.disabled) actFromGesture(action, value);
    });
  }

  bindButton(begin, 'begin');
  bindButton(byId('mobile-pause'), 'pause');
  bindButton(byId('mobile-cycle'), 'cycle');
  bindButton(byId('mobile-reset'), 'reset');
  keyboard.addEventListener('pointerdown', stop);
  keyboard.addEventListener('click', (event) => { stop(event); notice = ''; focusFromGesture(); });
  toggle.addEventListener('click', (event) => {
    stop(event);
    enabled = true;
    render();
    focusFromGesture();
  });
  // Never let DOM control gestures become canvas menu or enemy clicks.
  for (const event of ['pointerdown', 'pointerup', 'click', 'touchstart', 'touchend']) root.addEventListener(event, stop);

  function render() {
    document.body.classList.toggle('mobile-mode', enabled);
    root.hidden = !enabled || !callback;
    toggle.hidden = enabled || !callback;
    const playing = model.state === 'playing';
    menu.hidden = playing;
    play.hidden = !playing;
    input.disabled = !playing || !callback;
    keyboard.disabled = !playing || !callback;
    byId('mobile-pause').disabled = !playing || !callback;
    byId('mobile-cycle').disabled = !playing || !callback;
    byId('mobile-reset').disabled = !playing || !callback;
    begin.hidden = model.state !== 'intermission';
    begin.disabled = !callback;
    if (!playing) {
      cancelComposition();
      if (ownsFocus()) input.blur();
    }
    text('mobile-heading', headings[model.state] || 'BLACK RELAY');
    text('mobile-summary', model.state === 'intermission'
      ? '白い単語を最後まで入力。一語、一発。英字キーボードを選んで出発 / Type the whole word to fire.'
      : model.state === 'ending' ? '出口へ移動中… / Reaching the exit…'
      : model.state === 'victory' || model.state === 'defeat' ? 'SCORE ' + (model.score || 0)
      : model.state === 'paused' ? '再開をタップするとキーボードが開きます / Tap Resume to open the keyboard.'
      : model.state === 'settings' ? '項目をタップして変更 / Tap a setting to change it.'
      : '一語、一発。黒雨の街を抜けろ / One word. One shot. Escape the street.');
    text('mobile-target', model.target || '標的を待っています / Keep moving');
    text('mobile-typed', model.typed || '');
    text('mobile-remaining', model.remaining || '');
    text('mobile-cut', model.cut || '');
    byId('mobile-cut').hidden = !model.cut;
    text('mobile-hp', 'HP ' + (model.hp == null ? '–' : model.hp));
    text('mobile-score', 'SCORE ' + (model.score == null ? '0' : model.score));

    // Publish changes without replacing focused buttons on every Godot frame.
    const menuActions = model.state !== 'intermission' && Array.isArray(model.actions) ? model.actions : [];
    const signature = JSON.stringify(menuActions.map((item) => [String(item.label || ''), item.enabled !== false]));
    if (signature !== actionSignature) {
      actionSignature = signature;
      actions.replaceChildren();
      menuActions.forEach((item, index) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = String(item.label || 'ACTION ' + (index + 1));
        button.disabled = item.enabled === false || !callback;
        button.className = index === 0 ? 'mobile-primary' : '';
        bindButton(button, 'menu', String(index));
        actions.appendChild(button);
      });
    }
    refreshHint();
  }

  function update(payload) {
    let next;
    try { next = typeof payload === 'string' ? JSON.parse(payload) : payload; }
    catch (_) { return false; }
    if (!next || !states.has(next.state)) return false;
    if (next.state !== model.state) notice = '';
    model = next;
    render();
    return true;
  }

  function consume(value, composition) {
    if (!acceptsText() || !value) return;
    if (!/^[a-z'-]+$/i.test(value)) { showNotice(ENGLISH_HINT); return; }
    if (!composition && value.length !== 1) { showNotice(SINGLE_HINT); return; }
    notice = '';
    send('text', value.toLowerCase());
    refreshHint();
  }

  function rejectTransfer(event) {
    stop(event);
    event.preventDefault();
    cancelComposition();
    showNotice(SINGLE_HINT);
  }
  input.addEventListener('paste', rejectTransfer);
  input.addEventListener('drop', rejectTransfer);
  input.addEventListener('dragover', (event) => { stop(event); event.preventDefault(); });
  input.addEventListener('beforeinput', (event) => {
    stop(event);
    if (!acceptsText()) { event.preventDefault(); clearInput(); return; }
    if (/^(insertFromPaste|insertFromDrop|insertReplacementText|history)/.test(event.inputType || '')) {
      rejectTransfer(event); return;
    }
    if ((event.inputType || '').startsWith('delete') && !composing && !event.isComposing) {
      event.preventDefault();
      resetPending = true;
      window.setTimeout(() => { resetPending = false; }, 0);
      clearInput();
      notice = '';
      send('reset');
    }
  });
  input.addEventListener('compositionstart', (event) => {
    stop(event);
    composing = true;
    cancelledComposition = false;
    compositionCommit = null;
  });
  input.addEventListener('compositionupdate', stop);
  input.addEventListener('compositionend', (event) => {
    stop(event);
    if (!composing) { clearInput(); return; }
    composing = false;
    const value = String(event.data == null ? input.value.replaceAll(SENTINEL, '') : event.data);
    compositionCommit = value;
    // Safari may dispatch one final non-composing input after compositionend.
    window.setTimeout(() => { compositionCommit = null; }, 0);
    clearInput();
    consume(value, true);
  });
  input.addEventListener('input', (event) => {
    stop(event);
    if (composing || event.isComposing) return;
    if (cancelledComposition) { clearInput(); return; }
    if (!acceptsText()) { clearInput(); return; }
    const type = event.inputType || '';
    if (/^(insertFromPaste|insertFromDrop|insertReplacementText|history)/.test(type)) {
      clearInput(); showNotice(SINGLE_HINT); return;
    }
    if (type.startsWith('delete')) {
      clearInput();
      if (!resetPending) send('reset');
      resetPending = false;
      return;
    }
    const value = String(event.data == null ? input.value.replaceAll(SENTINEL, '') : event.data);
    if (compositionCommit !== null && value === compositionCommit) {
      compositionCommit = null;
      clearInput();
      return;
    }
    compositionCommit = null;
    clearInput();
    consume(value, false);
  });
  // Text is sent ONLY by input/compositionend, never by keydown.
  input.addEventListener('keydown', (event) => {
    stop(event);
    if (event.repeat) { event.preventDefault(); return; }
    if (composing || event.isComposing || event.keyCode === 229) return;
    compositionCommit = null; // An independent physical key is never a composition tail.
    cancelledComposition = false;
    if (event.key === 'Escape' || event.key === 'Tab' || event.key === 'Enter') {
      event.preventDefault();
      if (model.state === 'playing') actFromGesture(event.key === 'Escape' ? 'pause' : 'cycle');
    }
  });
  input.addEventListener('keyup', stop);
  input.addEventListener('keypress', stop);
  input.addEventListener('focus', () => { clearInput(); refreshHint(); });
  input.addEventListener('blur', () => { cancelComposition(); refreshHint(); });

  function focusLost() {
    if (lostFocus) return;
    lostFocus = true;
    cancelComposition();
    if (ownsFocus()) input.blur();
    send('focus_lost');
  }
  window.addEventListener('blur', focusLost);
  window.addEventListener('focus', () => { if (!document.hidden) lostFocus = false; });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) focusLost();
    else lostFocus = false; // Return requires an explicit Resume or Keyboard tap.
  });

  function resize() {
    const viewport = window.visualViewport;
    const height = viewport ? viewport.height : window.innerHeight;
    const top = viewport ? viewport.offsetTop : 0;
    const left = viewport ? viewport.offsetLeft || 0 : 0;
    const width = viewport ? viewport.width : window.innerWidth;
    const cssWidth = Math.max(1, width || window.innerWidth || 1);
    if (manualCanvasSize) {
      const canvas = byId('canvas');
      const ratio = window.devicePixelRatio || 1;
      const cssHeight = Math.max(1, height);
      // canvasResizePolicy=0 makes Godot track these externally owned dimensions.
      const pixelWidth = Math.round(cssWidth * ratio);
      const pixelHeight = Math.round(cssHeight * ratio);
      if (canvas.width !== pixelWidth) canvas.width = pixelWidth;
      if (canvas.height !== pixelHeight) canvas.height = pixelHeight;
      canvas.style.position = 'absolute';
      canvas.style.top = Math.max(0, top) + 'px';
      canvas.style.left = Math.max(0, left) + 'px';
      canvas.style.width = cssWidth + 'px';
      canvas.style.height = cssHeight + 'px';
    }
    document.documentElement.style.setProperty('--br-visual-height', Math.max(1, height) + 'px');
    document.documentElement.style.setProperty('--br-visual-top', Math.max(0, top) + 'px');
    document.documentElement.style.setProperty('--br-visual-left', Math.max(0, left) + 'px');
    document.documentElement.style.setProperty('--br-visual-width', cssWidth + 'px');
  }
  window.addEventListener('resize', resize);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', resize);
    window.visualViewport.addEventListener('scroll', resize);
  }
  window.BlackRelayMobile = {
    bindGame(fn) {
      callback = typeof fn === 'function' ? fn : null;
      actionSignature = ''; // Rebuild action enabled states if the bridge reconnects.
      render();
    },
    update,
    ownsFocus,
    isEnabled: () => enabled
  };
  clearInput();
  resize();
  render();
})(window, document);
