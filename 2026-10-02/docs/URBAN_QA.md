# Urban slice verification

## Scope

The approved revision replaces the stationary mechanical station with a75-second/47m street route and24 zombie encounters. The typing/save foundation remains. A safe first contact teaches one-word kills; contextual CUT is optional. Route completion is not a timeout.

## Regression evidence

`game/tests/run.gd` currently passes4,367 checks, including2,120 declared Japanese aliases, non-destructive errors, uppercase input events, terminal n/nn across target changes, repeated-key rejection, per-target progress, contextual CUT/counter and anti-farming, clean combo/chain feedback, pause/settings freeze, checkpoint rollback, local score isolation and all6 difficulty/language playthroughs.

Each full simulation kills24 enemies with no canonical-input mismatch. Deterministic fast input finishes the active route in75seconds. Camera position changes by more than30m. Existing old campaign records are not reassigned to the new urban score profile. Repeated corpses/effects return to the baseline node count.

This suite does not prove subjective fun, visual quality, real keyboard latency or rendering speed.

## First native captures and corrections

Native Godot was launched through the cloud desktop terminal and inspected through app-scoped UI tools. Actual runtime uses Mesa llvmpipe. First screenshot revealed stretched asphalt UVs, repeated bright facades, incorrect hand framing and excessive idle HUD. Those were treated as defects, not final art.

The second close-range image is explicitly a QA encounter fixture at the route midpoint. It uses the actual renderer, characters and combat HUD but is not a natural-play screenshot. Corrected world-space UVs, connected hands, dark weapon metal, route-distance display and skinned people are visible. Further framing, animation variation, keyed lighting and performance revisions followed.

Initial software-rendered fixture reported3FPS /845 draw calls at1280×880 while an older debug renderer was also running. That old renderer was stopped. Clean final measurement and normal-play evidence are recorded below after recapture.

## Known verification boundaries

- Browser preview was blocked by ERR_BLOCKED_BY_CLIENT in this environment. No bypass was attempted. Web export success is not browser playtest success
- Native audio backend falls back to Dummy. Rain/typing/gunshot/Foley pass objective format/loop/headroom checks, but in-game audible listening is not claimed
- macOS/Windows exports do not establish execution on those operating systems
- No GPU hardware is available in this cloud desktop. GPU quality/performance remain unverified
- No commit, remote push, PR, merge or public deployment was performed

## Final evidence

- Final `GODOT_BIN=/workspace/shared/godot/bin/godot npm run check`: passed original+urban audio checks, Godot import,4,367 regressions and Web export
- New slow-input regression:50seconds without typing leaves one safe visible first target, the camera holds before passing it, and resumes after the kill
- Native key verification: X then A/M/E preserves completion and awards160points; Escape pauses; paused settings lock difficulty/language; restart resets route and score
- Normal-play screenshot: `builds/urban-normal/black_relay_capture.png`; this pre-final-lighting capture records6FPS/310draw calls
- Software fallback native play observed roughly10–16FPS while moving,20–22FPS in pause, with70%3D resolution/full-resolution UI. It remains software rendering, not a GPU performance estimate
- Final reflection/wet-material/light-budget source passed headless checks but was not given another expensive pixel pass after the user requested minimal local testing and Web publication
- A final video was not generated after that instruction. Earlier milestone videos are not evidence of the urban revision
- Web build includes credits.html and public source/license notices. Browser gameplay verification remains for the publication/user assessment pass

## Side-by-side references

Actual old-game baseline: `../2026-09-28/art/verification/v13-station-concourse.png`.
Old station milestone: `docs/screenshots/black-relay-switchyard.png`.
New ordinary encounter: `builds/urban-normal/black_relay_capture.png`.
New staged close encounter: `builds/urban-near/black_relay_capture.png`.
These are comparison inputs, not certification that one game is better.


## Mobile control follow-up

The later Web-only tap/soft-keyboard change and its current validation are recorded in MOBILE_QA.md. Earlier screenshots and source manifests above describe the pre-mobile urban milestone, not an iPhone playtest.
