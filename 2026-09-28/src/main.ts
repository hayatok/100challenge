import "./style.css";
import "./fever.css";
import "./journey.css";
import { FeverShow } from "./fever.ts";
import { CelebrationState } from "./spectacle.ts";
import { Game, type GameState } from "./game.ts";
import { World } from "./scene.ts";
import { GameAudio } from "./audio.ts";
import { readSave, writeSave, recordResult, betterResult, resultKey, RESULT_RULES_VERSION, type SavedResult } from "./storage.ts";
import { gradeResult, previousComparable, compareResults } from "./results.ts";
import { nextGoal } from "./goals.ts";
const app = document.querySelector<HTMLDivElement>("#app")!;
app.innerHTML = `<div id="world" aria-hidden="true">
</div>
<div class="vignette">
</div>
<div id="combat-glow" aria-hidden="true">
</div>
<header>
<a class="brand" href="#">夜勤<span>NIGHTSHIFT / TYPING</span>
</a>
<div class="top-center">● 午前零時の商店街<span id="stage">午前零時・営業中</span>
</div>
<button id="pause-button" aria-label="一時停止" hidden>Ⅱ</button>
<button id="sound-button" aria-label="音を切り替える">♪</button>
</header>
<div id="loading" class="center-card">
<p class="eyebrow">開店準備</p>
<h1>夜の準備中…</h1>
<p id="loading-text" role="status">商店街へ向かっています</p>
</div>
<section id="title" hidden>
<div class="title-copy">
<p class="title-kicker">黒猫商店街・深夜営業</p>
<h1 class="arcade-logo" aria-label="夜勤タイピング">
<span class="logo-night">夜勤</span>
<span class="logo-typing">タイピング</span>
</h1>
<p class="title-sub">午前零時の商店街</p>
<p class="description">一文字、一発。朝まで、生き残れ。</p>
<button id="start-button" class="primary">勤務開始<small>PRESS ENTER</small>
</button>
<div class="title-options">
<button id="settings-button">設定</button>
<button id="credits-button">クレジット</button>
</div>
<p class="keyboard-note">PC・キーボード専用 ／ 分岐のある短い一勤務</p>
</div>
<footer>
<span>生きて、定時で帰ろう。</span>
<span>ALPHA 0.12 / 黒猫商店街</span>
</footer>
</section>
<section id="hud" hidden>
<div id="route-choice" hidden><p class="eyebrow">01 / 探る</p><h2>時計台へ、抜け道を探せ。</h2><p>店の奥で、何かが倒れる音がした。</p><div class="route-actions"><button id="route-service"><b>1</b> 搬入口へ<small>狭い裏道 / 素早い敵</small></button><button id="route-store"><b>2</b> 店内へ<small>灯りの先 / 重い足音</small></button></div><small>1・2キー、またはクリックで進路を選択</small></div>
<div id="vista-panel" hidden><p class="eyebrow">04 / 息をつく</p><h2>夜明けまで、生き延びた。</h2><p>次は、時計台へ。</p><button id="vista-continue">勤務を終える <small>ENTER</small></button></div>
<div id="journey-caption" aria-live="polite"></div>
<div class="health-block">
<p class="eyebrow" id="shift-label">
</p>
<div class="health-row">
<small>体力</small>
<div id="health">
</div>
</div>
<small id="practice-label">
</small>
</div>
<div class="score-block">
<div class="score-label">SCORE <b id="score">000000</b>
</div>
<div class="combo">
<strong id="combo">0</strong>
<span>連撃<small id="combo-word">KEEP TYPING</small>
</span>
</div>
<small class="charge-label">残業ゲージ</small>
<div class="fever-track">
<div id="fever-fill">
</div>
</div>
<small id="fever-next">
</small>
</div>
<div id="rush-banner" hidden>
<small>短文を続けて、撃ち抜け。</small>
<strong>限界残業</strong>
<div id="rush-pips">
</div>
<span id="rush-count">
</span>
</div>
<div id="lucky-banner" hidden>
<small>踊る深夜のボーナスタイム</small>
<strong>幸運出勤</strong>
<div id="lucky-pips">
</div>
<span id="lucky-count">
</span>
<p>3文完成で +500点・体力1回復</p>
</div>
<div id="boss-hud" hidden>
<small>黒猫商店街・終業責任者</small>
<b>店長 <span id="boss-phase">
</span>
</b>
<div id="boss-pips">
</div>
</div>
<div id="fever-show" aria-hidden="true" hidden>
<div class="fever-wash"></div><div class="fever-rays"></div>
<div class="fever-rail rail-top"></div><div class="fever-rail rail-bottom"></div>
<div class="fever-wing wing-left"><span>FEVER</span></div><div class="fever-wing wing-right"><span>FEVER</span></div>
<div class="fever-orbit orbit-one"></div><div class="fever-orbit orbit-two"></div>
<div class="fever-cutin"><small id="fever-cue-label">FEVER RUSH</small><strong id="fever-cue-title">限界残業</strong><span id="fever-cue-caption">短文4連戦、撃ち抜け。</span></div>
<div class="fever-count"><strong id="fever-hit-count">0</strong><span>/ 4 群突破</span></div>
<div class="fever-confetti">${Array.from({length:24},(_,i)=>`<i style="--i:${i};--x:${(i*37)%100}%"></i>`).join("")}</div>
</div>
<div id="spectacle-frame" aria-hidden="true">
<div id="heat-marquee" class="heat-marquee">NIGHTSHIFT // OVERDRIVE // KEEP FIRING</div>
</div>
<div id="showtime" aria-hidden="true" hidden>
<div class="show-rays">
</div>
<small id="show-badge">
</small>
<strong id="show-title">
</strong>
<span id="show-caption">
</span>
</div>
<div id="targets">
</div>
<div id="milestone" aria-hidden="true">
<small id="milestone-caption">
</small>
<strong id="milestone-word">
</strong>
</div>
<div id="score-pop" aria-hidden="true">
</div>
<div id="feedback" aria-live="polite">
</div>
<div id="reticle" class="reticle">+</div>
<div id="typing-panel">
<div class="panel-top">
<span id="target-number">
</span>
<span id="input-status">
</span>
</div>
<div id="phrase">
</div>
<div id="reading">
</div>
<div id="romaji">
</div>
<div class="deadline">
<div id="deadline-bar">
</div>
</div>
<div class="panel-bottom">
<span>一文字、一発。</span>
<span>ESC 一時停止</span>
</div>
</div>
<div id="travel-message" hidden>
</div>
</section>
<div id="modal" class="modal" hidden>
<section class="modal-card" role="dialog" aria-modal="true" aria-labelledby="modal-title">
<div id="modal-content">
</div>
</section>
</div>
<input id="key-capture" type="text" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="ゲーム入力。半角英字でタイプしてください">
<div id="notice" role="status" hidden>
</div>`;
const el = <T extends HTMLElement = HTMLElement>(id: string) =>
  document.getElementById(id) as T;
