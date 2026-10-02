extends SceneTree

func _initialize() -> void:
    call_deferred("_validate")

func _validate() -> void:
    var report := {}
    for name in ["zombie_city", "thin_zombie", "pistol_hands"]:
        var path := "res://assets/models/city/%s.glb" % name
        var packed := load(path) as PackedScene
        if not packed:
            push_error("Missing asset " + path)
            quit(1)
            return
        var scene := packed.instantiate() as Node3D
        root.add_child(scene)
        var entry := {"path": path}
        var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if player:
            var clips := {}
            for animation_name in player.get_animation_list():
                clips[animation_name] = player.get_animation(animation_name).length
            entry["animations"] = clips
        var skeleton := _find_skeleton(scene)
        if skeleton:
            var bones := []
            for i in range(skeleton.get_bone_count()):
                bones.append(skeleton.get_bone_name(i))
            entry["bones"] = bones
            if name == "zombie_city" and player and player.has_animation("City_Death"):
                player.play("City_Death")
                player.seek(1.55,true)
                player.advance(0)
                skeleton.force_update_all_bone_transforms()
                var poses := {}
                for bone_name in ["mixamorig_Hips","mixamorig_Head","mixamorig_LeftHand","mixamorig_RightHand","mixamorig_LeftForeArm","mixamorig_RightForeArm"]:
                    var at := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin
                    poses[bone_name] = [at.x,at.y,at.z]
                entry["death_terminal"] = poses
        var muzzle := scene.find_child("Muzzle",true,false) as Node3D
        if muzzle:
            entry["muzzle"] = [muzzle.global_position.x,muzzle.global_position.y,muzzle.global_position.z]
        report[name] = entry
        scene.queue_free()
    var output := FileAccess.open("res://../art/source/city/godot_asset_contract.json",FileAccess.WRITE)
    output.store_string(JSON.stringify(report,"  "))
    print("CITY_ASSET_CONTRACT ",JSON.stringify(report))
    quit()

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found:
            return found
    return null
