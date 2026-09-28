import "./style.css";
import { Game, type GameState } from "./game.ts";
import { World } from "./scene.ts";
import { GameAudio } from "./audio.ts";
import { readSave, writeSave, recordResult, betterResult, resultKey, RESULT_RULES_VERSION, type SavedResult } from "./storage.ts";
import { gradeResult, previousComparable, compareResults } from "./results.ts";
import { nextGoal } from "./goals.ts";
const app = document.querySelector<HTMLDivElement>("#app")!;
app.innerHTML = `<div id="world" aria-hidden="true"></div><div class="vignette"></div><div id="combat-glow" aria-hidden="true"></div><header><a class="brand" href="#">夜勤<span>NIGHTSHIFT / TYPING</span></a><div class="top-center">● 午前零時の商店街<span id="stage">AFTER HOURS — 00:13</span></div><button id="pause-button" aria-label="一時停止" hidden>Ⅱ</button><button id="sound-button" aria-label="音を切り替える">♪</button></header><div id="loading" class="center-card"><p class="eyebrow">OPENING THE NIGHT</p><h1>夜の準備中…</h1><p id="loading-text" role="status">商店街へ向かっています</p></div><section id="title" hidden><div class="title-copy"><p class="eyebrow">— A MIDNIGHT TYPING SHOOTER</p><h1><span>夜勤</span>タイピング<span class="period">。</span></h1><p class="title-sub">今夜の残業は、少し騒がしい。</p><p class="description">迫るゾンビを、打って撃て。<br>一文字で一発。打ち切って、とどめを。</p><button id="start-button" class="primary">出勤する <span>↗</span></button><div class="title-options"><button id="settings-button">装備と設定</button><button id="credits-button">クレジット</button></div><p class="keyboard-note">⌨ PC・キーボード専用 ／ 1 PLAY 約3–5分</p></div><div class="stamp">深夜勤務<b>歓迎</b><small>NO EXPERIENCE REQUIRED</small></div><footer><span>生きて、定時で帰ろう。</span><span>ALPHA 0.6 / 黒猫商店街</span></footer></section><section id="hud" hidden><div class="health-block"><p class="eyebrow" id="shift-label"></p><div id="health"></div><small id="practice-label"></small></div><div class="score-block"><div class="score-label">SCORE <b id="score">000000</b></div><div class="combo"><strong id="combo">0</strong><span>COMBO<small id="combo-word">KEEP TYPING</small></span></div><small class="charge-label">FEVER CHARGE</small><div class="fever-track"><div id="fever-fill"></div></div><small id="fever-next"></small></div><div id="rush-banner" hidden><small>短文を続けて、撃ち抜け。</small><strong>FEVER RUSH</strong><div id="rush-pips"></div><span id="rush-count"></span></div><div id="lucky-banner" hidden><small>踊る深夜のボーナスタイム</small><strong>LUCKY SHIFT</strong><div id="lucky-pips"></div><span id="lucky-count"></span><p>3文完成で +500点・体力1回復</p></div><div id="boss-hud" hidden><small>黒猫商店街・終業責任者</small><b>店長 <span id="boss-phase"></span></b><div id="boss-pips"></div></div><div id="targets"></div><div id="milestone" aria-hidden="true"><small id="milestone-caption"></small><strong id="milestone-word"></strong></div><div id="score-pop" aria-hidden="true"></div><div id="feedback" aria-live="polite"></div><div id="reticle" class="reticle">+</div><div id="typing-panel"><div class="panel-top"><span id="target-number"></span><span id="input-status"></span></div><div id="phrase"></div><div id="reading"></div><div id="romaji"></div><div class="deadline"><div id="deadline-bar"></div></div><div class="panel-bottom"><span>一文字、一発。</span><span>ESC 一時停止</span></div></div><div id="travel-message" hidden></div></section><div id="modal" class="modal" hidden><section class="modal-card" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div id="modal-content"></div></section></div><input id="key-capture" type="text" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="ゲーム入力。半角英字でタイプしてください"><div id="notice" role="status" hidden></div>`;
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
  modalKind = kind;
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
}
function title() {
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
  el("stage").textContent = "AFTER HOURS — 00:13";
  el("start-button").focus();
}
function settings() {
  modal(
    `<p class="eyebrow">BEFORE YOUR SHIFT</p><h2 id="modal-title">装備と設定</h2><p class="note">設定はこのブラウザに保存されます。</p><label>勤務の厳しさ</label><div class="difficulty">${[
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
      )}</div><label class="toggle"><span>練習勤務<small>敵の攻撃なし。ラッキーは必ず登場（時間制限あり）。</small></span><input id="practice" type="checkbox" ${preferences.practice ? "checked" : ""}></label><label class="toggle"><span>画面の動き<small>オフで揺れ・強い発光を減らします。</small></span><input id="motion" type="checkbox" ${preferences.motion ? "checked" : ""}></label><label class="range">BGM<input id="music" type="range" min="0" max="100" value="${preferences.music * 100}"></label><label class="range">銃声・効果音<input id="effects" type="range" min="0" max="100" value="${preferences.effects * 100}"></label><button id="settings-close" class="primary">準備できた <span>✓</span></button>`,
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
    `<p class="eyebrow">THE PEOPLE BEHIND THE NIGHT</p><h2 id="modal-title">クレジット</h2><p>企画・ゲーム・街・演出：NIGHTSHIFT TYPING</p><p>住人・作業員・店長の原型：Rikindle3D / Male City Zombie（CC0）<br><small>衣服と肌の配色・体格・補助動作を調整。</small><br>疾走ゾンビ：Rosswet Mobile / <a href="https://opengameart.org/content/thin-zombie-awake-zombie-asset" target="_blank" rel="noreferrer">Thin Zombie [Awake Zombie Asset]</a>（<a href="https://creativecommons.org/licenses/by/3.0/" target="_blank" rel="noreferrer">CC BY 3.0</a>）<br><small>GLB変換・テクスチャ再接続・動作選択・スケール調整。</small><br>拳銃：loafbrr_1 / Pistol（CC0）<br>腕：para / FPS Arms（CC0）</p><p>音楽：MintoDog / <a href="https://opengameart.org/content/darkness-roadremeke" target="_blank" rel="noreferrer">Darkness Road Remake</a>（CC0）<br>打撃・破片：Kenney / Impact Sounds（CC0）<br>銃声：© 2009 Vincent Sevedge / <a href="https://opengameart.org/content/gunshot-sounds" target="_blank" rel="noreferrer">Gunshot Sounds</a>（<a href="https://creativecommons.org/licenses/by/3.0/" target="_blank" rel="noreferrer">CC BY 3.0</a>）<br><small>銃声は切り出し・EQ・圧縮・音量調整をしています。</small></p><p class="note"><a href="./THIRD_PARTY_NOTICES.txt" target="_blank" rel="noreferrer">素材出典とライセンス情報</a>を同梱。元作品のキャラクター・音声・ロゴは使用していません。</p><button id="credits-close" class="primary">商店街へ戻る <span>↗</span></button>`,
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
    `<p class="eyebrow">KEYBOARD CHECK</p><h2 id="modal-title">まず、弾を込めよう。</h2><p>日本語入力をオフにして、<b>go</b> と打ってください。</p><div id="check-letters">go</div><p id="check-status" class="note">そのままキーボードで入力できます。</p><p class="note">正しい文字 → 発砲 ／ 単語完成 → 撃破<br>打ち間違いは打ち直し不要。続きを打てばOK。<br>ゲージ満タンで短文4連戦。赤いタンクの敵は、倒すと隣も巻き込みます。<br>踊るラッキーゾンビはボーナス。見逃してもペナルティなし。</p><button id="check-back" class="text-button">タイトルに戻る</button>`,
    "input",
  );
  el("check-back").onclick = title;
  focus();
}
function start(seed = Date.now() >>> 0) {
  world.reset();
  lastTime = performance.now();
  close();
  game = new Game({
    difficulty: preferences.difficulty,
    practice: preferences.practice,
    seed,
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
    `<p class="eyebrow">ON A BREAK</p><h2 id="modal-title">一時停止</h2><p>${reason}</p><p class="note">敵も制限時間も止まっています。<br>半角英字入力に戻してから再開してください。</p><button id="resume" class="primary">勤務に戻る <span>↗</span></button><button id="quit" class="text-button">タイトルに戻る</button>`,
    "pause",
  );
  el("resume").onclick = () => {
    void audio.unlock();
    screen = "input";
    check = "";
    modal(
      '<p class="eyebrow">KEYBOARD CHECK</p><h2 id="modal-title">再開前の入力確認</h2><p>半角英字で <b>go</b> と入力してください。</p><div id="check-letters">go</div><p id="check-status" class="note">確認中は敵も時間も止まっています。</p><button id="resume-back" class="text-button">タイトルに戻る</button>',
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
    `<p class="eyebrow">${s.mode === "clear" ? "SHIFT COMPLETE" : "SHIFT INTERRUPTED"}${r.practice ? " / PRACTICE" : ""}</p><h2 id="modal-title">${s.mode === "clear" ? "お疲れさまでした。" : "今夜は、手強かった。"}</h2><p>${s.mode === "clear" ? "商店街に、いつもの静けさが戻った。" : "この区間から、もう一度。"}</p><div class="result-hero"><div class="result-grade"><small>RANK</small>${gradeResult(result)}</div><div class="result-score">${r.score.toLocaleString()}<small>SCORE / ${difficulty}${r.practice ? "・練習" : ""}</small></div></div><div class="result-record"><span>${newBest ? "NEW BEST" : "PERSONAL BEST"}<b>${best ? best.score.toLocaleString() : "未達成"}</b></span><span>前回とのスコア差<b>${delta}</b></span></div><div class="result-grid"><div><b>${r.maxCombo}</b><span>MAX COMBO</span></div><div><b>${r.correct + r.mistakes ? (r.accuracy * 100).toFixed(1) + "%" : "—"}</b><span>正確率</span></div><div><b>${Math.round(r.keysPerMinute)}</b><span>KEYS / MIN</span></div></div><div class="result-extra"><span>FEVER <b>${r.rushes}回</b></span><span>巻き込み撃破 <b>${r.chainKills}体</b></span></div><div class="result-lucky">${r.luckyEncounters ? `LUCKY SHIFT <b>${r.luckyClears ? "大当たり" : "遭遇"}</b><span>ボーナス +${r.luckyBonus}</span>` : "今夜のラッキー遭遇なし"}</div><div class="next-goal"><small>NEXT SHIFT / 次の目標</small><b>${goal.title}</b><p>${goal.detail}</p></div><p class="note">${r.practice ? "練習記録は通常勤務と別に保存。 / " : ""}勤務時間 ${Math.floor(r.clearTime / 60)}分${Math.floor(r.clearTime % 60)}秒 / リトライ ${r.attempts - 1}回</p><button id="again" class="primary">${s.mode === "defeat" ? "この区間から再出勤" : "同じ出題でもう一度"} <span>↗</span></button><div class="result-actions">${s.mode === "clear" ? '<button id="new-run" class="text-button">新しい出題で出勤</button>' : ""}<button id="result-title" class="text-button">タイトルへ戻る</button></div>`,
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
  "入口 / ようこそ深夜へ",
  "アーケード / まだ帰れない",
  "裏通り / 残業の気配",
  "終点 / 店長、出勤",
];
function draw(s: GameState) {
  if(s.mode === "playing") luckyOutro=null;
  text("stage", `SHIFT 0${s.stage + 1} — ${stages[s.stage]}`);
  text("shift-label", `SHIFT 0${s.stage + 1} / ${stages[s.stage].split(" / ")[0]}`);
  text("score", String(s.score).padStart(6, "0"));
  text("combo", String(s.combo));
  text("combo-word", [
    "KEEP TYPING",
    "NICE SHIFT",
    "ON FIRE",
    "OVERTIME",
    "NIGHT FEVER",
  ][s.effectsLevel]);
  text("health", "♥ ".repeat(s.health) + "♡ ".repeat(3 - s.health));
  el("health").setAttribute("aria-label", `体力 ${s.health} / 3`);
  text("practice-label", s.practice ? "PRACTICE / 攻撃なし" : "");
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
  text("fever-next", s.rushing ? `RUSH / 残り ${s.rushRemaining} 体` : s.stage === 3 ? "FINAL SHIFT / 店長を撃退せよ" : s.rushes >= 2 ? "FEVER 2 / 2 — 今夜のラッシュ終了" : s.rushCharge >= 100 ? "READY / この集団の後に突入" : `CHARGE ${Math.round(s.rushCharge)}% / 撃破でたまる`);
  show("rush-banner", s.rushing);
  text("rush-count", `残り ${s.rushRemaining} / 4`);
  if (el("rush-pips").dataset.remaining !== String(s.rushRemaining)) {
    el("rush-pips").dataset.remaining = String(s.rushRemaining);
    el("rush-pips").innerHTML = [0,1,2,3].map(i => `<i class="${i < 4-s.rushRemaining ? "done" : ""}"></i>`).join("");
  }
  show("boss-hud", s.stage === 3 && s.mode !== "clear");
  text("boss-phase", ["01 / 開店準備", `02 / 反撃 ${s.bossCounter || 1}/3`, "03 / 最終通告"][Math.min(2, s.bossPhase)]);
  if (el("boss-pips").dataset.phase !== String(s.bossPhase)) {
    el("boss-pips").dataset.phase = String(s.bossPhase);
    el("boss-pips").innerHTML = [0,1,2].map(i => `<i class="${i < s.bossPhase ? "done" : i === s.bossPhase ? "active" : ""}"></i>`).join("");
  }
  const e = s.enemies.find((e) => e.id === s.lockedId) ?? s.enemies[0];
  const blastVictims = new Set(s.enemies.flatMap(e => e.explosive ? e.blastTargets : []));
  const sig = JSON.stringify([
    s.enemies.map((e) => [e.id, e.phrase, e.keys, e.locked, e.threatRank, e.explosive, e.blastTargets, e.lucky]),
    e?.typed,
    e?.guide,
    s.mode, s.rushing, s.bossCounter, s.luckyActive, s.luckyStep,
  ]);
  if (sig !== signature) {
    signature = sig;
    el("targets").innerHTML = s.enemies
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
      r.textContent = e.guide;
      el("romaji").append(t, r);
    }
    text("input-status", s.luckyActive ? "ミス・見逃しでコンボは切れません" : s.lockedId
      ? "LOCKED ON / そのまま打ち切れ"
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
    if (s.mode === "playing" && lastMode === "countdown") audio.start();
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
  el("milestone-caption").textContent = `COMBO LEVEL ${level} / 勤務熱量上昇`;
  el("milestone-word").textContent = ["", "NICE SHIFT", "ON FIRE", "OVERTIME", "NIGHT FEVER"][level];
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
    world.event(e);
    if (e.type === "hit") {
      audio.shot({lucky:e.lucky, rush: game!.state.rushing, zone: e.hitZone === "head" ? "head" : e.hitZone === "shoulder" ? "limb" : "body", finishing: e.finisher, level: e.effectsLevel ?? game!.state.effectsLevel});
      punch("reticle", 1.55);

    }
    if (e.type === "kill" && !e.collateral) {
      audio.kill(e.combo ?? game!.state.combo, e.kind === "boss" ? "boss" : "normal");
      const combo = e.combo ?? game!.state.combo;
      const level = e.effectsLevel ?? game!.state.effectsLevel;
      feedback(e.kind === "boss" ? e.phase === 2 ? "SHIFT COMPLETE" : "ARMOR BREAK" : e.clean ? "CLEAN KILL" : "TAKE DOWN", "good");
      el("score-pop").textContent = `+${e.scoreDelta ?? 100}${combo >= 3 ? " / " + combo + " CHAIN" : ""}`;
      el("score-pop").getAnimations().forEach(a => a.cancel());
      el("score-pop").animate(preferences.motion ? [{opacity: 1, translate: "0 10px"}, {opacity: 0, translate: "0 -20px"}] : [{opacity: 1}, {opacity: 0}], {duration: 900});
      punch("combo", 1.35);
      punch("score", 1.12);
      const arrival = level > shownLevel;
      const streak = !arrival && combo >= 20 && combo % 5 === 0;
      if (arrival) { milestone(level); audio.tier(level); }
      if (streak) { milestone(4); el("milestone-caption").textContent = `${combo} COMBO / まだ止まらない`; el("milestone-word").textContent = "UNSTOPPABLE"; audio.streak(combo); }
      shownLevel = level;
      if (preferences.motion) el("combat-glow").animate([{opacity: arrival || streak ? .42 : .14}, {opacity: 0}], {duration: 380});
    }
    if(e.type === "luckyStart") {
      audio.luckyStart(); text("feedback","");el("score-pop").getAnimations().forEach(a=>a.cancel());milestone(3);text("milestone-caption","今夜は、ツイてる。");text("milestone-word","LUCKY SHIFT");
    }
    if(e.type === "luckyStep") { audio.luckyWord(e.step ?? 1);feedback(`${e.step} / 3 — NICE MOVES!`,"lucky"); }
    if(e.type === "luckyEnd") {
      luckyOutro=!!e.success;
      audio.luckyEnd(!!e.success);
      if(e.success){
        milestone(3);text("milestone-caption",e.healing ? "大当たり / 体力 +1" : "大当たり / 体力は満タン");text("milestone-word","LUCKY CLEAR!");
        text("score-pop",`BONUS +${e.scoreDelta ?? 500}`);
        el("score-pop").getAnimations().forEach(a=>a.cancel());
        el("score-pop").animate([{opacity:1},{opacity:0}],{duration:1600});punch("score",1.2);feedback("お疲れさまでした！","lucky");
      } else feedback("また会う日まで！ / ペナルティなし","lucky");
    }
    if (e.type === "rushStart") {
      audio.rushStart(); milestone(4); text("milestone-caption", "ゲージ解放 / 短文4連戦"); text("milestone-word", "FEVER RUSH");
    }
    if (e.type === "rushEnd") {
      audio.rushEnd(); feedback(e.success ? "RUSH COMPLETE / 4体撃破" : "RUSH END / 通常戦へ", "good");
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
    if (e.type === "miss") {
      if(!e.lucky) audio.miss();
      feedback(e.lucky ? "続きからどうぞ！ / コンボ継続" : "続きから、落ち着いて。", e.lucky ? "lucky" : "miss");
    }
    if (e.type === "attack") {
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
function tick(now: number) {
  const dt = advance(now);
  const s = game?.state ?? null;
  if(!document.hidden && screen === "game" && s?.mode !== "paused" && s?.mode !== "countdown") world.update(dt, s);
  events();
  if (s && screen === "game") draw(s);
  audio.setLevel(s?.effectsLevel ?? 0);
  audio.setRush(s?.rushing ?? false);
  audio.setLucky(s?.luckyActive ?? false);
  if (s) shownLevel = Math.min(shownLevel, s.effectsLevel);
  if (now > feedbackUntil) el("feedback").textContent = "";
  requestAnimationFrame(tick);
}
window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    if (screen === "game" && modalKind !== "pause") pause();
    else if (["input", "resume-input"].includes(modalKind)) title();
    else if (["settings", "credits"].includes(modalKind)) {
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
      '<p class="eyebrow">SOMETHING WENT WRONG</p><h1>開店できませんでした。</h1><p>3D画面または素材の読み込みに失敗しました。<br>接続とWebGLが有効か確認してください。</p><button id="reload" class="primary">再読み込み ↗</button>';
    el("reload").onclick = () => location.reload();
  }
}
void boot();
