extends SceneTree

const Visual = preload("res://racers/RacerVisual.gd")
const STATES = ["idle", "ready", "launch", "run", "jump", "land", "stumble", "fall", "finish", "finish_win", "sprint", "dive", "slide"]

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var failed := false
	for index in 6:
		var visual = Visual.new()
		root.add_child(visual)
		visual.setup(index)
		var rigs := visual.model.find_children("*", "Skeleton3D", true, false) as Array
		var meshes := visual.model.find_children("*", "MeshInstance3D", true, false) as Array
		if rigs.size() != 1 or meshes.size() != 2 or not visual.face or not visual.player:
			push_error("Missing body, face or skeleton for bib %02d" % (index + 1))
			failed = true
			visual.free()
			continue
		var rig := rigs[0] as Skeleton3D
		for mesh: MeshInstance3D in meshes:
			if mesh.mesh.get_surface_count() != 1 or mesh.get_node_or_null(mesh.skeleton) != rig or mesh.skin == null or not mesh.get_active_material(0) is ShaderMaterial:
				push_error("Invalid skinned surface on %s" % mesh.name)
				failed = true
		for key in Visual.FACE_KEYS:
			var shape: int = visual.face.find_blend_shape_by_name(key)
			if shape < 0 or not is_zero_approx(visual.face.get_blend_shape_value(shape)):
				push_error("Missing or nonneutral imported face key %s" % key)
				failed = true
		visual.face_camera(Vector3(0.0, 1.3, 4.0), 0.0)
		if visual.face.visible:
			push_error("Back views should omit the hidden facial surface")
			failed = true
		visual.emotion = Vector3(0.88, 0.0, 0.0)
		visual.face_camera(Vector3(2.0, 1.3, -3.0), 0.0)
		if not visual.face.visible or visual.face.get_blend_shape_value(visual.shape_indices[0]) < 0.87:
			push_error("Turning to camera should restore the current expression immediately")
			failed = true
		var period := 3.35 + index * 0.19
		var blink_clock := 2.0 * period + 0.094 - index * 0.73 - 0.61
		var reaction := {"state":"sprint", "elapsed":0.18, "phase":0.3, "steer":0.0, "grounded":true, "speed":4.0}
		visual.race_pose(reaction, 7.0, blink_clock, 0.0, false)
		var focus_blink: float = visual.face.get_blend_shape_value(visual.shape_indices[4])
		reaction.state = "stumble"
		visual.race_pose(reaction, 7.0, blink_clock, 0.0, false)
		var startle_blink: float = visual.face.get_blend_shape_value(visual.shape_indices[5])
		visual.race_pose(reaction, 7.3, blink_clock + 0.3, 0.0, false)
		if focus_blink < 0.9 or startle_blink < 0.9 or visual.face.get_blend_shape_value(visual.shape_indices[1]) < 0.9:
			push_error("A collision during a blink must reopen into the startled expression")
			failed = true
		visual.reset_performance()
		var thigh := rig.find_bone("Thigh_L")
		if thigh < 0:
			thigh = rig.find_bone("Thigh.L")
		if thigh < 0:
			failed = true
			visual.free()
			continue
		for state in STATES:
			if not visual.player.has_animation(state):
				push_error("Missing %s on bib %02d" % [state, index + 1])
				failed = true
			visual.pose(state, 0.14, 0.23, 0.1)
		visual.pose("run", 0, 0.0, 0.0)
		var reference := rig.get_bone_pose_rotation(thigh)
		var maximum := 0.0
		for frame in range(1, 20):
			visual.pose("run", 0.0, frame / 20.0, 0.0)
			maximum = maxf(maximum, reference.angle_to(rig.get_bone_pose_rotation(thigh)))
		if maximum < 0.55:
			push_error("Running stride amplitude is too small for bib %02d" % (index + 1))
			failed = true
		# Bibs alternate the lead leg. The same thigh must both tuck and extend.
		var tuck_and_extend := 0.0
		for side in ["L", "R"]:
			var leg: int = visual._bone_index("Thigh", side)
			visual.pose("jump", 0.02, 0.3, 0.0)
			var takeoff := rig.get_bone_pose_rotation(leg)
			visual.pose("jump", Visual.FLIGHT_SECONDS * 0.5, 0.3, 0.0)
			var apex := rig.get_bone_pose_rotation(leg)
			visual.pose("jump", Visual.FLIGHT_SECONDS * 0.94, 0.3, 0.0)
			var approach := rig.get_bone_pose_rotation(leg)
			tuck_and_extend = maxf(tuck_and_extend, minf(takeoff.angle_to(apex), apex.angle_to(approach)))
		if tuck_and_extend < 0.4:
			push_error("Jump pose did not advance for bib %02d" % (index + 1))
			failed = true
		visual.pose("sprint", 0, 0.12, 0.0)
		var left_support := rig.get_bone_pose_rotation(thigh)
		visual.pose("sprint", 0, 0.62, 0.0)
		if left_support.angle_to(rig.get_bone_pose_rotation(thigh)) < 0.7:
			push_error("Sprint did not alternate knees for bib %02d" % (index + 1))
			failed = true
		var chest := rig.find_bone("Chest")
		visual.pose("dive", 0.0, 0.0, 0.0)
		var launch_chest := rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()
		visual.pose("dive", 0.3, 0.0, 0.0)
		var reaching := rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()
		visual.pose("dive", 1.35, 0.73, 0.0)
		var held := rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()
		if launch_chest.angle_to(reaching) < 0.7 or reaching.angle_to(held) > 0.01:
			push_error("Dive reach or hold failed for bib %02d" % (index + 1))
			failed = true
		visual.pose("slide", 0.14, 0.0, 0.0)
		var prone := rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()
		visual.pose("slide", Visual.Race.SLIDE_SECONDS, 0.0, 0.0)
		if prone.angle_to(rig.get_bone_global_pose(chest).basis.get_rotation_quaternion()) < 0.7:
			push_error("Slide recovery failed for bib %02d" % (index + 1))
			failed = true
		var finish := {"state":"finish", "elapsed":0.0, "phase":0.0, "steer":0.0, "grounded":true, "speed":0.0}
		visual.race_pose(finish, 45.0, 45.0, 0.0, true)
		visual.race_pose(finish, 46.5, 46.5, 0.0, true)
		if visual.active_clip != "finish_win" or visual.face.get_blend_shape_value(visual.shape_indices[2]) < 0.9:
			push_error("The winner must smile at the peak of the gesture")
			failed = true
		visual.race_pose(finish, 48.0, 48.0, 0.0, true)
		var held_sole: Vector3 = visual.trail_point(0, "sprint")
		visual.race_pose(finish, 55.0, 55.0, 0.0, true)
		if held_sole.distance_to(visual.trail_point(0, "sprint")) > 0.001 or visual.emotion.z >= 0.5:
			push_error("The winner's feet must hold as the eyes reopen after the cheer")
			failed = true
		visual.reset_performance()
		visual.race_pose(finish, 45.0, 45.0, 0.0, false)
		visual.race_pose(finish, 47.0, 47.0, 0.0, false)
		if visual.active_clip != "finish" or visual.face.get_blend_shape_value(visual.shape_indices[2]) < 0.7:
			push_error("The other finishers must recover and smile")
			failed = true
		print("Bib %02d  bones %d  skinned surfaces %d  expressions %d  clips %d  max thigh change %.3f rad" % [
			index + 1, rig.get_bone_count(), meshes.size(), visual.face.mesh.get_blend_shape_count(), STATES.size(), maximum
		])
		visual.free()
	quit(1 if failed else 0)
