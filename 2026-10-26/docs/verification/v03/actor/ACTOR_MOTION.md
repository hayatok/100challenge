# v0.3 actor motion verification

Recorded on 2026-10-28 JST with native Godot 4.7.2 Compatibility on Apple M5. This folder records the actor implementation and selected native evidence during integration. The parent integrator maintains the final combined Web/UI, terrain, portrait, Japanese review, Astra, CI and publication evidence. Native screenshots here precede the parent's final terrain and UI acceptance; they are not a claim to show the final public build.

## Implementation and source

- `game/scripts/actor.gd` and `game/scenes/actor.tscn` replace rectangular boot slices with full down/up/side contact poses. Side-left mirrors the side source. Four editable `SpriteFrames` resources use 24 accepted PNG poses.
- Consecutive resolved moves alternate contacts. Re-presenting the same active destination does not restart a step. The root settles at the resolved cell; idle keeps the visual feet grounded.
- A measured per-pose hand socket carries a small native salvage hook. Editable clips provide anticipation, contact, recovery, recoil, arrival, quiet arrival and loss. The hook is generic presentation equipment, not the equipped item model.
- Crab, wader and diver have distinct attack/ready clips. Modal and focus pause freeze clips and bound movement; reduced motion uses static directional/outcome stances and restrained hurt color.
- The family used four original-sheet calls, two initially approved corrective edits and one separately approved Sui separation correction: seven calls total. All seven originals, exact prompts, manifest and source QA are retained under `game/assets/art/v03/`. The rejected Sui seam-trim draft was never imported. The selected Sui correction has six isolated complete figures.
- Source checks found six isolated silhouettes in every selected sheet and real alpha. All 24 normalized canvases retain transparent padding. Pale, stone and water previews were inspected at a 94-unit visible character height. No brown background halo was observed at that scale.

## Automated verification

`actor-probe.txt`: **132 checks, 0 failures**. `actor_probe.gd` checks all four crew identities, null-texture stage configuration, full directional frames, absence of rectangular foot slices, side mirroring, alternating contacts, stable repeated presentation, exact movement settlement, grounded idle, tool anticipation/contact/recovery, supplied recoil direction, local pause/resume, focus pause, quiet arrival, held loss, reduced motion and distinct enemy attacks. It also checks a same-turn queued hurt keeps its recoil direction. The fixture waits for initial process frames before timing clips, so startup loading time does not substitute for action playback time.

`region-probe.txt`: **120 checks, 0 failures** using the existing v0.2 district probe with the new actor implementation. Coverage includes same-seed district switches, state immutability, 625 ground cells, authored blocked landmark anchors, hidden enemy/container/landmark visibility, 48-percent player-foot focus, distinct water and paused clocks.

`import.txt`: Godot native import succeeded after the final runtime actor edits. `git diff --check` passed for the actor script, scene and brief. Rules and integrated UI/Web export are checked separately by the parent integrator.

## Native operation and selected frames

`native_motion_capture.gd` records actual runtime actor clips for every crew member and direction. Selected files show the directional baseline, two successive contacts, anticipation, contact and arrival/quiet-arrival/loss. The full sequential PNG set remains in `.scratch/versions/v03/motion/`. These large clip fixtures use approximately 150-unit actors to make hand/tool alignment and silhouettes inspectable; they are not gameplay screenshots.

`native_game_capture.gd` instantiates the real main scene with `--qa`, keeping player storage untouched. For each of the four workers it resolves two real upward movement actions and captures six frames per step. For combat inspection only, it then places the worker adjacent to a real generated enemy and resolves the actual bump attack, capturing twelve frames. That placement is a fixture, not evidence of a completed route. State JSON remains unchanged while presentation frames play.

The same capture also covers all four district departure screens and inventory overlays, plus 390 by 844, 360 by 740 and 1280 by 900 native window sizes. Selected phone, combat, small and desktop images are stored here. The four district starts use an unlocked-profile fixture; they do not prove the campaign was earned in those captures.

## Limits

There are two source contact poses per facing and no separately authored passing pose. The source art and tool clips improve directional/limb changes, but they are not a continuous articulated character rig. Human playtesting, physical phones, Safari, sound listening and acceptance of fun are unperformed by this actor task. Final exported Web operation and all release decisions belong to the parent integrator.

No further image generation or feature expansion was performed after the user's request to publish v0.3 and then stop.
