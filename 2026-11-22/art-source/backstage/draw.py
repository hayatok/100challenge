"""Draw the backstage plates with the same local ComfyUI graph as the night sky."""
import argparse
import copy
import hashlib
import json
import time
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent

def api(url, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf8")
    request = Request(url, data, headers={"Content-Type":"application/json"})
    with urlopen(request, timeout=60) as response:
        return json.load(response)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8196)
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--graph", type=Path, default=HERE.parent/"nightscape"/"graph.json")
    parser.add_argument("--plates", type=Path, default=HERE/"plates.json")
    parser.add_argument("--prefix", default="kinsei-backstage")
    args = parser.parse_args()
    args.work.mkdir(exist_ok=True, parents=True)
    graph = json.loads(args.graph.read_text(encoding="utf8"))
    host = f"http://127.0.0.1:{args.port}"
    for plate in json.loads(args.plates.read_text(encoding="utf8")):
        name = plate["key"]
        record_path = args.work/(name+".json")
        file = args.work/(name+".png")
        if record_path.exists() and file.exists():
            if hashlib.sha256(file.read_bytes()).hexdigest() == json.loads(record_path.read_text())["sha256"]:
                continue
        drawing = copy.deepcopy(graph)
        nodes = {i: n["inputs"] for i,n in drawing.items()}
        nodes["4"]["text"] = plate["prompt"]
        nodes["5"]["text"] = "watermark, stock photo logos, typographic mistakes, digital illustration, plastic doll, oversharpened"
        nodes["6"].update(width=plate["width"], height=plate["height"])
        nodes["7"]["seed"] = plate["seed"]
        nodes["9"]["filename_prefix"] = args.prefix+"/"+name
        pid = api(host+"/prompt", {"prompt":drawing,"client_id":args.prefix})["prompt_id"]
        while True:
            entry = api(host+"/history/"+pid).get(pid)
            if entry:
                break
            time.sleep(2)
        if entry["status"]["status_str"] != "success":
            raise RuntimeError(entry["status"])
        item = entry["outputs"]["9"]["images"][0]
        with urlopen(host+"/view?"+urlencode(item), timeout=60) as response:
            file.write_bytes(response.read())
        times = [details["timestamp"] for _,details in entry["status"]["messages"] if "timestamp" in details]
        record = dict(key=name, prompt_id=pid, file=item["filename"],sha256=hashlib.sha256(file.read_bytes()).hexdigest(), seconds=(max(times)-min(times))/1000)
        record_path.write_text(json.dumps(record,indent=2)+"\n", encoding="utf8")
        print(name, pid, record["seconds"], flush=True)

if __name__ == "__main__":
    main()
