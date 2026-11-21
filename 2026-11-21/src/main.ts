import './style.css';
import { BoardFeedback } from './board-feedback.ts';
import { BoardView } from './board-view.ts';
import { BOARD_WIDTH, clampDropX, DEFAULT_DROP_X, FIRST_BOARD_SEED, PinboardRun, REFILL_CHAIN, STEP } from './game.ts';
import type { Phase, Upgrade } from './game.ts';
import { GameSound } from './sound.ts';

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const board = element('board');
const launcher = element<HTMLButtonElement>('launcher');
const railHint = element('rail-hint');
const effects = element('board-effects');
const stage = element('stage');
const remaining = element('remaining');
const score = element('score');
const goal = element('goal');
const combo = element('combo');
const meter = element<HTMLProgressElement>('score-meter');
const status = element('status');
const shootPanel = element('shoot-panel');
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

function setStatus(message: string, tone: 'neutral' | 'success' | 'error' = 'neutral') {
  status.textContent = message;
  status.hidden = message.length === 0;
  status.dataset.tone = tone;
}

function start() {
  let view: BoardView;
  try {
    view = new BoardView(board, motionPreference.matches);
  } catch (error) {
    console.error('Could not create the pinboard renderer.', error);
    setStatus('盤面を表示できませんでした。WebGL 2 が使えるブラウザで開き直してください。', 'error');
    soundButton.disabled = true;
    return;
  }

  let run = new PinboardRun(launchSeed);
  let aimX = DEFAULT_DROP_X;
  let capturedPointer: number | null = null;
  let lastTime: number | undefined;
  let timeBank = 0;
  let drawAvailable = true;
  let metGoal = false;
  const feedback = new BoardFeedback(board, effects, motionPreference.matches);
  element('refill-hits').textContent = String(REFILL_CHAIN);
  element('refill-rule').hidden = false;

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
    shootPanel.hidden = finished || run.phase === 'upgrade';
    upgradePanel.hidden = run.phase !== 'upgrade';
    resultPanel.hidden = !finished;
    launcher.disabled = !drawAvailable || shootPanel.hidden;
    updateLauncher();

    const active = element('active-upgrade');
    active.hidden = run.upgrade === null;
    active.textContent = run.upgrade === 'split' ? '強化中 · 青ピンで3球に分裂' : '強化中 · 黄ピンから2球追加';
    element('split-rule').textContent = run.upgrade === 'split' ? 'その場で3球に分裂' : 'その場で2球に分裂';
    element('bonus-rule').textContent = run.upgrade === 'bonus' ? 'レールの左右から各1球追加' : 'レールの左・中央・右のいずれかから1球追加';

    if (finished) {
      const clear = run.phase === 'clear';
      resultTitle.textContent = clear ? '2面クリア' : `第${run.stage}面で終了`;
      element('result-description').textContent = clear
        ? '同じ配置でもう一方の強化を試せます。'
        : `ノルマまであと ${run.goal - run.stageScore} 点でした。`;
      element('total-score').textContent = String(run.totalScore);
      element('max-chain').textContent = String(run.bestChain);
    }
  }

  function updateLauncher() {
    launcher.setAttribute('aria-disabled', String(!run.canDrop || !drawAvailable));
    railHint.hidden = !run.canDrop || run.shotsUsed > 0;
  }

  function showBoard() {
    timeBank = 0;
    lastTime = undefined;
    metGoal = false;
    feedback.reset();
    view.reset(run.pins, run.stage);
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
    const action = run.canDrop ? `あと ${run.remaining} 球、すぐ放せます。` : `手持ち0球。${REFILL_CHAIN}連鎖で1球補充。`;
    setStatus(metGoal ? `ノルマ達成。${action}` : action, metGoal ? 'success' : 'neutral');
  }

  function applyUpgrade(upgrade: Upgrade) {
    if (!drawAvailable || !run.chooseUpgrade(upgrade)) return;
    sound.activate();
    showBoard();
    setStatus(`第2面。${run.goal} 点を目指します。`);
    launcher.focus();
  }

  function restart(seed: number) {
    if (!drawAvailable || (run.phase !== 'clear' && run.phase !== 'failed')) return;
    sound.activate();
    const sameBoard = run.seed === seed;
    run = new PinboardRun(seed);
    aimX = DEFAULT_DROP_X;
    showBoard();
    setStatus(sameBoard ? '前回と同じ配置で始めます。' : '新しい配置で始めます。');
    launcher.focus();
  }

  function onPhaseChange(before: Phase) {
    if (before === run.phase) return;
    updatePanels();
    if (run.phase === 'ready') {
      setStatus(run.stageScore >= run.goal
        ? `ノルマ達成。残り ${run.remaining} 球で得点を伸ばせます。`
        : `この面の最高は ${run.chain} 連鎖。ノルマまであと ${run.goal - run.stageScore} 点。`, run.stageScore >= run.goal ? 'success' : 'neutral');
    } else if (run.phase === 'upgrade') {
      setStatus('第1面クリア。強化を選んでください。', 'success');
      upgradeSplit.focus();
    } else if (run.phase === 'clear' || run.phase === 'failed') {
      if (run.phase === 'failed') sound.fail();
      setStatus(run.phase === 'clear' ? '両方のノルマを達成しました。' : '同じ配置で玉を放す位置を変えて試せます。', run.phase === 'clear' ? 'success' : 'error');
      resultTitle.focus();
    }
  }

  launcher.addEventListener('pointermove', (event) => {
    if (!run.canDrop || !drawAvailable) return;
    if (capturedPointer === event.pointerId || (capturedPointer === null && event.pointerType === 'mouse')) aimAtPointer(event);
  });
  launcher.addEventListener('pointerdown', (event) => {
    if (!run.canDrop || !drawAvailable || capturedPointer !== null || !event.isPrimary || event.button !== 0) return;
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
    if (!run.canDrop || !drawAvailable || capturedPointer !== null || event.altKey || event.ctrlKey || event.metaKey) return;
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
    if (document.hidden) feedback.reset();
  });
  const canvas = board.querySelector('canvas');
  canvas?.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    drawAvailable = false;
    releasePointer();
    feedback.reset();
    updatePanels();
    setStatus('画面の描画を一時停止しました。戻らない場合は再読み込みしてください。', 'error');
  });
  canvas?.addEventListener('webglcontextrestored', () => {
    drawAvailable = true;
    lastTime = undefined;
    timeBank = 0;
    updatePanels();
    setStatus('画面の描画を再開しました。');
  });

  showBoard();
  setStatus('');
  view.animate((now) => {
    if (!drawAvailable || document.hidden) return;
    const delta = Math.min((now - (lastTime ?? now)) / 1000, 0.05);
    lastTime = now;
    const phaseBefore = run.phase;
    let refills = 0;
    if (run.phase === 'dropping') {
      timeBank += delta;
      while (timeBank >= STEP && run.phase === 'dropping') {
        const impacts = run.step(STEP);
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
            setStatus('ピンをすべて倒しました。盤面の玉が落ちきるまで待ちます。', 'success');
          }
        }
        if (!metGoal && run.stageScore >= run.goal) {
          metGoal = true;
          feedback.goal();
          sound.clear();
          if (run.hasPins) setStatus('ノルマを達成しました。', 'success');
        }
        timeBank -= STEP;
      }
    } else {
      timeBank = 0;
    }
    if (refills > 0) {
      feedback.refill(refills, remaining);
      sound.refill();
      if (run.canDrop) setStatus(`手持ちが${refills}球増えました。続けて放せます。`, 'success');
    }
    onPhaseChange(phaseBefore);
    view.draw(run.balls, run.canDrop ? aimX : null, delta);
  });
}

start();
