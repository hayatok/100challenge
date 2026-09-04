import { useCallback, useEffect, useRef, useState } from "react";
import { loadArt, type Art } from "./art";
import Scene from "./Scene";
import {
  brakingDistance,
  createGame,
  depart,
  parseSeed,
  randomSeed,
  STEP,
  tick,
  totalScore,
  type Game,
} from "./game/simulation";
const demo = import.meta.env.DEV
  ? new URLSearchParams(location.search).get("demo")
  : null;
function initialGame() {
  let game = createGame(
    parseSeed(new URLSearchParams(location.search).get("seed")) ?? randomSeed(),
  );
  if (demo === "lost")
    return {
      ...depart(game),
      status: "lost" as const,
      slip: 1,
      lean: 1.4,
      message: "お客様だけ、先に到着。",
    };
  if (demo === "station" || demo === "won") {
    for (let i = 0; i < (demo === "won" ? 3 : 1); i++) {
      game = depart(game);
      game = { ...game, x: game.route[game.leg].length };
      for (let f = 0; f < 60; f++) game = tick(game, false);
    }
  }
  return game;
}
function readBest() {
  try {
    const n = Number(localStorage.getItem("pudding-best-v1"));
    return Number.isFinite(n) && n >= 0 && n <= 3000 ? Math.floor(n) : 0;
  } catch {
    return 0;
  }
}
function App() {
  const [game, setGame] = useState<Game>(initialGame),
    g = useRef(game);
  const [art, setArt] = useState<Art | null>(null),
    [error, setError] = useState(false),
    [attempt, setAttempt] = useState(0);
  const [paused, setPaused] = useState(false),
    pausedRef = useRef(false),
    input = useRef(false),
    [pressed, setPressed] = useState(false);
  const [best, setBest] = useState(readBest),
    [storageWarning, setStorageWarning] = useState(false),
    [help, setHelp] = useState(false);
  const [reduced, setReduced] = useState(
    () => matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  const [copyText, setCopyText] = useState("路線をコピー");
  const commit = useCallback((next: Game) => {
    g.current = next;
    setGame(next);
  }, []);
  const release = useCallback(() => {
    input.current = false;
    setPressed(false);
  }, []);
  const pause = useCallback(() => {
    release();
    pausedRef.current = true;
    setPaused(true);
  }, [release]);
  useEffect(() => {
    let active = true;
    setError(demo === "error");
    setArt(null);
    if ((demo === "error" || demo === "loading") && attempt === 0) return;
    loadArt()
      .then((a) => {
        if (active) setArt(a);
      })
      .catch(() => {
        if (active) setError(true);
      });
    return () => {
      active = false;
    };
  }, [attempt]);
  useEffect(() => {
    const media = matchMedia("(prefers-reduced-motion: reduce)");
    const change = () => setReduced(media.matches);
    media.addEventListener("change", change);
    return () => media.removeEventListener("change", change);
  }, []);
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.code === "Escape") {
        pause();
        return;
      }
      if (e.code !== "Space" || e.repeat) return;
      const target = e.target as HTMLElement;
      if (
        target.closest("button,a,summary,input") &&
        !target.closest("[data-accelerate]")
      )
        return;
      e.preventDefault();
      if (g.current.status === "running" && !pausedRef.current) {
        input.current = true;
        setPressed(true);
      }
    };
    const up = (e: KeyboardEvent) => {
      if (e.code === "Space") {
        if (input.current) e.preventDefault();
        release();
      }
    };
    const hide = () => {
      if (document.hidden && g.current.status === "running") pause();
    };
    const blur = () => {
      if (g.current.status === "running") pause();
      else release();
    };
    window.addEventListener("keydown", down);
    window.addEventListener("keyup", up);
    window.addEventListener("blur", blur);
    window.addEventListener("pointerup", release);
    document.addEventListener("visibilitychange", hide);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
      window.removeEventListener("pointerup", release);
      document.removeEventListener("visibilitychange", hide);
    };
  }, [pause, release]);
  useEffect(() => {
    if (!art) return;
    let id = 0,
      last = 0,
      accumulator = 0,
      uiTime = 0;
    const frame = (now: number) => {
      const delta = last ? Math.min((now - last) / 1000, 0.05) : 0;
      last = now;
      if (!pausedRef.current && g.current.status === "running") {
        accumulator += delta;
        while (accumulator >= STEP) {
          g.current = tick(g.current, input.current);
          accumulator -= STEP;
        }
        if (now - uiTime > 32 || g.current.status !== "running") {
          setGame({ ...g.current });
          uiTime = now;
        }
      } else accumulator = 0;
      id = requestAnimationFrame(frame);
    };
    id = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(id);
  }, [art]);
  useEffect(() => {
    if (game.status !== "won" || demo) return;
    const score = totalScore(game);
    setBest((old) => Math.max(old, score));
    try {
      localStorage.setItem(
        "pudding-best-v1",
        String(Math.max(readBest(), score)),
      );
    } catch {
      setStorageWarning(true);
    }
  }, [game.status, game.reports]);
  const reset = (seed: number) => {
    release();
    pausedRef.current = false;
    setPaused(false);
    setCopyText("路線をコピー");
    commit(createGame(seed));
    const url = new URL(location.href);
    url.searchParams.set("seed", String(seed));
    history.replaceState(null, "", url);
  };
  const resume = () => {
    pausedRef.current = false;
    setPaused(false);
    requestAnimationFrame(() =>
      document
        .querySelector<HTMLButtonElement>("[data-accelerate]")
        ?.focus({ preventScroll: true }),
    );
  };
  const start = () => {
    release();
    resume();
    commit(depart(g.current));
  };
  const stop = game.route[game.leg],
    distance = stop.length - game.x,
    remaining = stop.deadline - game.elapsed;
  const nextBump = stop.bumps[game.bumpIndex],
    bumpDistance = nextBump === undefined ? null : nextBump - game.x;
  const end = game.status === "won" || game.status === "lost",
    running = game.status === "running";
  const stability = Math.max(0, Math.round((1 - game.slip) * 100));
  const warning =
    game.slip > 0.5
      ? "落下注意！"
      : Math.abs(game.lean) > 0.55
        ? "ぐらぐら"
        : "安定運行";
  const guidance =
    distance < 0
      ? "通り過ぎました。ブレーキで停車。"
      : distance <= stop.tolerance
        ? "停車範囲です。離して止まろう。"
        : distance < brakingDistance(game.speed) + 20
          ? "駅が近い！ 離してブレーキ。"
          : bumpDistance !== null && bumpDistance < 90
            ? `継ぎ目まで ${Math.ceil(bumpDistance)}m。速度を落とすと揺れが小さく。`
            : "押して加速。離すとブレーキ。";
  const share = async () => {
    const url = new URL(location.href);
    url.searchParams.set("seed", String(game.seed));
    try {
      await navigator.clipboard.writeText(url.href);
      setCopyText("コピーしました");
    } catch {
      setCopyText("コピーできません。URL欄からどうぞ");
      history.replaceState(null, "", url);
    }
  };
  return (
    <main className="shell">
      <header className="masthead">
        <a href="../" className="back">
          ← アプリ一覧
        </a>
        <div className="edition">ぷるぷる鉄道 ／ 一日乗車券</div>
        <span className="best">
          最高記録 <b>{best.toLocaleString()}</b>
        </span>
      </header>
      <section className="title-row">
        <div>
          <p className="eyebrow">揺れる車内で、倒れない心。</p>
          <h1>
            プリン<span>通勤</span>
            <i aria-hidden="true">。</i>
          </h1>
        </div>
        <div className="stamp">
          こわれもの
          <br />
          <strong>乗車中</strong>
        </div>
      </section>
      <div className="layout">
        <section className="play-area" aria-label="運転席">
          <div className="destination">
            <span>
              つぎは <strong>{stop.name}</strong>
            </span>
            <span>
              {game.leg + 1} / 3 駅{" "}
              <button
                className="small"
                onClick={() => {
                  if (paused) {
                    resume();
                  } else pause();
                }}
                disabled={!running}
              >
                {paused ? "再開" : "一時停止"}
              </button>
            </span>
          </div>
          <div className="scene">
            {art ? (
              <Scene art={art} game={game} reduced={reduced} />
            ) : (
              <div className="loading" role="status">
                {error
                  ? "素材を読み込めませんでした。"
                  : "プリンが乗車しています…"}
                {error && (
                  <button onClick={() => setAttempt((a) => a + 1)}>
                    読み込みを再試行
                  </button>
                )}
              </div>
            )}
            {art && (
              <>
                <span
                  className={`condition ${game.slip > 0.5 ? "danger" : ""}`}
                >
                  {warning}
                </span>
                <span className="direction">進行方向 →</span>
              </>
            )}
            {art && (game.status === "ready" || paused) && (
              <div className="curtain">
                <div className="boarding">
                  <small>
                    {paused ? "ひとやすみ" : "本日の乗客：プリン 1名"}
                  </small>
                  <h2>{paused ? "運転を一時停止" : "落とさず、遅れず。"}</h2>
                  <p>
                    {paused
                      ? "プリンも休憩しています。"
                      : "押して加速、離してブレーキ。"}
                  </p>
                  <button
                    className="primary"
                    onClick={() => {
                      if (paused) {
                        resume();
                      } else start();
                    }}
                  >
                    {paused ? "運転を再開" : "出発進行"}
                  </button>
                </div>
              </div>
            )}
            {art && end && (
              <div className="end-label">
                <small>
                  {game.status === "won" ? "終点に到着" : "運転終了"}
                </small>
                <strong>
                  {game.status === "won" ? "無事、出勤。" : "プリン、下車。"}
                </strong>
              </div>
            )}
          </div>
          <div className="instruments">
            <div>
              <small>速度</small>
              <strong>
                {Math.round(game.speed * 2)}
                <em>km/h</em>
              </strong>
            </div>
            <div>
              <small>停車位置まで</small>
              <strong>
                {Math.round(distance)}
                <em>m</em>
              </strong>
            </div>
            <div className={remaining < 0 ? "late" : ""}>
              <small>{remaining < 0 ? "遅れ" : "定刻まで"}</small>
              <strong>
                {Math.abs(remaining).toFixed(1)}
                <em>秒</em>
              </strong>
            </div>
          </div>
          <div className="route-meter" aria-label="この駅までの進行状況">
            <div className="rail" />
            <div
              className="stop-zone"
              style={{
                left: `${((stop.length - stop.tolerance) / (stop.length + 75)) * 100}%`,
                width: `${((stop.tolerance * 2) / (stop.length + 75)) * 100}%`,
              }}
            />
            {stop.bumps.map((b) => (
              <span
                key={b}
                className="bump"
                title="線路の継ぎ目"
                style={{ left: `${(b / (stop.length + 75)) * 100}%` }}
              >
                〰
              </span>
            ))}
            <span
              className="train-mark"
              style={{
                left: `${Math.min(97, (game.x / (stop.length + 75)) * 100)}%`,
              }}
            >
              電車
            </span>
            <span className="stop-label">停車範囲</span>
          </div>
          <div className="drive-guidance">
            {running ? guidance : game.message}
          </div>
          {(running || game.status === "ready") && (
            <button
              data-accelerate
              className={`accelerate ${pressed ? "pressed" : ""}`}
              aria-pressed={pressed}
              disabled={!art || !running || paused}
              onPointerDown={(e) => {
                if (e.button !== 0) return;
                e.preventDefault();
                e.currentTarget.setPointerCapture(e.pointerId);
                input.current = true;
                setPressed(true);
              }}
              onPointerUp={release}
              onPointerCancel={release}
              onLostPointerCapture={release}
              onContextMenu={(e) => e.preventDefault()}
            >
              <strong>{pressed ? "加速中" : "押して加速"}</strong>
              <span>{pressed ? "離すとブレーキ" : "長押し / SPACE"}</span>
            </button>
          )}
          {(game.status === "station" || end) && (
            <div className="action-row">
              {game.status === "station" ? (
                <button className="primary" onClick={start}>
                  次の駅へ出発
                </button>
              ) : (
                <>
                  <button className="primary" onClick={() => reset(game.seed)}>
                    同じ路線で再挑戦
                  </button>
                  <button onClick={() => reset(randomSeed())}>
                    新しい路線で出発
                  </button>
                </>
              )}
            </div>
          )}
        </section>
        <aside className="ticket">
          <div className="ticket-top">
            <span>乗 務 記 録</span>
            <small>No. {game.seed}</small>
          </div>
          <div className="stability">
            <div>
              <strong>プリンの安定</strong>
              <b>
                {stability}
                <small>%</small>
              </b>
            </div>
            <meter
              min="0"
              max="100"
              low={45}
              high={70}
              optimum={100}
              value={stability}
            >
              {stability}%
            </meter>
            <p>
              {game.status === "lost"
                ? "お皿を離れてしまいました。再挑戦しよう。"
                : game.slip > 0.5
                  ? "皿の端です。揺れを戻して！"
                  : "傾いたら、加速とブレーキで立て直そう。"}
            </p>
          </div>
          <ol className="stops">
            {game.route.map((s, i) => (
              <li key={s.name} className={i === game.leg ? "current" : ""}>
                <span className="station-dot">
                  {game.reports[i] ? "済" : i + 1}
                </span>
                <div>
                  <strong>{s.name}</strong>
                  <small>
                    {game.reports[i]
                      ? `${game.reports[i].score}点 · ${game.reports[i].passed ? "通過" : game.reports[i].late > 0 ? "遅れて到着" : "定刻到着"}`
                      : `${s.length}m · ${s.bumps.length ? "継ぎ目 " + s.bumps.length + "か所" : "穏やかな線路"}`}
                  </small>
                </div>
              </li>
            ))}
          </ol>
          <div className="score">
            <small>今回の運転評価</small>
            <strong>
              {totalScore(game).toLocaleString()}
              <span>点</span>
            </strong>
            <small>停車位置 ＋ 定刻 ＋ 安全運転</small>
          </div>
          {(game.status === "station" || end) && (
            <div className="report" role="status">
              <h2>{game.message}</h2>
              {game.reports.length > 0 && (
                <p>
                  直前の駅：停車 {game.reports.at(-1)!.accuracy} / 定刻{" "}
                  {game.reports.at(-1)!.time} / 安全 {game.reports.at(-1)!.care}
                </p>
              )}
            </div>
          )}
          {!end && game.status !== "station" && (
            <p className="ticket-note">
              急いでも、プリンは急に
              <br />
              かたくなれません。
            </p>
          )}
          <div className="secondary">
            <button
              onClick={() => {
                setHelp(!help);
                if (running) pause();
              }}
            >
              {help ? "遊び方を閉じる" : "遊び方"}
            </button>
            <button onClick={share}>{copyText}</button>
            {!end && (
              <button onClick={() => reset(randomSeed())}>新しい路線</button>
            )}
          </div>
          {help && (
            <div className="help">
              <p>
                ① 押すと加速、離すとブレーキ。連打より、揺れを見て切り替えよう。
              </p>
              <p>② 継ぎ目は減速して通過。駅の緑の範囲で止まると到着。</p>
              <p>③ 遅刻・通過は減点。皿から落ちたら終了。3駅走れば完走！</p>
              <p>再挑戦は同じ路線。新しい路線は毎回ランダム。Escで一時停止。</p>
            </div>
          )}
          {storageWarning && (
            <p role="status">このブラウザでは最高記録を保存できません。</p>
          )}
        </aside>
      </div>
      <footer>
        <span>安全・安心・おいしい通勤</span>
        <span>音なしで遊べます ／ 1プレイ 約1分</span>
      </footer>
    </main>
  );
}
export default App;
