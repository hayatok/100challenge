import './style.css';
import { BoardFeedback } from './board-feedback.ts';
import { BoardView } from './board-view.ts';
import { BOARD_WIDTH, clampDropX, FIRST_BOARD_SEED, PinboardRun, REFILL_CHAIN, STEP } from './game.ts';
import type { Kicker, Phase, Upgrade } from './game.ts';
import { GameSound } from './sound.ts';

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const board = element('board');
const launcher = element<HTMLButtonElement>('launcher');
const railHint = element('rail-hint');
const pinGuide = element('pin-guide');
const effects = element('board-effects');
const stage = element('stage');
const remaining = element('remaining');
const score = element('score');
const goal = element('goal');
const combo = element('combo');
const meter = element<HTMLProgressElement>('score-meter');
const status = element('status');
const bootPanel = element('boot-panel');
const bootTitle = element('boot-title');
const bootDetail = element('boot-detail');
const shootPanel = element('shoot-panel');
const activeUpgrade = element('active-upgrade');
const upgradePanel = element('upgrade-panel');
const resultPanel = element('result-panel');
const resultTitle = element('result-title');
const soundButton = element<HTMLButtonElement>('sound-toggle');
const upgradeSplit = element<HTMLButtonElement>('upgrade-split');

const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
const sound = new GameSound();
let soundEnabled = true;
const seedParameter = new URLSearchParams(location.search).get('seed');
const launchSeed = seedParameter && /^\d{1,10}$/.test(seedParameter) ? Number(seedParameter) : FIRST_BOARD_SEED;

function showUnavailable(title: string, detail: string) {
  bootTitle.textContent = title;
  bootDetail.textContent = detail;
  bootPanel.hidden = false;
  bootTitle.focus({ preventScroll: true });
}

