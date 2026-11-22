"""Submit and record the MOSS surface studies for the street and its receiver."""
import hashlib
import io
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parent
HOST = 'http://127.0.0.1:8188'
GRAPH = ROOT.parent / 'west-bath/materials/graph.json'
PREFIX = 'Single flat top-down material scan, 1:1 square full bleed, eye perpendicular to the surface, neutral diffuse illumination without cast shadows. '
AVOID = 'objects, signs, handwriting, border, oblique perspective, horizon, reflection of buildings, grate, people, leaves, poster, painted lines, watermark'
SAMPLES = {
    'Enamel': (1602104, 'A 22-centimetre chip of ivory porcelain enamel on a 1970s outdoor Japanese TV receiver chassis. Uniform creamy warm off-white fired glossy enamel under cross-polarized lighting, extremely sparse dispersed tiny dark iron pinholes 0.3 to 0.8 mm diameter, microscratches and a handful of barely visible small yellowed flecks. Face on, very subdued unblemished dominant field. No large rust, no paint peeling, highlights, knobs or typography, no shadows.'),
    'Grille': (1602105, 'An eight-centimetre sample of tightly stretched dark coffee-brown radio speaker fabric on a 1970s Japanese street television. The thin horizontal tan cotton ribs pass over a fine chocolate and charcoal warp, tightly repeating minute open square pinholes. Uniform stretched weave under flat, neutral illumination, no frame, logo, speaker, button, dust blobs or folds. Macro photograph of textile only.'),
    'Asphalt': (1602101, 'A 26-centimetre portion of well-used mid-grey Japanese neighborhood hot mix asphalt with tightly bound basalt grit, tiny pale 3-6 mm fragments in a dark warm charcoal binder, little pits and gently abraded pebble tops. Extremely realistic mineral surface, subtle close variation, low contrast. Dry evenly illuminated albedo scan. No isolated loose stones or gravel pile.'),
    'Basin': (1602102, 'A scientific vertical field photograph looking down at 75 cm of a very shallow weathered asphalt depression at the edge of an Osaka back street after rain. Several irregular interlocking dark pools of still water feather into lighter drying neutral grey aggregate islands. Create coherent broad flat dark areas with asymmetrical eroded, pebbled peri­meters, mostly grey half tones. No sky, shafts of light, puddle ripples, reflections, painted marks or drains. The pooled regions in this scan will be used to produce an irregular wetness mask.'),
    'Ripple': (1602103, 'A twelve-centimetre patch of a very shallow water surface in an old Osaka stone gutter. Ultra-fine irregular close ripples running in crossing directions in a light breeze; short, soft low-relief grey interference strokes, uniform pale-grey ground. Scientific raking diffuse light for a tiny micro-relief scan. No single splash centre, concentric circles, objects, stones, hard highlights, caustic lines or reflected buildings.'),
}


def request(path, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    return urlopen(Request(HOST + path, data=data, headers={'Content-Type': 'application/json'}), timeout=35)


def generate(name, seed, detail, *, directory=ROOT, prefix='rain', negative=AVOID):
    destination = directory / (name + '.png')
    record = directory / (name + '.json')
    if destination.exists() and record.exists():
        expected = json.loads(record.read_text(encoding='utf-8'))['sha256']
        if hashlib.sha256(destination.read_bytes()).hexdigest() == expected:
            return
    graph = json.loads(GRAPH.read_text(encoding='utf-8'))
    graph['4']['inputs']['text'] = PREFIX + detail
    graph['5']['inputs']['text'] = negative
    graph['7']['inputs']['seed'] = seed
    graph['9']['inputs']['filename_prefix'] = 'kinsei/' + prefix + '-' + name.lower()
    with request('/prompt', {'prompt': graph, 'client_id': 'kinsei-' + prefix}) as response:
        job = json.load(response)['prompt_id']
    for _ in range(450):
        with request('/history/' + job) as response:
            run = json.load(response).get(job)
        if run:
            break
        time.sleep(2)
    else:
        raise TimeoutError(job)
    if run['status']['status_str'] != 'success':
        raise RuntimeError(run['status'])
    output = run['outputs']['9']['images'][0]
    with request('/view?' + urlencode(output)) as stream:
        png = stream.read()
    with Image.open(io.BytesIO(png)) as image:
        assert image.format == 'PNG' and image.size == (1024, 1024)
    digest = hashlib.sha256(png).hexdigest()
    destination.write_bytes(png)
    record.write_text(json.dumps({'prompt_id': job, 'sha256': digest, 'seed': seed, 'source': output,
                                  'execution': run['status'], 'graph': graph}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(name, job, digest, flush=True)


if __name__ == '__main__':
    for material, (seed, detail) in SAMPLES.items():
        generate(material, seed, detail)
