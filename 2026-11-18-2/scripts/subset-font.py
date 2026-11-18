"""Rebuild the UI font after editing in-game copy. Requires the fonttools package."""
from pathlib import Path
from fontTools import subset

app = Path(__file__).resolve().parents[1]
font_path = app.parent / "2026-10-02/game/assets/fonts/NotoSansCJKjp-Medium.otf"
scripts = [p for p in (app/"game").rglob("*")
           if p.suffix in {".gd", ".html", ".tscn", ".godot"} and ".godot" not in p.parts]
text = "".join(p.read_text() for p in scripts)
options = subset.Options()
font = subset.load_font(str(font_path), options)
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=set(range(32, 127)) | set(range(0x3000, 0x3100)) | set(map(ord, text)))
subsetter.subset(font)
subset.save_font(font, str(app/"game/media/jp.ttf"), options)
