import './style.css';
import { BoardView } from './board-view.ts';
import { BOARD_WIDTH, FIRST_BOARD_SEED, LANES, PinboardRun, STEP } from './game.ts';
import type { Phase, Upgrade } from './game.ts';
import { GameSound } from './sound.ts';

const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const board = element('board');
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
const dropButton = element<HTMLButtonElement>('drop');
const soundButton = element<HTMLButtonElement>('sound-toggle');
const upgradeSplit = element<HTMLButtonElement>('upgrade-split');
const lanes = [...document.querySelectorAll<HTMLButtonElement>('[data-lane]')];

const motionPreference = matchMedia('(prefers-reduced-motion: reduce)');
const sound = new GameSound();
let soundEnabled = true;
const seedParameter = new URLSearchParams(location.search).get('seed');
const launchSeed = seedParameter && /^\d{1,10}$/.test(seedParameter) ? Number(seedParameter) : FIRST_BOARD_SEED;

function setStatus(message: string, tone: 'neutral' | 'success' | 'error' = 'neutral') {
  status.textContent = message;
  status.dataset.tone = tone;
}

function start() {
  let view: BoardView;
  try {
    view = new BoardView(board, motionPreference.matches);
  } catch (error) {
    console.error('Could not create the pinboard renderer.', error);
    setStatus('盤面を表示できませんでした。WebGL 2 が使えるブラウザで開き直してください。', 'error');
    for (const button of [...lanes, soundButton]) button.disabled = true;
    return;
  }

  let run = new PinboardRun(launchSeed);
  let aimedLane = 2;
  let lastTime: number | undefined;
  let timeBank = 0;
  let drawAvailable = true;
  let metGoal = false;

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
    const ready = run.phase === 'ready' && drawAvailable;
    dropButton.disabled = !ready;
    dropButton.textContent = run.phase === 'dropping' ? '玉が落下中…' : '玉を落とす';
    for (const [index, button] of lanes.entries()) {
      button.disabled = !ready;
      button.setAttribute('aria-pressed', String(index === aimedLane));
    }

    const active = element('active-upgrade');
    active.hidden = run.upgrade === null;
    active.textContent = run.upgrade === 'split' ? '強化中 · 青ピンで3球に分裂' : '強化中 · 黄ピンから2球追加';
    element('split-rule').textContent = run.upgrade === 'split' ? 'その場で3球に分裂' : 'その場で2球に分裂';
    element('bonus-rule').textContent = run.upgrade === 'bonus' ? '左右端から各1球追加' : '上の3か所のいずれかから1球追加';

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

  function showBoard() {
    timeBank = 0;
    lastTime = undefined;
    metGoal = false;
    view.reset(run.pins, run.stage);
    updateScore();
    updatePanels();
  }

  function setLane(lane: number) {
    if (run.phase !== 'ready' || !drawAvailable) return;
    const next = Math.max(0, Math.min(LANES.length - 1, lane));
    if (next === aimedLane) return;
    aimedLane = next;
    updatePanels();
  }

  function shoot() {
    if (!drawAvailable || !run.drop(aimedLane)) return;
    sound.activate();
    sound.launch();
    updateScore();
    updatePanels();
    setStatus(`${run.shotsUsed}球目を投入口 ${aimedLane + 1} から落としました。`);
  }

  function applyUpgrade(upgrade: Upgrade) {
    if (!drawAvailable || !run.chooseUpgrade(upgrade)) return;
    sound.activate();
    showBoard();
    setStatus(`第2面。${run.goal} 点を目指します。`);
    dropButton.focus({ preventScroll: true });
  }

  function restart(seed: number) {
    if (!drawAvailable || (run.phase !== 'clear' && run.phase !== 'failed')) return;
    sound.activate();
    const sameBoard = run.seed === seed;
    run = new PinboardRun(seed);
    aimedLane = 2;
    showBoard();
    setStatus(sameBoard ? '前回と同じ配置で始めます。' : '新しい配置で始めます。');
    dropButton.focus({ preventScroll: true });
  }

  function onPhaseChange(before: Phase) {
    if (before === run.phase) return;
    updatePanels();
    if (run.phase === 'ready') {
      setStatus(run.stageScore >= run.goal
        ? `ノルマ達成。残り ${run.remaining} 球で得点を伸ばせます。`
        : `この球は ${run.chain} 連鎖。ノルマまであと ${run.goal - run.stageScore} 点。`, run.stageScore >= run.goal ? 'success' : 'neutral');
      if (document.activeElement === document.body) dropButton.focus({ preventScroll: true });
    } else if (run.phase === 'upgrade') {
      setStatus('第1面クリア。強化を選んでください。', 'success');
      upgradeSplit.focus({ preventScroll: true });
    } else if (run.phase === 'clear' || run.phase === 'failed') {
      if (run.phase === 'failed') sound.fail();
      setStatus(run.phase === 'clear' ? '両方のノルマを達成しました。' : '別の投入口や強化を試せます。', run.phase === 'clear' ? 'success' : 'error');
      resultTitle.focus({ preventScroll: true });
    }
  }

  for (const [index, button] of lanes.entries()) button.addEventListener('click', () => setLane(index));
  dropButton.addEventListener('click', shoot);
  board.addEventListener('click', (event) => {
    const bounds = board.getBoundingClientRect();
    const x = (event.clientX - bounds.left) * BOARD_WIDTH / bounds.width;
    setLane(Math.round((x - LANES[0]) / (LANES[1] - LANES[0])));
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
    if (run.phase !== 'ready' || event.altKey || event.ctrlKey || event.metaKey) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      setLane(aimedLane + (event.key === 'ArrowLeft' ? -1 : 1));
    } else if (event.code === 'Space' && !event.repeat &&
      (!(event.target instanceof HTMLButtonElement) || event.target.hasAttribute('data-lane'))) {
      event.preventDefault();
      shoot();
    }
  });

  motionPreference.addEventListener('change', (event) => view.setReducedMotion(event.matches));
  document.addEventListener('visibilitychange', () => {
    lastTime = undefined;
    timeBank = 0;
  });
  const canvas = board.querySelector('canvas');
  canvas?.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    drawAvailable = false;
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
  setStatus('盤面から直接、投入口を選ぶこともできます。');
  view.animate((now) => {
    if (!drawAvailable || document.hidden) return;
    const delta = Math.min((now - (lastTime ?? now)) / 1000, 0.05);
    lastTime = now;
    const phaseBefore = run.phase;
    if (run.phase === 'dropping') {
      timeBank += delta;
      while (timeBank >= STEP && run.phase === 'dropping') {
        const impacts = run.step(STEP);
        for (const impact of impacts) {
          view.hit(impact);
          sound.hit(impact.pin.kind, impact.chain);
        }
        if (impacts.length) updateScore();
        if (!metGoal && run.stageScore >= run.goal) {
          metGoal = true;
          sound.clear();
          setStatus('ノルマを達成しました。', 'success');
        }
        timeBank -= STEP;
      }
    } else {
      timeBank = 0;
    }
    onPhaseChange(phaseBefore);
    view.draw(run.balls, run.phase === 'ready' ? aimedLane : null, delta);
  });
}

start();