const show = (id: string, v: boolean) => {
  if (el(id).hidden === v) el(id).hidden = !v;
};
const text = (id: string, value: string) => { if(el(id).textContent !== value) el(id).textContent = value; };
const save = readSave();
const preferences = save.preferences;
let history = save.results;
let personalBests = save.personalBests;
const audio = new GameAudio();
const spectacle = new CelebrationState();
const fever = new FeverShow();
let feverRevision = -1;
const warnedEnemies=new Set<number>();
let renderedCelebration = spectacle.current;
function resetSpectacle(){fever.reset();show("fever-show",false);document.body.dataset.fever="off";spectacle.reset();renderedCelebration=null;show("showtime",false);el("showtime").getAnimations().forEach(a=>a.cancel());}
audio.setVolumes(preferences.music, preferences.effects);
let world: World,
  game: Game | null = null;
let screen = "loading",
  modalKind = "",
  check = "",
  lastMode = "",
  signature = "";
let lastTime = performance.now(),
  feedbackUntil = 0,
  saved = false;
let finishAt = 0, shownLevel = 0, announcedStage = -1;
let luckyOutro: null | boolean = null;
const input = el<HTMLInputElement>("key-capture");
function notify(t: string) {
  el("notice").textContent = t;
  show("notice", true);
  setTimeout(() => show("notice", false), 4500);
}
function persist() {
  if (!writeSave(preferences, history, personalBests))
    notify("記録を保存できません。プレイは続けられます。");
}
function focus() {
  input.value = "";
  input.focus({ preventScroll: true });
}
function modal(html: string, kind: string) {
  el("title").inert = true;
  el("hud").inert = true;
  document.querySelector("header")!.inert = true;
  document.body.dataset.screen = screen;
  modalKind = kind;
  el("modal").dataset.kind = kind;
  el("modal-content").innerHTML = html;
  show("modal", true);
  el("modal-content").scrollTop = 0;
  el("modal").querySelector<HTMLButtonElement>("button")?.focus({preventScroll:true});
}
function close() {
  el("title").inert = false;
  el("hud").inert = false;
  document.querySelector("header")!.inert = false;
  show("modal", false);
  modalKind = "";
  delete el("modal").dataset.kind;
}
function title() {
  resetSpectacle();
  world.reset();
  audio.stop();
  game = null;
  screen = "title";
  finishAt = 0;
  document.body.dataset.level = "0";
  document.body.dataset.rush = "false";
  audio.setRush(false);
  audio.setLucky(false);
  document.body.dataset.lucky = "false";
  world.update(0, null);
  el("milestone").getAnimations().forEach(a => a.cancel());
  close();
  show("title", true);
  show("hud", false);
  show("pause-button", false);
  el("stage").textContent = "午前零時・営業中";
  el("start-button").focus();
}
function settings() {
  modal(
    `<p class="eyebrow">勤務前点検</p><h2 id="modal-title">筐体設定</h2><p class="note">設定はこのブラウザに保存されます。</p><label>勤務の厳しさ</label><div class="difficulty">${[
      ["relaxed", "研修", "ゆったり"],
      ["normal", "通常", "ほどよい緊張"],
      ["fierce", "残業", "速い人向け"],
    ]
      .map(
        ([v, l, d]) =>
          `<button data-difficulty="${v}" class="${preferences.difficulty === v ? "selected" : ""}" aria-pressed="${preferences.difficulty === v}">${l}<small>${d}</small></button>`,
      )
      .join(
        "",
      )}</div><label class="toggle"><span>練習勤務<small>敵の攻撃なし。ラッキーは必ず登場（時間制限あり）。</small></span><input id="practice" type="checkbox" ${preferences.practice ? "checked" : ""}></label><label class="toggle"><span>画面の動き<small>オフで揺れ・強い発光を減らします。</small></span><input id="motion" type="checkbox" ${preferences.motion ? "checked" : ""}></label><label class="range">BGM<input id="music" type="range" min="0" max="100" value="${preferences.music * 100}"></label><label class="range">銃声・効果音<input id="effects" type="range" min="0" max="100" value="${preferences.effects * 100}"></label><button id="settings-close" class="primary">設定完了</button>`,
    "settings",
  );
  el("modal")
    .querySelectorAll<HTMLButtonElement>("[data-difficulty]")
    .forEach(
      (b) =>
        (b.onclick = () => {
          preferences.difficulty = b.dataset
            .difficulty as typeof preferences.difficulty;
          settings();
          el("modal").querySelector<HTMLButtonElement>(`[data-difficulty="${b.dataset.difficulty}"]`)?.focus();
        }),
    );
  el<HTMLInputElement>("practice").onchange = (e) =>
    (preferences.practice = (e.target as HTMLInputElement).checked);
  el<HTMLInputElement>("motion").onchange = (e) => {
    preferences.motion = (e.target as HTMLInputElement).checked;
    world.motion = preferences.motion;
    document.body.dataset.motion = String(preferences.motion);
  };
  for (const id of ["music", "effects"] as const)
    el<HTMLInputElement>(id).oninput = (e) => {
      preferences[id] = +(e.target as HTMLInputElement).value / 100;
      audio.setVolumes(preferences.music, preferences.effects);
    };
  el("settings-close").onclick = () => {
    persist();
    close();
    el("start-button").focus();
  };
}
function credits() {
  modal(
    `<p class="eyebrow">制作・素材提供</p><h2 id="modal-title">クレジット</h2><p>企画・ゲーム・街・演出：NIGHTSHIFT TYPING</p><p>住人・作業員・店長の原型：Rikindle3D / Male City Zombie（CC0）<br><small>衣服と肌の配色・体格・補助動作を調整。</small><br>疾走ゾンビ：Rosswet Mobile / <a href="https://opengameart.org/content/thin-zombie-awake-zombie-asset" target="_blank" rel="noreferrer">Thin Zombie [Awake Zombie Asset]</a>（<a href="https://creativecommons.org/licenses/by/3.0/" target="_blank" rel="noreferrer">CC BY 3.0</a>）<br><small>GLB変換・テクスチャ再接続・動作選択・スケール調整。</small><br>拳銃：loafbrr_1 / Pistol（CC0）<br>腕：para / FPS Arms（CC0）</p><p>音楽：MintoDog / <a href="https://opengameart.org/content/darkness-roadremeke" target="_blank" rel="noreferrer">Darkness Road Remake</a>（CC0）<br>打撃・破片：Kenney / Impact Sounds（CC0）<br>銃声：© 2009 Vincent Sevedge / <a href="https://opengameart.org/content/gunshot-sounds" target="_blank" rel="noreferrer">Gunshot Sounds</a>（<a href="https://creativecommons.org/licenses/by/3.0/" target="_blank" rel="noreferrer">CC BY 3.0</a>）<br><small>銃声は切り出し・EQ・圧縮・音量調整をしています。</small></p><p class="note"><a href="./THIRD_PARTY_NOTICES.txt" target="_blank" rel="noreferrer">素材出典とライセンス情報</a>を同梱。元作品のキャラクター・音声・ロゴは使用していません。</p><button id="credits-close" class="primary">商店街へ戻る</button>`,
    "credits",
  );
  el("credits-close").onclick = () => {
    close();
    el("start-button").focus();
  };
}
function prepare() {
  screen = "input";
  check = "";
  modal(
    `<p class="eyebrow">装填確認</p><h2 id="modal-title">まず、弾を込めよう。</h2><p>日本語入力をオフにして、<b>go</b> と打ってください。</p><div id="check-letters">go</div><p id="check-status" class="note">そのままキーボードで入力できます。</p><p class="note">正しい文字 → 発砲 ／ 単語完成 → 撃破<br>打ち間違いは打ち直し不要。続きを打てばOK。<br>1・2キーで進路を選択。広場のFEVERでは一語で3体を一掃。<br>踊るラッキーゾンビはボーナス。見逃してもペナルティなし。</p><button id="check-back" class="text-button">タイトルに戻る</button>`,
    "input",
  );
  el("check-back").onclick = title;
  focus();
}
function start(seed = Date.now() >>> 0) {
  warnedEnemies.clear();
  resetSpectacle();
  world.reset();
  lastTime = performance.now();
  close();
  game = new Game({
    difficulty: preferences.difficulty,
    practice: preferences.practice,
    seed, journey: true,
  });
  world.update(0, game.state);
  lastTime = performance.now();
  screen = "game";
  saved = false;
  finishAt = 0;
  shownLevel = 0;
  luckyOutro=null;
  for (const id of ["milestone", "score-pop", "combat-glow"]) el(id).getAnimations().forEach(a => a.cancel());
  text("feedback", "");
  audio.setRush(false);
  audio.setLucky(false);
  document.body.dataset.lucky = "false";
  announcedStage = -1;
  lastMode = "";
  signature = "";
  show("title", false);
  show("hud", true);
  show("pause-button", true);
  audio.start();
  focus();
}
function pause(reason = "ひと休みしましょう。") {
  if (
    screen !== "game" ||
    !game ||
    ["paused", "defeat", "clear"].includes(game.state.mode)
  )
    return;
  game.pause(reason);
  audio.stop();
  modal(
    `<p class="eyebrow">休憩中</p><h2 id="modal-title">一時停止</h2><p>${reason}</p><p class="note">敵も制限時間も止まっています。<br>半角英字入力に戻してから再開してください。</p><button id="resume" class="primary">勤務に戻る</button><button id="quit" class="text-button">タイトルに戻る</button>`,
    "pause",
  );
  el("resume").onclick = () => {
    void audio.unlock();
    screen = "input";
    check = "";
    modal(
      '<p class="eyebrow">装填確認</p><h2 id="modal-title">再開前の入力確認</h2><p>半角英字で <b>go</b> と入力してください。</p><div id="check-letters">go</div><p id="check-status" class="note">確認中は敵も時間も止まっています。</p><button id="resume-back" class="text-button">タイトルに戻る</button>',
      "resume-input",
    );
    el("resume-back").onclick = title;
    focus();
  };
  el("quit").onclick = title;
}
function finish(s: GameState) {
  if (saved) return;
  saved = true;
  screen = "result";
  audio.stop(false);
  const r = s.results!;
  const result: SavedResult = {
    score: r.score,
    combo: r.maxCombo,
    accuracy: r.accuracy,
    seconds: r.clearTime,
    cleared: s.mode === "clear",
    difficulty: r.difficulty,
    practice: r.practice,
    retries: r.attempts - 1,
    date: new Date().toISOString(),
    rulesVersion: RESULT_RULES_VERSION,
    seed: r.seed, rushes: r.rushes, chainKills: r.chainKills,
    luckyEncounters:r.luckyEncounters,luckyClears:r.luckyClears,luckyBonus:r.luckyBonus,
  };
  const goal = nextGoal(result);
  const previous = previousComparable(history, result);
  const comparison = compareResults(result, previous);
  const oldBest = personalBests[resultKey(result)];
  const updated = recordResult({preferences, results: history, personalBests}, result);
  history = updated.results;
  personalBests = updated.personalBests;
  const best = personalBests[resultKey(result)];
  const newBest = betterResult(result, oldBest);
  const delta = comparison ? `${comparison.scoreDelta >= 0 ? "+" : ""}${comparison.scoreDelta.toLocaleString()}` : "—";
  const difficulty = {relaxed:"研修", normal:"通常", fierce:"残業"}[r.difficulty];
  persist();
  modal(
    `<div class="receipt-head"><p class="eyebrow">黒猫商店街 / 勤務精算票</p><h2 id="modal-title">${s.mode === "clear" ? "勤務終了" : "勤務中断"}</h2><p class="note">${difficulty}勤務${r.practice ? "・練習記録" : ""} / 本日もお疲れさまでした。</p></div><div class="result-hero"><div class="result-grade"><small>判定</small><strong>${gradeResult(result)}</strong><span class="result-verdict">${r.practice ? "練習終了" : s.mode === "clear" ? "全区間突破" : "再出勤求む"}</span></div><div class="result-score">${String(r.score).padStart(6,"0")}<small>勤務得点 / SCORE</small></div></div><div class="result-record" data-new-best="${newBest}"><span>${newBest ? "自己最高" : "最高記録"}<b>${best ? best.score.toLocaleString() : "未達成"}</b></span><span>前回との差<b>${delta}</b></span></div><div class="result-grid"><div><b>${r.maxCombo}</b><span>最大連撃</span></div><div><b>${r.correct + r.mistakes ? (r.accuracy * 100).toFixed(1) + "%" : "—"}</b><span>正確率</span></div><div><b>${Math.round(r.keysPerMinute)}</b><span>打鍵 / 分</span></div></div><div class="result-extra"><span>FEVER <b>${r.rushes}回</b></span><span>巻き込み撃破 <b>${r.chainKills}体</b></span></div><div class="result-lucky">${r.luckyEncounters ? `幸運出勤 <b>${r.luckyClears ? "大当り" : "遭遇"}</b><span>ボーナス +${r.luckyBonus}</span>` : "今夜のラッキー遭遇なし"}</div><div class="next-goal"><small>次の勤務目標</small><b>${goal.title}</b><p>${goal.detail}</p></div><p class="note receipt-time">${r.practice ? "練習記録は通常勤務と別に保存。<br>" : ""}勤務時間 ${Math.floor(r.clearTime / 60)}分${Math.floor(r.clearTime % 60)}秒 / リトライ ${r.attempts - 1}回</p><button id="again" class="primary">${s.mode === "defeat" ? "この区間から再出勤" : "もう一勤務"}<small>${s.mode === "defeat" ? "区間の最初から再開" : "同じ出題で再挑戦"}</small></button><div class="result-actions">${s.mode === "clear" ? '<button id="new-run" class="text-button">新しい出題で勤務</button>' : ""}<button id="result-title" class="text-button">タイトルへ</button></div>`,
    "result",
  );
  el("again").onclick = () => {
    if (s.mode === "clear") start(r.seed);
    else {
      game?.retryCheckpoint();
      world.reset(game?.state.stage);
      screen = "game";
      saved = false;
      finishAt = 0;
      shownLevel = 0;
      close();
      audio.start();
      focus();
    }
  };
  if(s.mode === "clear") el("new-run").onclick = () => start();
  el("result-title").onclick = title;
}
const stages = [
  "裏路地 / 灯りの先へ",
  "店内 / 重い足音",
  "荷捌き広場 / 解き放て",
  "広場の奥 / 最後の用心棒",
];
function draw(s: GameState) {
  if(s.mode === "playing") luckyOutro=null;
  const exploring=s.mode==='explore', vista=s.mode==='vista';
  const quiet=exploring||vista||s.mode==='clear'||world.moving;
  document.body.dataset.quiet=String(quiet);
  document.body.dataset.area=s.journey?.area??'alley';
  show('route-choice',exploring);
  show('vista-panel',vista&&!world.moving);
  show('journey-caption',world.moving);
  text('journey-caption',s.journey?.area==='roof'?'階段の先に、朝の気配。':s.journey?.area==='store'?'扉の向こうで、足音が止まった。':s.journey?.area==='service'?'狭い道から、誰かが駆けてくる。':s.journey?.area==='court'?'空が開けた。集団が、こちらを見た。':'灯りを頼りに、奥へ。');
  const stageLabel=exploring?'裏路地 / 進路を選べ':(vista||s.mode==='clear')?'屋上 / 夜明けの気配':s.stage===1&&s.journey?.route==='service'?'搬入口 / 狭い抜け道':stages[s.stage];
  text("stage", `SHIFT 0${s.stage + 1} — ${stageLabel}`);
  text("shift-label", `SHIFT 0${s.stage + 1} / ${stageLabel.split(" / ")[0]}`);
  text("score", String(s.score).padStart(6, "0"));
  text("combo", String(s.combo));
  text("combo-word", [
    "勤務開始",
    "連撃好調",
    "熱烈勤務",
    "残業上等",
    "限界突破",
  ][s.effectsLevel]);
  text("health", "✚ ".repeat(s.health) + "— ".repeat(3 - s.health));
  el("health").setAttribute("aria-label", `体力 ${s.health} / 3`);
  text("practice-label", s.practice ? "練習勤務 / 攻撃なし" : "");
  document.body.dataset.level = String(s.effectsLevel);
  if(document.body.dataset.rush !== String(s.rushing)) document.body.dataset.rush = String(s.rushing);
  if(document.body.dataset.lucky !== String(s.luckyActive)) document.body.dataset.lucky = String(s.luckyActive);
  show("lucky-banner",s.luckyActive);
  text("lucky-count",`あと ${Math.ceil(s.luckyRemaining)} 秒 / ${s.luckyStep} OF 3`);
  if(el("lucky-pips").dataset.step !== String(s.luckyStep)){
    el("lucky-pips").dataset.step=String(s.luckyStep);
    el("lucky-pips").innerHTML=[1,2,3].map(i=>`<i class="${i<s.luckyStep?"done":i===s.luckyStep?"active":""}"></i>`).join("");
  }
  const charge = s.rushing ? s.rushRemaining / 4 : s.rushCharge / 100;
  el("fever-fill").style.transform = `scaleX(${charge})`;
  text("fever-next", s.rushing ? `SHOTGUN / 残り ${s.rushRemaining} 群` : s.stage === 3 ? "FINAL SHIFT / 店長を撃退せよ" : s.journey && s.rushes >= 1 ? "一掃完了 / 時計台への道を開け" : s.rushes >= 2 ? "FEVER 2 / 2 — 今夜のラッシュ終了" : s.rushCharge >= 100 ? "READY / この集団の後に突入" : s.journey ? "広場でSHOTGUN解放" : `CHARGE ${Math.round(s.rushCharge)}% / 撃破でたまる`);
  show("rush-banner", s.rushing);
  text("rush-count", `一語で3体 / 残り ${s.rushRemaining} 群`);
  if (el("rush-pips").dataset.remaining !== String(s.rushRemaining)) {
    el("rush-pips").dataset.remaining = String(s.rushRemaining);
    el("rush-pips").innerHTML = [0,1,2,3].map(i => `<i class="${i < 4-s.rushRemaining ? "done" : ""}"></i>`).join("");
  }
  show("boss-hud", s.stage === 3 && !quiet);
  text("boss-phase", ["01 / 開店準備", `02 / 反撃 ${s.bossCounter || 1}/3`, "03 / 最終通告"][Math.min(2, s.bossPhase)]);
  if (el("boss-pips").dataset.phase !== String(s.bossPhase)) {
    el("boss-pips").dataset.phase = String(s.bossPhase);
    el("boss-pips").innerHTML = [0,1,2].map(i => `<i class="${i < s.bossPhase ? "done" : i === s.bossPhase ? "active" : ""}"></i>`).join("");
  }
  const targets=s.enemies.filter(e=>!e.support);
  const e = targets.find((e) => e.id === s.lockedId) ?? targets[0];
  const blastVictims = new Set(s.enemies.flatMap(e => e.explosive ? e.blastTargets : []));
  const sig = JSON.stringify([
    s.enemies.map((e) => [e.id, e.phrase, e.keys, e.locked, e.threatRank, e.explosive, e.blastTargets, e.lucky]),
    e?.typed,
    e?.guide,
    s.mode, s.rushing, s.bossCounter, s.luckyActive, s.luckyStep,
  ]);
  if (sig !== signature) {
    signature = sig;
    el("targets").innerHTML = targets
      .map(
        (e) =>
          `<div class="target ${e.locked ? "locked" : ""} ${e.lucky ? "lucky" : e.explosive ? "explosive" : blastVictims.has(e.id) ? "blast-linked" : ""}" data-enemy="${e.id}"><b>${e.keys.join("/").toUpperCase()}</b><span><small>${e.lucky ? "ラッキーゾンビ / 攻撃なし" : e.explosive ? `爆発ゾンビ / 巻き込み ${e.blastTargets.length}体` : blastVictims.has(e.id) ? "巻き込み対象" : e.rush ? "RUSH TARGET" : ({office:"徘徊者",runner:"疾走者",worker:"巨体",boss:"店長"})[e.kind]}${e.threatRank === 1 && s.enemies.length > 1 ? " / 接近中" : ""}</small>${e.phrase}</span><i class="enemy-time"></i></div>`,
      )
      .join("");
    text("phrase", e?.phrase ?? (luckyOutro !== null ? luckyOutro ? "今夜の幸運、いただきました。" : "また今度、踊ろう。" : s.mode === "clear" ? "本日の勤務、終了。" : "次の勤務先へ"));
    text("reading", e?.reading ?? "");
    el("romaji").replaceChildren();
    if (e) {
      const t = document.createElement("span");
      t.className = "typed";
      t.textContent = e.typed;
      const r = document.createElement("span");
      const current = document.createElement("span");
      current.className = "current-key";
      current.textContent = e.guide.slice(0, 1);
      r.append(current, document.createTextNode(e.guide.slice(1)));
      el("romaji").append(t, r);
    }
    text("input-status", s.rushing ? "中央を打ち切れ / ショットガンで3体一掃" : s.luckyActive ? "ミス・見逃しでコンボは切れません" : s.lockedId
      ? "照準固定 / そのまま打ち切れ"
      : e?.explosive ? "長文を打ち切って、一掃せよ" : s.enemies.length > 1 ? "接近中の敵を優先 / 一文字で狙う" : "最初の一文字で狙う");
    text("target-number", s.luckyActive ? `LUCKY SHIFT / ${s.luckyStep} OF 3` : s.stage === 3
        ? `BOSS / ${Math.min(3, s.bossPhase + 1)} OF 3`
        : s.rushing ? `FEVER RUSH / ${5 - s.rushRemaining} OF 4` : e?.explosive ? `EXPLOSIVE / 隣の ${e.blastTargets.length} 体も撃破` : `TARGET ${String(e?.id ?? 0).padStart(2, "0")}`);
  }
  for (const enemy of s.enemies) {
    const label = el("targets").querySelector<HTMLElement>(
        `[data-enemy="${enemy.id}"]`,
      ),
      pos = world.project(enemy.id);
    if (label && pos) {
      label.style.left = `${enemy.kind === "boss" ? innerWidth * .27 : Math.max(140, Math.min(innerWidth - 140, pos.x))}px`;
      label.style.top = `${Math.max(s.luckyActive ? 270 : s.rushing ? 225 : enemy.kind === "boss" ? 205 : 175, pos.y)}px`;
      label.classList.toggle("danger", enemy.telegraph);
      label.style.setProperty("--remaining", String(1 - enemy.progress));
    }
  }
  el("deadline-bar").style.transform = `scaleX(${e ? 1 - e.progress : 0})`;
  el("deadline-bar").classList.toggle("danger", !s.luckyActive && (e?.progress ?? 0) > 0.75);
  show("travel-message", (s.mode === "travel" && luckyOutro === null) || s.mode === "countdown");
  text("travel-message", s.mode === "countdown"
      ? "READY…"
      : s.rushing ? "FEVER RUSH / 短文4連戦" : s.stage === 3
        ? ["店長が出勤しました。", "まだ、帰らせてもらえない。", "これで、最後の残業だ。"][Math.min(2, s.bossPhase)]
        : "足音が、近づいてくる。");
  if (s.mode !== lastMode) {
    if (lastMode === "countdown" && s.mode!=="paused") audio.start();
    if (s.mode === "clear" || s.mode === "defeat") finishAt = performance.now() + (s.mode === "clear" ? 3100 : 700);
    lastMode = s.mode;
  }
  if (finishAt && performance.now() >= finishAt) { finishAt = 0; finish(s); }
}
function feedback(t: string, kind: string) {
  el("feedback").textContent = t;
  el("feedback").className = kind;
  feedbackUntil = performance.now() + 750;
}
function punch(id: string, scale = 1.18) {
  if (!preferences.motion) return;
  el(id).getAnimations().forEach(a => a.cancel());
  el(id).animate([{scale: String(scale), filter: "brightness(1.8)"}, {scale: "1", filter: "brightness(1)"}], {duration: 240, easing: "cubic-bezier(.12,.7,.3,1)"});
}
function milestone(level: number) {
  el("milestone-caption").textContent = `勤務熱量 ${level} / 連撃継続`;
  el("milestone-word").textContent = ["", "連撃好調", "熱烈勤務", "残業上等", "限界突破"][level];
  el("milestone").getAnimations().forEach(a => a.cancel());
  el("milestone").animate(preferences.motion ? [
    {opacity: 0, translate: "-30px 0", scale: "1.15", offset: 0},
    {opacity: 1, translate: "0 0", scale: "1", offset: .12},
    {opacity: 1, translate: "0 0", scale: "1", offset: .7},
    {opacity: 0, translate: "15px 0", scale: "1", offset: 1},
  ] : [{opacity: 1}, {opacity: 0}], {duration: 1650, easing: "ease-out"});
}
function events() {
  for (const e of game?.drainEvents() ?? []) {
    spectacle.event(e);
    fever.event(e);
    if(e.type === "kill" && !e.collateral && spectacle.rushing) audio.rushKill(spectacle.rushHits);
    if(world.event(e)) audio.storefrontImpact();
    if (e.type === "hit") {
      audio.shot({lucky:e.lucky, rush: e.rush, zone: e.hitZone === "head" ? "head" : e.hitZone === "shoulder" ? "limb" : "body", finishing: e.finisher, level: e.effectsLevel ?? game!.state.effectsLevel});
      punch("reticle", 1.55);

    }
    if (e.type === "kill" && !e.collateral) {
      audio.kill(e.combo ?? game!.state.combo, e.kind === "boss" ? "boss" : "normal");
      const combo = e.combo ?? game!.state.combo;
      const level = e.effectsLevel ?? game!.state.effectsLevel;
      feedback(e.kind === "boss" ? e.phase === 2 ? "勤務終了" : "防御突破" : e.clean ? level >= 3 ? "完全撃退！" : "一撃必殺！" : "撃退！", "good");
      el("score-pop").textContent = `+${e.scoreDelta ?? 100}${combo >= 3 ? " / " + combo + " 連撃" : ""}`;
      el("score-pop").getAnimations().forEach(a => a.cancel());
      el("score-pop").animate(preferences.motion ? [{opacity: 1, translate: "0 10px"}, {opacity: 0, translate: "0 -20px"}] : [{opacity: 1}, {opacity: 0}], {duration: 900});
      punch("combo", 1.35);
      punch("score", 1.12);
      const arrival = level > shownLevel;
      const streak = !arrival && combo >= 20 && combo % 5 === 0;
      if (arrival) { milestone(level); audio.tier(level); }
      if (streak) { milestone(4); el("milestone-caption").textContent = `${combo} 連撃 / まだ止まらない`; el("milestone-word").textContent = "連撃無双"; audio.streak(combo); }
      shownLevel = level;
      if (preferences.motion) el("combat-glow").animate([{opacity: arrival || streak ? .42 : .14}, {opacity: 0}], {duration: 380});
    }
    if(e.type === "luckyStart") {
      audio.luckyStart(); text("feedback","");el("score-pop").getAnimations().forEach(a=>a.cancel());milestone(3);text("milestone-caption","今夜は、ツイてる。");text("milestone-word","幸運出勤");
    }
    if(e.type === "luckyStep") { audio.luckyWord(e.step ?? 1);feedback(`${e.step} / 3 — NICE MOVES!`,"lucky"); }
    if(e.type === "luckyEnd") {
      luckyOutro=!!e.success;
      audio.luckyEnd(!!e.success);
      if(e.success){
        milestone(3);text("milestone-caption",e.healing ? "大当たり / 体力 +1" : "大当たり / 体力は満タン");text("milestone-word","大当り");
        text("score-pop",`BONUS +${e.scoreDelta ?? 500}`);
        el("score-pop").getAnimations().forEach(a=>a.cancel());
        el("score-pop").animate([{opacity:1},{opacity:0}],{duration:1600});punch("score",1.2);feedback("お疲れさまでした！","lucky");
      } else feedback("また会う日まで！ / ペナルティなし","lucky");
    }
    if (e.type === "rushStart") {
      audio.rushStart(); milestone(4); text("milestone-caption", "ゲージ解放 / 短文4連戦"); text("milestone-word", "限界残業");
    }
    if (e.type === "rushEnd") {
      audio.rushEnd(!!e.success); feedback(e.success ? "RUSH COMPLETE / 4群を突破" : "RUSH END / 通常戦へ", "good");
    }
    if (e.type === "explosion") {
      audio.explosion(e.count ?? 0);
      feedback(e.count ? `${e.count! + 1}体 一掃！` : "TANK DESTROYED", "good");
      text("score-pop", `連鎖ボーナス +${(e.count ?? 0)*75}`);
      punch("score",1.2);
      if(preferences.motion) el("combat-glow").animate([{opacity:.3},{opacity:0}],{duration:400});
    }
    if (e.type === "travel" && e.stage !== announcedStage) {
      announcedStage = e.stage ?? game!.state.stage;
      audio.transition(announcedStage);
      if (announcedStage === 3) audio.bossPhase(1);
    }
    if (e.type === "bossPhase" && e.phase !== undefined && e.phase < 3) audio.bossPhase((e.phase + 1) as 1 | 2 | 3);
    if (e.type === "clear") audio.victory();
    if (e.type === "vista") { resetSpectacle(); audio.setSceneMood('vista'); }
    if (e.type === "sweep") { audio.sweep(e.count??3); text('score-pop',`${e.count??3}体 一掃！`); punch('score',1.18); }

    if (e.type === "miss") {
      if(!e.lucky) audio.miss();
      feedback(e.lucky ? "続きからどうぞ！ / コンボ継続" : "続きから、落ち着いて。", e.lucky ? "lucky" : "miss");
    }
    if (e.type === "attack" && !e.collateral) {
      audio.hurt();
      feedback("近づかれた！", "damage");
      document.body.classList.remove("hurt");
      void document.body.offsetWidth;
      document.body.classList.add("hurt");
    }
  }
}
function advance(now: number) {
  const dt = Math.max(0, (now - lastTime) / 1000);
  lastTime = Math.max(lastTime, now);
  if (game && screen === "game") {
    if (dt > 0.25) pause("処理が一時的に遅れたため、停止しました。");
    else game.update(dt);
  }
  return Math.min(dt, 0.05);
}
function drawSpectacle(dt:number, s:GameState|null){
  const playing=screen==='game'&&!!s&&!['paused','countdown'].includes(s.mode);
  if(document.body.dataset.playing!==String(playing)) document.body.dataset.playing=String(playing);
  text("heat-marquee",s?.luckyActive?"LUCKY SHOW // BONUS TIME":s?.rushing?"FEVER RUSH // KEEP FIRING":s?.effectsLevel===4?"OVERDRIVE // LIMIT BREAK":`NIGHTSHIFT // HEAT LEVEL ${s?.effectsLevel??0}`);
  fever.update(playing ? dt : 0);
  const phase = fever.phase;
  if (document.body.dataset.fever !== phase) document.body.dataset.fever = phase;
  const feverRoot = el("fever-show");
  show("fever-show", phase !== "off");
  feverRoot.style.setProperty("--fever-impact", String(fever.pulse));
  if (feverRevision !== fever.revision) {
    feverRevision = fever.revision;
    feverRoot.dataset.hits = String(fever.hits);
    text("fever-hit-count", String(fever.hits));
    text("fever-cue-label", phase === "complete" ? "FEVER COMPLETE" : phase === "end" ? "RUSH END" : "FEVER RUSH");
    text("fever-cue-title", phase === "complete" ? "全員退勤" : phase === "end" ? "残業終了" : "限界残業");
    text("fever-cue-caption", phase === "complete" ? "4群突破・道を切り開いた！" : phase === "end" ? "通常勤務へ" : "一語で3体、撃ち抜け。");
    el("fever-hit-count").getAnimations().forEach(a => a.cancel());
    if (preferences.motion && fever.active && fever.hits > 0) el("fever-hit-count").animate(
      [{transform:"scale(1.7) rotate(-12deg)"},{transform:"scale(1) rotate(0deg)"}],
      {duration:450,easing:"cubic-bezier(.15,.75,.2,1)"},
    );
  }
  spectacle.update(playing?dt:0);
  const current=spectacle.current;
  if(current!==renderedCelebration){
    renderedCelebration=current;
    el('showtime').getAnimations().forEach(a=>a.cancel());
    show('showtime',!!current);
    if(current){
      text('show-title',current.title);text('show-caption',current.caption);text('show-badge',current.badge);
      el('showtime').dataset.theme=current.theme;
      el('showtime').dataset.feverCue=String(['限界残業','一体撃破','二連撃','三連撃','四連撃','全員退勤','残業終了'].includes(current.title));
      el('showtime').animate(preferences.motion?[
        {opacity:0,transform:'translateY(18px) scale(1.28) rotate(-5deg)',offset:0},
        {opacity:1,transform:'translateY(0) scale(1) rotate(-3deg)',offset:.12},
        {opacity:1,transform:'translateY(0) scale(1.025) rotate(-3deg)',offset:.78},
        {opacity:0,transform:'translateY(-16px) scale(.95) rotate(-3deg)',offset:1}
      ]:[{opacity:1},{opacity:1,offset:.8},{opacity:0}],{duration:current.remaining*1000,fill:'both',easing:'ease-out'});
    }
  }
  for(const animation of [el('showtime'), el('fever-hit-count')].flatMap(node => node.getAnimations())){
    if(!playing&&animation.playState==='running')animation.pause();
    else if(playing&&animation.playState==='paused')animation.play();
  }
}
function tick(now: number) {
  if (document.body.dataset.screen !== screen) document.body.dataset.screen = screen;
  const dt = advance(now);
  const s = game?.state ?? null;
  if(!document.hidden && screen === "game" && s?.mode !== "paused" && s?.mode !== "countdown") world.update(dt, s);
  events();
  drawSpectacle(dt,s);
  if (s && screen === "game") draw(s);
  audio.setSceneMood(!s||s.mode==='explore'||world.moving?'explore':s.mode==='vista'||s.mode==='clear'?'vista':s.rushing?'fever':'combat');
  const threat=s?.enemies.find(e=>!e.support&&e.telegraph);
  if(threat && !warnedEnemies.has(threat.id)){warnedEnemies.add(threat.id);audio.approach(.85);}
  audio.setLevel(s?.effectsLevel ?? 0);
  audio.setRush(s?.rushing ?? false);
  audio.setLucky(s?.luckyActive ?? false);
  if (s) shownLevel = Math.min(shownLevel, s.effectsLevel);
  if (now > feedbackUntil) el("feedback").textContent = "";
  requestAnimationFrame(tick);
}
window.addEventListener("keydown", (e) => {
  if (e.key === "Tab" && modalKind && !["input", "resume-input"].includes(modalKind)) {
    const controls = [...el("modal").querySelectorAll<HTMLElement>('button:not(:disabled), input, a[href]')];
    const first = controls[0], last = controls.at(-1);
    if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last?.focus(); }
    else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first?.focus(); }
  }
  if (e.key === "Escape") {
    if (screen === "game" && modalKind !== "pause") pause();
    else if (["input", "resume-input"].includes(modalKind)) title();
    else if (["settings", "credits"].includes(modalKind)) {
      if (modalKind === "settings") persist();
      close();
      el("start-button").focus();
    }
    return;
  }
  if (e.isComposing || e.key === "Process" || e.key === "Dead") {
    if (screen === "game") pause("日本語入力がオンになっています。");
    if (screen === "input")
      el("check-status").textContent =
        "日本語入力をオフにして、半角の go を入力してください。";
    return;
  }
  if (e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
  if (screen === "game" && e.key.length === 1 && e.key.charCodeAt(0) > 127) {
    pause("半角英字入力に切り替えてください。");
    return;
  }
  if (
    screen === "input" &&
    ["input", "resume-input"].includes(modalKind) &&
    e.key.length === 1
  ) {
    e.preventDefault();
    if (e.key.toLowerCase() === "go"[check.length])
      check += e.key.toLowerCase();
    else check = "";
    el("check-letters").innerHTML =
      `<span class="typed">${check}</span>${"go".slice(check.length)}`;
    if (check === "go") {
      if (modalKind === "resume-input") {
        screen = "game";
        close();
        game?.resume();
        focus();
      } else start();
    }
    return;
  }
  if(screen==='game' && game?.state.mode==='explore' && ['1','2'].includes(e.key)){
    e.preventDefault();game.chooseRoute(e.key==='1'?'service':'store');focus();return;
  }
  if(screen==='game' && game?.state.mode==='vista' && e.key==='Enter' && !world.moving){
    e.preventDefault();game.continueVista();return;
  }
  if (
    screen === "game" &&
    game?.state.mode === "playing" &&
    /^[a-zA-Z'-]$/.test(e.key)
  ) {
    e.preventDefault();
    advance(
      Math.abs(performance.now() - e.timeStamp) < 10000
        ? e.timeStamp
        : performance.now(),
    );
    game.type(e.key);
    events();
    draw(game.state);
  }
});
input.addEventListener("compositionstart", () => {
  if (screen === "game") pause("日本語入力をオフにしてから再開してください。");
  else if (screen === "input")
    el("check-status").textContent = "半角英字入力に切り替えてください。";
});
input.addEventListener("input", () => (input.value = ""));
window.addEventListener("blur", () =>
  pause("画面を離れたため、一時停止しました。"),
);
document.addEventListener("visibilitychange", () => {
  if (document.hidden) pause("画面を離れたため、一時停止しました。");
});
el("pause-button").onclick = () => pause();
el('route-service').onclick=()=>{game?.chooseRoute('service');focus();};
el('route-store').onclick=()=>{game?.chooseRoute('store');focus();};
el('vista-continue').onclick=()=>{if(!world.moving)game?.continueVista();focus();};
el("start-button").onclick = () => {
  void audio.unlock().then((ok) => {
    if (!ok) notify("音声を開始できませんでした。無音でプレイできます。");
  });
  prepare();
};
el("settings-button").onclick = settings;
el("credits-button").onclick = credits;
el("sound-button").onclick = () => {
  void audio.unlock();
  audio.setVolumes(preferences.music, preferences.effects, !audio.muted);
  el("sound-button").textContent = audio.muted ? "×♪" : "♪";
};
document.querySelector<HTMLAnchorElement>(".brand")!.onclick = (e) => {
  e.preventDefault();
  if (screen === "game") pause();
  else if (screen !== "loading") title();
};
el("hud").onclick = () => {
  if (screen === "game" && !modalKind) focus();
};
async function boot() {
  try {
    world = new World(el("world"));
    world.motion = preferences.motion;
    document.body.dataset.motion = String(preferences.motion);
    const soundReady = Promise.resolve().then(() => audio.load()).catch(() => false);
    await world.load((t) => (el("loading-text").textContent = t));
    if (!(await soundReady)) notify("一部の音源を読み込めませんでした。再読み込みで再試行できます。");
    show("loading", false);
    title();
    lastTime = performance.now();
    requestAnimationFrame(tick);
  } catch (error) {
    console.error(error);
    el("loading").innerHTML =
      '<p class="eyebrow">開店エラー</p><h1>開店できませんでした。</h1><p>3D画面または素材の読み込みに失敗しました。<br>接続とWebGLが有効か確認してください。</p><button id="reload" class="primary">再読み込み</button>';
    el("reload").onclick = () => location.reload();
  }
}
void boot();
