# Mobile Web input verification

## Change and input contract

The title already had clickable controls; the briefing after it was keyboard-only. The briefing now has a real START hitbox and action, with Space/Enter retained. Touch-to-mouse emulation uses the same handler.

Touch browsers also get HTML menu/combat controls and a real text input. The input opens only from a player gesture (start/resume/input button), never from a frame update. It sends committed ASCII romaji through the existing matcher. Japanese kana conversion is rejected with an English-keyboard instruction, not transliterated into a free correct answer. Paste/drop/prediction replacement are rejected; Backspace/reset clears the selected target. Per-target progress, optional CUT, terminal n/nn, score profiles and difficulty locks remain unchanged.

An external word readout keeps typed/remaining letters readable above the keyboard. Window blur or a hidden tab pauses combat; returning never automatically resumes or reopens the keyboard. Desktop canvas controls and the loading/WebGL error screen remain available.

## Why a browser text input

- Godot's Web virtual-keyboard export option is still marked experimental: <https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html#class-editorexportplatformweb-property-html-experimental-virtual-keyboard>
- iOS WebKit restricts showing the software keyboard without a direct user gesture: <https://bugs.webkit.org/show_bug.cgi?id=195884>
- A retained JavaScriptBridge callback synchronously handles the action and publishes the new state, allowing focus in that same gesture: <https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html>
- VisualViewport resize/scroll events reflect the visible area around a software keyboard: <https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport>

No third-party library, network service, analytics, extra permission, workflow change or new credential is required.

DOM buttons bypass Godot canvas input handlers, including their audio unlock. The synchronous menu/begin callback therefore invokes the pinned 4.7.2 template's `_godot_audio_resume()` through a guarded, engine-local JavaScriptBridge eval. This is a small version-specific adapter, not a public Engine API. The export step asserts that the hook exists and must be reviewed when the engine version changes. It does not generate gameplay key events or move focus through the canvas. Audible behavior still needs device validation.

## Verified

- Godot 4.7.2 headless import and gameplay suite: 4,386 assertions passed, including 19 new touch/web regressions
- New gameplay tests exercise scaled pointer hit-testing into briefing START, repeat-start guard, pause freeze, resume, reset, checkpoint retry, uppercase/IME input gating, target mirroring and locked settings
- Existing 2,120 romaji aliases and all six language/difficulty playthroughs still pass
- Root repository tests: 38 passed
- Existing audio format/headroom/loop and combat-mix checks passed

- Browser event harness: 28 dependency-free Node tests passed (input/composition ordering, transfer rejection, repeated-key rejection, gesture-only focus, desktop blur, menu state, and visual viewport sizing)
- Full app `npm run check`: audio checks, browser event tests, Godot import, gameplay regressions and Web release export passed
- Exported `index.js` contains the pinned audio-resume adapter; `web_mobile.js` is copied next to the generated HTML
- Baseline hosted page was opened in the cloud browser and shows its existing WebGL2 compatibility error. The local shell harness returned `ERR_BLOCKED_BY_CLIENT`; that route was stopped without an alternative bypass. Final portrait/landscape shell pixels are therefore not verified here.

## Not established by these tests

This cloud browser has no WebGL2, so the real exported game's rendering cannot be played here. The execution shell has no X11/Wayland display; native runtime launch was attempted and could not create a display. Neither limitation was bypassed. Headless game checks and a simulated browser callback do not establish actual iPhone Safari/Android keyboard event ordering, keyboard visibility, WebGL performance, subjective playability or in-game audio quality.

The requested minimal local testing scope is retained. No additional native platform builds or expensive software-rendered replay are needed for this Web-only control fix.

## Device check after deployment

On the published page, reload once, tap START and then 出発, and select the English keyboard. Type the first safe target, hide/reopen the keyboard, switch/reset targets, pause/resume, and retry. Check portrait and landscape with the keyboard open. If the page reports missing WebGL2, input changes cannot make that browser render the game.