function start() {
  let view: BoardView;
  try {
    view = new BoardView(board, motionPreference.matches);
  } catch (error) {
    console.error('Could not create the pinboard renderer.', error);
    showUnavailable('盤面を表示できません', 'WebGL 2 が使えるブラウザで開き直してください。');
    soundButton.disabled = true;
    return;
  }

  let run = new PinboardRun(launchSeed);
  let aimX = run.openingAim;
  let capturedPointer: number | null = null;
  let lastTime: number | undefined;
  let timeBank = 0;
  let drawAvailable = true;
  let metGoal = false;
  let statusTimeout = 0;
  const feedback = new BoardFeedback(board, effects, motionPreference.matches);
  const onKick = (kicker: Kicker, x: number) => {
    feedback.kick(kicker, x);
    sound.kick();
  };
  element('refill-hits').textContent = String(REFILL_CHAIN);
  element('refill-rule').hidden = false;

  function setStatus(message: string, tone: 'neutral' | 'success' = 'neutral', duration = 1800) {
    window.clearTimeout(statusTimeout);
    status.textContent = message;
    status.dataset.tone = tone;
    if (duration > 0 && message) statusTimeout = window.setTimeout(() => { status.textContent = ''; }, duration);
  }

  function updateScore() {
    stage.textContent = String(run.stage);
    remaining.textContent = String(run.remaining);
    score.textContent = String(run.stageScore);
    combo.textContent = String(run.chain);
    goal.textContent = String(run.goal);
    meter.max = run.goal;
    meter.value = run.stageScore;
    const achieved = String(run.stageScore >= run.goal);
    meter.dataset.met = achieved;
    score.closest('.score-goal')?.setAttribute('data-met', achieved);
  }

  function updatePanels() {
    const finished = run.phase === 'clear' || run.phase === 'failed';
    const canPlay = drawAvailable && !finished && run.phase !== 'upgrade';
    if (!canPlay) releasePointer();
    shootPanel.hidden = !canPlay;
    upgradePanel.hidden = !drawAvailable || run.phase !== 'upgrade';
    resultPanel.hidden = !drawAvailable || !finished;
    launcher.disabled = !canPlay;
    updateLauncher();

    activeUpgrade.hidden = !canPlay || run.upgrade === null;
    activeUpgrade.textContent = run.upgrade === 'split' ? '＝ 青ピンで3球に分裂' : '＋ 黄ピンから2球追加';

    if (finished) {
      const clear = run.phase === 'clear';
      resultPanel.dataset.outcome = clear ? 'clear' : 'failed';
      resultTitle.textContent = clear ? '2面クリア' : `第${run.stage}面で終了`;
      element('result-description').textContent = clear
        ? ''
        : `ノルマまであと ${run.goal - run.stageScore} 点`;
      element('total-score').textContent = String(run.totalScore);
      element('max-chain').textContent = String(run.bestChain);
    }
  }

  function updateLauncher() {
    launcher.setAttribute('aria-disabled', String(!run.canDrop || !drawAvailable));
    railHint.hidden = launcher.disabled || !run.canDrop || run.shotsUsed > 0;
    pinGuide.hidden = railHint.hidden;
  }

  function canAim() {
    return !launcher.disabled && run.hasPins;
  }

  function showBoard() {
    timeBank = 0;
    lastTime = undefined;
    metGoal = false;
    aimX = run.openingAim;
    feedback.reset();
    setStatus('');
    view.reset(run.pins, run.stage, run.kickers);
    updateScore();
    updatePanels();
  }

  function aimAtPointer(event: PointerEvent) {
    const rect = board.getBoundingClientRect();
    if (rect.width > 0) aimX = clampDropX((event.clientX - rect.left) * BOARD_WIDTH / rect.width);
  }

  function releasePointer() {
    const pointer = capturedPointer;
    capturedPointer = null;
    if (pointer !== null && launcher.hasPointerCapture(pointer)) launcher.releasePointerCapture(pointer);
    delete launcher.dataset.grabbed;
  }

  function shoot() {
    if (!drawAvailable || !run.drop(aimX)) return;
    sound.activate();
    sound.launch();
    updateScore();
    updatePanels();
    setStatus(run.canDrop ? '' : '補充待ち　先に狙えます', 'neutral', 0);
  }

  function applyUpgrade(upgrade: Upgrade) {
    if (!drawAvailable || !run.chooseUpgrade(upgrade)) return;
    sound.activate();
    showBoard();
    launcher.focus({ preventScroll: true });
  }

  function restart(seed: number) {
    if (!drawAvailable || (run.phase !== 'clear' && run.phase !== 'failed')) return;
    sound.activate();
    run = new PinboardRun(seed);
    showBoard();
    launcher.focus({ preventScroll: true });
  }

  function onPhaseChange(before: Phase) {
    if (before === run.phase) return;
    updatePanels();
    if (run.phase === 'upgrade') {
      setStatus('');
      upgradeSplit.focus({ preventScroll: true });
    } else if (run.phase === 'clear' || run.phase === 'failed') {
      if (run.phase === 'failed') sound.fail();
      setStatus('');
      resultTitle.focus({ preventScroll: true });
    }
  }

  launcher.addEventListener('pointermove', (event) => {
    if (!canAim()) return;
    if (capturedPointer === event.pointerId || (capturedPointer === null && event.pointerType === 'mouse')) aimAtPointer(event);
  });
  launcher.addEventListener('pointerdown', (event) => {
    if (!canAim() || capturedPointer !== null || !event.isPrimary || event.button !== 0) return;
    capturedPointer = event.pointerId;
    launcher.setPointerCapture(event.pointerId);
    launcher.dataset.grabbed = 'true';
    aimAtPointer(event);
  });
  launcher.addEventListener('pointerup', (event) => {
    if (capturedPointer !== event.pointerId) return;
    aimAtPointer(event);
    releasePointer();
    shoot();
  });
  launcher.addEventListener('pointercancel', (event) => {
    if (capturedPointer === event.pointerId) releasePointer();
  });
  launcher.addEventListener('lostpointercapture', (event) => {
    if (capturedPointer === event.pointerId) releasePointer();
  });
  launcher.addEventListener('click', (event) => {
    // Assistive activation has no pointer sequence.
    if (event.detail === 0 && capturedPointer === null) shoot();
  });
  upgradeSplit.addEventListener('click', () => applyUpgrade('split'));
  element('upgrade-bonus').addEventListener('click', () => applyUpgrade('bonus'));
  element('retry').addEventListener('click', () => restart(run.seed));
  element('new-board').addEventListener('click', () => {
    const [seed] = crypto.getRandomValues(new Uint32Array(1));
    restart(seed === run.seed ? (seed + 1) >>> 0 : seed);
  });

  soundButton.addEventListener('click', () => {
    soundEnabled = !soundEnabled;
    sound.setEnabled(soundEnabled);
    if (soundEnabled) sound.activate();
    soundButton.setAttribute('aria-pressed', String(soundEnabled));
    soundButton.textContent = soundEnabled ? '音あり' : '音なし';
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && capturedPointer !== null) {
      releasePointer();
      return;
    }
    const onLauncher = event.target === launcher;
    const launchKey = event.code === 'Space' || (onLauncher && event.key === 'Enter');
    if (event.repeat && event.target instanceof HTMLButtonElement && (event.key === 'Enter' || event.code === 'Space')) {
      event.preventDefault();
      return;
    }
    // The rail's native activation must also pass the pointer and shot guards.
    if (onLauncher && launchKey) event.preventDefault();
    if (!canAim() || capturedPointer !== null || event.altKey || event.ctrlKey || event.metaKey) return;
    if (event.target instanceof HTMLButtonElement && !onLauncher) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      aimX = clampDropX(aimX + (event.key === 'ArrowLeft' ? -8 : 8));
    } else if (launchKey) {
      event.preventDefault();
      if (!event.repeat) shoot();
    }
  });

  motionPreference.addEventListener('change', (event) => {
    view.setReducedMotion(event.matches);
    feedback.setReducedMotion(event.matches);
  });
  window.addEventListener('blur', releasePointer);
  document.addEventListener('visibilitychange', () => {
    lastTime = undefined;
    timeBank = 0;
    if (document.hidden) {
      releasePointer();
      feedback.reset();
    }
  });
  const canvas = board.querySelector('canvas');
  canvas?.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    drawAvailable = false;
    feedback.reset();
    updatePanels();
    setStatus('');
    showUnavailable('描画を一時停止', '画面が戻らない場合は、再読み込みしてください。');
  });
  canvas?.addEventListener('webglcontextrestored', () => {
    const restoreFocus = document.activeElement === bootTitle;
    drawAvailable = true;
    lastTime = undefined;
    timeBank = 0;
    bootPanel.hidden = true;
    updatePanels();
    if (restoreFocus) {
      const control = run.phase === 'upgrade' ? upgradeSplit : launcher.disabled ? resultTitle : launcher;
      control.focus({ preventScroll: true });
    }
  });

  showBoard();
  bootPanel.hidden = true;
  view.animate((now) => {
    if (!drawAvailable || document.hidden) return;
    const delta = Math.min((now - (lastTime ?? now)) / 1000, 0.05);
    lastTime = now;
    const phaseBefore = run.phase;
    const wasEmpty = run.remaining === 0;
    let refills = 0;
    if (run.phase === 'dropping') {
      timeBank += delta;
      while (timeBank >= STEP && run.phase === 'dropping') {
        const impacts = run.step(STEP, onKick);
        for (const impact of impacts) {
          view.hit(impact);
          feedback.hit(impact);
          sound.hit(impact.pin.kind, impact.chain);
          if (impact.earnedBall) refills++;
        }
        if (impacts.length) {
          updateScore();
          updateLauncher();
          if (!run.hasPins) {
            releasePointer();
            setStatus('全ピン撃破　落下が終わるまで待機', 'success', 0);
          }
        }
        if (!metGoal && run.stageScore >= run.goal) {
          metGoal = true;
          feedback.goal();
          sound.clear();
          if (run.hasPins) setStatus('ノルマ達成', 'success');
        }
        timeBank -= STEP;
      }
    } else {
      timeBank = 0;
    }
    if (refills > 0) {
      feedback.refill(refills, remaining);
      sound.refill();
      if (run.canDrop) {
        if (wasEmpty) view.refillAim();
        setStatus(wasEmpty ? `＋${refills}球　今すぐ投球` : `手持ち ＋${refills}球`, 'success');
      }
    }
    onPhaseChange(phaseBefore);
    view.draw(run.balls, canAim() ? aimX : null, run.remaining > 0, delta);
  });
}

start();
