"""Generate the companion upholstery material using the poster's exact MOSS stack."""
import json, pathlib, urllib.request
root=pathlib.Path(__file__).resolve().parent
graph=json.loads((root/'poster-api.json').read_text(encoding='utf-8'))
graph['4']['inputs']['text']='''Orthographic straight-on studio material scan of luxurious dark oxblood burgundy red button-tufted vinyl leather upholstery from a 1973 Japanese cabaret banquette. A continuous repeating diamond quilting pattern fills the entire square image edge to edge, with deep softly folded diamond seams and small matching leather covered buttons at every intersection, regular evenly spaced tufting. Eight large diamond tufts visible across the width. Rich tactile glossy vintage vinyl grain, delicate tiny pores, softened wear on raised rounded cushions, dark wine shadows inside seams, subdued warm ivory highlights on the bulging leather. Deep red maroon tones with realistic variation and finely detailed surface texture. Perfectly flat frontal orthographic view, no perspective, no furniture silhouette, no surrounding room, no border, no text, no objects. Seamless tileable surface repeating across every edge, even neutral diffuse studio illumination from the front, natural physically plausible material, restrained photographic contrast, beautifully preserved vintage upholstery.'''
graph['5']['inputs']['text']='text, watermark, frame, room, furniture edges, perspective, uneven lighting, white background, ornament, worst quality, jpeg artifact'
graph['7']['inputs']['seed']=19731123
graph['9']['inputs']['filename_prefix']='kinsei/kinsei-oxblood-vinyl'
(root/'vinyl-api.json').write_text(json.dumps(graph,ensure_ascii=False,indent=2),encoding='utf-8')
req=urllib.request.Request('http://127.0.0.1:8188/prompt',data=json.dumps({'prompt':graph,'client_id':'kinsei-art'}).encode(),headers={'Content-Type':'application/json'})
response=json.loads(urllib.request.urlopen(req).read())
(root/'vinyl-submission.json').write_text(json.dumps(response,indent=2),encoding='utf-8')
print(response)
