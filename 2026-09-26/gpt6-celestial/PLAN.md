# GPT–6 / Celestial

- Goal: A 24-second, typography-led celestial teaser introducing Astra, Sol and Luna as a standalone HTML animation.
- Context: User's X reference emphasizes deliberate typography, diverse compositions, beat-based choreography and finishing detail. This is a film prototype before tool development.
- Constraints: No HyperFrames. Plain HTML/CSS/JS and Canvas 2D. No framework or runtime network requests. No invented performance claims. Preserve unrelated repository files. No publishing or MP4 export requested.
- Done when: Portable HTML plays, pauses, scrubs and replays; all names are readable; audio is opt-in; desktop/mobile and reduced motion are checked in a real browser; verification is recorded.

## Treatment

One orbital line becomes a stellar instrument, then a sun, then a lunar terminator. Large type leads; celestial geometry supplies the motion. 24 seconds, 120 BPM, 1920×1080 design canvas.

| Time | Film |
| --- | --- |
| 0–4 | An orbit assembles the numeral 6. THREE BODIES / ONE UNIVERSE. |
| 4–9 | ASTRA: a field of points becomes a constellation, huge letterforms expand out of a narrow aperture. Icy chart lines and spatial depth. |
| 9–14 | SOL: the stellar point ignites into a coral sun. Radial geometry and warm full-screen colour; the O is a sun. |
| 14–19 | LUNA: the sun is eclipsed into a moon. Lunar phases and silver type drift on a dark field. |
| 19–24 | Three bodies orbit a shared centre; they align above a monumental GPT–6 end card. |

## Implementation

1. Author one pure draw(time) renderer with seeded geometry and named phase functions.
2. Build an accessible player around it: play/pause, replay, time scrub, scene jumps, optional original synthesized score, fullscreen.
3. Embed the font, CSS and JS into index.html with a dependency-free build script. Sources remain separately editable.
4. Verify browser interaction and visual frames at every phase plus transitions and responsive widths.

## Design exception

This is an explicitly requested celestial motion-design film, not a daily utility UI. It uses cinematic black/ivory, orbit lines and solar radiance rather than the shared comic app styling. Fonts and repeated spacings are centralized. UI remains understated and separate from the film.

## Progress

## Revision 2 — kinetic typography, 2026-09-26

- Goal: Replace the static title-card pacing with letter deformation, particle-to-type assembly, depth travel, a solar O/eclipse transition, and a lunar orbit-to-6 finale.
- Context: User rejected v1 as weak compared with the viewed X showreels. Existing pure-time Canvas renderer, embedded font and player are reusable. Reference observations: https://x.com/stephanlivera/status/2103315922098470926 and https://x.com/twoclipping/status/2103273003555402193.
- Constraints: No HyperFrames, no new dependencies, keep 24 seconds/120 BPM and opt-in synthesized audio. Save the self-contained original as versions/v1.html. Film-specific palette and full-frame type are an intentional exception to utility app styling.
- Done when: Every act changes internally, all three model names are legible, transitions have distinct mechanisms, seeking remains deterministic, real browser playback and desktop/mobile screenshots are reviewed, checks pass.
- Beat plan: 0–2 ignition typography; 2–4 stars assemble; 4–6 ASTRA type; 6–8 depth flight; 8–10 SOL reveal; 10–12 solar expansion; 12–14 eclipse; 14–16 LUNA type; 16–18 lunar orbital geometry; 18–20 three-body montage; 20–22 orbit-to-6; 22–24 final lockup.
- Verification guide: docs/VERIFICATION.md is absent in the current checkout. Use this artifact's npm run check plus browser evidence, without claiming missing root checks ran.

- Repository guidelines and nearby Canvas renderer reviewed. Target is new, so no pre-existing target screen exists.
- The earlier HyperFrames skill update finished before the user's correction; no HyperFrames project or dependency was created. The deliverable uses no HyperFrames code or tools.
- Implemented the continuous Canvas film, original procedural score, accessible player and standalone build.
- Visually reviewed all five main frames and four responsive widths, and exercised playback/seek/fullscreen/audio controls. `npm run check` passes.
- Direct file navigation and OS reduced-motion simulation remain unverified; see `docs/verification/RESULTS.md`.

## Pages publication

- Goal: Publish CUT 02 as one standalone film before discussing a creation app.
- Context: Existing apps.json registry and release-tag-triggered Deploy GitHub Pages workflow.
- Constraints: Preserve the approved film bytes and unrelated untracked work; reuse prior published apps; publish only the final HTML and cover SVG to the date route.
- Done when: Catalog and film checks pass, PR is merged, release deploy succeeds, and the live Pages route plays correctly.
- Added a dependency-free date-level build wrapper and a catalog entry. Local catalog tests (38), audio tests (2), syntax/build and explicit publication-file checks pass.
- Publication complete: PR #117 merged; release-2026-09-26 deployed successfully; production HTML equality, catalog navigation, playback, desktop and mobile screenshots verified. App planning remains a subsequent task.
