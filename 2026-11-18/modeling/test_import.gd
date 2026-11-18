extends SceneTree

const Visual = preload("res://racers/RacerVisual.gd")
const STATES = ["idle", "run", "jump", "land", "stumble", "fall", "finish", "sprint", "dive", "slide"]

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
		if rigs.size() != 1 or meshes.size() != 1 or not visual.player:
			failed = true
			visual.free()
			continue
		var rig := rigs[0] as Skeleton3D
		var mesh := meshes[0] as MeshInstance3D
		var thigh := rig.find_bone("Thigh_L")
		if thigh < 0:
			thigh = rig.find_bone("Thigh.L")
		if thigh < 0:
			failed = true
			visual.free()
			continue
		for state in STATES:
			if not visual.player.has_animation(state):
				failed = true
			visual.pose(state, 0.14, 0.23, 0.1)
		visual.pose("run", 0, 0.0, 0.0)
		var reference := rig.get_bone_pose_rotation(thigh)
		var maximum := 0.0
		for frame in range(1, 20):
			visual.pose("run", 0.0, frame / 20.0, 0.0)
			maximum = maxf(maximum, reference.angle_to(rig.get_bone_pose_rotation(thigh)))
		if maximum < 0.55 or mesh.mesh.get_surface_count() != 1:
			failed = true
		# Stride phase stays fixed in the air. The thigh should tuck and extend again.
		visual.pose("jump", 0.02, 0.3, 0.0)
		var launch := rig.get_bone_pose_rotation(thigh)
		visual.pose("jump", Visual.FLIGHT_SECONDS * 0.5, 0.3, 0.0)
		var apex := rig.get_bone_pose_rotation(thigh)
		visual.pose("jump", Visual.FLIGHT_SECONDS * 0.94, 0.3, 0.0)
		var approach := rig.get_bone_pose_rotation(thigh)
		if launch.angle_to(apex) < 0.4 or apex.angle_to(approach) < 0.4:
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
		print("Bib %02d  bones %d  surfaces %d  max thigh change %.3f rad" % [
			index + 1, rig.get_bone_count(), mesh.mesh.get_surface_count(), maximum
		])
		visual.free()
	quit(1 if failed else 0)
