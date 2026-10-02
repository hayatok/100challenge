# Mobile Web keyboard verification

## Focused correction

The prior HTML touch menu and combat panel covered the game on the user's iPhone. They are removed, including the duplicate word/health/score readouts, action buttons and visible input field. Only the existing Godot game UI and the native keyboard remain during play.

The shell retains a transparent 1×1 CSS-pixel, 16px-font input with `pointer-events:none`. It is focusable while playing, stays inside the visible viewport, and cannot intercept a game tap. It is not `display:none`, offscreen or a full-canvas overlay.

- Start, briefing, settings, resume and retry use the existing Godot HUD
- The existing pause footer now has a hitbox; enemy taps retain normal target selection
- Touch is handled once on the canvas, synchronously via JavaScriptBridge, before Godot's buffered touch-to-mouse path can duplicate it or steal focus
- The resulting playing state is published before focus, within the same touchend gesture
- Tapping the game reopens the keyboard even if iOS retains activeElement after dismissal
- State/frame updates, window return and viewport resize never reopen the keyboard
- Cancelled touches, drags and multi-touch do not activate controls
- Desktop mouse and physical keyboard paths remain; Backspace resets and Tab/Enter in the input cycles targets
- ASCII commits, IME-tail deduplication, kana rejection, transfer/prediction rejection and pause-on-background remain

No new dependency, service, workflow, credential or permission is required. The existing pinned Godot 4.7.2 audio-resume adapter also runs for synchronous canvas taps, since those bypass the engine's own touch handler.

## Verified for this correction

- 29 dependency-free Node event/DOM tests: gesture-only focus, repeated reopen, synchronous start/pause/resume, one handled touch, viewport coordinate mapping, interrupted gestures, IME commit ordering/deduplication, transfer rejection, desktop behavior and background pause
- Static shell/style regression: no mobile menu/panel/word/actions or visible keyboard button; exactly one mobile input, with a 1×1 box, opacity 0, pointer-events none, no border/padding, and no display/visibility hiding
- Godot 4.7.2 headless import and gameplay regression: 4,392 assertions, including existing 2,120 romaji aliases and all six language/difficulty playthroughs
- Godot additions cover synchronous existing START/resume hit tests, pause footer, stale-menu hitbox rejection, invalid tap payloads, scaled/offset hit testing and no browser HUD readout
- Root repository tests: 38 passed
- App `npm run check`: audio checks, Node tests, import, gameplay regressions and Web release export

## Verification limits

The cloud browser previously reported missing WebGL2 for the hosted game. The local browser harness previously returned `ERR_BLOCKED_BY_CLIENT`, an access restriction that is not bypassed. This correction therefore verifies mobile UI absence with source DOM and box/style checks, not new rendered mobile screenshots. No iPhone Safari or Android soft keyboard, audible device behavior, subjective playability or GPU performance is claimed verified.

The user's requested minimal local testing scope is retained: no additional native exports or software-rendered replay. A build/CI pass does not establish actual device behavior or live deployment.

## Device check after deployment

Reload the published page, tap START and 出発 in the game, and select the English keyboard. Check that no separate mobile panel covers the scene. Type the first safe target, hide/reopen the keyboard by tapping the game, tap an enemy to select it, use Backspace, and use the in-game pause footer/resume/retry. Check portrait and landscape with the keyboard open. Publication still requires the existing manual Pages workflow after merge.
