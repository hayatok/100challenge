# Art and audio

Original character, weapon, environment and title references were created for this game with OpenAI ImageGen. The material atlas supplies the quay's corrugated steel, fish-crate print, wet floor and deck plating. The production models were built in Blender and exported to glTF. The image prompts are recorded in [art-prompts.json](art-prompts.json).

Suno composed two instrumental cues for this game. The selected performances are packaged locally in the Web build. Each generation also produced a second take.

| Cue | In game | Alternate take |
| --- | --- | --- |
| 04.17 / Auction Floor | [104.76 s](https://suno.com/song/985e4bc1-1416-4d15-be46-8bf6bc29d586) | [104.72 s](https://suno.com/song/ddbb69e0-779c-4add-9998-d88997ebcb45) |
| Dead Freight / Last Crossing | [99.96 s](https://suno.com/song/bde44d00-fe29-4df1-8f02-de3d647924b3) | [99.60 s](https://suno.com/song/445ef03d-fbb3-44a3-8eb0-eb23e60b8579) |

The gunfire, footsteps, brass bell, machinery, chain and departure horn are original synthesized sound effects. Rebuild the PCM files with `python3 scripts/make-sfx.py`.

Godot is distributed under the MIT license. Third-party notices are included in the Web export as `GODOT-LICENSE.txt` and `GODOT-COPYRIGHT.txt`. The UI uses a subset of Noto Sans CJK JP Medium from the repository, distributed under the SIL Open Font License 1.1 in `NOTO-OFL.txt`.
