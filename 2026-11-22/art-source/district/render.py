"""Render the district plates using the same installed MOSS graph as the original poster."""
import argparse
import copy
import json
import sys
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "atelier"))
from generate import BASE, request

STREET = "Photochemical location still, contemporary Osaka one year after its Showa centenary festival. An ordinary surviving Showa shopping lane, modest scale, human work and imperfect everyday surfaces, no digital screens, no captions. "
COFFEE = "LOTUS is a narrow eight-seat Japanese kissaten with sage-green mosaic tiled counter, warm ivory laminate, amber ribbed pendant, walnut stools and lotus frosted glass. The owner is a short Japanese woman around 60 with greying bob, tortoiseshell spectacles, cream blouse and brick-red apron. "
RECORD = "Hariondo is a narrow Japanese neighborhood record lending shop with blue painted plywood bins, ginger pegboard, black rubber floor runner, small window by the entrance. The keeper is a wiry Japanese man about 45 with unruly curls, indigo work jacket over striped shirt, half-moon spectacles. "
STATION = "The modest shared television relay office has pale duck-egg painted metal racks, cream cable ties, worn charcoal rubber mat, red and ivory patch cords, tungsten pilot lamps, a small convex CRT. Its operator is a Japanese woman about 40 in rolled-sleeve dark teal workwear, clipped-back hair and a pencil behind her ear. "
SCAN = "Perfectly square-on full bleed physical print scan, no surrounding table or frame, no perspective, visible ink on real paper. "
SPECS = [
    ("lotus-float",768,1024,SCAN+"Vintage 1970s Osaka coffee shop soda counter poster. One elegant tall fluted glass of green melon cream soda, single ivory scoop of ice cream, coral cherry, bent striped straw. Pale celadon field and clean ivory margins. Delicate realistic commercial airbrush illustration mixed with bold offset print, lightly sun-faded. Exactly one large heading LOTUS at top. Limit other writing to zero, no small text. Asymmetrical diagonal graphic shadow, small orange four-petal flower, charming but sophisticated."),
    ("lotus-voucher",1024,512,SCAN+"Single two-to-one horizontal vintage Japanese coffee ticket printed on ivory buff rag paper, large hand-drawn ink-green illustration of one demitasse cup and steam at left, two faded terracotta ink stripes and heavy serif LOTUS in dark bottle green at right. Small perforation line near left edge. Quiet authentic late Showa trade printing, very little text, no numbers or paragraphs, simple strong legibility."),
    ("needle-sleeve",960,960,SCAN+"Square full-bleed collectible Japanese instrumental jazz LP jacket artwork. Deep marine-blue ink ground, cut-paper vermilion stylus arm swings diagonally over eccentric nested cream grooves like a rising crescent moon. Single tiny ochre disc at the needle tip. Modernist 1968 Osaka record shop house label. Beautiful screenprint irregularities and edge abrasions, a cream vertical obi strip at left with just one large dark-blue musical note. Completely wordless. No objects or people."),
    ("needle-return",1024,512,SCAN+"Two-to-one horizontal shop counter placard for the returns shelf of a vintage Osaka record lending shop. Rich ochre yellow thick enamel, deep marine-blue ink, big leftward arrow and a bold half vinyl record motif with a red spindle on left. The only lettering reads RETURN in robust condensed navy capitals on right. Strong iconic shapes, raised ink, isolated screw heads, tiny worn corners. Entire artwork edge to edge."),
    ("relay-test",1024,768,SCAN+"Old Japanese local television relay service camera-alignment test card, 4:3 landscape, printed in muted olive, mustard, oxblood, grey, charcoal and ivory. A large centred cream circle with a crisp charcoal eight-point station star, flanked by graduated stepped bars and a fine technical grid. A small strip of six restrained colour squares along bottom. Large clear symmetrical geometric composition, flat physical litho printed on off-white paper with traces of foxing. No words, no numbers, no simulated television cabinet."),
    ("relay-card",1024,640,SCAN+"Macro scan of one very old 85 by 53 mm Osaka television subscriber's card cropped exactly to its edges. Card fills entire 8:5 image. Marbled oxblood phenolic resin, a broad worn brass contact strip with parallel fine grooves occupying left third, diagonal ivory eight-point station star embossed at right, one drilled registration hole near top right. High spots polished by thumbs, neutral straight diffuse light, quiet restrained patina, no printed words, no text, no background."),
    ("lotus-open",1216,832,STREET+COFFEE+"Morning, camera inside at counter height. Owner lowers the pour-over kettle over a small cloth coffee dripper; an elderly regular waits with his folded racing paper. Five cups upside down on a polished drip tray, daylight cut by green awning, copper side of the boiler catching honey light. Convey the reach across this narrow counter, two people each busy with a small gesture."),
    ("lotus-close",1216,832,STREET+COFFEE+"Evening after closing, view from outside through the side of the etched lotus window. Owner alone, counting two saucers into a stack and a couple of stools inverted on counter, amber pendant the last lit bulb, green awning visible outside. A clean damp cloth hangs over the rail; dark reflections in foreground. Do not fill the scene with theatrical neon."),
    ("needle-open",1216,832,STREET+RECORD+"Daylight. Close eye-level interior view along shoulder-high sleeve bins. Owner carefully withdraws a record from its paper liner using fingertips at rim and centre, young Japanese woman customer in plum jacket holds her canvas shopping bag and studies the sleeve. Uneven sleeves, a single paper price divider, clear dustcover and small headphones on back table, old dry cardboard texture."),
    ("needle-close",1216,832,STREET+RECORD+"After closing seen side-on through half lowered slatted shutter, a warm desk lamp at back. Keeper with a wooden brush dusts empty listening deck; hand-lettered dividers stand up from rows of sleeves, worn bright blue corners, a bent metal coat hanger. Customers gone, a damp umbrella dries by door and reflections of a distant cabaret glow on the shutter."),
    ("relay-open",1216,832,STREET+STATION+"Workday dispatch window. Operator exchanges one palm-sized dark red contact card with a Japanese delivery runner in tan uniform. Both stand on opposite sides of a chest-height narrow wooden service sill; mail cubbies and one cable reel sit behind. Three quarter view, manual labor not science fiction, warm human exchange, daylight at door and honey pilot lamps."),
    ("relay-close",1216,832,STREET+STATION+"After public hours. A small wooden service hatch is closed, metal shutter down, the woman operator alone in profile sorting two worn red connector cards in numbered pigeonholes under a green desk lamp. One rack of small analog red standby lights remains lit. Quiet empty customer bench and wet umbrella tray, cinematic wide composition with deep night beyond frosted door."),
    ("contact-wear",1216,832,"Materials inspector macro photograph diptych. LEFT close-up: same marbled oxblood phenolic subscriber card, brass contact edge, diagonal eight-point ivory star, drilled indexing hole. RIGHT extreme macro shows how grooves have been rubbed nearly flat on ONE brass edge by a thousand insertions, fine scratches and little heaps of black residue. The grain of a small thumbprint provides scale. Neutral soft side-light, no type or labels, exquisitely tactile analog prop."),
    ("greenroom",1216,832,STREET+"Behind the scallop-shell stage of Kinsei. Modest private dressing room, vanity only 75 cm wide, chipped honey incandescent globes reflected along edge of a small spotted mirror. Japanese woman lounge singer in her forties with short finger-waved black hair and one pearl earring sits in black satin robe, touching the earring in the reflection. A single elbow glove laid at side, garment bag on knob, distant oxblood curtain. Softly framed intimate candid still without writing."),
    ("patch-room",1216,832,STREET+STATION+"Rear room behind the dispatch window, seen from one end of a very narrow aisle. Operator seen from behind at an arm's length from a chest-high patchbay, moving one ivory patch cord, and holding an open ruled ledger in the crook of elbow. Worn ring of paint around favorite sockets, chalk routing lines on pegboard, a field of cables on hooks. Left side of her face lit by small amber lamps. Ordinary municipal repair equipment."),
    ("lane-round",1216,832,STREET+"An early morning still outside the three adjacent small stores, viewed low behind a Japanese delivery rider pushing an old bicycle by hand. Wire basket carrying square LP sleeves in oilcloth, takeaway thermos and one oxblood document pouch. In depth green coffee awning with lotus emblem, blue paint on a record bin and a small frosted municipal service hatch. Brick-red apron of cafe owner greeting rider in background, slowly retreating rain across pavement, no towering buildings or readable signage."),
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8193)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    host = f"http://127.0.0.1:{args.port}"
    for index, (name, width, height, prompt) in enumerate(SPECS):
        if args.names and name not in args.names:
            continue
        while (args.work/"pause").exists():
            time.sleep(2)
        graph = copy.deepcopy(BASE)
        graph["4"]["inputs"]["text"] = prompt
        graph["5"]["inputs"]["text"] = "watermark, digital graphic overlay, glossy CGI, CGI render, anime, fantasy, anatomical error"
        graph["6"]["inputs"].update(width=width, height=height)
        graph["7"]["inputs"]["seed"] = 2026112230 + index
        graph["9"]["inputs"]["filename_prefix"] = "kinsei-district/"+name
        prompt_id = request(host+"/prompt", {"prompt":graph,"client_id":"kinsei-district"})["prompt_id"]
        while True:
            time.sleep(2)
            record = request(host+"/history/"+prompt_id).get(prompt_id)
            if record:
                break
        if record["status"]["status_str"] != "success":
            raise RuntimeError(record["status"])
        item = record["outputs"]["9"]["images"][0]
        (args.work/(name+".png")).write_bytes(urlopen(host+"/view?"+urlencode(item)).read())
        (args.work/(name+".json")).write_text(json.dumps(record["status"]["messages"]), encoding="utf8")
        print(name, prompt_id, flush=True)

if __name__ == "__main__":
    main()
