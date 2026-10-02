> Historical station milestone report. The current urban revision is documented in URBAN_QA.md.

# Verification report

Date: 2026-10-02 (Asia/Tokyo). Engine: Godot 4.7.2 stable, Compatibility renderer. Asset generation: Blender 4.3.2.

## Passed

- `npm run check`: deterministic audio validation, Godot import, **4,338 assertions**, and single-threaded Web export
- All **2,117 declared romaji spellings** can be typed to completion; alternate spellings, wrong-letter retention, slow optional terminal-n, small-tsu forms, and disjoint CUT/PURGE initials are checked
- Six full headless campaigns (Japanese/English × three difficulties) reach the actual ending and stable results screen
- CUT, PURGE, armored CHOIR, timed BACKFEED, target switching/progress retention, exact score/combo math, accuracy/WPM, boss phases, defeat, checkpoint rollback and retry
- Pause freezes gameplay and tutorial notices; reduced-camera-motion behavior; focus-loss pause path implemented and manual pause tested
- Volume cycling and literal mute; persistence; six independent difficulty/language score profiles; legacy unclassified best retained; profile changes locked during active runs
- No CUT-reset score farming; checkpoint retry cannot duplicate score; results remain stable over time; enemy cleanup and shard particle expiry
- All 16 original WAV assets: rate, channels, duration, headroom, onset, DC and loop seam. Fresh generations are byte-identical. Dense 20-characters/second stress mix peaks at -4.93 dBFS with no clipped samples
- All seven final GLB assets import and instantiate; mesh/material/emission checks pass
- Web, Linux x86_64, Windows x86_64 and macOS universal exports complete without Godot errors
- Exported Linux binary starts and exits cleanly in headless mode
- Custom Web loading/error shell has expanded export placeholders and syntax-valid inline JavaScript

## Native visual and interaction checks

The game was actually launched on the cloud Linux desktop using llvmpipe/OpenGL Compatibility, both from the editor and as a standalone exported executable. Checked 1280×720 game content and the desktop's 1180×812 window composition.

Manually verified title → briefing → first encounter; real keyboard `ito` CUT then `oto` PURGE; score and kill progress; Escape pause; keyboard menu navigation; settings; title return. Main prompts, health, timing, menus and Japanese text are legible.

Native game-only captures verify all four chapter compositions, the enlarged boss, clear combat sightlines, distinct lane-label anchors, and the lower high-contrast word panel. Visual review caught and corrected a front rib blocking the broadcast well, overlapping distant threat labels, insufficient boss scale, and text stacking around the boss notification.

An automated **native rendered** boss sequence reaches the ending/results. The accompanying silent video records the actual viewport with real frame timestamps; it is not a mockup or a claim of manual expert play. Automated input and `--qa-stage` are development verification tools; the permanent campaign tests cover ordinary stage progression.

## Difficulty measurements

A strict input-cadence simulation, with perfect typing, zero reading/reaction latency and a simple target policy, was used for tuning. These are deterministic test results, not a guarantee of human play times.

| Mode / policy | Observed outcome |
|---|---|
| Assist / 30 WPM, all CUT | Win, about 3m59s active time |
| Standard / 30 WPM, all CUT | Win, about 3m26s active time |
| Overdrive / 15 WPM | Fail during Arrival |
| Overdrive / 30 WPM | Fail during Switchyard |
| Overdrive / 45 WPM, purge priority | Win, about 2m28s active time, some damage |
| Overdrive / 45 WPM, cut every threat | Fail during Broadcast Well |
| Overdrive / 60 WPM | Win, about 2m11s–2m12s, no damage |

The short run is approximately a **3–5 minute vertical slice**, plus briefing/reading time and retries. It is not a 10–15 minute campaign. Overdrive introduces longer authored prompts, faster approach and denser waves rather than adding waiting time.

## Limits and unverified areas

- **macOS and Windows exports are build-validated, not runtime-tested on those operating systems**. The macOS universal app is ad-hoc signed and is not Apple-notarized
- **Web browser runtime remains unverified**. The cloud browser returned `ERR_BLOCKED_BY_CLIENT` for the local preview. No alternate route was used to bypass that denial. Web export and shell checks are passed, not equivalent to browser gameplay
- **Subjective audio playback remains unverified**. The native cloud terminal launch had no audio output device and fell back to the Dummy driver. WAV content, import, looping setup and mix levels were checked separately. Final capture launches explicitly selected Dummy
- Native renderer reported unsupported V-Sync switching on llvmpipe; this is an environment warning. GPU hardware performance, broad device coverage and frame-time benchmarking have not been established
- No external human playtest or subjective superiority comparison against commercial games has been established
- Keyboard-first desktop game. Touch/mobile interaction is not a supported primary mode

## Re-run

```sh
GODOT_BIN=/path/to/godot-4.7.2 npm run check
GODOT_BIN=/path/to/godot-4.7.2 npm run build:linux
GODOT_BIN=/path/to/godot-4.7.2 npm run build:mac
GODOT_BIN=/path/to/godot-4.7.2 npm run build:windows
```

Test saves are isolated from normal game records. See `game/tests/run.gd` for executable assertions. Representative native frames are in `docs/screenshots/`. The boss-only QA results frame intentionally shows an eight-second isolated boss run; it is not a full-campaign speedrun. See `docs/AUDIO.md` for waveform validation and `art/validation/` for model-level evidence.
