/* BLACK RELAY keyboard bridge. All visible controls and words stay in the Godot HUD. */
(function (window, document) {
  'use strict';

  const input = document.getElementById('mobile-input');
  const canvas = document.getElementById('canvas');
  if (!input || !canvas) return;
  const SENTINEL = '\u200b'; // Lets soft-keyboard Backspace work even after a consumed letter.
  const ENGLISH_HINT = '英字キーボードで入力 / Use an English keyboard (a–z).';
  const SINGLE_HINT = '1文字ずつ入力。貼り付け・予測変換は使えません / Type letters; no paste or prediction.';
  const states = new Set(['title', 'settings', 'intermission', 'playing', 'paused', 'ending', 'victory', 'defeat']);
  const enabled = Boolean((window.matchMedia && window.matchMedia('(any-pointer: coarse)').matches) ||
    (window.navigator && window.navigator.maxTouchPoints > 0));
  let callback = null;
  let model = {state: 'title', actions: []};
  let composing = false;
  let compositionCommit = null;
  let cancelledComposition = false;
  let resetPending = false;
  let lostFocus = false;
  let touch = null;

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
  function showNotice(value) { input.setAttribute('aria-description', value); }

  // Only called in a real touchend or keyboard handler, never by update()/a frame.
  function focusFromGesture() {
    if (!enabled || !callback || model.state !== 'playing') return;
    clearInput();
    // iOS can keep activeElement after dismissing the keyboard. Blur/refocus in
    // this same gesture reopens it, without any timers or polling for focus.
    if (ownsFocus()) input.blur();
    input.focus({preventScroll: true});
  }

  function actFromGesture(action, value) {
    cancelComposition();
    send(action, value);
    // The Godot callback synchronously publishes the state after the HUD action.
    if (model.state === 'playing') focusFromGesture();
  }

  function takeTouch(event) {
    if (!enabled || !callback) return false;
    // Handle this canvas touch once, before Godot's buffered touch-to-mouse path
    // can focus the canvas or queue the same menu action. Desktop mouse and key
    // handlers are untouched. The input itself has pointer-events:none.
    event.preventDefault();
    event.stopImmediatePropagation();
    return true;
  }
  const touchOptions = {capture: true, passive: false};
  canvas.addEventListener('touchstart', (event) => {
    if (!takeTouch(event)) return;
    touch = event.touches.length === 1 ? {
      id: event.touches[0].identifier,
      x: event.touches[0].clientX,
      y: event.touches[0].clientY
    } : null;
  }, touchOptions);
  canvas.addEventListener('touchmove', (event) => {
    if (!takeTouch(event)) return;
    const point = Array.from(event.touches).find((item) => item.identifier === touch?.id);
    if (!point || Math.hypot(point.clientX - touch.x, point.clientY - touch.y) > 20) touch = null;
  }, touchOptions);
  canvas.addEventListener('touchcancel', (event) => {
    if (takeTouch(event)) touch = null;
  }, touchOptions);
  canvas.addEventListener('touchend', (event) => {
    if (!takeTouch(event)) return;
    const point = Array.from(event.changedTouches).find((item) => item.identifier === touch?.id);
    const previous = touch;
    touch = null;
    if (!point || event.touches.length || Math.hypot(point.clientX - previous.x, point.clientY - previous.y) > 20) return;
    const rect = canvas.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    const x = (point.clientX - rect.left) / rect.width;
    const y = (point.clientY - rect.top) / rect.height;
    if (x < 0 || x > 1 || y < 0 || y > 1) return;
    actFromGesture('tap', JSON.stringify({x, y}));
  }, touchOptions);

  function render() {
    document.body.classList.toggle('mobile-mode', enabled);
    input.disabled = !enabled || !callback || model.state !== 'playing';
    if (input.disabled) {
      cancelComposition();
      if (ownsFocus()) input.blur();
    }
  }

  function update(payload) {
    let next;
    try { next = typeof payload === 'string' ? JSON.parse(payload) : payload; }
    catch (_) { return false; }
    if (!next || !states.has(next.state)) return false;
    model = next;
    render();
    return true;
  }

  function consume(value, composition) {
    if (!acceptsText() || !value) return;
    if (!/^[a-z'-]+$/i.test(value)) { showNotice(ENGLISH_HINT); return; }
    if (!composition && value.length !== 1) { showNotice(SINGLE_HINT); return; }
    send('text', value.toLowerCase());
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
  input.addEventListener('focus', clearInput);
  input.addEventListener('blur', cancelComposition);

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
    else lostFocus = false; // Return requires an explicit in-game Resume tap.
  });

  function resize() {
    const viewport = window.visualViewport;
    const height = viewport ? viewport.height : window.innerHeight;
    const top = viewport ? viewport.offsetTop : 0;
    const left = viewport ? viewport.offsetLeft || 0 : 0;
    const width = viewport ? viewport.width : window.innerWidth;
    const cssWidth = Math.max(1, width || window.innerWidth || 1);
    if (enabled) {
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
