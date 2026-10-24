"""Label the nine existing runtime material renders; source geometry/textures untouched."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
base=Path(__file__).resolve().parent.parent
variants=['A_original','B_matte_normal035','C_matte_normal035_toon']
views=['face_threequarter','face_left','fullbody']
labels=['A / original material','B / matte + normal 0.35','C / B + toon diffuse']
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',16)
sheet=Image.new('RGB',(1152,1152),'#142c3e')
for row,variant in enumerate(variants):
    for column,view in enumerate(views):
        image=Image.open(base/f'previews/material_{variant}_{view}.png').convert('RGB').resize((384,384))
        draw=ImageDraw.Draw(image);draw.rectangle((0,0,384,28),fill='#142c3e')
        draw.text((8,5),labels[row]+' / '+['3quarter','left','body'][column],font=font,fill='#fffdf8')
        sheet.paste(image,(column*384,row*384))
sheet.save(base/'previews/material-comparison-contact.png')
report_path=base/'reports/material-comparison.json'
report=json.loads(report_path.read_text())
report['recommendation']={
    'variant':'C_matte_normal035_toon',
    'reason':'In the actual Main environment, C gives the clearest eyes, skin/hair separation and teal collar interior while removing the distracting fine white specular streaks. It better matches the intended anime-game rendering direction.',
    'A_observation':'Original normal strength and specular response produce many narrow bright streaks on hair, collar, skin and glove/arm details. These emphasize the generated surface noise.',
    'B_observation':'Lower normal strength and disabled specular smooth the chest, neck and hair response. Under the same Main light, face and navy hair remain dark and the hair layers merge more than in C.',
    'C_observation':'The toon diffuse response lifts readable skin, eyes, jacket and teal collar colors. Collar folds, sleeve rims and hair silhouette retain visible volume, and navy clothing remains distinct from the pale jacket. Geometry and actual thickness are unchanged.',
    'remaining_limits':'C retains hard light/shadow boundaries across the nose and cheek, baked color streaks and irregular jacket surface details. Adjacent duplicated cloud marks and coral tabs are source defects and remain. These nine static views do not approve final visual quality or show all headings and motion.',
    'status':'Proposal only. No game material, loader or source asset was edited.'
}
report_path.write_text(json.dumps(report,indent=2))
print('Labeled material contact and observations saved')
