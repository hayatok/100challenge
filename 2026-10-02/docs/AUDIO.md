# BLACK RELAY audio

## Direction

An abandoned flooded signal station heard through its working terminal: filtered
ventilation, damp pressure, ceramic keycaps and resonant cable couplings. Feedback
should remain readable during rapid typing without bright repetitive beeps,
startle-volume jumps, sharp full-band noise or sustained sub-bass. The player
sounds are quicker and cleaner than the enemies' strained machinery.

All 16 files were synthesized specifically for this game. There are no borrowed
recordings, sound libraries or melodies. Rights/provenance are recorded in
`game/assets/audio/ORIGINAL_AUDIO_LICENSE.txt`; technical details, SHA-256 hashes
and per-file measurements are in `game/assets/audio/audio_manifest.json`.

## Integration contract

Every path below is relative to Godot's resource root: `res://assets/audio/`.
All files are 48,000 Hz, signed 16-bit PCM WAV. The ambience is stereo. Other
sounds are mono so the game can position them without doubled stereo memory.

| File | Length | Event / character |
| --- | ---: | --- |
| `ambience.wav` | 20.000 s | Seamless quiet station bed: machinery, water, distant ceramic droplets |
| `typing_01.wav` through `typing_04.wav` | 0.095 s each | Felt key-bed thock, ceramic cap, tiny key return; four timbral variations |
| `confirm.wav` | 0.480 s | Small ascending two-hit relay, confirmed UI choice / target lock |
| `error.wav` | 0.130 s | Optional soft hollow rejected keystroke; never louder than accepted typing |
| `cut.wav` | 0.480 s | Immediate cable shear, short pressure punch, brittle ring |
| `purge.wav` | 1.650 s | Immediate relay impact followed by a wider valve release |
| `kill.wav` | 0.780 s | Falling power and irregular ceramic fragments |
| `attack.wav` | 0.670 s | Breathy rising cable strain; enemy telegraph |
| `hurt.wav` | 0.580 s | Damped shock and momentary rough texture |
| `boss.wav` | 2.900 s | Three unequal power-coupling strikes; arrival/major phase cue |
| `transition.wav` | 1.600 s | Restrained rising relay handover |
| `victory.wav` | 3.600 s | Original short release motif, warmer material and a gentle tail |
| `defeat.wav` | 2.000 s | Optional final relay power-down |

### Playback

- Preload one-shots. Event onset is below 0.5 ms in the files; do not add a timer.
- Round-robin the four typing variants, or use random selection without immediate
  repetition. Their timbre already varies; pitch randomization is optional and
  should stay around ±2.5%. Return to pitch scale 1.0 for non-typing players.
- Start with Master -3 dB, SFX 0 dB, typing 0 dB and ambience -4 dB. Assets already
  have deliberate headroom. Typing peaks are about -18.5 dBFS, and one-shot peaks
  range from -9 to -20 dBFS. Tune these gains in the actual game rather than
  normalizing every file to 0 dBFS.
- Use limited polyphony: 4 typing voices, roughly 6–8 main SFX voices, one ambience
  player and one long-event player are sufficient. Avoid multiplying the same
  kill sound at identical timestamps when a PURGE destroys several enemies.
  Rate-limit or aggregate simultaneous kill cues. Do not restart `boss.wav` every
  frame of a phase change.
- WAV files contain no embedded looping instruction. Explicitly set ambience
  looping via import or `AudioStreamWAV.LOOP_FORWARD`, begin frame **0**, end frame
  **960000** (exclusive). Keep pitch 1.0. The waveform is periodic by construction;
  do not add a fade at every loop boundary. Fade the player's volume over roughly
  0.4 seconds when initially starting/stopping it.
- Godot 4.7.2 defaults to QOA compression (`compress/mode=2`) for WAV import.
  Source measurements in the manifest describe the original PCM. For exact
  waveform/loop fidelity, set `compress/mode=0` for the ambience import; doing so
  for all sounds retains the entire pack at just 5.06 MiB. Both default QOA and
  uncompressed PCM imports were validated in an isolated Godot 4.7.2 project.
- Preserve sound settings across runs, pause all active gameplay audio on pause,
  and provide a master mute. No timing, target, attack or error information may
  depend exclusively on hearing the sound.
- Browser playback must be unlocked by the existing user Start interaction.

## Regeneration and checks

Only Python 3.10+ and NumPy are needed; no network, external synthesizer, SciPy or
sound-file packages are required. WAV writing uses Python's standard library.

```sh
python scripts/generate_audio.py
python scripts/generate_audio.py --check
python scripts/generate_audio.py --check --preview
```

The generator only owns its audio files and manifest. It never edits game code or
Godot import files. `--check` verifies the existing WAVs and manifest checksums
without rewriting them. `--preview` makes `builds/audio_preview.wav` with a text
cue sheet. This ignored development reel is outside the exported Godot assets;
it includes the actual ambience seam and short rapid-typing repetitions.

