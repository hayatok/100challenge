"""Finalize the saved Blender toon preview; does not reconstruct geometry."""
import bpy,os
from mathutils import Vector
p=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'art/source/kohaku-v3.blend')
bpy.ops.wm.open_mainfile(filepath=p)
for m in bpy.data.materials:
 if 'kohaku_base' not in m:continue
 nodes=m.node_tree.nodes;links=m.node_tree.links;ramp=next(n for n in nodes if n.type=='VALTORGB')
 n=nodes.new('ShaderNodeNewGeometry');dot=nodes.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=Vector((-.4,-.65,.8)).normalized();links.new(n.outputs['Normal'],dot.inputs[0]);links.new(dot.outputs['Value'],ramp.inputs[0]);ramp.color_ramp.elements[0].position=-.15;ramp.color_ramp.elements[1].position=.22;ramp.color_ramp.elements[2].position=.65
bpy.ops.wm.save_as_mainfile(filepath=p)
