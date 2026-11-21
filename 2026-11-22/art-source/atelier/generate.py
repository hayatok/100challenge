"""Recreate the art department plates on a local MOSS ComfyUI instance."""
import argparse
import json
import pathlib
import time
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
BASE = json.loads((HERE.parent / "moss" / "poster-api.json").read_text(encoding="utf8"))
STUDIO = "Japanese 1970s motion-picture wardrobe continuity photography. Three photographs side by side on a warm dove-grey seamless wall: front and profile full-length from hair to shoes, and a large three-quarter face closeup. Identical Japanese man and identical outfit throughout. Quiet natural expression. Soft oblique window light, realistic cloth and skin. No words or graphic decoration. "
SPECS = [
("camellia",1024,768,"Full bleed flat scan of a horizontal decorative panel made for the wall of a luxurious Osaka cabaret in 1973. One fully opened Japanese folding fan seen straight on, vermilion lacquer ribs, ink-black silk painted with two sumptuous cream camellias and a tiny chestnut bird, fine hand-dusted gold leaf. Oxblood lacquer ground. Off-centre asymmetrical Edo botanical design, minimal sinuous lines, warm aged artisan surface, no writing, no photograph of a room, no frame. Peripheral margins in dark oxblood."),
("broadcast",768,1024,"Flat full-bleed vertical scan of a stylish 1973 Japanese television station programme handbill. Thick ivory rag paper, near-black, burgundy and midnight teal two-colour offset reproduction, huge curved CRT screen containing a half-tone silhouette of two dancers, radial transmission waves and a single brass star. Elegant Swiss-inspired Japanese modernist printing. Exactly one line of large Latin heading reads KINSEI TV. No fine print, no writing elsewhere. Bold shapes readable from afar, no drop shadow, no table."),
("chanteuse",768,1024,"Vertical full-frame archival publicity portrait of a fictional Japanese lounge chanteuse aged 44 in 1973 Osaka. High cheekbones, short finger-waved hair, single pearl earring, black satin gown, sheer silk gloves, enigmatic mild smile directly at camera. Closeup at three quarters, neck and one shoulder, undulating curtain softly blurred. Actual gelatin silver portrait, exquisite soft charcoal blacks and warm ivory emulsion, tiny film grain, sober framing. No lettering, no signature, no frame or surrounding objects."),
("lotus-sign",1024,640,"Enamel arcade shop fascia rectangular graphic, front-on full bleed. Blackened forest-green enamel rectangle, continuous warm coral neon tubing bent into a large elegant lotus flower at left, next to exactly one large word LOTUS in ivory rounded outline capitals; at far right one tiny warm gold star. Plausible vintage Japanese coffee bar sign, dusty enamel and pale ceramic stand-offs, restrained tube glow, minimal clean geometry, no other words, no façade, no sky, closely framed."),
("makabe",1216,832,STUDIO+"The lead negotiator Makabe, late thirties, tall and straight backed, angular lean face, broad eyebrows, pronounced cheekbones, swept pompadour. Sharp charcoal-blue single breasted wool suit, warm ivory shirt, burgundy tie, folded pocket square, aged brass lapel pin, black shoes. His stillness is the performance."),
("tatsu",1216,832,STUDIO+"Tatsu the energetic lieutenant, early thirties, stocky square shoulders, wide round jaw, thick swept glossy hair, lively eyes, a little smile on one side. Copper-rust double-breasted suit with six brass buttons, ivory shirt, claret tie, tobacco shoes."),
("kaji",1216,832,STUDIO+"Kaji, Osaka club negotiator, weathered Japanese man of fifty, lean face, grizzled temples, narrowing dark eyes, old pale thin scar below left eye. Olive-brown wool suit with generous lapels, ivory shirt and claret tie, black cap-toe shoes. Wary posture."),
("otouto",1216,832,STUDIO+"Kaji's younger brother. Slim small-framed Japanese man in his late twenties, long youthful face, uncertain watchful eyes, neat black side-part with a fallen forelock. Moss green single-breasted suit cut slightly too large, open ivory collar with loosened burgundy tie, dull black shoes. Shoulders slightly hunched."),
("relay",1216,832,"1973 industrial design photograph triptych. Three views of the exact same desk videophone in a straight horizontal row: front, side profile, rear with ventilation slots. Broad oxblood Bakelite cabinet encloses a convex black CRT in a deep brass bezel; a matching telephone handset cradled on the LEFT; a brass rotary dial below the screen; braided black cord. Heavy physical curves, ivory Bakelite knobs. Neutral tobacco-grey studio cyclorama. Beautifully built practical prop from a Japanese cabaret, full objects clearly separated. No labels or writing."),
("assistance",1216,832,"Three consecutive stills on a single horizontal Japanese film blocking contact sheet. Same two Japanese adult men in all three panels on a plain honey-lit cabaret floor. A tall man in a charcoal suit offers his shoulder to support a smaller man in a moss-green suit. Left image the two stand supported shoulder-to-shoulder; centre the younger begins to lower, touching one knee to the floor; right the younger kneels facing a waist-high oxblood CRT videophone, the taller standing to one side. Peaceful concerned expressions. Side-on full-length staging, distinct silhouettes, no weapons or text."),
("facade",1216,832,"1973 Osaka cabaret exterior, low three-quarter architectural location photograph in light drizzle at blue hour. Compact two-storey façade wedged between a bicycle repairer and a shuttered kissaten. Pale green glazed tile, horizontally ribbed brass marquee, oxblood double doors with tiny round portholes. Above doors a warm five-point star and exactly two large gold letters 金星. Honey in the lobby against cold turquoise gutter light. Foreground bicycle rack, modest alley, very few passersby. Intimate ordinary neighborhood, no skyscrapers, no cyberpunk. Cinematic photochemical realism."),
("daylight",1216,832,"Daytime location scout photograph inside a shuttered 1973 Osaka cabaret viewed obliquely FROM the stage wing over crescent wine vinyl banquettes towards the entrance. Blunt daylight from open double doors slices across dust and reveals a floor of small dark green tiles, upended chairs, and a cleaner wiping a brass rail. Edge of scalloped footlight shell in near foreground, lamps switched off. Muted olive, chalk and oxblood tones. Quiet workaday beauty, tactile daylight, no lettering."),
("evening",1216,832,"Occupied Osaka cabaret in 1973, cinematic documentary still shot at seated customer eye level through silhouettes of two suited men quietly talking in an oxblood banquette. In the middle distance a Japanese singer in ivory silk and a small jazz trio perform in front of a great theatrical scallop shell traced by rows of incandescent honey bulbs. Groups of Japanese adults at four tables make an intimate packed house. Low copper ashtrays, dark plum curtain, brass handrails, cool green light leaks from vestibule. Visible faces and layered depth, no text."),
("swatches",1216,832,"Wardrobe department physical sample tray for a 1973 Osaka cabaret film, perfectly overhead detail photograph. Four long vertical strips of worsted suit fabric laid across plain putty board: dark blue charcoal subtle herringbone, copper rust double twill with six patinated brass buttons, old olive-brown wool, faded moss green gabardine. At the bottom lie folded ivory cotton shirting, a narrow claret silk tie and a tiny gold star lapel pin. Tailor's chalk tick marks and slight frayed edges. Daylight, crisp woven fibers, no printed text."),
]

