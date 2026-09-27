import "./style.css";
import { Game, type GameState } from "./game.ts";
import { World } from "./scene.ts";
import { GameAudio } from "./audio.ts";
import { readSave, writeSave } from "./storage.ts";
const app = document.querySelector<HTMLDivElement>("#app")!;
app.innerHTML = `<div id="world" aria-hidden="true"></div><div class="vignette"></div><header><a class="brand" href="#">夜勤<span>NIGHTSHIFT / TYPING</span></a><div class="top-center">● 午前零時の商店街<span id="stage">AFTER HOURS — 00:13</span></div><button id="pause-button" aria-label="一時停止" hidden>Ⅱ</button><button id="sound-button" aria-label="音を切り替える">♪</button></header><div id="loading" class="center-card"><p class="eyebrow">OPENING THE NIGHT</p><h1>夜の準備中…</h1><p id="loading-text" role="status">商店街へ向かっています</p></div><section id="title" hidden><div class="title-copy"><p class="eyebrow">— A MIDNIGHT TYPING SHOOTER</p><h1><span>夜勤</span>タイピング<span class="period">。</span></h1><p class="title-sub">今夜の残業は、少し騒がしい。</p><p class="description">迫るゾンビを、打って撃て。<br>一文字で一発。打ち切って、とどめを。</p><button id="start-button" class="primary">出勤する <span>↗</span></button><div class="title-options"><button id="settings-button">装備と設定</button><button id="credits-button">クレジット</button></div><p class="keyboard-note">⌨ PC・キーボード専用 ／ 1 PLAY 約3–5分</p></div><div class="stamp">深夜勤務<b>歓迎</b><small>NO EXPERIENCE REQUIRED</small></div><footer><span>生きて、定時で帰ろう。</span><span>SHIFT 01 / 黒猫商店街</span></footer></section><section id="hud" hidden><div class="health-block"><p class="eyebrow" id="shift-label"></p><div id="health"></div><small id="practice-label"></small></div><div class="score-block"><div class="score-label">SCORE <b id="score">000000</b></div><div class="combo"><strong id="combo">0</strong><span>COMBO<small id="combo-word">KEEP TYPING</small></span></div></div><div id="targets"></div><div id="feedback" aria-live="polite"></div><div class="reticle">+</div><div id="typing-panel"><div class="panel-top"><span id="target-number"></span><span id="input-status"></span></div><div id="phrase"></div><div id="reading"></div><div id="romaji"></div><div class="deadline"><div id="deadline-bar"></div></div><div class="panel-bottom"><span>一文字、一発。</span><span>ESC 一時停止</span></div></div><div id="travel-message" hidden></div></section><div id="modal" class="modal" hidden><section class="modal-card" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div id="modal-content"></div></section></div><input id="key-capture" type="text" autocomplete="off" autocapitalize="off" spellcheck="false" aria-label="ゲーム入力。半角英字でタイプしてください"><div id="notice" role="status" hidden></div>`;
const el = <T extends HTMLElement = HTMLElement>(id: string) =>
  document.getElementById(id) as T;
