"""Render authored action evidence from the editable saved original."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/hero.blend'))
rig=bpy.data.objects['Rig']
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=bpy.data.actions['slash_1']
bpy.context.scene.frame_set(10)
bpy.context.scene.render.filepath=str(ROOT/'art/hero_slash_preview.png')
bpy.ops.render.render(write_still=True)
