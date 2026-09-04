import type { Game } from "./game/simulation";

export default function Scene({
  game,
  reduced,
  previous,
  compact,
}: {
  game: Game;
  reduced: boolean;
  previous?: number;
  compact: boolean;
}) {
  const stop = game.route[game.leg],
    distance = stop.length - game.x;
  const c = compact ? 400 : 500;
  const width = compact ? 800 : 1000;
  const lean = game.lean;
  const fall = game.status === "lost" && game.reason === "fall";
  const settled = game.status === "station" || game.status === "won";
  // The caramel's mass center reaches the plate rim at |lean| = 1, the physics failure boundary.
  const top = c + lean * 250,
    base = c + lean * 75;
  const stretch = Math.abs(lean),
    y = 302 + stretch * 24;
  const body = `M ${base - 125} 489 Q ${base - 138} 484 ${base - 116} 450 L ${top - 98} ${y + 15} Q ${top - 95} ${y - 10} ${top - 68} ${y - 9} Q ${top + 12} ${y - 12} ${top + 88} ${y - 3} Q ${top + 110} ${y + 2} ${top + 110} ${y + 26} Q ${top + 112} ${y + 65} ${base + 126} 478 Q ${base + 128} 488 ${base + 112} 490 Z`;
  const marker = Math.max(-90, Math.min(width + 130, c + distance * 13));
  const cx = top + 24,
    cy = y + 65;
  const face = stretch > 0.68 ? "strained" : settled ? "relieved" : "plain";
  const shift = reduced ? 0 : (game.x * 19) % 220;
  const caution = Math.abs(lean) > 0.8;
  const gap =
    Math.abs(distance) < 1
      ? `${Math.round(Math.abs(distance) * 100)}cm`
      : `${Math.abs(distance).toFixed(Math.abs(distance) < 30 ? 1 : 0)}m`;
  const distanceText = distance >= 0 ? `あと ${gap}` : `${gap} 超過`;
  return (
    <svg
      className={`game-scene ${fall ? "fallen" : ""} ${settled ? "settled" : ""}`}
      viewBox={`0 0 ${width} 570`}
      role="img"
      aria-label={`プリンは${fall ? "転倒" : caution ? "皿の端" : settled ? "安定して停車" : "揺れています"}。停止線まで${distance.toFixed(1)}m。`}
    >
      <defs>
        <clipPath id="pudding-body">
          <path d={body} />
        </clipPath>
        <clipPath id="window">
          <rect x="24" y="26" width={width - 48} height="382" rx="24" />
        </clipPath>
      </defs>
      <rect
        x="2"
        y="2"
        width={width - 4}
        height="566"
        rx="18"
        fill="#83aea0"
        stroke="#493526"
        strokeWidth="4"
      />
      <rect
        x="12"
        y="14"
        width={width - 24}
        height="408"
        rx="30"
        fill="#e3bd7d"
        stroke="#493526"
        strokeWidth="4"
      />
      <rect
        className="window-frame"
        x="24"
        y="26"
        width={width - 48}
        height="382"
        rx="24"
      />
      <g clipPath="url(#window)">
        <path
          d={`M0 258 Q120 205 260 264 T540 248 T${width} 255 V380 H0Z`}
          fill="#d3dbc0"
        />
        <g fill="#abc4ac" stroke="#789887" strokeWidth="2">
          {Array.from({ length: 6 }, (_, i) => (
            <g key={i} transform={`translate(${i * 200 - shift * 0.4} 0)`}>
              <path d="M-30 287 V251 L8 225 L48 251 V287Z" />
              <path d="M63 288 V210 H121 V288Z" />
              <path d="M78 226 H105 M78 242 H105 M78 258 H105" fill="none" />
            </g>
          ))}
        </g>
        <rect x="0" y="288" width={width} height="91" fill="#e9d7b1" />
        <path d={`M0 300 H${width}`} stroke="#c6ac7d" strokeWidth="6" />

        <g className="platform" fill="none" strokeWidth="2">
          <path
            d={`M24 242 H${width - 24} M24 365 H${width - 24} M24 373 H${width - 24}`}
          />
          {Array.from({ length: 7 }, (_, i) => (
            <path
              key={i}
              d={`M${i * 220 - shift} 244 V363 M${i * 220 - shift + 8} 244 V363`}
            />
          ))}
          <g transform={`translate(${marker + 145} 0)`}>
            <path d="M-18 25 V373 H22 V25 M-24 33 H28" fill="#f1e3bd" />
            <rect
              x="-18"
              y="217"
              width="40"
              height="22"
              fill="#d64b3b"
              stroke="none"
              opacity=".45"
            />
            <text
              x="2"
              y="177"
              textAnchor="middle"
              writingMode="vertical-rl"
              className="station-name"
            >
              {stop.name}
            </text>
          </g>
        </g>
        <g className="stopping-target" transform={`translate(${marker} 0)`}>
          <rect
            x={-stop.tolerance * 13}
            y="118"
            width={stop.tolerance * 26}
            height="66"
            fill="#f7e1da"
            stroke="#d64b3b"
            strokeWidth="2"
          />
          <path d="M0 109 V192" stroke="#d64b3b" strokeWidth="5" />
          <text y="211" textAnchor="middle" className="target-label">
            停止線
          </text>
        </g>
        {previous !== undefined && (
          <g
            transform={`translate(${c + (distance + previous) * 13} 0)`}
            opacity=".55"
          >
            <path
              d="M0 118 V184"
              stroke="#493526"
              strokeWidth="2"
              strokeDasharray="4 5"
            />
            <text y="233" textAnchor="middle" className="target-label">
              前回
            </text>
          </g>
        )}
        <g className="alignment">
          <path d={`M${c - 7} 94 L${c} 107 L${c + 7} 94 Z`} fill="#302d29" />
          <path
            d={`M${c} 110 V184`}
            stroke="#493526"
            strokeWidth="2"
            strokeDasharray="4 5"
          />
        </g>
      </g>
      <g fill="#fff4d4" stroke="#493526" strokeWidth="3">
        {[c - 240, c + 240].map((x) => (
          <g key={x}>
            <path d={`M${x} 27 V55`} fill="none" />
            <path
              d={`M${x - 10} 57 Q${x} 50 ${x + 10} 57 L${x + 19} 77 Q${x + 19} 85 ${x + 10} 85 H${x - 10} Q${x - 19} 85 ${x - 19} 77Z`}
            />
            <path
              d={`M${x - 9} 64 L${x - 13} 77 H${x + 13} L${x + 9} 64Z`}
              fill="#e3bd7d"
              strokeWidth="2"
            />
          </g>
        ))}
      </g>
      <text x={c} y="78" textAnchor="middle" className="distance">
        {distanceText}
      </text>
      <path
        d={`M24 439 Q24 429 40 429 H${width - 40} Q${width - 24} 429 ${width - 24} 442 V486 H24Z`}
        fill="#477b6b"
        stroke="#493526"
        strokeWidth="3"
      />
      <path d={`M36 443 H${width - 36}`} stroke="#afccaa" strokeWidth="3" />
      <path
        d={`M2 488 H${width - 2} V550 H2Z`}
        fill="#d6aa71"
        stroke="#493526"
        strokeWidth="3"
      />
      <path d={`M3 521 H${width - 3}`} className="shelf" />
      <ellipse cx={c} cy="519" rx="222" ry="9" fill="#302d29" opacity=".08" />
      <path
        d={`M${c - 250} 490 Q${c - 232} 536 ${c} 529 Q${c + 223} 534 ${c + 250} 490 Z`}
        fill="#fff4d4"
        stroke="#493526"
        strokeWidth="3"
      />
      <ellipse
        cx={c}
        cy="490"
        rx="250"
        ry="15"
        fill="#fff4d4"
        stroke="#493526"
        strokeWidth="3"
      />
      <g
        className={`pudding ${fall && lean < 0 ? "fall-left" : ""}`}
        style={{ transformOrigin: `${c + Math.sign(lean) * 250}px 490px` }}
      >
        <path
          d={body}
          fill="#ffcf62"
          stroke="#493526"
          strokeWidth="3"
          strokeLinejoin="round"
        />
        <path
          d={`M${top - 94} ${y + 9} Q${top - 103} ${y - 8} ${top - 65} ${y - 10} Q${top + 10} ${y - 13} ${top + 88} ${y - 3} Q${top + 108} ${y + 2} ${top + 107} ${y + 22} Q${top + 44} ${y + 32} ${top - 55} ${y + 23} Q${top - 84} ${y + 21} ${top - 94} ${y + 9}Z`}
          fill="#884521"
          stroke="#493526"
          strokeWidth="2.5"
        />
        <g clipPath="url(#pudding-body)" pointerEvents="none">
          <path
            d={`M${top + 86} ${y + 32} Q${top + 70} ${y + 100} ${base + 81} 490 H${base + 140} L${top + 132} ${y + 23}Z`}
            fill="#e6ae46"
          />
          <path
            d={`M${top - 82} ${y + 43} l-12 37`}
            stroke="#ffe9a6"
            strokeWidth="11"
            strokeLinecap="round"
          />
        </g>
        <g stroke="#493526" strokeWidth="3" strokeLinecap="round" fill="none">
          {face === "strained" ? (
            <>
              <path
                d={`M${cx - 32} ${cy} l17 4 M${cx + 15} ${cy + 4} l17 -4 M${cx - 20} ${cy + 36} l28 -1`}
              />
              <path d={`M${cx - 17} ${cy + 5} v4 M${cx + 17} ${cy + 5} v4`} />
            </>
          ) : face === "relieved" ? (
            <>
              <path
                d={`M${cx - 32} ${cy + 3} q8 8 16 0 M${cx + 15} ${cy + 3} q8 8 16 0 M${cx - 6} ${cy + 29} h16`}
              />
            </>
          ) : (
            <>
              <path
                d={`M${cx - 22} ${cy} v6 M${cx + 22} ${cy} v6 M${cx - 5} ${cy + 29} h10`}
              />
            </>
          )}
          {caution && (
            <path
              d={`M${top - 128} ${y + 20} q-15 -15 -16 -1 q-1 9 11 8 M${top - 132} ${y - 2} l-8 -9`}
            />
          )}
        </g>
        <path
          d={`M${base + 15 + lean * 95} 416 l12 -6 11 8 -13 13 Z M${base + 25 + lean * 95} 430 Q${base + lean * 12} 459 ${base - 45 - lean * 44} 435 L${base - 61 - lean * 44} 448 Q${base + lean * 25} 481 ${base + 32 + lean * 95} 434 Z`}
          fill="#c65e43"
          stroke="#493526"
          strokeWidth="2.5"
        />
      </g>
      <path
        d={`M${c - 232} 502 Q${c} 526 ${c + 232} 502`}
        fill="none"
        stroke="#477b6b"
        strokeWidth="4"
      />
      {caution && !fall && (
        <path
          d={`M${c + Math.sign(lean) * 257} 472 l${Math.sign(lean) * 12} -8 M${c + Math.sign(lean) * 265} 490 h${Math.sign(lean) * 12}`}
          stroke="#d64b3b"
          strokeWidth="3"
        />
      )}
    </svg>
  );
}
