"""Generate four original native-resolution material plates with the open Moss-image workflow.
Usage: python surface_scans.py queue WORKDIR, then python surface_scans.py collect WORKDIR.
The local ComfyUI instance owns model selection and inference. Pillow and NumPy pack the plates.
"""
import argparse
import copy
import io
import json
from pathlib import Path
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
SERVER="http://127.0.0.1:8188"
SURFACES={
    "asphalt":("road surface made of dark fine Japanese asphalt aggregate, variegated embedded tiny basalt stones, a few flatter polished pebbles, threshold between damp and dry grains without puddles",(.19,.18,.17)),
    "plaster":("warm grey cast architectural concrete with very fine sand texture, small irregular pinholes and traces of trowel work, elegant subtle modulation in a coastal city public building",(.69,.66,.61)),
    "metal":("weathered brushed steel painted a neutral mid grey, e-coat visible across shallow scrapes, tiny scuffs in several directions and sparse hairline scratches, used in municipal train equipment",(.45,.44,.43)),
    "canvas":("olive-brown heavy woven workwear twill cloth, extremely clear fine fibres in alternating diagonal warp and weft, slight fading of the high threads, completely flat uncut fabric",(.31,.30,.23)),
}


def request(path,data=None):
    raw=None if data is None else json.dumps(data).encode()
    req=urllib.request.Request(SERVER+path,data=raw,headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=30) as response:return json.load(response)


def queue(folder):
    history=request("/history?max_items=25")
    graph=next(row["prompt"][2] for row in reversed(list(history.values())) if any(
        "moss_image_sft" in str(node.get("inputs",{}).get("unet_name","")) for node in row["prompt"][2].values()))
    ids={}
    for index,(name,(material,_)) in enumerate(SURFACES.items()):
        g=copy.deepcopy(graph)
        # Follow the visible graph links instead of depending on local node IDs.
        by_type={n["class_type"]:n for n in g.values()}
        switch=next(n for n in g.values() if n["class_type"]=="ComfySwitchNode" and g[n["inputs"]["on_false"][0]]["class_type"]=="PrimitiveStringMultiline")
        switch["inputs"]["switch"]=False
        g[switch["inputs"]["on_false"][0]]["inputs"]["value"]=(
            "Photoreal orthographic seamless material scan for a videogame PBR surface. "+material+
            ". Edge-to-edge single surface, uniformly sized fine detail across the image. Flat cross-polarised daylight, neutral albedo plate, "
            "no shadows, perspective, seam lines, border, labels, tools, objects, lettering or large damage. Entire square is in sharp focus.")
        by_type["ResolutionSelector"]["inputs"].update(aspect_ratio="1:1 (Square)",megapixels=4.0)
        by_type["KSampler"]["inputs"].update(seed=181703+index,steps=22)
        by_type["SaveImage"]["inputs"]["filename_prefix"]="EvacRefinement/surface_"+name
        ids[name]=request("/prompt",{"prompt":g,"client_id":"evac-surface-refinement"})["prompt_id"]
        (folder/"prompts.json").write_text(json.dumps(ids,indent=2))
        print(name,ids[name],flush=True)


def collect(folder):
    ids=json.loads((folder/"prompts.json").read_text())
    atlas=Image.new("RGB",(4096,4096))
    for index,(name,(_,target)) in enumerate(SURFACES.items()):
        row=request("/history/"+ids[name]).get(ids[name])
        if not row or not row["status"].get("completed"):raise RuntimeError(name+" is still rendering or failed")
        metadata=next(o["images"][0] for o in row["outputs"].values() if o.get("images"))
        url=SERVER+"/view?"+urllib.parse.urlencode(metadata)
        with urllib.request.urlopen(url) as data:img=Image.open(io.BytesIO(data.read())).convert("RGB")
        if img.size!=(2048,2048):raise ValueError((name,img.size))
        img.save(folder/(name+".png"))
        # Low-frequency illumination is removed while retaining the scan's genuine fine structure.
        rgb=np.asarray(img,dtype="float32")/255
        broad=np.asarray(img.filter(ImageFilter.GaussianBlur(39)),dtype="float32")/255
        base=np.median(rgb.reshape(-1,3),axis=0)
        normalized=np.array(target,dtype="float32")*(.83*rgb/np.maximum(broad,.045)+.17*rgb/np.maximum(base,.045))
        normalized=np.uint8(np.clip(normalized,0,1)*255+.5)
        atlas.paste(Image.fromarray(normalized),((index%2)*2048,(index//2)*2048))
    atlas.save(ROOT/"Game/Assets/Resources/World/SurfaceScan.png",optimize=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=("queue","collect"))
    parser.add_argument("directory",type=Path)
    args=parser.parse_args()
    args.directory.mkdir(parents=True,exist_ok=True)
    (queue if args.action=="queue" else collect)(args.directory)
