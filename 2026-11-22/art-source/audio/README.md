# 金星 — original offline music and sound, v0.1

All twenty WAV files under `Game/Assets/Resources/KinseiAudio` were rendered locally from `render.py` on 2026-11-22. No sample packs, soundfonts, recordings, existing melodies, remote generation, API credentials or paid calls were used. The instruments are custom additive/subtractive synthesis. These files introduce no third-party sample or soundfont licensing requirement; the project may use, edit and redistribute them with the game. NumPy and SciPy were rendering tools and are not shipped in the Unity player.

## Score

The audio renderer and the stage piano share [StageScore.json](../../Game/Assets/Resources/KinseiAudio/StageScore.json). The 16 bars specify the chord pitches and the melody's note-on times and durations. The Windows player reads the loop's current audio sample and moves the corresponding black and white keys. The stage performer uses the moving keytops as contact targets. Rendering all 20 WAV files from the shared score reproduced every previously released file byte-for-byte.

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

## 共同放送の朝のリクエスト曲

「堺の朝」はト長調、3拍子、四分音符84の12小節。25.714秒のステレオループを朝の送出卓から再生する。曲中のピアノと金星の3D鍵盤は同じ MorningScore.json を読む。ベースと短い弱音器付きの管の応答を加えた。音源は夜の曲と共通の合成楽器で新しく演奏した。render_morning.py で原稿からWAVを再生成できる。ピーク0.66、RMS −17.80 dBFS、SHA-256は 364c7057889a120b8b6738b3b89bf0cbbda47c0be8350584accfa8b61bbd44e1。

## 舞台から町へ流す兄貴分の声

舞台の中継を選ぶと、兄貴分が「金星を取ったんは、わしや。幕を返す。」と話す。店名は「きんせい」と読ませた。48 kHzのステレオ音源は4.220秒。音声から取り出した各音の時刻を使い、毎秒60回、口の開きと唇の丸みを別々に記録した。「わしや」は1.97～2.53秒、「幕を返す」は2.94～3.74秒。ゲームはこれらの区間で、兄貴分が胸に手を寄せ、客席へ掌を開く。

音源の制作には Open JTalk の HTS Voice NIT ATR503 M001 v1.05 と HTS engine API 1.10 を使った。ゲームの実行時には録音した音声を再生する。270～3,900 Hzの帯域成分を原音に加え、客席の反射を左右に27 msと42 ms遅らせた。音声と口形を同時に再生成するには、NumPy、SciPy、pyopenjtalk-plus 0.4.1.post10 と辞書を用意し、次を実行する。

```powershell
python render_testimony.py <hts_engine.exeのパス> <nitech_jp_atr503_m001.htsvoiceのパス>
```

元モデルのREADMEと学習音声のCOPYINGに沿った表記を配布物に同梱する。[Open JTalk](https://open-jtalk.sourceforge.net/)・[音声モデルの配布元](https://packages.debian.org/source/trixie/hts-voice-nitech-jp-atr503-m001)・[ゲームに含めるクレジット](../../Game/Assets/StreamingAssets/StageVoiceCredits.txt)。
