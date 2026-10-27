# v0.3 art and motion brief

Status: the parent integrator approved this direction and asset-only source production during v0.2 on 2026-10-28 JST. Generated originals and QA stay in ignored `.scratch/versions/v03/art/` until v0.2 is committed. Actor code and imported game assets remain on hold until the parent integrator opens the v0.3 implementation phase.

## Intended experience

A worker should look as though she is choosing a route, planting her weight, carrying a tool and responding to what happened. The current field miniature has a split lower hem, but translating two rectangular boot crops while the whole portrait bobs does not provide a convincing stride. The next pass must change the silhouettes of the legs, arms and coat, not increase that bob.

Preserve the Sunlit Tideglass family, four adult identities, 64-unit tiles, approximately 94-unit field character height and the current player-foot focal position. The district renderer introduced in v0.2 already reads actual district geometry and authored blocked anchors. v0.3 should refine that presentation through motion rather than add unrelated scenery over the maps.

## Asset production target

Use a small directional pose family with real changes in silhouette, then animate the visible tool and secondary parts in engine. Keep all original portraits and R2 miniatures. New files belong in `game/assets/art/v03/`, with prompts, source paths, alpha/crop reports, pivot measurements and inspected contact sheets recorded in a manifest.

First produce Isana only: six isolated full-body field poses arranged as three facing pairs, viewed down, up and sideways. Each pair contains left-foot contact and right-foot contact. Both boots, knees, hands, the coat hem and equipment must be distinct and anatomically plausible. Side poses may be mirrored horizontally after inspection; vertical facing requires a different source silhouette. Each pose should fit a 256 by 320 logical cell, use the same head size and clothing volume, and place the planted foot on a common baseline. Generated grid spacing is a request; inspect actual bounds before slicing.

The technical target is transparent RGBA, no ground shadow or scene background, clean silhouette, no text or labels, upper-left daylight, controlled outlines and approximately 3.5-head field proportions. All four workers remain adults: Isana has a chestnut ponytail and ochre coat; Ritsu a silver bob, navy clothing and red scarf; Kohaku copper curls, brown skin and rust workwear; Sui long black hair, ivory coat and teal clothing. Retain their established faces and costumes.

Inspect the Isana poses as a contact sheet and a native 390 by 844 animation fixture before producing the other three workers. Initial budget: four generation calls, one character sheet per call, plus at most two corrective edits for the family. The first failed representative is corrected before spending calls on the others. If six calls cannot supply usable identity, alpha and pivots, record the missing production work and request a revised scope rather than silently expanding the budget or claiming success.

The initial four-sheet/two-correction budget was used to produce the family and correct Isana and Ritsu contact alternation. Sui's first sheet had two upper boot soles touching lower-row hair. A measured seam split was inspected as a rejected QA draft; clipping the sole or hair is not an accepted final-source repair. The parent integrator then explicitly approved one exceptional seventh built-in call, solely to reduce the six intact Sui figures and add transparent separation. The revised total cap is seven calls, not seven original sheets. The corrected source must show six isolated silhouettes, complete hair and boots, true alpha, stable adult identity and readable directional contacts at 94 units before import. If that correction fails, report the missing asset rather than generate further images or claim it passed.

Use the built-in GPT image tool after reading its imagegen skill. Supply the existing R2 family and the character portrait as references. Deterministic crop, padding and alignment scripts may normalize source pixels; they must not stretch limbs to hide drift. Reject false alpha, merged hands, boots that change shape between contacts, hidden footplants and severe face or costume drift. Preserve original generated output beside normalized sheets.

## Godot implementation

Keep `Board.present(state, events, reduced_motion)`, `cell_selected` and the existing actor methods. Rules resolve immediately. Presentation reads resolved state and never advances time, modifies ownership or delays saving. Keep all animation data editable in native SpriteFrames or AnimationPlayer resources. Do not add an animation library dependency.

