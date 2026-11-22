"""Record the three 1.7 material originals using the local MOSS-Image graph."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT.parent / 'rain-street'))
from make_surfaces import generate


SAMPLES = {
    'Stone': (1702201, 'A 64-centimetre square of pale warm grey cream Japanese 1960s polished artificial architectural stone, a finely honed cast cement matrix with embedded 3 to 7 millimetre rounded off-white shell chips and grey to brown tuff and rare charcoal mineral inclusions. A maintained public entrance, slightly abraded grain and tiny hand polishing marks, visible varied aggregate at architect scale. Material only, even distribution. Physically plausible neutral albedo under cross-polarised soft light, no veining.'),
    'Skirting': (1702202, 'A 50-centimetre square of dark anthracite terrazzo from the clean lower wall of a well-loved late Showa theatre entrance. Flakes of ivory, bluish grey and warm grey stone of mixed 2 to 6 millimetre size, sparsely embedded in a dominant dark warm graphite binder. Fragments sit flush in the polished body. Uninterrupted honed surface, no build-up of dirt, no directional gradients. Cross-polarised neutral albedo photograph.'),
    'Brass': (1702203, 'A 24-centimetre square of flat satin aged brass, a cut sheet intended for a narrow architectural trim at an Osaka theatre. Subdued ochre bronze, uniform soft horizontal brushing so fine that texture is subtle and continuous. Gentle faded patches from hand polishing and sporadic very fine hairline marks. Well-maintained metal photographed under cross-polarised neutral white dome lighting, uniform restrained albedo and no directional glare.'),
}
NEGATIVE = 'objects, signage, labels, text, watermark, border, seams, joints, bevels, trims, perspective, reflected scene, cast shadow, relief lighting, prominent damage, flaking paint, border patina, damp spots, vignette'


if __name__ == '__main__':
    for name, (seed, detail) in SAMPLES.items():
        generate(name, seed, detail, directory=ROOT, prefix='frontage', negative=NEGATIVE)
