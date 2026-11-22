"""Submit the bathhouse surfaces to the local ComfyUI and preserve the original PNGs."""
import hashlib
import io
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from PIL import Image

ROOT = Path(__file__).resolve().parent
HOST = "http://127.0.0.1:8188"
BASE = ("Straight-on cross-polarized material scan, uniform diffuse illumination. "
        "This is a texture for a game mesh, every pixel is the same surface, "
        "edge to edge, no object outline, no scene or cast shadow. ")
NEGATIVE = ("text, inscription, picture frame, border, scene, ruler, label, hands, logo, "
            "hard reflection of scenery, horizon line, lens distortion, perspective, watermark")
SURFACES = {
    "Glass": (1502705, "A 12-centimetre square scan filling the frame with a single sheet of old Japanese cast privacy glass, the tiny three-dimensional irregular seed and flowing fern pattern embossed in the glass seen by softly transmitted neutral grey light. Nearly colorless, delicate diffuse medium-grey relief on a pale smoky grey field, tightly packed minute ridges and flutes, restrained range. Face-on perpendicular, no room or view or objects visible through it, no window border, no metal wires, printed decoration or cracks."),
    "Tile": (1502701, "A tightly cropped patch of one single sea-green glazed ceramic tile from a well-kept 1969 Osaka public bath entrance. Inside the tile surface only. Soft cool jade green with a little celadon mottling and faint darker green pooling, tiny irregular hairline crazing in the fired glaze which only becomes visible from close up. No grout, no other tiles, no sharp highlights, no cracks through the body. The quality of fired hand-dipped glaze."),
    "Terrazzo": (1502702, "Twenty-centimetre section of polished, exposed aggregate cast stone on an Osaka canal bridge pier. Closely packed irregular 2 to 8 mm chips of warm granite, milky ivory quartz, sparse black basalt, pink feldspar and sand grains in a medium warm grey cement matrix. Small tool-polished speckles distributed over the full field. No big stones, veins, masonry joints, loose pebbles or slab edge."),
    "Noren": (1502703, "An eight-centimetre square macro scan cut from the undisturbed middle of a Japanese bathhouse noren, deep aubergine purple, plain-weave indigo-red dyed medium weight cotton. Horizontal weft and vertical warp threads cross evenly, thread-level muted variation and a few pale slubs. Flat textile laid on scanner, no lettering, no seams, no folds, no gesture of lighting. Purple rather than bright pink."),
    "Mat": (1502704, "Straight-down full-bleed macro scan of very dark grey-brown vulcanized rubber at an Osaka bathhouse threshold. Many narrow parallel fine traction ribs running vertically from top to bottom of the entire scan, no edge, one dull patch of sanded and flattened rib crests in the middle third where sandals turn each evening. Quiet small dry grit in a few grooves, no footprints, no lettering, no solid wet puddle.")
}


def api(path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    with urlopen(Request(HOST + path, data=data, headers={"Content-Type": "application/json"}), timeout=30) as response:
        return json.load(response)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def generate(name, seed, detail):
    graph = json.loads((ROOT / "graph.json").read_text(encoding="utf-8"))
    graph["4"]["inputs"]["text"] = BASE + detail
    graph["5"]["inputs"]["text"] = NEGATIVE
    graph["7"]["inputs"]["seed"] = seed
    graph["9"]["inputs"]["filename_prefix"] = "kinsei/west-" + name.lower()
    job = api("/prompt", {"prompt": graph, "client_id": "kinsei-west-bath"})["prompt_id"]
    for _ in range(540):
        result = api("/history/" + job).get(job)
        if result:
            break
        time.sleep(2)
    else:
        raise TimeoutError(job)
    if result["status"]["status_str"] != "success":
        raise RuntimeError(result["status"])
    source = result["outputs"]["9"]["images"][0]
    query = {key: source[key] for key in ("filename", "subfolder", "type")}
    with urlopen(HOST + "/view?" + urlencode(query), timeout=30) as response:
        raw = response.read()
    with Image.open(io.BytesIO(raw)) as image:
        assert image.format == "PNG" and image.size == (1024, 1024)
    (ROOT / (name + ".png")).write_bytes(raw)
    write_json(ROOT / (name + ".json"), {
        "prompt_id": job, "seed": seed, "positive": BASE + detail, "negative": NEGATIVE,
        "source": query, "sha256": hashlib.sha256(raw).hexdigest(),
        "status": result["status"]["status_str"], "execution": result["status"]["messages"]
    })
    print(name, job, hashlib.sha256(raw).hexdigest(), flush=True)


if __name__ == "__main__":
    for material, (seed, detail) in SURFACES.items():
        saved = ROOT / (material + ".json")
        original = ROOT / (material + ".png")
        if saved.is_file() and original.is_file():
            if hashlib.sha256(original.read_bytes()).hexdigest() == json.loads(saved.read_text())["sha256"]:
                continue
        generate(material, seed, detail)
