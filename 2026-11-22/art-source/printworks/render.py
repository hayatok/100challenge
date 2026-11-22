"""Generate the individual print masters with the local Kinsei MOSS graph."""

import argparse
import copy
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
JACKET = "Flat full-bleed square scan of a fictional Japanese LP sleeve from a neighborhood Osaka rental record store. Print right to all four edges. No record or room around it. Real commercial offset ink, restrained tiny shelfwear on corners. Compose a unified collectible album front. "
LABEL = "Flat scan of the ink artwork of one fictional vintage Osaka bottling house spirit label. Full bleed square image with graphic motifs contained within the central two thirds for die cutting. Face on, no bottle, no backdrop or scene, no branding copied from actual products. "
SPECS = [
    (
        "singer",
        1024,
        1024,
        JACKET
        + "An intimate black and warm-ivory publicity photograph of a Japanese lounge chanteuse aged 44 with short waved black hair, one pearl earring and satin collar, looking past the camera, smiling quietly. Dramatic crop on right. At lower left one large cinnabar camellia overprints her shoulder; broad dark empty strip above. Understated 1971 modern kayō record. No text or lettering.",
    ),
    (
        "trio",
        1024,
        1024,
        JACKET
        + "Japanese hard bop trio, 1966. Fractured cobalt-blue and ink-black angular woodcuts of a double bass player, a pianist and a drummer, with a single orange cymbal hanging in blank sky. Bauhaus-inflected Osaka independent jazz press, forceful asymmetry, solid screenprint grain and ivory stave lines. No words or captions.",
    ),
    (
        "folk",
        1024,
        1024,
        JACKET
        + "Rust-orange and black traditional katazome stencil textile print: two stylized dancing women in indigo work kimono circle one straw sheaf beside a stylized moon seen as unprinted paper. Japanese riverside minyo field recordings, austere blockcut design, visible uneven indigo and raw flax stock. No lettering whatsoever.",
    ),
    (
        "forty",
        1024,
        1024,
        JACKET
        + "The 40 theaters relay network's first local live LP. A striking ivory eight-point broadcast star is approached by many thin red and forest-green connecting lines terminating in small dots. These lines form a schematic miniature of a city around one black CRT silhouette, printed muted ochre card. Rigorous postwar Japanese graphic design. No type.",
    ),
    (
        "percussion",
        1024,
        1024,
        JACKET
        + "Experimental Osaka percussion record. Bird's eye black-and-white studio photo of three hammered-bronze gongs, drumheads and two mallets, quarter circles cropped at edges. A single brilliant yellow silkscreen disk overlays the strongest shadow. Angular modernist 1960s layout, deep charcoal and silver gelatin paper. No lettering.",
    ),
    (
        "harbor",
        1024,
        1024,
        JACKET
        + "1970s Osaka port ballad album in three-color lithography. Broad translucent pools of petrol-green water and a long thin vermilion tugboat, repetitive crane silhouettes, huge pale-butter setting sun like a circular label. Grainy tusche, uncoated bleached paper. Quiet horizon in upper third, bold abstract reflections. No lettering.",
    ),
    (
        "guitar",
        1024,
        1024,
        JACKET
        + "Elegant solo nylon-string guitar album, intimate extreme crop of a Japanese guitarist's hand and six parallel strings on an amber brown classical guitar, amber and tobacco photogravure, black and ivory radial soundhole marquetry, one diagonal strip of dusty violet screenprint crossing the lower corner. Rich printed photo, no words or type.",
    ),
    (
        "nighttrain",
        1024,
        1024,
        JACKET
        + "Midnight instrumental album. Irregular dark-indigo linocut of a Japanese local train's lit windows speeding across the lower third of a rainy night, two vermilion signal lamps, fine horizontal pale silver rain strokes, rippled window reflections. Artful negative space in navy sky, printed on blue cotton stock. No lettering.",
    ),
    (
        "amber",
        1024,
        1024,
        LABEL
        + "Deep amber brown and ivory horizontal art deco guilloche, geometric radial sun behind a small copper heron in silhouette, elegant concentric sun rays engraved in gold ochre on warm cream all across the image. No text, lettering, numbers or bottle outline.",
    ),
    (
        "gin",
        1024,
        1024,
        LABEL
        + "A navy-blue Japanese copperplate botanical illustration of juniper sprigs and berries on misty pale blue rag paper, a small sharp crescent moon high above the sprigs, airy asymmetrical composition within center, delicate classic engraving. No text or lettering.",
    ),
    (
        "plum",
        1024,
        1024,
        LABEL
        + "An ornamental 1960s plum liqueur lithograph. Sparse large ivory plum blossoms with vermilion centers on an elegantly crooked near-black branch on oxblood burgundy rice-paper ground. Centre oval composition with room above branch. Sophisticated delicate Japanese textile print. No lettering or type.",
    ),
    (
        "bitters",
        1024,
        1024,
        LABEL
        + "Chinese bellflowers and a split citrus fruit in the style of a delicate old Japanese botanical pharmacy engraving, mustard yellow and black woodcut ink on warm olive brown paper. Balanced symmetrical vertical composition and fine engraved dots. No letters or writing.",
    ),
    (
        "meter",
        1024,
        512,
        "Panoramic two-to-one straight-on macro reproduction of the flat faceplate of a 1960s Japanese analog volume-unit meter. Aged honey-ivory celluloid with very subtle hairline crazing, almost entirely blank, subtle uneven unprinted cream field, three tiny age spots, soft even scanner light no shadows. No frame, no lettering, no needle, no graphics, no numbers, no ticks. A blank industrial printing surface for adding functional scales.",
    ),
    (
        "line",
        1024,
        512,
        "Full-bleed straight-on photograph of a worn two-to-one teal-green painted brass signal tag blank. Hammered enamel, very subtle horizontal scratches at edges and four tiny screw heads near corners, rubbed warmer brass at the lip, solid dark oxidized teal empty centre. No text or symbols or border around the tag, no surrounding table.",
    ),
    (
        "schedule",
        1024,
        512,
        "Full bleed panoramic horizontal 2:1 vintage offset program handbill on aged natural cream paper. On the left quarter only: red and navy halftone illustration of a tiny microphone inside concentric radiowaves. Right three quarters mostly bare cream stock for adding actual timetable typography later. Pleasant quiet offset lithograph and thin burgundy border. No words numbers or type.",
    ),
    (
        "ticket",
        1024,
        512,
        "Horizontal 2:1 scan of an old ivory Japanese festival keepsake ticket. Elaborate faded rose and golden apricot guilloche line engraving over the whole paper, a large fan-shaped suburst crest at left, a discreet narrow perforated stub at far right, a few visible fibres and slight foxing. Dark brown printing area in center left blank for typesetting. No text or numbers, front on full bleed.",
    ),
]

