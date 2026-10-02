"""Append readable launch notes and required licenses to the Godot macOS ZIP."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parent.parent
archive=root/'builds/urban-macos/BLACK_RELAY_URBAN.zip'
notes='''BLACK RELAY / 黒雨の街\n\nGodot 4.7.2 universal macOS build (Apple Silicon + Intel).\nExtract the ZIP and open the included .app bundle.\n\nThis app is ad-hoc signed, not Apple-notarized. Runtime has not been tested on macOS.\nIf macOS blocks opening it, review the app using your normal macOS security controls;\nthe source project and complete validation report are provided separately.\n\nPhysical keyboard required. Turn Japanese IME off for romaji input.\nEnter: begin. Space: continue briefing. Type the white word for one-shot kills. Amber CUT is an optional near-threat stagger.\nTab: target. Esc: pause. F11: fullscreen.\nSettings support Japanese/English prompts, Assist/Standard/Overdrive, volume/mute,\nreduced camera shake and high contrast.\n\nA 75-second urban route with 24 zombies. The route stops for remaining threats; no typing timeout. No account, network, analytics or purchases.\nSettings and separate difficulty/language records are local to this Mac.\n\nOriginal environment/audio mixed with licensed CC0 and CC BY 3.0 human/weapon/audio assets.
See THIRD_PARTY_NOTICES.md and Licenses/ for attribution.\n'''
files={
 'THIRD_PARTY_NOTICES.md':root/'THIRD_PARTY_NOTICES.md',
 'Licenses/Noto-SIL-OFL.txt':root/'game/assets/fonts/LICENSE.txt',
 'Licenses/DejaVu.txt':root/'game/assets/fonts/DEJAVU-LICENSE.txt',
 'Licenses/Godot-and-dependencies.txt':root/'docs/licenses/GODOT-LICENSE.txt',
 'Licenses/Original-models-CC0.txt':root/'art/LICENSE.txt',
 'Licenses/Original-audio.txt':root/'game/assets/audio/ORIGINAL_AUDIO_LICENSE.txt',
}
with zipfile.ZipFile(archive,'a',zipfile.ZIP_DEFLATED) as z:
 z.writestr('README-MAC.txt',notes)
 for name,path in files.items():z.write(path,name)
 assert z.testzip() is None
print('macOS ZIP includes launch limitations and complete license notices')
