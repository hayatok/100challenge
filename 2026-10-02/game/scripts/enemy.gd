class_name RelayEnemy
extends Node3D

const Romaji = preload("res://scripts/romaji.gd")
var kind := "hush"
var lane := 0
var speed := 1.0
var phase := "approach"
var telegraph := 0.0
var telegraph_max := 2.4
var stun := 0.0
var cut_used := false
var clean := true
var dead := false
var age := 0.0
var hit_flash := 0.0
var purge_text := ""
var cut_text := ""
var purge_kana := ""
var cut_kana := ""
var purge = Romaji.new()
var cut = Romaji.new()
var active_word := ""
var visual: Node3D
var halo: MeshInstance3D
var hp := 1
var identifier := 0
var attack_count := 0
var moving_parts: Array[Node3D] = []
var animation: AnimationPlayer
var camera: Camera3D
var walk_clip := "Zombie_Walk"
var idle_clip := "Zombie_Idle"
var attack_clip := "Zombie_Attack"
var death_clip := "Death"
var current_clip := ""
var entry_from := Vector3.ZERO
var entry_to := Vector3.ZERO
var entry_duration := 1.3
var corpse_time := 0.0
var corpse_lifetime := 7.0
var death_direction := 1.0
var is_crowd := false

func setup(type: String, path_lane: int, word: Dictionary, interrupt_word: Dictionary, difficulty: int, id: int) -> void:
    kind = type
    lane = path_lane
    identifier = id
    purge_text = word.text
    purge_kana = word.kana
    cut_text = interrupt_word.text
    cut_kana = interrupt_word.kana
    purge.reset(purge_kana)
    cut.reset(cut_kana)
    position = Vector3(path_lane * 2.2, 0.03, -12.0)
    speed = (1.35 if kind == "skip" else 0.68) * [0.68, 1.0, 1.38][difficulty]
    telegraph_max = [3.4, 2.4, 1.65][difficulty]
    _make_visual()

func _make_visual() -> void:
    var model_path := "res://assets/models/city/zombie_city.glb"
    if kind == "skip" and ResourceLoader.exists("res://assets/models/city/thin_zombie.glb"):
        model_path = "res://assets/models/city/thin_zombie.glb"
        walk_clip = "run"
        idle_clip = "idle"
        attack_clip = "attack1_l"
        death_clip = "dead1"
    if not ResourceLoader.exists(model_path):
        model_path = "res://assets/models/city/zombie_city_source.glb"
        death_clip = "Zombie_Dying"
    visual = load(model_path).instantiate()
    add_child(visual)
    animation = visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
    if animation:
        animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
        for clip in animation.get_animation_list():
            var anim := animation.get_animation(clip)
            if "Walk" in clip or "Idle" in clip or clip in ["run","walk","walk2","idle"]:
                anim.loop_mode = Animation.LOOP_LINEAR
        if animation.has_animation("City_Death"): death_clip = "City_Death"
        elif animation.has_animation("Collapse"): death_clip = "Collapse"
        elif animation.has_animation("Zombie_Death"): death_clip = "Zombie_Death"
        elif animation.has_animation("Death"): death_clip = "Death"
        _play(walk_clip)
        if animation.has_animation(walk_clip):
            animation.seek(fmod(identifier*0.37,animation.get_animation(walk_clip).length),true)
    _vary_materials()
    # A human body with small physical variation, never abstract mechanical silhouettes.
    var body_scale := 1.0 + float(identifier % 4 - 1)*0.025
    visual.scale *= Vector3(body_scale,1.0+float(identifier%3)*0.025,body_scale)
    halo = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 0.40
    ring.outer_radius = 0.425
    ring.rings = 24
    ring.ring_segments = 4
    halo.mesh = ring
    halo.position.y = 0.025
    halo.material_override = emissive(Color("f8c56b"))
    halo.visible = false
    add_child(halo)

func set_entry(from: Vector3, to: Vector3, view: Camera3D) -> void:
    camera = view
    entry_from = from
    entry_to = to
    position = from
    phase = "emerging"
    age = 0.0

