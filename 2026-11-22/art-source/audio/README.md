# 金星 — original offline music and sound, v0.1

All twenty WAV files under `Game/Assets/Resources/KinseiAudio` were rendered locally from `render.py` on 2026-11-22. No sample packs, soundfonts, recordings, existing melodies, remote generation, API credentials or paid calls were used. The instruments are custom additive/subtractive synthesis. These files introduce no third-party sample or soundfont licensing requirement; the project may use, edit and redistribute them with the game. NumPy and SciPy were rendering tools and are not shipped in the Unity player.

## Score

`kinsei-waltz.wav`, working title **金星、閉店前**, is an original 16-bar slow minor jazz waltz, 3/4 at 76 quarter notes per minute, lasting 37.895 seconds. A-minor opening, F-sharp half-diminished colour, F-major seventh, E7 turnaround, D minor and G7/C-major colour give the room a restrained cabaret atmosphere. The melody and harmony are explicitly authored in the renderer rather than sampled from another composition.

Additive decaying, slightly inharmonic piano; rounded plucked upright-style bass; filtered-noise brushes; low soft kick; four sparse muted-horn answers. Stereo placement and a short reflected-room network leave space in the centre for action. It is a stylized synthesized small ensemble, not an acoustic recording. The repeating arrangement has melody/voicing changes across the sixteen bars. Instrument tails and room reflections wrap into the next loop; 5 ms boundary fades prevent sample-edge clicks.

## Cue contract

Global `KinseiSound : MonoBehaviour` lives at `Game/Assets/Kinsei/Audio/KinseiSound.cs`. Session code may call `Cue(string key)` and `SetPaused(bool)`. `SetDialogue(bool)` is an optional integration hook for subtitle/voice ducking. `MusicGain`, `SfxGain`, and `AmbientGain` are static gains in [0,1] when applied. No AudioMixer asset is required in this headless production pass; source levels all pass through these shared gains.

|Key|Sound and variation|
|---|---|
|door|Soft hinge/cabinet movement then padded latch|
|dial|Two restrained high piano notes|
|shot|Three distinct filtered noise/body/reverberant stylized shots|
|distant|Three low-pass, softer shot variants with slight stereo positions|
|strike|Three padded body-impact variants|
|choice|Unresolved two-note piano attention figure|
|result|Four-note rising minor-colour result figure|
|accord|Warm resolving F-major-seventh piano figure|
|loss|Descending E–C–A piano figure|
|step|Three soft filtered shoe/floor impacts|

Six concurrent cue sources are the hard limit; excess bursts are dropped, never stacked indefinitely. Steps have a 220 ms minimum spacing, distant shots 190 ms, shots 85 ms and strikes 140 ms. Variants rotate with small pitch changes for footsteps/action, while melodic UI cues keep their tuning. Each cue is an intentionally short event, with no simulated dialogue or crowds of voices. Cue placement is non-positional in v0.1 because the supplied contract contains only a string key; distant cues have restrained stereo offset. A future position-aware emitter can replace this without changing the assets.

## Balance and pause

Default source factors are music `MusicGain × 0.38`, room `AmbientGain × 0.16`; local shot `SfxGain × 0.63`, distant `× 0.28`, footsteps `× 0.13`, other cues `× 0.48`. The music file measures −18.67 dBFS RMS before runtime gain, approximately −29.9 dBFS RMS at the default music gain. This leaves the foreground cue peaks clearly above it. Non-soft cues temporarily duck music to 48%; dialogue hook ducks it to 38%, with smooth gain movement. The music returns after the cue window. No unrelated music or voice plays over the ensemble.

Pause and application focus loss pause all eight sources, and resume them from the same sample positions. A cue requested while paused or unfocused is discarded. New sessions create new sources; destruction releases their child objects. No runtime synthesis or audio clip allocation happens in `Update`.

## Reproduction and checks

Run `render.py` using `C:/comfy/ComfyUI/ComfyUI/.venv/Scripts/python.exe` (existing local NumPy/SciPy). Fixed RNG seed `19731122`; exact arrangement and synthesis are in the script. Output is 44.1 kHz 16-bit PCM, stereo for music and pitched UI figures, mono for world effects/room. `measurements.json` records duration, peak, RMS and SHA-256 of every WAV.

Numerical validation: 20 WAVs, 10.66 MB total; all finite, nonzero data; no sample reaches integer clipping; first/last samples are zero on every file. Music peak 0.72; action peaks at most 0.78. No Unity instance was launched for this subtask. Actual player playback, perceptual listening, cue balance through speakers/headphones, pause/focus behavior and performance remain integration checks for the parent task; numerical checks are not a claim of listening validation.

Implementation guidance read: Unity `using-unity` / `craft-game-floors` / `game-audio` skill references, and Unity 6000.3 `AudioSource.Pause` and `AudioSource.PlayOneShot` reference pages. Existing repository audio contract takes precedence; headless shared gains were used instead of authoring a mixer through the Editor UI.
