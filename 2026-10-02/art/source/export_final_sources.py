import bpy
from pathlib import Path
out=Path(__file__).resolve().parent.parent
for name in ('enemy_walker','enemy_crawler','enemy_beacon','boss_relay','relay_cabinet','hazard_gate','conduit_bundle'):
    root=bpy.data.objects[name]
    root.location=(0,0,0)
    if name=='boss_relay':root.scale=(1,1,1)
    scene=bpy.data.scenes.new(name+'_source')
    for ob in [root]+list(root.children_recursive):
        scene.collection.objects.link(ob)
        ob.hide_render=False
    bpy.data.libraries.write(str(out/'source'/(name+'_final.blend')),{scene},fake_user=True,compress=True)
    bpy.data.scenes.remove(scene)
    print('SOURCE_READY', name)