static func emissive(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.1
    return material

func _play(clip: String, blend := 0.12) -> void:
    if not animation or current_clip == clip or not animation.has_animation(clip): return
    animation.play(clip,blend)
    current_clip = clip

func _advance_animation(delta: float) -> void:
    if animation: animation.advance(delta)

func tick(delta: float, selected_target: bool) -> bool:
    if dead: return false
    age += delta
    hit_flash = maxf(0.0,hit_flash-delta*7.0)
    halo.visible = selected_target and not is_crowd
    var target := Vector3(0,0,4)
    if is_instance_valid(camera): target = Vector3(camera.global_position.x+lane*0.62,0,camera.global_position.z-1.4)
    var direction := target-global_position
    direction.y = 0
    if direction.length() > 0.01:
        rotation.y = lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,delta*5.0))
    visual.position.z = -hit_flash*0.035
    visual.rotation.x = -hit_flash*0.035
    if stun > 0:
        stun = maxf(0,stun-delta)
        _play(idle_clip)
        _advance_animation(delta*0.4)
        return false
    if phase == "emerging":
        position = entry_from.lerp(entry_to,smoothstep(0.0,entry_duration,age))
        _play(walk_clip)
        _advance_animation(delta)
        if age >= entry_duration: phase = "approach"
    elif phase == "approach":
        _play(walk_clip)
        var distance := direction.length()
        if distance > 1.8:
            position += direction.normalized()*speed*delta
        else:
            phase = "attack"
            telegraph = 0.0
        _advance_animation(delta*(1.05 if kind == "skip" else 0.72+float(identifier%5)*0.065))
    elif phase == "attack":
        telegraph += delta
        _play(attack_clip)
        _advance_animation(delta*0.8)
        if telegraph >= telegraph_max:
            attack_count += 1
            telegraph = 0
            position -= direction.normalized()*2.5
            phase = "approach"
            return true
    return false

func urgency() -> float:
    if dead: return INF
    if phase == "attack": return maxf(0,stun)+telegraph_max-telegraph
    var target := Vector3(0,0,4)
    if is_instance_valid(camera): target = Vector3(camera.global_position.x+lane*0.62,0,camera.global_position.z-1.4)
    var distance := Vector2(position.x-target.x,position.z-target.z).length()
    var rail_speed := 0.55 if is_instance_valid(camera) else 0.0
    return maxf(0,stun)+maxf(0,distance-1.8)/maxf(speed+rail_speed,0.01)+telegraph_max

func can_cut() -> bool:
    return not cut_used and (phase == "attack" or urgency() <= 7.0 or active_word == "cut")

func interrupt() -> bool:
    var counter := phase == "attack"
    cut_used = true
    stun = 2.0
    phase = "approach"
    telegraph = 0
    active_word = ""
    hit_flash = 1.0
    _play(idle_clip)
    return counter

func kill() -> void:
    if dead: return
    dead = true
    halo.hide()
    corpse_time = 0
    death_direction = -1.0 if identifier%2 == 0 else 1.0
    _play(death_clip,0.06)
    _advance_animation(0)
    set_process(true)

func _process(delta: float) -> void:
    if not dead: return
    var game = get_parent()
    if game and (game.state == "paused" or (game.state == "settings" and game.settings_origin == "paused")): return
    corpse_time += delta
    _advance_animation(delta)
    # Weight is carried by the authored skeletal collapse. Body stays at real size.
    if not animation or not animation.has_animation(death_clip):
        visual.rotation.x = lerpf(visual.rotation.x,-PI*0.5,minf(1,delta*5))
        visual.position.y = lerpf(visual.position.y,0.16,minf(1,delta*4))
    if corpse_time < 0.22:
        position.z -= delta*1.15
        visual.rotation.x = -sin(corpse_time/0.22*PI)*0.09
    if corpse_time > corpse_lifetime: queue_free()

func current_matcher() -> RelayRomaji:
    return cut if active_word == "cut" else purge

func label_height() -> float:
    return 2.08

func boss_damage(_index: int) -> void:
    pass

func _vary_materials() -> void:
    var outfits := [Color("b6c1ce"),Color("b0a17e"),Color("bf9688"),Color("849886")]
    var skins := [Color("dfdfcc"),Color("d9c6b7"),Color("bac8bc"),Color("c4c0b1")]
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D = item
        if not mesh.mesh: continue
        for surface in range(mesh.mesh.get_surface_count()):
            var original := mesh.get_active_material(surface)
            if original is StandardMaterial3D:
                var material: StandardMaterial3D = original.duplicate()
                if "Outfit" in material.resource_name:
                    material.albedo_color *= outfits[identifier%outfits.size()]
                    material.roughness = 0.89
                elif "Body" in material.resource_name:
                    material.albedo_color *= skins[identifier%skins.size()]
                    material.roughness = 0.82
                mesh.set_surface_override_material(surface,material)
