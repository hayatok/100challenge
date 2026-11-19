"""Generate and wrap a coastal sky plate with the active Moss-image graph."""
import argparse
import copy
import io
import json
from pathlib import Path
import urllib.parse

import numpy as np
from PIL import Image

from surface_scans import ROOT, SERVER, request
import urllib.request


def queue(folder):
    history=request("/history?max_items=25")
    graph=next(row["prompt"][2] for row in reversed(list(history.values())) if any(
        "moss_image_sft" in str(node.get("inputs",{}).get("unet_name",""))
        for node in row["prompt"][2].values()))
    graph=copy.deepcopy(graph)
    nodes={node["class_type"]:node for node in graph.values()}
    switch=next(node for node in graph.values() if node["class_type"]=="ComfySwitchNode"
                and graph[node["inputs"]["on_false"][0]]["class_type"]=="PrimitiveStringMultiline")
    switch["inputs"]["switch"]=False
    graph[switch["inputs"]["on_false"][0]]["inputs"]["value"]=(
        "A continuous ultrawide panoramic color photograph for a grounded game skybox, viewed from above a small Japanese coastal city at standstill. "
        "The horizon stays perfectly horizontal and is extremely low, about 86 percent down the image. "
        "More than eighty percent of the full frame is a detailed realistic daytime sky: brooding broken maritime stratocumulus and soft cumulus clusters, "
        "distinct pale cyan clear openings, subtle warm diffused sunlight from the left and blues and greys in the cloud shade. "
        "A very narrow atmospheric layer at the bottom shows extremely distant anonymous low rooftops and a few thin chimneys barely perceptible in silvery "
        "marine sea mist, across several kilometers of coastal basin. No prominent tower, large foreground objects, vegetation, people, lettering, "
        "border, sun disk, rainbow, sunset orange, anime, fisheye lines, exaggerated clouds or dramatic mountains. "
        "Raw ultrawide photoreal capture, natural slight humidity, believable low daytime contrast and no color grading.")
    nodes["ResolutionSelector"]["inputs"].update(aspect_ratio="21:9 (Ultrawide)",megapixels=3.5)
    nodes["KSampler"]["inputs"].update(seed=24111908,steps=23)
    nodes["SaveImage"]["inputs"]["filename_prefix"]="EvacRefinement/coastal_sky"
    prompt_id=request("/prompt",{"prompt":graph,"client_id":"evac-coastal-sky"})["prompt_id"]
    (folder/"prompt.json").write_text(json.dumps({"prompt_id":prompt_id},indent=2),encoding="ascii")
    print(prompt_id)


def collect(folder):
    prompt_id=json.loads((folder/"prompt.json").read_text())["prompt_id"]
    row=request("/history/"+prompt_id).get(prompt_id)
    if not row or not row["status"].get("completed"):
        raise RuntimeError("Sky plate is still rendering or failed")
    result=next(out["images"][0] for out in row["outputs"].values() if out.get("images"))
    with urllib.request.urlopen(SERVER+"/view?"+urllib.parse.urlencode(result)) as response:
        source=Image.open(io.BytesIO(response.read())).convert("RGB")
    source.save(folder/"original.png")
    # A narrow overlap moves the left/right join into one continuous crossfade.
    # No pixels are reflected, so both the cloud masses and skyline remain asymmetric.
    pixels=np.asarray(source.resize((2208,1024),Image.Resampling.LANCZOS),dtype=np.float32)
    overlap=pixels.shape[1]-2048
    fade=np.linspace(0,1,overlap,dtype=np.float32)[None,:,None]
    blend=pixels[:,-overlap:]*(1-fade)+pixels[:,:overlap]*fade
    wrapped=np.concatenate((blend,pixels[:,overlap:-overlap]),axis=1)
    # Match the top of the plate to one zenith color. This removes the pinch
    # near the pole without hiding the detail in the rest of the hemisphere.
    upper=wrapped[:16].mean(axis=(0,1),keepdims=True)
    zenith=np.clip((np.arange(len(wrapped),dtype=np.float32)/84),0,1)[:,None,None]
    zenith=zenith*zenith*(3-2*zenith)
    wrapped=wrapped*zenith+upper*(1-zenith)
    result=Image.fromarray(np.uint8(np.clip(wrapped,0,255)+.5))
    target=ROOT/"Game/Assets/Resources/World/CoastalPlate.jpg"
    result.save(target, quality=92,subsampling=0,optimize=True)
    print(source.size,target,target.stat().st_size)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("action",choices=("queue","collect"))
    parser.add_argument("directory",type=Path)
    args=parser.parse_args()
    args.directory.mkdir(parents=True,exist_ok=True)
    (queue if args.action=="queue" else collect)(args.directory)