SPECS.extend(
    [
        (
            "singer-proof",
            1024,
            1024,
            JACKET
            + "A SINGLE Japanese woman, the sole subject of this fictional kayokyoku solo album. Intimate high-contrast warm-black duotone bust portrait of a mature 44 year old Osaka nightclub singer in a black satin dress and one pearl earring, short swept finger waves, thoughtful half smile, in a single spotlight. One hand in a black glove resting against her cheek, a single red camellia tucked into her hair, deep burgundy background with dark blank area above for later typesetting. Only one portrait, no collage, no print or lettering.",
        ),
        (
            "gin-proof",
            1024,
            1024,
            LABEL
            + "Stylized deep-blue juniper berries and dark slender needles nod beside two silver-white crescent moons. Bold graphic Japanese stencil on a pale-blue flat printed paper ground. Keep emblem small within centre top half. Elegant craft gin insignia in just two dark blue spot colors. Absolutely no type or numbers.",
        ),
    ]
)


def call(url, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    return json.load(
        urlopen(Request(url, data=body, headers={"Content-Type": "application/json"}), timeout=30)
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8194)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    base = json.loads((HERE / "graph.json").read_text(encoding="utf8"))
    host = f"http://127.0.0.1:{args.port}"
    for i, (name, width, height, prompt) in enumerate(SPECS):
        if args.names and name not in args.names:
            continue
        if (args.work / (name + ".json")).is_file() and (args.work / (name + ".png")).is_file():
            continue
        while (args.work / "pause").exists():
            time.sleep(2)
        graph = copy.deepcopy(base)
        graph["4"]["inputs"]["text"] = prompt
        graph["5"]["inputs"]["text"] = (
            "watermark, artwork mockup, rotated image, three dimensional room, modern digital gradients"
        )
        graph["6"]["inputs"].update(width=width, height=height)
        graph["7"]["inputs"]["seed"] = 2026112260 + i
        graph["9"]["inputs"]["filename_prefix"] = "kinsei-printworks/" + name
        pid = call(host + "/prompt", {"prompt": graph, "client_id": "kinsei-printworks"})["prompt_id"]
        while True:
            time.sleep(2)
            record = call(host + "/history/" + pid).get(pid)
            if record:
                break
        if record["status"]["status_str"] != "success":
            raise RuntimeError(record["status"])
        item = record["outputs"]["9"]["images"][0]
        (args.work / (name + ".png")).write_bytes(urlopen(host + "/view?" + urlencode(item)).read())
        (args.work / (name + ".json")).write_text(
            json.dumps(record["status"]["messages"]), encoding="utf8"
        )
        print(name, pid, flush=True)


if __name__ == "__main__":
    main()
