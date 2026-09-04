import { useCallback, useEffect, useRef, useState } from "react";
import Scene from "./Scene";
import { playSound, unlockSound } from "./sound";
import {
  createGame,
  depart,
  parseSeed,
  randomSeed,
  retry,
  STEP,
  tick,
  totalScore,
  type Game,
} from "./game/simulation";
import { recordedInput } from "./game/recordings";
const params = new URLSearchParams(location.search);
const replay = import.meta.env.DEV ? params.get("replay") : null;
function readBest() {
  try {
    const n = Number(localStorage.getItem("pudding-best-v2"));
    return Number.isFinite(n) && n >= 0 && n <= 3300 ? Math.floor(n) : 0;
  } catch {
    return 0;
  }
}
function useMedia(query: string) {
  const [value, setValue] = useState(() => matchMedia(query).matches);
  useEffect(() => {
    const media = matchMedia(query),
      update = () => setValue(media.matches);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [query]);
  return value;
}
export default function App() {
  const [game, setGame] = useState(() =>
      createGame(parseSeed(params.get("seed")) ?? randomSeed()),
    ),
    g = useRef(game);
  const [pressed, setPressed] = useState(false),
    input = useRef(false);
  const [paused, setPaused] = useState(false),
    pauseRef = useRef(false);
  const [best, setBest] = useState(readBest),
    [storageWarning, setStorageWarning] = useState(false);
  const [help, setHelp] = useState(false),
    [sound, setSound] = useState(false),
    soundRef = useRef(false);
  const [previous, setPrevious] = useState<number | undefined>(),
    [copy, setCopy] = useState("コースをコピー");
  const button = useRef<HTMLButtonElement>(null);
  const compact = useMedia("(max-width: 600px)"),
    reduced = useMedia("(prefers-reduced-motion: reduce)");
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
    pauseRef.current = true;
    setPaused(true);
  }, [release]);
  const resume = useCallback(() => {
    pauseRef.current = false;
    setPaused(false);
  }, []);
  const press = useCallback(() => {
    if (soundRef.current) unlockSound();
    if (pauseRef.current) {
      resume();
      return;
    }
    const current = g.current;
    if (current.status === "ready" || current.status === "station") {
      setPrevious(undefined);
      commit(depart(current));
    } else if (current.status === "lost") {
      setPrevious(current.x - current.route[current.leg].length);
      commit(retry(current));
    } else if (current.status === "won") {
      setPrevious(undefined);
      commit(depart(createGame(current.seed)));
    }
    input.current = true;
    setPressed(true);
  }, [commit, resume]);
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.code === "Escape") {
        if (g.current.status === "running") {
          e.preventDefault();
          if (pauseRef.current) resume();
          else pause();
        }
        return;
      }
      if (e.code !== "Space" || e.repeat) return;
      if (
        (e.target as HTMLElement).closest("button,a,summary,input") &&
        !(e.target as HTMLElement).closest("[data-drive]")
      )
        return;
      e.preventDefault();
      press();
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
    window.addEventListener("pointercancel", release);
    document.addEventListener("visibilitychange", hide);
    return () => {
      window.removeEventListener("keydown", down);
      window.removeEventListener("keyup", up);
      window.removeEventListener("blur", blur);
      window.removeEventListener("pointerup", release);
      window.removeEventListener("pointercancel", release);
      document.removeEventListener("visibilitychange", hide);
    };
  }, [press, release, pause, resume]);
  useEffect(() => {
    let id = 0,
      last = 0,
      accumulator = 0;
    const frame = (now: number) => {
      const delta = last ? Math.min((now - last) / 1000, 0.05) : 0;
      last = now;
      if (!pauseRef.current && g.current.status === "running") {
        accumulator += delta;
        while (accumulator >= STEP && g.current.status === "running") {
          const old = g.current,
            hold = replay ? recordedInput(old, replay) : input.current;
          g.current = tick(old, hold);
          accumulator -= STEP;
          if (soundRef.current) {
            if (!old.caught && g.current.caught) playSound("catch");
            if (g.current.status === "lost")
              playSound(g.current.reason === "fall" ? "fall" : "miss");
            if (g.current.status === "station" || g.current.status === "won")
              playSound("stop");
          }
          if (g.current.status !== "running") {
            input.current = false;
            setPressed(false);
          }
        }
        if (replay && g.current.status === "running")
          setPressed(recordedInput(g.current, replay));
        setGame(g.current);
      } else accumulator = 0;
      id = requestAnimationFrame(frame);
    };
    id = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(id);
  }, []);
  useEffect(() => {
    if (game.status !== "won" || replay) return;
    const next = Math.max(readBest(), totalScore(game));
    setBest(next);
    try {
      localStorage.setItem("pudding-best-v2", String(next));
    } catch {
      setStorageWarning(true);
    }
  }, [game.status, game.reports]);
  function newCourse() {
    release();
    resume();
    setPrevious(undefined);
    setCopy("コースをコピー");
    commit(createGame(randomSeed()));
    const url = new URL(location.href);
    url.searchParams.set("seed", String(g.current.seed));
    history.replaceState(null, "", url);
    button.current?.focus();
  }
  async function share() {
    const url = new URL(location.href);
    url.search = "";
    url.searchParams.set("seed", String(game.seed));
    try {
      await navigator.clipboard.writeText(url.href);
      setCopy("コピーしました");
    } catch {
      setCopy("コピーできませんでした");
    }
  }
  const stop = game.route[game.leg],
    distance = stop.length - game.x;
  const success = game.status === "station" || game.status === "won",
    lost = game.status === "lost";
  const active = game.status === "running";
  const isCatch = game.elapsed - game.catchAt < 0.75;
  const warning = Math.abs(game.lean) > 0.72 && game.angular > 0;
  const report = game.reports.at(-1);
  let title = "";
  let detail = "";
  if (paused) {
    title = "一時停止";
    detail = "離れた指を戻して、再開。";
  } else if (lost) {
    title =
      game.reason === "fall"
        ? "落ちた。"
        : game.reason === "overshoot"
          ? "行きすぎた。"
          : "時間切れ。";
    detail =
      game.reason === "fall"
        ? "前に伸びたら、短く押して戻そう。"
        : game.reason === "overshoot"
          ? `${(game.x - stop.length).toFixed(1)}m 超過。次は少し早く離そう。`
          : "止まりすぎたら、少し加速。";
  } else if (success && report) {
    title =
      Math.abs(report.offset) < 0.3
        ? "ぴたり。"
        : game.status === "won"
          ? "到着。"
          : "停車。";
    detail = `${report.offset < 0 ? "手前" : "超過"} ${Math.abs(report.offset * 100).toFixed(0)}cm${report.recovery ? " ／ 立て直し +250" : ""}`;
  }
  const driveLabel = paused
    ? "再開"
    : lost
      ? "同じ駅でもう一度"
      : game.status === "won"
        ? "同じコースでもう一度"
        : game.status === "station"
          ? "次の駅へ"
          : pressed
            ? "加速中"
            : "押して加速";
  const guidance =
    game.status === "ready"
      ? "赤い停止線を、黒い▼に合わせて止まる。"
      : paused
        ? ""
        : lost
          ? detail
          : success
            ? detail
            : warning
              ? "短く押して戻す"
              : isCatch
                ? "戻った！"
                : game.speed === 0 && distance > stop.tolerance
                  ? "少し押して、停止線へ"
                  : distance < 25 && distance > 12
                    ? "そろそろ離す"
                    : pressed
                      ? "離してブレーキ"
                      : "押し直すと、揺れが戻る";
  return (
    <main>
      <header>
        <h1>プリン通勤</h1>
        <div className="header-tools">
          <span className="station-count">{game.leg + 1} / 3</span>
          <button
            className="quiet"
            disabled={!active}
            onClick={() => (paused ? resume() : pause())}
          >
            {paused ? "再開" : "一時停止"}
          </button>
        </div>
      </header>
      <section className="playfield" aria-label="運転席">
        <div className="scene-wrap">
          <Scene
            game={game}
            compact={compact}
            reduced={reduced}
            previous={previous}
          />
          {(lost || success || paused) && (
            <div className={`outcome ${lost ? "failure" : ""}`} role="status">
              <strong>{title}</strong>
              {success && report && (
                <span>
                  +{report.score}
                  <small>点</small>
                </span>
              )}
            </div>
          )}
          {!lost && !success && !paused && (
            <div className="speed-label">
              {Math.round(game.speed * 3.6)}
              <small> km/h</small>
            </div>
          )}
          {active && game.elapsed > 14 && !paused && (
            <div className="time-left">
              残り {(stop.deadline - game.elapsed).toFixed(1)}秒
            </div>
          )}
        </div>
        <div
          className={`guidance ${warning && !lost ? "urgent" : ""}`}
          role={active ? undefined : "status"}
        >
          {guidance}
        </div>
        <div className="controls">
          <button
            ref={button}
            data-drive
            className={`drive ${pressed && !paused ? "pressed" : ""}`}
            aria-pressed={active ? pressed : undefined}
            onPointerDown={(e) => {
              if (e.button !== 0) return;
              e.preventDefault();
              e.currentTarget.focus({ preventScroll: true });
              e.currentTarget.setPointerCapture(e.pointerId);
              press();
            }}
            onPointerUp={release}
            onPointerCancel={release}
            onLostPointerCapture={release}
            onContextMenu={(e) => e.preventDefault()}
            onKeyDown={(e) => {
              if (e.code === "Enter" && !e.repeat) {
                e.preventDefault();
                press();
              }
            }}
            onKeyUp={(e) => {
              if (e.code === "Enter") release();
            }}
            onClick={(e) => {
              if (e.detail === 0 && !active && !input.current) press();
            }}
          >
            {driveLabel}
          </button>
          <p className="control-caption">
            {lost
              ? "長押しですぐ出発"
              : success
                ? "長押しで出発"
                : "離してブレーキ"}
            <small>長押し / Space</small>
          </p>
        </div>
      </section>
      <footer>
        <span className="score">
          {totalScore(game)}
          <small> 点</small>
          <span className="best">最高 {best}</span>
        </span>
        <div className="footer-tools">
          <button
            onClick={() => {
              setHelp(!help);
              if (active && !paused) pause();
            }}
          >
            遊び方
          </button>
          <button
            onClick={() => {
              const next = !sound;
              soundRef.current = next;
              setSound(next);
              if (next) {
                unlockSound();
                playSound("catch");
              }
            }}
          >
            音 {sound ? "あり" : "なし"}
          </button>
          <button onClick={newCourse}>別のコース</button>
        </div>
      </footer>
      {help && (
        <section className="help" aria-label="遊び方">
          <h2>止めて、戻す。</h2>
          <p>
            押すと加速、離すとブレーキ。赤い範囲が黒い▼に重なったところで止まろう。
          </p>
          <p>
            ブレーキでプリンが前に伸びたら、短く押して立て直す。ただし、押したぶんだけ電車も進む。
          </p>
          <p>
            停車100点 ＋ 停止位置 最大600点 ＋ 速さ
            最大150点。端から戻して停車すると、さらに250点。通過・転倒・20秒経過で失敗。
          </p>
          <p>
            失敗しても同じ駅から。前回の位置が薄い線で残る。別のコースは駅間距離が変わる。3駅とも停車すると完走。
          </p>
          <div className="help-bottom">
            <button onClick={share}>{copy}</button>
            <span>No. {game.seed}</span>
            <span>Escで一時停止</span>
          </div>
        </section>
      )}
      {storageWarning && (
        <p role="status">最高記録を保存できません。このまま遊べます。</p>
      )}
      {replay && (
        <p className="replay-note">
          開発用入力リプレイ：{replay}（実際の物理で再生・記録保存なし）
        </p>
      )}
      <a className="back-link" href="../">
        アプリ一覧
      </a>
    </main>
  );
}
