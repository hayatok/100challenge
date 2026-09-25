# Verification — 2026-09-26

## Deliverable

- `index.html`: approximately 212 KiB, single-file HTML with embedded font, CSS, renderer, player and original audio synthesis. 24 seconds, 1920×1080 design coordinates. No HyperFrames or third-party runtime.
- Source files, dependency-free build script, font licence, README and two audio tests are contained in this project directory.

## Commands

- `npm run check`: passed. JavaScript syntax checks for the three sources; two Node tests; standalone build.
- Audio tests cover exact duration/channel lengths, finite samples, non-silence, unclipped peak, fade to silence, stereo difference and repeatable synthesis.
- `git diff --check`: passed for tracked changes. This deliverable is new/untracked and has not been committed.
- Dedicated lint/typecheck tools are not configured in this plain JavaScript project.

## Browser verification

Used the Codex in-app Chromium browser at `http://127.0.0.1:8266/`.

- Reviewed actual screenshots of the opening, Astra at 6s, Sol at 11s, Luna at 16s, and the end card at 23–24s.
- Reviewed 375×812, 768×1024, 1024×768 and 1440×900 layouts. No horizontal document overflow; names and playback controls remain visible. Secondary film metadata intentionally scales with the 16:9 artwork.
- Verified play, pause, replay, scene jumps and slider seeking. Observed time advancing through the film and stopping at exactly 24s with a replay control.
- Verified sound toggle from OFF to ON and resumed playback from a nonzero offset without browser errors. The waveform was tested numerically; the agent did not directly audition the sound, so perceptual mix quality is not claimed as verified.
- Verified fullscreen entry, dedicated fullscreen play/pause controls and exit back to the player. Space and Right keyboard actions were exercised in fullscreen.
- Embedded font reports loaded. Browser console error/warning query returned no entries during the checked run.
- Reviewed the solar handoff during playback; matched its outgoing disc centre to the incoming solar scene.
- Changed desktop fitting to leave room for controls, and kept the final card free of a replay overlay.

## Boundaries

- Direct `file://` navigation was blocked by the browser tool's URL security policy. No workaround was attempted. The delivered file is fully embedded, but double-click launch was not directly verified. Local HTTP playback was verified.
- Reduced-motion behavior is implemented as no autoplay (the default for everyone) and pause on a newly enabled reduced-motion preference. No OS preference was changed to test the media query.
- No MP4, publishing, production deployment, catalog registration, or model-quality comparison is part of this deliverable.
- The pre-correction HyperFrames skill-refresh command had completed. No HyperFrames project files, runtime dependencies, rendering or validation tools were used to make this film.

## CUT 02 revision — 2026-09-26

### Changes

- Preserved the original self-contained film at `versions/v1.html` before editing.
- Replaced the film renderer with particle-to-ASTRA assembly, spring-driven large typography, a perspective star flight, solar radial choreography, a continuous eclipse-to-moon transition, sliced LUNA type, a three-column family portrait, and particles forming the final 6.
- Re-timed the original synthesized score to the new 2/4/6/8/10/14/18/20/22-second accents; added synthesized swells and percussion and dropped drums during the eclipse.
- Kept the standalone HTML build, existing player, explicit playback, optional audio, and no external dependencies. Updated scene jump times and the CUT 02 edition label.

### Verification performed on CUT 02

- `npm run check`: syntax checks, both audio waveform tests and embedded HTML build pass. Dedicated lint/typecheck are not configured.
- Actual IAB playback advanced from 0 to 24 seconds and stopped with the replay control, both muted and with synthesized audio enabled. Sound OFF/ON controls and scene jumps work. Audio perception was not auditioned; waveform properties and the browser control path were verified.
- Screenshots reviewed at 3.2, 4.8, 6.8, 9.1, 10.8, 13.2/13.8, 14.5, 15.2, 17, 19, 21.99, 22.01 and 23 seconds, plus frames sampled during playback. Fixed alpha overlap during the eclipse and aligned the closing numeral to its final typesetting coordinates.
- Desktop 1440×900, 1024×768, tablet 768×1024 and phone 375×812 screenshots inspected. Main names fit; controls remain usable. At 375/768/1024, measured document width equals viewport width. Small artwork metadata scales with the film and is secondary to the model names.
- A clipped browser screenshot at 6.75 seconds matched byte-for-byte after seeking forward to 15.2 seconds and back to 6.75 seconds.
- Fullscreen entry, fullscreen play/pause and exit were exercised. Browser error/warning logs were empty during the checked run. Font status was loaded.
- Browser was returned to normal viewport, paused poster, sound OFF. The preview remains at http://127.0.0.1:8266/.
- Direct file launch and OS reduced-motion preference change remain unverified as noted above. No MP4/export or publication was requested or performed. No claim of model parity is inferred from these checks.
