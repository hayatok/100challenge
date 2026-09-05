import { CleaningMap } from "./CleaningMap";
import { CELL, cleaningPercent, paintFloor, STATION } from "./game/cleaning";
import { bestRecord, saveRecord } from "./game/records";
import { useEffect, useRef, useState } from "react";
import { GameScene } from "./scene";
import {
  choose,
  synergies,
  synergyHint,
  createGame,
  INFO,
  LIMIT,
  spawnEnemy,
  STEP,
  tick,
  WEAPONS,
  xpNeeded,
  type Game,
  type Point,
  type Upgrade,
  type Weapon,
} from "./game/simulation";
const params = new URLSearchParams(location.search);
const qa = import.meta.env.DEV ? params.get("qa") : null;
const clock = (t: number) =>
  `${Math.floor(t / 60)
    .toString()
    .padStart(2, "0")}:${Math.floor(t % 60)
    .toString()
    .padStart(2, "0")}`;
function seed() {
  const n = Number(params.get("seed"));
  return Number.isInteger(n) && n > 0 && n <= 0xffffffff
    ? n
    : crypto.getRandomValues(new Uint32Array(1))[0];
}
function previewGame() {
  const g = createGame(seed());
  for (let i = 0; i < 12; i++) {
    const e = spawnEnemy(
      g,
      i % 4 === 0 ? "box" : i % 3 === 0 ? "dash" : "dust",
    );
    const a = (i / 12) * Math.PI * 2;
    e.x = Math.sin(a) * (5 + (i % 3) * 2);
    e.z = Math.cos(a) * (5 + (i % 3) * 2);
    e.angle = Math.atan2(-e.x, -e.z);
  }
  return g;
}
function fixture(name: string) {
  const g = createGame(42);
  g.status = "running";
  if (["cleaning", "station", "synergy", "won", "lost"].includes(name)) {
    for (let i = 0; i <= 30; i++)
      paintFloor(g.floor, { x: -i * 0.25, z: -i / 6 }, 1.15);
    for (let i = 0; i <= 45; i++)
      paintFloor(g.floor, { x: i * 0.23, z: Math.sin(i * 0.1) * 3 }, 1.4);
    if (name === "station" || name === "won") {
      g.station.active = true;
      g.station.age = 30;
      paintFloor(g.floor, STATION, 6.5);
    }
    if (name === "synergy") {
      g.weapons = { nozzle: 3, spray: 3, mop: 3, disc: 0 };
      g.level = 9;
    }
    if (name === "cleaning") {
      const e = spawnEnemy(g, "mud");
      e.x = -4;
      e.z = -4;
    }
  }
  if (name === "upgrade") {
    g.level = 4;
    g.status = "upgrade";
    g.choices = ["mop", "spray", "disc"];
  }
  if (name === "won" || name === "lost") {
    g.status = name;
    g.kills = 387;
    g.time = 321;
    g.level = 18;
    g.reason =
      name === "won"
        ? "夜勤完了。朝を迎えよう。"
        : "バッテリー切れ。おつかれさま！";
  }
  if (name === "boss" || name === "stress") {
    g.time = 300;
    g.bossSpawned = true;
    g.level = 22;
    g.weapons = { nozzle: 5, mop: 5, spray: 0, disc: 5 };
    g.boosts = { speed: 3, health: 3, haste: 3, magnet: 3 };
    g.hp = 160;
    g.maxHp = 160;
    for (let i = 0; i < (name === "stress" ? 200 : 30); i++) {
      const e = spawnEnemy(
        g,
        i % 4 === 0 ? "box" : i % 3 === 0 ? "dash" : "dust",
      );
      const a = i * 2.4;
      e.x = Math.sin(a) * (6 + (i % 10));
      e.z = Math.cos(a) * (6 + (i % 10));
    }
    if (name === "boss") {
      const b = spawnEnemy(g, "boss");
      b.x = 0;
      b.z = -6;
    }
  }
  return g;
}
export default function App() {
  const g = useRef<Game>(previewGame()),
    host = useRef<HTMLDivElement>(null),
    scene = useRef<GameScene | null>(null);
  const [version, update] = useState(0),
    [loading, setLoading] = useState(0),
    [error, setError] = useState(""),
    [reload, setReload] = useState(0);
  const [best, setBest] = useState(bestRecord),
    [warning, setWarning] = useState(""),
    [help, setHelp] = useState(false),
    [sound, setSound] = useState(false);
  const [reduced, setReduced] = useState(
      () => matchMedia("(prefers-reduced-motion: reduce)").matches,
    ),
    [fps, setFps] = useState(0);
  const input = useRef<Point>({ x: 0, z: 0 }),
    keys = useRef(new Set<string>()),
    stick = useRef<{ id: number; x: number; y: number } | null>(null),
    [thumb, setThumb] = useState<Point>({ x: 0, z: 0 });
  const soundRef = useRef(false),
    audio = useRef<AudioContext | null>(null),
    saved = useRef(false),
    testFreeze = useRef(qa === "stress"),
    modal = useRef<HTMLDivElement>(null),
    arena = useRef<HTMLDivElement>(null);
  const refresh = () => update((v) => v + 1);
  const clearInput = () => {
    keys.current.clear();
    input.current = { x: 0, z: 0 };
    stick.current = null;
    setThumb({ x: 0, z: 0 });
  };
  const pause = () => {
    if (g.current.status === "running") {
      g.current.status = "paused";
      clearInput();
      refresh();
    }
  };
  const start = () => {
    const next = createGame(seed());
    next.status = "running";
    next.view = g.current.view;
    next.cap = matchMedia("(pointer: coarse)").matches ? 100 : 200;
    g.current = next;
    testFreeze.current = false;
    saved.current = false;
    clearInput();
    setHelp(false);
    refresh();
    arena.current?.focus();
  };
  const resume = () => {
    if (g.current.status === "paused") {
      g.current.status = "running";
      refresh();
      arena.current?.focus();
    }
  };
  const upgrade = (c: Upgrade) => {
    choose(g.current, c);
    clearInput();
    refresh();
    if (g.current.status === "running") arena.current?.focus();
  };
  const beep = (frequency: number) => {
    if (!soundRef.current || !audio.current) return;
    const ac = audio.current,
      osc = ac.createOscillator(),
      gain = ac.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(frequency, ac.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      frequency * 0.5,
      ac.currentTime + 0.08,
    );
    gain.gain.setValueAtTime(0.045, ac.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.12);
    osc.connect(gain);
    gain.connect(ac.destination);
    osc.start();
    osc.stop(ac.currentTime + 0.13);
  };
  useEffect(() => {
    let alive = true;
    let s: GameScene;
    setError("");
    setLoading(0);
    try {
      if (qa === "error" && reload === 0)
        throw new Error("確認用：3Dアセットを読み込めませんでした。");
      s = new GameScene(host.current!, (message) => {
        if (alive) {
          g.current.status = "paused";
          setError(message);
        }
      });
      scene.current = s;
      s.load((n) => alive && setLoading(n))
        .then(() => {
          if (!alive) return;
          if (
            qa &&
            [
              "upgrade",
              "won",
              "lost",
              "boss",
              "stress",
              "cleaning",
              "station",
              "synergy",
              "route",
            ].includes(qa)
          )
            g.current = fixture(qa);
          s.render(g.current, reduced);
          refresh();
        })
        .catch(() => {
          if (alive)
            setError(
              "3Dアセットを読み込めませんでした。通信を確認して再試行してください。",
            );
        });
    } catch (e) {
      setError(
        e instanceof Error && e.message.startsWith("確認用")
          ? e.message
          : "3D表示を開始できませんでした。WebGL対応ブラウザで開き直してください。",
      );
    }
    return () => {
      alive = false;
      s?.dispose();
      scene.current = null;
    };
    // Rendering preferences are read in the frame loop, never reload assets for a toggle.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reload]);
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.code === "Escape") {
        e.preventDefault();
        if (g.current.status === "running") pause();
        else if (g.current.status === "paused" && !help) resume();
        return;
      }
      if (
        g.current.status === "upgrade" &&
        ["Digit1", "Digit2", "Digit3"].includes(e.code)
      ) {
        e.preventDefault();
        if (e.repeat) return;
        const c = g.current.choices[Number(e.code.slice(-1)) - 1];
        if (c) upgrade(c);
        return;
      }
      if (
        g.current.status !== "running" ||
        ![
          "KeyW",
          "KeyA",
          "KeyS",
          "KeyD",
          "ArrowUp",
          "ArrowDown",
          "ArrowLeft",
          "ArrowRight",
        ].includes(e.code)
      )
        return;
      e.preventDefault();
      keys.current.add(e.code);
    };
    const up = (e: KeyboardEvent) => keys.current.delete(e.code),
      hide = () => {
        if (document.hidden) pause();
      },
      blur = () => {
        clearInput();
        pause();
      };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    document.addEventListener("visibilitychange", hide);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
      document.removeEventListener("visibilitychange", hide);
    };
  });
  useEffect(() => {
    let id = 0,
      last = 0,
      acc = 0,
      hud = 0,
      frames = 0,
      measure = 0;
    const frame = (now: number) => {
      const delta = last ? Math.min((now - last) / 1000, 0.1) : 0;
      last = now;
      if (loading === 1 && !error) {
        const game = g.current,
          oldKills = game.kills,
          oldStatus = game.status;
        if (game.status === "running" && !testFreeze.current) {
          acc += delta;
          const k = keys.current;
          const movement = {
            x:
              input.current.x +
              (k.has("KeyD") || k.has("ArrowRight") ? 1 : 0) -
              (k.has("KeyA") || k.has("ArrowLeft") ? 1 : 0),
            z:
              input.current.z +
              (k.has("KeyS") || k.has("ArrowDown") ? 1 : 0) -
              (k.has("KeyW") || k.has("ArrowUp") ? 1 : 0),
          };
          while (acc >= STEP && game.status === "running") {
            tick(game, movement);
            acc -= STEP;
          }
        } else acc = 0;
        scene.current?.render(game, reduced);
        frames++;
        measure += delta;
        if (measure >= 1) {
          setFps(Math.round(frames / measure));
          measure = 0;
          frames = 0;
        }
        if (oldKills !== game.kills) beep(460);
        if (oldStatus !== game.status) {
          clearInput();
          beep(game.status === "upgrade" ? 880 : 250);
        }
        if (
          (game.status === "won" || game.status === "lost") &&
          !saved.current
        ) {
          saved.current = true;
          if (!qa) {
            const previous = bestRecord(),
              record = {
                kills: Math.max(previous.kills, game.kills),
                cleared: previous.cleared || game.status === "won",
              };
            setBest(record);
            setWarning(
              saveRecord(record)
                ? ""
                : "記録を保存できませんでした。このまま遊べます。",
            );
          }
        }
        if (now - hud > 100 || oldStatus !== game.status) {
          hud = now;
          refresh();
        }
      }
      id = requestAnimationFrame(frame);
    };
    id = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(id);
  }, [loading, error, reduced]);
  const game = g.current,
    status = game.status,
    overlay = error || loading < 1 || status !== "running" || help;
  useEffect(() => {
    if (overlay)
      modal.current
        ?.querySelector<HTMLButtonElement>("button:not(:disabled)")
        ?.focus();
  }, [status, loading, error, help, !!overlay]);
  useEffect(
    () => () => {
      void audio.current?.close();
    },
    [],
  );
  function stickMove(e: React.PointerEvent<HTMLDivElement>) {
    if (!stick.current || e.pointerId !== stick.current.id) return;
    const x = e.clientX - stick.current.x,
      z = e.clientY - stick.current.y,
      d = Math.max(42, Math.hypot(x, z));
    input.current = { x: x / d, z: z / d };
    setThumb({ x: (x / d) * 34, z: (z / d) * 34 });
  }
  const boss = game.enemies.find((e) => e.kind === "boss");
  const stationDirection = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][
    (Math.round(
      Math.atan2(STATION.x - game.player.x, game.player.z - STATION.z) /
        (Math.PI / 4),
    ) +
      8) %
      8
  ];
  return (
    <main data-frame={version}>
      <header className="masthead">
        <a href="../" className="back" aria-label="アプリ一覧">
          ←
        </a>
        <div>
          <span className="eyebrow">MIDNIGHT CLEANING CLUB / 01</span>
          <h1>
            ホコリ無双<span>深夜のおそうじ隊</span>
          </h1>
        </div>
        <div className="shift">
          夜勤 00:00—06:00
          <br />
          <b>倉庫街・中央通路</b>
        </div>
      </header>
      <section className="game-shell" aria-label="ホコリ無双ゲーム">
        <div className="hud">
          <div className="health">
            <span>
              BATTERY{" "}
              <b>
                {Math.ceil(game.hp)}
                <small> / {game.maxHp}</small>
              </b>
            </span>
            <div
              className="meter"
              role="meter"
              aria-label="HP"
              aria-valuenow={Math.ceil(game.hp)}
              aria-valuemin={0}
              aria-valuemax={game.maxHp}
            >
              <i style={{ width: `${(game.hp / game.maxHp) * 100}%` }} />
            </div>
          </div>
          <div className="timer">
            <small>夜明けまで</small>
            <strong>{clock(LIMIT - game.time)}</strong>
          </div>
          <div className="kill">
            <b>{game.kills.toString().padStart(3, "0")}</b>
            <span>体 おそうじ</span>
          </div>
          <button
            className="pause"
            onClick={pause}
            disabled={status !== "running" || loading < 1 || !!error}
          >
            一時停止
          </button>
        </div>
        <div
          ref={arena}
          className="arena"
          tabIndex={0}
          aria-label="ゲーム操作領域。WASDまたは矢印キーで移動"
        >
          <div ref={host} className="canvas-host" />
          <div className="floor-label">
            NIGHT SHIFT 02<span>MAKE YOUR OWN WAY.</span>
          </div>
          {loading === 1 &&
            !error &&
            (status === "running" || status === "paused") && (
              <div className="cleaning-hud">
                <span className="clean-rate">
                  清掃率{" "}
                  <b>
                    {cleaningPercent(game.floor)}
                    <small>%</small>
                  </b>
                </span>
                <span className={game.routeBoost ? "route active" : "route"}>
                  {game.routeBoost
                    ? "清掃ルート ＋18%"
                    : "掃除した道はスピードUP"}
                </span>
                <span className="station-state">
                  {game.station.active
                    ? "清掃機 復旧済み・自動清掃中"
                    : game.station.connected
                      ? `接続中 ${Math.round((game.station.progress / 2) * 100)}%`
                      : `清掃機 ${stationDirection} ${Math.ceil(Math.hypot(STATION.x - game.player.x, STATION.z - game.player.z))}m・道をつなごう`}
                </span>
              </div>
            )}
          {boss && (
            <div className="boss-health">
              <b>大掃除のこし</b>
              <div className="meter">
                <i style={{ width: `${(boss.hp / boss.maxHp) * 100}%` }} />
              </div>
            </div>
          )}
          {status === "running" && (
            <>
              <div className="mission">
                {game.station.active && game.time < 30
                  ? "清掃機が復旧！ HP＋20・電池＋5。周囲を自動清掃。"
                  : game.time < 15
                    ? "まずは左上の清掃機へ、掃除しながら進もう。"
                    : game.bossSpawned
                      ? "ボスを倒して、夜勤を終えよう。"
                      : game.time < 60
                        ? "電池で成長。泡＋吸引で連携！"
                        : "茶色い靴の敵は、道を汚す。先に吸おう。"}
              </div>
              <div
                className="joystick"
                aria-label="ドラッグして移動"
                onPointerDown={(e) => {
                  if (stick.current) return;
                  e.currentTarget.setPointerCapture(e.pointerId);
                  const r = e.currentTarget.getBoundingClientRect();
                  stick.current = {
                    id: e.pointerId,
                    x: r.x + r.width / 2,
                    y: r.y + r.height / 2,
                  };
                  stickMove(e);
                }}
                onPointerMove={stickMove}
                onPointerUp={(e) => {
                  if (stick.current?.id === e.pointerId) clearInput();
                }}
                onPointerCancel={(e) => {
                  if (stick.current?.id === e.pointerId) clearInput();
                }}
                onLostPointerCapture={(e) => {
                  if (stick.current?.id === e.pointerId) clearInput();
                }}
              >
                <div
                  style={{ transform: `translate(${thumb.x}px,${thumb.z}px)` }}
                />
                <span>MOVE</span>
              </div>
            </>
          )}
          {overlay && (
            <div
              className={`overlay ${status === "ready" && !error && loading === 1 && !help ? "intro-overlay" : ""}`}
            >
              <div
                ref={modal}
                className={`panel ${status === "upgrade" ? "upgrade-panel" : ""}`}
                role="dialog"
                aria-modal="true"
                aria-label={
                  help
                    ? "遊び方"
                    : error
                      ? "読み込みエラー"
                      : status === "upgrade"
                        ? "装備を強化"
                        : "ゲームメニュー"
                }
                onKeyDown={(e) => {
                  if (e.key !== "Tab") return;
                  const list = Array.from(
                    e.currentTarget.querySelectorAll<HTMLButtonElement>(
                      "button:not(:disabled),a[href]",
                    ),
                  );
                  if (!list.length) return;
                  const first = list[0],
                    last = list[list.length - 1];
                  if (e.shiftKey && document.activeElement === first) {
                    e.preventDefault();
                    last.focus();
                  } else if (!e.shiftKey && document.activeElement === last) {
                    e.preventDefault();
                    first.focus();
                  }
                }}
              >
                {error ? (
                  <>
                    <span className="eyebrow">LOADING ERROR</span>
                    <h2>準備が止まりました</h2>
                    <p role="alert">{error}</p>
                    <button
                      className="primary"
                      onClick={() => {
                        g.current = previewGame();
                        setReload((r) => r + 1);
                      }}
                    >
                      再試行
                    </button>
                  </>
                ) : loading < 1 ? (
                  <>
                    <span className="eyebrow">準備中</span>
                    <h2>お掃除道具を搬入中</h2>
                    <progress value={loading} max={1} />
                    <p>{Math.round(loading * 100)}% 読み込み中</p>
                  </>
                ) : help ? (
                  <>
                    <span className="eyebrow">夜勤のしおり</span>
                    <h2>掃除した道が、逃げ道になる。</h2>
                    <ol>
                      <li>WASD／矢印キー、またはスティックで移動。</li>
                      <li>攻撃は自動。敵が落とす電池を拾うと成長。</li>
                      <li>レベルアップで3択。武器は最大3つ。</li>
                      <li>掃除した道を走り直すと移動速度＋18%。</li>
                      <li>
                        出発地点から左上の清掃機へ道をつなぐと復旧。HP20＋電池5、周囲を自動清掃。
                      </li>
                      <li>泡＋吸引は連鎖攻撃。泡＋モップは幅広い清掃帯。</li>
                      <li>茶色い靴の敵は道を汚す。設備の復旧は副目標。</li>
                      <li>5分でボス登場。6分までに倒せばクリア！</li>
                    </ol>
                    <p>オレンジの矢印は突進の予告。横へ避けよう。</p>
                    <button className="primary" onClick={() => setHelp(false)}>
                      閉じる
                    </button>
                  </>
                ) : status === "ready" ? (
                  <>
                    <span className="stamp">夜勤、出動。</span>
                    <h2>
                      掃除して、
                      <br />
                      つないだ道で
                      <br />
                      <em>生き残れ。</em>
                    </h2>
                    <p>
                      ちいさなロボ vs ホコリの大群。
                      <br />
                      掃除した道をつないで、街を取り戻そう。
                    </p>
                    <button className="primary" onClick={start}>
                      おそうじ開始 <span>→</span>
                    </button>
                    <small>1プレイ6分 / 攻撃はオート</small>
                  </>
                ) : status === "upgrade" ? (
                  <>
                    <span className="eyebrow">
                      LEVEL {game.level} / 作業を一時停止中
                    </span>
                    <h2>掃除が、はかどる。</h2>
                    <p>装備をひとつ選んで再開。</p>
                    <div className="choices">
                      {game.choices.map((c, i) => (
                        <button key={c} onClick={() => upgrade(c)}>
                          <span className="choice-number">0{i + 1}</span>
                          <b>{INFO[c].name}</b>
                          <p>{INFO[c].desc}</p>
                          {synergyHint(game, c) && (
                            <span className="synergy-hint">
                              {synergyHint(game, c)}
                            </span>
                          )}
                          <span className="choice-level">
                            {WEAPONS.includes(c as Weapon)
                              ? `Lv.${game.weapons[c as keyof Game["weapons"]]} → ${game.weapons[c as keyof Game["weapons"]] + 1}`
                              : "強化する"}{" "}
                            →
                          </span>
                        </button>
                      ))}
                    </div>
                    <small>数字キー 1 / 2 / 3 でも選択できます</small>
                  </>
                ) : status === "paused" ? (
                  <>
                    <span className="eyebrow">BREAK TIME</span>
                    <h2>ちょっと、ひと休み。</h2>
                    <p>倉庫の時間は止まっています。</p>
                    <button className="primary" onClick={resume}>
                      おそうじ再開 →
                    </button>
                  </>
                ) : (
                  <>
                    <span className="stamp">
                      {status === "won" ? "業務完了！" : "本日の業務終了"}
                    </span>
                    <h2>
                      {status === "won"
                        ? "朝が来た。道が残った。"
                        : "この道は、がんばった証。"}
                    </h2>
                    <p>{game.reason}</p>
                    <div className="results">
                      <b>
                        {game.kills}
                        <small>体 おそうじ</small>
                      </b>
                      <b>
                        Lv.{game.level}
                        <small>{clock(game.time)} 生存</small>
                      </b>
                    </div>
                    <div className="cleaning-results">
                      <figure>
                        <CleaningMap floor={game.floor} before />
                        <figcaption>出動前</figcaption>
                      </figure>
                      <div>
                        <b>
                          {Math.round(game.floor.cleaned * CELL * CELL)}
                          <small>m²</small>
                        </b>
                        <span>
                          清掃済み · 全体の{cleaningPercent(game.floor)}%
                        </span>
                        <small>
                          {game.station.active
                            ? "清掃機 復旧！"
                            : "清掃機 未復旧"}
                        </small>
                      </div>
                      <figure>
                        <CleaningMap floor={game.floor} />
                        <figcaption>今回の足跡</figcaption>
                      </figure>
                    </div>
                    <p className="result-weapons">
                      {WEAPONS.filter((w) => game.weapons[w])
                        .map((w) => `${INFO[w].name} Lv.${game.weapons[w]}`)
                        .join(" / ")}
                    </p>
                    <button className="primary" onClick={start}>
                      もう一度おそうじ →
                    </button>
                  </>
                )}
              </div>
            </div>
          )}
        </div>
        <div className="xp">
          <b>Lv.{game.level.toString().padStart(2, "0")}</b>
          <div
            className="xp-track"
            role="meter"
            aria-label="経験値"
            aria-valuemin={0}
            aria-valuemax={xpNeeded(game)}
            aria-valuenow={Math.min(game.xp, xpNeeded(game))}
          >
            <i
              style={{
                width: `${Math.min(100, (game.xp / xpNeeded(game)) * 100)}%`,
              }}
            />
          </div>
          <span>
            {game.xp} / {xpNeeded(game)}
          </span>
        </div>
        <div className="synergy-bar" aria-label="装備の連携">
          <b>道具の連携</b>
          <span>
            {synergies(game).join(" ＋ ") ||
              (WEAPONS.filter((w) => game.weapons[w]).length === 3
                ? "連携なし · 次の出動で泡を組み込もう"
                : "泡＋吸引で連鎖攻撃 ／ 泡＋モップで清掃帯")}
          </span>
        </div>
        <div className="equipment">
          <span className="equipment-label">おそうじ装備</span>
          {WEAPONS.filter((w) => game.weapons[w]).map((w) => (
            <div className="weapon" key={w}>
              <b>{INFO[w].name}</b>
              <span>
                {"■".repeat(game.weapons[w])}
                {"□".repeat(5 - game.weapons[w])}
              </span>
            </div>
          ))}
          {Array.from(
            { length: 3 - WEAPONS.filter((w) => game.weapons[w]).length },
            (_, i) => (
              <div className="weapon empty" key={i}>
                空きスロット
              </div>
            ),
          )}
        </div>
      </section>
      <footer>
        <span>
          <b>BEST {best.kills}</b> 体 {best.cleared ? " / クリア済み" : ""}
        </span>
        <div>
          <button
            onClick={() => {
              pause();
              setHelp(true);
            }}
          >
            遊び方
          </button>
          <button
            aria-pressed={sound}
            onClick={() => {
              const next = !sound;
              soundRef.current = next;
              setSound(next);
              if (next) {
                audio.current ??= new AudioContext();
                void audio.current.resume();
              }
            }}
          >
            音 {sound ? "あり" : "なし"}
          </button>
          <button aria-pressed={reduced} onClick={() => setReduced((v) => !v)}>
            演出 {reduced ? "軽減" : "通常"}
          </button>
        </div>
      </footer>
      {warning && (
        <p className="warning" role="status">
          {warning}
        </p>
      )}
      {qa && (
        <aside className="qa">
          <b>開発確認モード（記録なし）</b>
          <span>
            {testFreeze.current ? "時間停止・描画負荷のみ / " : ""}
            {fps} fps / {game.enemies.length} enemies / 清掃{" "}
            {cleaningPercent(game.floor)}% / 連携 {game.comboHits}回 / x{" "}
            {game.player.x.toFixed(1)} z {game.player.z.toFixed(1)}
          </span>
          <button
            onClick={() => {
              g.current = fixture("upgrade");
              testFreeze.current = false;
              refresh();
            }}
          >
            強化を確認
          </button>
          <button
            onClick={() => {
              g.current = fixture("boss");
              testFreeze.current = false;
              refresh();
            }}
          >
            ボス戦を確認
          </button>
          <button
            onClick={() => {
              clearInput();
              input.current = { x: -0.8, z: -0.6 };
            }}
          >
            左上へ走る
          </button>
          <button
            onClick={() => {
              clearInput();
              input.current = { x: 0.8, z: 0.6 };
            }}
          >
            右下へ走る
          </button>
          <button onClick={clearInput}>移動を止める</button>
          {["cleaning", "station", "synergy"].map((name) => (
            <button
              key={name}
              onClick={() => {
                g.current = fixture(name);
                testFreeze.current = false;
                refresh();
              }}
            >
              {name}を確認
            </button>
          ))}
          <button
            onClick={() => {
              g.current = fixture("stress");
              testFreeze.current = true;
              refresh();
            }}
          >
            200体を確認
          </button>
          <button
            onClick={() => {
              g.current = fixture("won");
              testFreeze.current = false;
              refresh();
            }}
          >
            勝利を確認
          </button>
          <button
            onClick={() => {
              g.current = fixture("lost");
              testFreeze.current = false;
              refresh();
            }}
          >
            敗北を確認
          </button>
        </aside>
      )}
    </main>
  );
}
