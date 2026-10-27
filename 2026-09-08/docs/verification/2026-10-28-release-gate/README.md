# Stage 05 release-gate fixture correction

[Issue #215](https://github.com/hayatok/100challenge/issues/215). Base: `50b64467e607af0f3faf87aaf145cf4a3d46550d`.

The release workflow 40554796536 stopped in the existing stage 05 negative fixture. That fixture opened the gate at 0.5 s and released the counterweight at 5 s, then required failure. Linux instead delivered the intact vase into the real box at 10.61 s. On native macOS 4.7.2, nine diagnostic variations/repeats produced eight valid rescues and one collision failure. The earlier full Mac gate passed once, and the unchanged full harness passed again in the copied diagnostic project. A single pass therefore did not establish this negative fixture across hosts or repeated physics trials.

The design permits physically safe alternative cut orders and requires the counterweight to power the high lift. The implemented gate can hold the vase on the low platform until the counterweight is released. Treating every gate-before-weight order as a mandatory failure was the incorrect test contract.

## Change

Stage 05's second `traps` action list now opens only the gate and never releases the counterweight. Its `not won` assertion remains. The severed-cable negative, reference and patient wins, all-cut and untouched checks remain, with the same 63 total assertions. Failure labels now identify the trap index and complete action list.

`traps` is test metadata: it is declared in `game/core/campaign.gd` and consumed only by `game/tests/run.gd`. Runtime World, UI, progression, save code and par calculations do not read it. The stage 12 copy receives the metadata change but no physical layout change. Geometry, physics settings, impact thresholds, success criteria, reference solutions and Japanese display strings are unchanged. No workflow, planner, app selection, retry gate or exception was introduced.

## Evidence and local checks

- [reproduction-summary.json](reproduction-summary.json): selected original nine-trial evidence and three gate-only negatives at initial X -1, 0, +1 px. The latter ran a 14,400-physics-frame budget each, nominally 120 simulated seconds; actual recorded elapsed times are preserved. All three remained below the high box without winning.
- [validation-summary.json](validation-summary.json): standard app check passed import, 63 campaign assertions, 2243 UI assertions and the single-thread Web release build. Root tests passed 38/38. Eight runtime/source files match the base SHA-256 exactly. All 68 Japanese string literals in campaign.gd are identical before/after; run.gd has zero Japanese strings in both versions.
- Original source snapshots, the full diagnostic scripts, all original fixture samples and complete logs remain in the working copy's QA scratch directories. The selected JSON records their source/evidence hashes.

Commands run: `npm run check` in 2026-09-08 and `npm test` at repository root. Both exited 0. The diagnostic fixtures use actual Godot rigid bodies, contacts and the existing World; they are automated tests, not human playtesting.

Linux selective CI and the standard full Pages gate still need to pass. This correction does not claim to make the existing physics fully deterministic or to guarantee the early-gate alternate route. No new gameplay or version is included.
