extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
 var world=Node3D.new();root.add_child(world)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("718c99");environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("c4dfef");environment.ambient_light_energy=0.6
 var we=WorldEnvironment.new();we.environment=environment;world.add_child(we)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-35,0);sun.light_energy=0.9;sun.shadow_enabled=true;world.add_child(sun)
 var rider=load("res://scenes/rider.tscn").instantiate();world.add_child(rider)
 var loader=load("res://scripts/asset_loader.gd").new();world.add_child(loader);loader.attach_rider(rider)
 var avatar=rider.get_node("Visual/Avatar").get_child(1)
 avatar.position.y=0.30
 var plane=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(5,5);plane.mesh=pm;plane.position.y=-0.05
 var floor_material=StandardMaterial3D.new();floor_material.albedo_color=Color("c4d0d0");floor_material.roughness=1;plane.material_override=floor_material;world.add_child(plane)
 var camera=Camera3D.new();camera.current=true;camera.fov=40;world.add_child(camera)
 var controller=loader.pose_controller;controller.reduced_motion=true
 var ready_for_render: bool=controller.setup(avatar,rider)
 print("RENDER_SETUP=",ready_for_render)
 if not ready_for_render:
  quit(1)
  return
 controller.set_process(false)
 var output=ProjectSettings.globalize_path("res://").path_join("../docs/verification/prototype/poses").simplify_path()
 DirAccess.make_dir_recursive_absolute(output)
 var evidence={"godot":Engine.get_version_info().string,"renderer":"gl_compatibility","viewport":[900,900],"bone_count":controller._skeleton.get_bone_count(),"axes":{"up":vec(controller._up),"across":vec(controller._across),"forward":vec(controller._forward)},"leg_length_skeleton_units":controller._leg_length,"avatar_anchor_y":0.30,"avatar_anchor_rotation_y":PI/2.0,"cases":[]}
 var directions=[["front",Vector3(3.8,1.4,0)],["side",Vector3(0,1.4,3.8)],["back",Vector3(-3.8,1.4,0)]]
 for category in [["surf",0.0,0.0],["boost",1.0,0.0],["air",0.0,1.0]]:
  controller._boost=category[1];controller._air=category[2];controller._gaze_weight=1.0;controller._apply_pose()
  var left_error=controller._pose_position("leftfoot").distance_to(controller._rest_position("leftfoot"))
  var right_error=controller._pose_position("rightfoot").distance_to(controller._rest_position("rightfoot"))
  for direction in directions:
   camera.position=direction[1];camera.look_at(Vector3(0,1.0,0),Vector3.UP)
   for i in range(6): await process_frame
   await RenderingServer.frame_post_draw
   var file_name=category[0]+"_"+direction[0]+".png"
   print("POSE_RENDER=",file_name," error=",root.get_texture().get_image().save_png(output+"/"+file_name))
   evidence.cases.append({"file":file_name,"camera":vec(camera.position),"boost":category[1],"air":category[2],"gaze_weight":1.0,"foot_error_local":[left_error,right_error]})
 controller._boost=0.0;controller._air=0.0;controller._gaze_weight=0.0;controller._apply_pose()
 camera.position=Vector3(2.7,1.7,2.6);camera.fov=48;camera.look_at(Vector3(0,1.0,0),Vector3.UP)
 for i in range(6): await process_frame
 await RenderingServer.frame_post_draw
 print("TITLE_RENDER error=",root.get_texture().get_image().save_png(output+"/title_neutral.png"))
 evidence.cases.append({"file":"title_neutral.png","camera":vec(camera.position),"boost":0.0,"air":0.0,"gaze_weight":0.0})
 var f=FileAccess.open(output+"/pose_metrics.json",FileAccess.WRITE);f.store_string(JSON.stringify(evidence,"  "));f.close()
 world.queue_free();await process_frame;quit()

func vec(value:Vector3)->Array:
 return [value.x,value.y,value.z]
