"""Generate atmospheric and reeded-glass master images with local MOSS."""

import argparse
import copy
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
PANE = "Frameless softly glowing obscured glass pane. The ENTIRE square canvas is the textured face of a single piece of glass; straight on orthographic close scan. No visible exterior wall, no door, no frame, no mullions. Impressionistic but photographed real pressed glass, tiny variations of transmission. Motifs softly diffuse so the sense of someone at home remains ambiguous. No words, no decals, no face detail, no text. "
SPECS = [
    (
        "kitchen",
        768,
        768,
        PANE
        + "Beyond yellow honey-coloured narrow reeded glass, vague dark silhouette of the back of a woman's head and shoulder beside a kettle on a kitchen shelf off to the left. A copper pendant muted in upper right. Dark corners, central amber wash. 1970s Osaka domestic room seen at night.",
    ),
    (
        "desk",
        768,
        768,
        PANE
        + "Night in a small Osaka radio repair room through pebbled bluegreen pressed glass. Isolated pool of soft mint light on technician's desk, lean indistinct shoulders bent over it at lower right. Faint arch of small task lamp and a few narrow components at lower left. Mostly dark smoky green muted wall.",
    ),
    (
        "linen",
        768,
        768,
        PANE
        + "Dim mauve curtain hanging in an upstairs dressing room behind pebbled patterned privacy glass, an indistinct dress on a hanger and tiny amber pool of tungsten lamp beside a mirror. Much dark brown and muted grape shadow against a honey cream glow. No person facing camera.",
    ),
    (
        "plant",
        768,
        768,
        PANE
        + "Silver green silhouette of an aspidistra, three long broad leaves unevenly spaced against warm paper-shaded light, through translucent fluted glass in a small Osaka flat; midtones muted brown gold with deep leaf shadows and faint cotton curtain in upper corner. No human figures.",
    ),
    (
        "air",
        1536,
        768,
        "Landscape 2:1 panoramic photograph of EMPTY evening sky only, still humid late evening following rain over Osaka. Frame entirely filled with air, fine photographic grain, muted deep ink-blue zenith fading into a faint slate mauve and blue-grey band of humid atmosphere at bottom. Very soft traces of long low stratus, indistinct gradients, restrained low contrast. No red sunset, no moon, no stars, no celestial objects, no skyline, no horizon line, no horizon silhouettes, no buildings, no landscape, no water, no signs, no text. Atmospheric sky dome texture, softly luminous but dark.",
    ),
    (
        "air-proof",
        1536,
        768,
        "An extremely quiet ink-navy and smoky violet night sky photograph, a broad sweep of very dark blue overcast at top and a long muted grey-violet ribbon of soft haze near bottom. Subtle irregularities of light dispersed through the cloud deck, broad horizontal brushlike wisps. Only sky fills entire photograph from edge to edge, no ground, no skyline or people or moon or stars. Humid urban night in Japan. Never bright, no pink sunset or fantasy lights.",
    ),
]


def call(url, payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    return json.load(
        urlopen(
            Request(url, data=body, headers={"Content-Type": "application/json"}),
            timeout=30,
        )
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8195)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    base = json.loads((HERE / "graph.json").read_text(encoding="utf8"))
    host = f"http://127.0.0.1:{args.port}"
    for i, (name, width, height, prompt) in enumerate(SPECS):
        if args.names and name not in args.names:
            continue
        if (args.work / (name + ".json")).is_file() and (
            args.work / (name + ".png")
        ).is_file():
            continue
        while (args.work / "pause").exists():
            time.sleep(2)
        graph = copy.deepcopy(base)
        graph["4"]["inputs"]["text"] = prompt
        graph["5"]["inputs"]["text"] = (
            "watermark, artwork mockup, rotated image, three dimensional room, modern digital gradients"
        )
        graph["6"]["inputs"].update(width=width, height=height)
        graph["7"]["inputs"]["seed"] = 2026112290 + i
        graph["9"]["inputs"]["filename_prefix"] = "kinsei-nightscape/" + name
        pid = call(
            host + "/prompt", {"prompt": graph, "client_id": "kinsei-nightscape"}
        )["prompt_id"]
        while True:
            time.sleep(2)
            record = call(host + "/history/" + pid).get(pid)
            if record:
                break
        if record["status"]["status_str"] != "success":
            raise RuntimeError(record["status"])
        item = record["outputs"]["9"]["images"][0]
        (args.work / (name + ".png")).write_bytes(
            urlopen(host + "/view?" + urlencode(item)).read()
        )
        (args.work / (name + ".json")).write_text(
            json.dumps(record["status"]["messages"]), encoding="utf8"
        )
        print(name, pid, flush=True)


if __name__ == "__main__":
    main()
