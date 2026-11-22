"""Build the cabinet and doorway silhouettes used by the hall's two commands."""
from pathlib import Path

from PIL import Image, ImageDraw


root = Path(__file__).resolve().parents[2]
atlas = Image.new('L', (256, 128))
pen = ImageDraw.Draw(atlas)

# Left, the curved glass and feet of the relay receiver. Right, an open door.
pen.rounded_rectangle((9, 24, 118, 96), radius=16, fill=255)
pen.rounded_rectangle((19, 34, 108, 81), radius=12, fill=0)
pen.line((41, 97, 36, 107), fill=255, width=7)
pen.line((86, 97, 92, 107), fill=255, width=7)
pen.ellipse((86, 86, 91, 91), fill=0)
pen.ellipse((98, 86, 103, 91), fill=0)
pen.line(((150, 104), (150, 18), (212, 18), (212, 38)), fill=255, width=8)
pen.polygon(((155, 21), (183, 32), (183, 105), (155, 98)), fill=255)
pen.ellipse((174, 63, 180, 69), fill=0)
pen.line((190, 68, 243, 68), fill=255, width=8)
pen.polygon(((231, 48), (251, 68), (231, 87)), fill=255)

image = Image.new('RGBA', atlas.size, (255, 255, 255, 255))
image.putalpha(atlas)
image.resize((128, 64), Image.Resampling.LANCZOS).save(root / 'Game/Assets/Resources/HallSigns.png')