Replace lower-portrait rectangle slicing with explicit directional pose regions on the field Sprite2D. Add a named weapon pivot with a small code-native salvage hook/knife silhouette and a hand socket for each facing/pose. A native drawn tool is acceptable because its edge, pivot and silhouette can be inspected directly. It must not duplicate a tool already painted into a supplied pose. Use a separate coat/scarf or hair accent only when the source supports a clean extraction; missing occluded anatomy is a source-art problem.

| Action | Visible staging | Timing and interruption |
| --- | --- | --- |
| Walk | Alternate left and right contact for consecutive resolved steps; the planted foot stays grounded while the other passes. A down-facing move shows the front pose, an up-facing move the back, and a horizontal move the side. The hand/tool counter-swings and the coat settles after contact. | About 0.22 seconds per step. Contact poses occupy the start/end; a passing interpolation is brief. A new deliberate input retargets from the current visual position and preserves contact parity. No input is dropped while animation plays. |
| Attack | Rearward hand/tool anticipation, visible shoulder/arm preparation, a quick hook/knife arc toward the actual target, then a weight recovery into the facing stance. The planted leg supports the strike. | Anticipation 0.08–0.11 seconds, contact 0.04, recovery 0.14–0.18. The hit effect and number coincide with contact. An immediately following hurt response preserves a short readable contact before recoil. |
| Hurt | Tool and shoulders recoil away from the actual attacker, knee/stance compresses briefly, then the worker recovers. | Roughly 0.24–0.30 seconds. Keep ground position truthful; recoil belongs to a visual pivot. Small warm flash only, no routine screen shake. |
| Idle | A resting stance with a subtle arm/tool adjustment and occasional head/shoulder attention toward the current facing. Distinct coat, scarf or hair accents may settle at different rates. | Slow 2.5–4 second cycle; mostly still. The feet do not drift and the whole body does not float. Stops under modal or focus pause. |
| Arrival | One planted half-step and a short relieved lowering of the tool; the active worker turns toward the receipt panel. Crew portrait gesture and item reveal match the actual extracted receipt. | About 0.6 seconds, with the return action available throughout. Empty returns do not create treasure or celebratory item particles. |
| Loss | Tool lowers, shoulders contract and the worker holds a tired stance. A restrained portrait response accompanies the actual loss receipt. | About 0.5 seconds. No victory motion; retry remains usable. No animation invents rescued gear or restored HP. |

Enemy intent remains legible above scenery. Crab, wader and diver retain distinct anticipation: claw spread, a low forward charge stance and a slow heavy brace. Do not make every enemy pulse identically. Camera and water continue to use the existing pause contract. District water flow is decorative and cannot imply a current that moves actors.

## Reduced motion and lifecycle

Reduced motion uses the final directional stance immediately, with a brief color/outline response at contact and static readable damage, loot and intent indicators. Remove travel, sway, cloth looping and large tool arcs. Modal opening and application focus loss freeze clips, active visual tweens, effect scheduling, water and ambient motion. On resume, continue the same presentation rather than replaying events. Entering a new map, changing character, retrying or leaving the scene resets pivots, color, tool socket and queued clips. Rapid explicit inputs still each resolve once.

## Acceptance evidence

Capture actual native and exported Web sequences for all four workers at 390 by 844 and the small 360 by 740 target. Inspect down/up/left/right movement, two successive alternating contacts, attack plus recoil, idle, arrival and loss. Include all four districts, a visible enemy intent, fog boundaries, occupied cells, the 178-unit control dock, inventory and result overlays. A sprite contact sheet is source QA, not proof of in-game motion.

Run the pure rules, save and deliberate-input suites; verify presentation does not mutate a state snapshot. Check pause midway through walking, tool anticipation and an effect schedule, resume without duplication, then repeat under reduced motion. Review real-size clips for baseline drift, sliding feet, hand/tool detachment, wrong facing, coat popping, face changes, unreadable numbers and scenery covering the route. Keep source captures and output paths under the version verification folder. Automated captures and agent operation are not human first-play testing; report human playtesting as unperformed unless a human actually plays.

The v0.3 milestone requires implementation, these checks, Japanese copy review where applicable and the mandatory Astra review. This proposal is preparation only and does not count as a completed version or release approval.