const show = (id: string, v: boolean) => {
  el(id).hidden = !v;
};
const save = readSave();
const preferences = save.preferences;
let history = save.results;
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
const input = el<HTMLInputElement>("key-capture");
function notify(t: string) {
  el("notice").textContent = t;
  show("notice", true);
  setTimeout(() => show("notice", false), 4500);
}
function persist() {
  if (!writeSave(preferences, history))
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
  el("modal").querySelector<HTMLButtonElement>("button")?.focus();
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
      )}</div><label class="toggle"><span>練習勤務<small>敵が攻撃しない。ゆっくり打てます。</small></span><input id="practice" type="checkbox" ${preferences.practice ? "checked" : ""}></label><label class="toggle"><span>画面の動き<small>オフで揺れ・強い発光を減らします。</small></span><input id="motion" type="checkbox" ${preferences.motion ? "checked" : ""}></label><label class="range">BGM<input id="music" type="range" min="0" max="100" value="${preferences.music * 100}"></label><label class="range">銃声・効果音<input id="effects" type="range" min="0" max="100" value="${preferences.effects * 100}"></label><button id="settings-close" class="primary">準備できた <span>✓</span></button>`,
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
    `<p class="eyebrow">THE PEOPLE BEHIND THE NIGHT</p><h2 id="modal-title">クレジット</h2><p>企画・ゲーム・街・音楽：NIGHTSHIFT TYPING</p><p>ゾンビ：Rikindle3D / Male City Zombie（CC0）<br>拳銃：loafbrr_1 / Pistol（CC0）<br>腕：para / FPS Arms（CC0）</p><p class="note">素材出典は同梱の THIRD_PARTY_NOTICES.md に記録。元作品のキャラクター・音声・ロゴは使用していません。</p><button id="credits-close" class="primary">商店街へ戻る <span>↗</span></button>`,
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
    `<p class="eyebrow">KEYBOARD CHECK</p><h2 id="modal-title">まず、弾を込めよう。</h2><p>日本語入力をオフにして、<b>go</b> と打ってください。</p><div id="check-letters">go</div><p id="check-status" class="note">そのままキーボードで入力できます。</p><p class="note">正しい文字 → 発砲 ／ 単語完成 → 撃破<br>打ち間違いは打ち直し不要。続きを打てばOK。</p><button id="check-back" class="text-button">タイトルに戻る</button>`,
    "input",
  );
  el("check-back").onclick = title;
  focus();
}
function start() {
  world.reset();
  lastTime = performance.now();
  close();
  game = new Game({
    difficulty: preferences.difficulty,
    practice: preferences.practice,
    seed: Date.now() >>> 0,
  });
  screen = "game";
  saved = false;
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
  history.push({
    score: r.score,
    combo: r.maxCombo,
    accuracy: r.accuracy,
    seconds: r.clearTime,
    cleared: s.mode === "clear",
    difficulty: r.difficulty,
    practice: r.practice,
    retries: r.attempts - 1,
    date: new Date().toISOString(),
  });
  history = history.slice(-10);
  persist();
  modal(
    `<p class="eyebrow">${s.mode === "clear" ? "SHIFT COMPLETE" : "SHIFT INTERRUPTED"}${r.practice ? " / PRACTICE" : ""}</p><h2 id="modal-title">${s.mode === "clear" ? "お疲れさまでした。" : "今夜は、手強かった。"}</h2><p>${s.mode === "clear" ? "商店街に、いつもの静けさが戻った。" : "この区間から、もう一度。"}</p><div class="result-score">${r.score.toLocaleString()}<small>SCORE</small></div><div class="result-grid"><div><b>${r.maxCombo}</b><span>MAX COMBO</span></div><div><b>${r.correct + r.mistakes ? (r.accuracy * 100).toFixed(1) + "%" : "—"}</b><span>正確率</span></div><div><b>${Math.round(r.keysPerMinute)}</b><span>KEYS / MIN</span></div></div><p class="note">勤務時間 ${Math.floor(r.clearTime / 60)}分${Math.floor(r.clearTime % 60)}秒 / リトライ ${r.attempts - 1}回</p><button id="again" class="primary">${s.mode === "defeat" ? "この区間から再出勤" : "もう一度、出勤する"} <span>↗</span></button><button id="result-title" class="text-button">タイトルへ戻る</button>`,
    "result",
  );
  el("again").onclick = () => {
    if (s.mode === "clear") start();
    else {
      game?.retryCheckpoint();
      world.reset(game?.state.stage);
      screen = "game";
      saved = false;
      close();
      audio.start();
      focus();
    }
  };
  el("result-title").onclick = title;
}
const stages = [
  "入口 / ようこそ深夜へ",
  "アーケード / まだ帰れない",
  "裏通り / 残業の気配",
  "終点 / 店長、出勤",
];
function draw(s: GameState) {
  el("stage").textContent = `SHIFT 0${s.stage + 1} — ${stages[s.stage]}`;
  el("shift-label").textContent =
    `SHIFT 0${s.stage + 1} / ${stages[s.stage].split(" / ")[0]}`;
  el("score").textContent = String(s.score).padStart(6, "0");
  el("combo").textContent = String(s.combo);
  el("combo-word").textContent = [
    "KEEP TYPING",
    "NICE SHIFT",
    "ON FIRE",
    "OVERTIME",
    "NIGHT FEVER",
  ][s.effectsLevel];
  el("health").textContent = "♥ ".repeat(s.health) + "♡ ".repeat(3 - s.health);
  el("health").setAttribute("aria-label", `体力 ${s.health} / 3`);
  el("practice-label").textContent = s.practice ? "PRACTICE / 攻撃なし" : "";
  document.body.dataset.level = String(s.effectsLevel);
  const e = s.enemies.find((e) => e.id === s.lockedId) ?? s.enemies[0];
  const sig = JSON.stringify([
    s.enemies.map((e) => [e.id, e.phrase, e.keys, e.locked]),
    e?.typed,
    e?.guide,
  ]);
  if (sig !== signature) {
    signature = sig;
    el("targets").innerHTML = s.enemies
      .map(
        (e) =>
          `<div class="target ${e.locked ? "locked" : ""}" data-enemy="${e.id}"><b>${e.keys.join("/").toUpperCase()}</b><span>${e.phrase}</span></div>`,
      )
      .join("");
    el("phrase").textContent = e?.phrase ?? "次の勤務先へ";
    el("reading").textContent = e?.reading ?? "";
    el("romaji").replaceChildren();
    if (e) {
      const t = document.createElement("span");
      t.className = "typed";
      t.textContent = e.typed;
      const r = document.createElement("span");
      r.textContent = e.guide;
      el("romaji").append(t, r);
    }
    el("input-status").textContent = s.lockedId
      ? "LOCKED ON / そのまま打ち切れ"
      : "最初の一文字で狙う";
    el("target-number").textContent =
      s.stage === 3
        ? `BOSS / ${Math.min(3, s.bossPhase + 1)} OF 3`
        : `TARGET ${String(e?.id ?? 0).padStart(2, "0")}`;
  }
  for (const enemy of s.enemies) {
    const label = el("targets").querySelector<HTMLElement>(
        `[data-enemy="${enemy.id}"]`,
      ),
      pos = world.project(enemy.id);
    if (label && pos) {
      label.style.left = `${Math.max(80, Math.min(innerWidth - 80, pos.x))}px`;
      label.style.top = `${Math.max(145, pos.y)}px`;
      label.classList.toggle("danger", enemy.telegraph);
    }
  }
  el("deadline-bar").style.transform = `scaleX(${e ? 1 - e.progress : 0})`;
  el("deadline-bar").classList.toggle("danger", (e?.progress ?? 0) > 0.75);
  show("travel-message", s.mode === "travel" || s.mode === "countdown");
  el("travel-message").textContent =
    s.mode === "countdown"
      ? "READY…"
      : s.stage === 3
        ? "店長が出勤しました。"
        : "足音が、近づいてくる。";
  if (s.mode !== lastMode) {
    if (s.mode === "playing" && lastMode === "countdown") audio.start();
    if (s.mode === "clear" || s.mode === "defeat") finish(s);
    lastMode = s.mode;
  }
}
function feedback(t: string, kind: string) {
  el("feedback").textContent = t;
  el("feedback").className = kind;
  feedbackUntil = performance.now() + 750;
}
function events() {
  for (const e of game?.drainEvents() ?? []) {
    world.event(e);
    if (e.type === "hit") audio.shot();
    if (e.type === "kill") {
      audio.celebrate();
      feedback(
        game!.state.combo >= 3 ? `${game!.state.combo} COMBO` : "NICE SHOT",
        "good",
      );
    }
    if (e.type === "miss") {
      audio.miss();
      feedback("続きから、落ち着いて。", "miss");
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
  world.update(dt, s);
  events();
  if (s && screen === "game") draw(s);
  audio.setLevel(s?.effectsLevel ?? 0);
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
    await world.load((t) => (el("loading-text").textContent = t));
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