Checks cover sample format/channels, zero one-shot endpoints, DC, intentional
peak headroom, onset, sub-50 Hz and above-8 kHz energy, ambience sample seam, file
hashes, and a dense synthetic combat mix at 20 characters per second. Exact
regeneration is tested by rendering into a temporary directory and comparing
all WAV SHA-256 hashes. Platform/NumPy versions may change the least-significant
bit of floating-point computations; the committed WAVs are the shipping source.

## Verification scope

Objective generation and file checks are performed. In the measured ambience,
the loop seam's sample step is only 0.133 times the 99th-percentile ordinary
sample step, DC is negligible, and left/right correlation is 0.054. PCM audio
footprint is 5.06 MiB for all 16 sounds. A synthetic high-density mix leaves
headroom (measured peak -4.93 dBFS, zero clipped samples); current measured results
are in the manifest. Two separate generations were byte-identical for every WAV.
An isolated Godot 4.7.2 headless import test loaded all 16 AudioStreamWAV resources
and confirmed sample rates, channel counts, lengths and runtime loop settings,
first with the engine's default QOA import and again with uncompressed PCM.

These measurements do not establish the final subjective mix. No headphone or
speaker listening test is claimed by the audio-generation pass. In-game mix,
menu/start unlocking, pause, muted play, simultaneous enemy feedback, boss entry,
the actual loop playback and complete-run comfort must be checked in the game.

## Wet-city zombie slice update · 2026-10-02

This section supersedes the station ambience direction and its old measured
values above. The existing four typing sounds and confirmation feedback remain
unchanged. `ambience.wav` is now an original wet urban-night field: restrained
rain on asphalt, shallow drain/ledge drips, wind between buildings and distant
non-tonal road wash. There are no machinery oscillators, periodic alarm tones,
recorded weather samples or borrowed ambience. It remains a seamless stereo
20-second, 48 kHz PCM16 loop with begin frame 0 and exclusive end frame 960000.

Two optional mono Foley cues are generated by `scripts/generate_urban_audio.py`,
using the original pack's deterministic DSP helpers. They are original project
audio under the existing ownership/provenance record; no external voice, sample
library or dialogue is used. The separate licensed `shot.mp3`,
`impact_body.ogg` and `impact_metal.ogg` are not covered by the original-audio
record and are not modified by either generator.

| File | Length | Source peak | Recommended player gain | Use |
| --- | ---: | ---: | ---: | --- |
| `ambience.wav` | 20.000 s | -15.0 dBFS | -6 dB | One quiet continuous rain/city player |
| `zombie_breath.wav` | 1.050 s | -16.5 dBFS | -6 dB | Low nonverbal throat groan and raspy exhalation |
| `footstep_wet.wav` | 0.300 s | -18.0 dBFS | -8 dB | Compact sole contact with shallow-puddle splash |

Use the breath instead of the old mechanical attack cue, rather than layering
both. Permit only one breath at a time, with at least 2.5 seconds between global
plays. Wet footsteps are optional detail: use one nearest threat and at least
1.2 seconds between plays, with no per-enemy footstep chorus. Keep type clicks
at -3 dB, gunshot at -5 dB, body impact at -9 dB and optional kill tail at -12 dB.
Start with master -3 dB. Avoid adding Foley on every accepted letter. Preserve
visible telegraph/attack feedback when any rate limit suppresses a sound.

Regenerate/check the original pack first, then the extension:

```sh
python scripts/generate_audio.py
python scripts/generate_urban_audio.py
python scripts/generate_audio.py --check
python scripts/generate_urban_audio.py --check
```

`urban_audio_manifest.json` records both added cues' checksums and measurements.
The extension's `--check` does not change source assets. When ffmpeg and the
licensed files are present, it also decodes the existing gunshot/body impact
read-only and measures a 12-second dense city-combat mix. It does not edit or
re-encode those licensed assets. ffmpeg is optional for asset generation and
format checks; its absence is explicitly reported for the mix test.

Verified after this update:

- All 16 original assets pass the existing format, headroom, DC, spectral,
  typing-onset, endpoint, checksum and seamless-loop checks
- The new rain loop has seam/interior-step-p99 ratio 0.59128, stereo correlation
  0.22457 and RMS -28.89 dBFS; the original 20-char/sec stress mix peaks at
  -4.86 dBFS with zero clipped samples
- Both added cues pass identical PCM format, DC, peak, spectral-limit and
  zero-endpoint measurements; every one of the 18 original WAVs is byte-identical
  across two independent generations
- The city mix includes 20 typed characters/sec, 19 licensed gunshots and body
  impacts in 12 seconds, spaced breaths/footsteps and overlapping hurt/CUT
  feedback. At the gains above it peaks at -6.70 dBFS with zero clipped samples
- An isolated Godot 4.7.2 headless import and resource test loads the new ambience,
  breath and wet footstep with correct rate, channels and exact durations; the
  rain loop uses the correct 960000-frame boundary

These are reproducible source/import/mix checks, not a subjective headphone or
speaker listening claim. The final in-game volume balance, licensed-shot feel,
breath timing, comfort while typing and actual loop playback still need runtime
audition. Synthetic mix safety does not permit unbounded simultaneous voices.