# Supplemental plates share the same continuity setup and fixed sequence of seeds.
SPECS.extend([
    ("elder", 1216, 832, STUDIO + "The senior impresario of an Osaka cabaret, an imposing Japanese man of sixty, broad shoulders, ivory wool dinner suit, dark claret tie and ivory shirt, black polished shoes. Slicked silver-streaked black hair, close small moustache, thick brows and broad lined cheeks. He looks accustomed to being quietly obeyed."),
    ("table-read", 1216, 832, "A still, intimate scene photographed in a 1973 Osaka cabaret, viewed at the seated men's eye level from the aisle. Two Japanese men face each other across one small ROUND walnut booth table. At left a stocky younger man in a copper-rust double-breasted suit with gold buttons is listening; at right a lean older man with silver at the temples in an olive-brown single-breasted suit is speaking quietly, one hand open on the tabletop. The same oxblood horseshoe banquette curves behind them. Single honey-glass table lamp softly lights both faces, a thread of cool green doorway light defines their shoulders. Stage bulbs are softly blurred in distant background. Natural stillness and readable eyelines, no guns or text."),
])

def request(url, data=None):
    body = None if data is None else json.dumps(data).encode()
    return json.load(urllib.request.urlopen(urllib.request.Request(url, data=body, headers={"Content-Type":"application/json"}), timeout=30))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8192)
    parser.add_argument("--work", type=pathlib.Path, required=True)
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    args.work.mkdir(parents=True, exist_ok=True)
    host = f"http://127.0.0.1:{args.port}"
    for index, (name, width, height, prompt) in enumerate(SPECS):
        if args.names and name not in args.names:
            continue
        graph = json.loads(json.dumps(BASE))
        graph["4"]["inputs"]["text"] = prompt
        graph["5"]["inputs"]["text"] = "watermark, CGI render, cartoon, glossy digital painting, anatomical errors, digital user interface"
        graph["6"]["inputs"].update(width=width,height=height)
        graph["7"]["inputs"]["seed"] = 1973112400 + index
        graph["9"]["inputs"]["filename_prefix"] = "kinsei-atelier/"+name
        submission = request(host+"/prompt", {"prompt":graph,"client_id":"kinsei-atelier"})
        prompt_id = submission["prompt_id"]
        while True:
            time.sleep(2)
            history = request(host+"/history/"+prompt_id)
            if prompt_id in history:
                break
        record = history[prompt_id]
        if record["status"]["status_str"] != "success":
            raise RuntimeError(record["status"])
        item = record["outputs"]["9"]["images"][0]
        from urllib.parse import urlencode
        (args.work/(name+".png")).write_bytes(urllib.request.urlopen(host+"/view?"+urlencode(item)).read())
        (args.work/(name+".json")).write_text(json.dumps({"prompt_id": prompt_id,"output":item,"events":record["status"]["messages"]},indent=2),encoding="utf8")
        print(name, prompt_id, flush=True)
        while (args.work/"pause").exists():
            time.sleep(2)
if __name__ == "__main__":
    main()

