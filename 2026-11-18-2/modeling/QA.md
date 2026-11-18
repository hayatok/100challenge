# Automated campaign evidence

The driver `qa_campaign.gd` observes actor positions and game state, aims precisely, and submits controls through the production UI bridge. It never changes health, enemy health, player position, wave counters, doors, or progression. It uses seed 918 and a fixed 60 Hz simulation. Test saves use `user://qa_campaign.cfg`.

```
Godot --headless --path game --fixed-fps 60 --script ../modeling/qa_campaign.gd -- --input=touch --out=/tmp/dead-freight-run/touch-final
Godot --path game --resolution 960x540 --fixed-fps 60 --script ../modeling/qa_campaign.gd -- --input=touch --retry --capture-chapters --capture-boss --out=/tmp/dead-freight-run/atlas-final-clips
```

`--input=touch` sends three fingers through `bridge._input`: left stick, right look drag, and fire. This exercises UI hit regions, touch aim scaling, dead zone, ownership selection, and `consume_controls`. It is an automated three-finger test, not evidence of two-thumb ergonomics or real Safari events. The headless harness uses a 960x540 SubViewport because its native dummy window is only 64x64. `--input=pc` sends key and mouse events, but the headless display cannot satisfy the production mouse-capture guard; that run failed and is not a PC input pass. The default bridge mode is a weaker direct bridge-state driver and is labelled separately.

`--retry` permits at most three normal checkpoint retry signals after death and records every death. It does not skip a checkpoint or refill inventory outside the normal game path. No retry was needed in the latest complete atlas capture run.

GPU clips are silent 960x540 native OpenGL captures sampled at 6 frames per simulated second. Chapter clips show the first 15 seconds of each chapter; boss clips show the final encounter. Rendering is explicitly stepped for the captured frames while normal physics and game logic continue at 60 Hz. These clips are not a frame-rate benchmark. The native test window is unfocusable and uses touch mode to avoid capturing the user's mouse.

Evidence under `/tmp/dead-freight-run/` is ephemeral. `campaign-baseline.mp4` uses earlier assets and progression. `atlas-final-clips/` uses final atlas assets and expanded routes, before the review correction narrowing boss sweep damage to the visible arc. `reviewed-boss/` is the post-review capture. Keep those versions separate. Exact run results, stage transitions, rally arrival positions, deaths, and boss states are in each run's `events.jsonl`.

Known evidence limits: automatic perfect aim is much stronger than ordinary human play; simulation duration is not a completion-time promise. Successful campaign runs can emit ObjectDB/resource warnings on process shutdown; no such warning is treated as a gameplay failure or silently removed from the logs. Human/browser performance and two-finger usability require separate verification.
