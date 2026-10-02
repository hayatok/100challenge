class_name RelayWorld
extends Node3D
## Kisaragi arcade: an authored, continuous night-time city route.
## Compatibility renderer: wet PBR materials, local light pools and reflected
## storefront streaks are used deliberately instead of unavailable SSR/bloom.

var camera: Camera3D
var environment: Environment
var lamps: Array[OmniLight3D] = []
var material_cache := {}
var station_sign: Label3D
var end_door: Node3D
var trolley: Node3D
var muzzle: OmniLight3D
var beam: MeshInstance3D
var stage_decor: Node3D
var ripples: Array[MeshInstance3D] = []
var corridor_geometry: Array[Node3D] = []
var fragments: Array[Dictionary] = []
var time := 0.0
var stage := 0
var reduced_motion := false
var screen_shake := 0.0
var intro_pan := true
var running := false
var route_progress := 0.0
var camera_height := 1.7
var _static_boxes: Array[MeshInstance3D] = []
var _static_pipes: Array[MeshInstance3D] = []
var shot_origin_camera := Vector3(0.100, 0.00765, -0.7183)
var _key_light: SpotLight3D
var _plaster_texture: NoiseTexture2D
var _mono: Font = preload("res://assets/fonts/DejaVuSansMono.ttf")
var _jp: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.seed = 2601002
    _make_environment()
    camera = Camera3D.new()
    camera.name = "StreetRailCamera"
    camera.fov = 61.0
    camera.near = 0.035
    camera.far = 180.0
    camera.current = true
    add_child(camera)
    _set_camera(0.0, 0.0)
    stage_decor = Node3D.new()
    stage_decor.name = "KisaragiShoppingStreet"
    add_child(stage_decor)
    _street_surface()
    _shopping_blocks()
    _street_furniture()
    _horizon()
    _consolidate_geometry()
    _make_static_reflection()
    muzzle = OmniLight3D.new()
    muzzle.name = "ShotFlash"
    muzzle.light_color = Color("ffd2a0")
    muzzle.omni_range = 7.0
    muzzle.light_energy = 0.0
    camera.add_child(muzzle)
    muzzle.position = shot_origin_camera
    set_stage(0)

func _make_environment() -> void:
    environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("081323")
    sky_mat.sky_horizon_color = Color("263641")
    sky_mat.ground_bottom_color = Color("101a22")
    sky_mat.ground_horizon_color = Color("25313a")
    sky_mat.sky_curve = 0.22
    sky_mat.sun_angle_max = 2.0
    sky.sky_material = sky_mat
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("aec1d1")
    environment.ambient_light_energy = 0.16
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.04
    environment.fog_enabled = true
    environment.fog_light_color = Color("2d414c")
    environment.fog_light_energy = 0.45
    environment.fog_density = 0.0065
    environment.fog_sky_affect = 0.55
    var env_node := WorldEnvironment.new()
    env_node.environment = environment
    add_child(env_node)
    var moon := DirectionalLight3D.new()
    moon.name = "CloudedMoon"
    moon.rotation_degrees = Vector3(-42, -32, 0)
    moon.light_color = Color("a9bdd2")
    moon.light_energy = 0.67
    moon.shadow_enabled = false
    moon.directional_shadow_max_distance = 24.0
    moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    add_child(moon)
    # A camera-following soft fill makes the approaching faces readable.
    var fill := OmniLight3D.new()
    fill.name = "SoftNightFill"
    fill.light_color = Color("e1cfb5")
    fill.light_energy = 0.22
    fill.omni_range = 16.0
    fill.position = Vector3(0, 3.0, 5.0)
    add_child(fill)
    # One narrow 2D shadow map replaces expensive omnidirectional/cascade passes.
    # Its oblique street-lamp key grounds foreground enemies and parked cars.
    _key_light = SpotLight3D.new()
    _key_light.name = "ForegroundStreetKey"
    _key_light.light_color = Color("ffd6a4")
    _key_light.light_energy = 3.1
    _key_light.spot_range = 18.0
    _key_light.spot_angle = 52.0
    _key_light.spot_attenuation = 0.9
    _key_light.shadow_enabled = true
    _key_light.shadow_bias = 0.035
    _key_light.shadow_normal_bias = 0.8
    add_child(_key_light)

func mat(key: String, color := Color.WHITE, metallic := 0.0, roughness := 0.65, glow := false) -> StandardMaterial3D:
    if material_cache.has(key):
        return material_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    if glow:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 0.62
    material_cache[key] = m
    return m

func _textured(key: String, folder: String, color: Color, roughness: float, scale_uv: float) -> StandardMaterial3D:
    var m := mat(key, color, 0.13, roughness)
    var base := "res://assets/materials/" + folder + "/"
    if ResourceLoader.exists(base + "diffuse.jpg"):
        m.albedo_texture = load(base + "diffuse.jpg")
    if ResourceLoader.exists(base + "normal.jpg"):
        m.normal_enabled = true
        m.normal_texture = load(base + "normal.jpg")
        m.normal_scale = 0.65
    if ResourceLoader.exists(base + "roughness.jpg"):
        m.roughness_texture = load(base + "roughness.jpg")
        m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE * scale_uv
    return m

func _plaster(key: String, color: Color) -> StandardMaterial3D:
    var m := mat(key, color, 0.0, 0.88)
    if not _plaster_texture:
        var noise := FastNoiseLite.new()
        noise.seed = 157
        noise.frequency = 0.11
        noise.fractal_octaves = 4
        _plaster_texture = NoiseTexture2D.new()
        _plaster_texture.width = 128
        _plaster_texture.height = 128
        _plaster_texture.noise = noise
        var gradient := Gradient.new()
        gradient.set_color(0, Color("cdd0ca"))
        gradient.set_color(1, Color("f0f0e9"))
        _plaster_texture.color_ramp = gradient
    m.albedo_texture = _plaster_texture
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE * 0.32
    return m

func box(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    node.mesh = mesh
    node.position = pos
    node.scale = size
    node.material_override = material
    add_child(node)
    _static_boxes.append(node)
    return node

func pipe(pos: Vector3, radius: float, height: float, material: Material, rotation_vector := Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 1.0
    mesh.radial_segments = 10
    node.mesh = mesh
    node.position = pos
    node.rotation = rotation_vector
    node.scale = Vector3(radius, height, radius)
    node.material_override = material
    add_child(node)
    _static_pipes.append(node)
    return node

func _sign(pos: Vector3, text: String, color: Color, pixel: float, yaw := 0.0, japanese := false) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.font = _jp if japanese else _mono
    label.font_size = 64
    label.pixel_size = pixel
    label.position = pos
    label.rotation.y = yaw
    label.modulate = color
    label.outline_size = 0
    label.no_depth_test = false
    label.shaded = false
    label.double_sided = true
    add_child(label)
    return label

func _street_surface() -> void:
    var asphalt := _textured("wet_asphalt", "worn_asphalt", Color("616a70"), 0.64, 0.31)
    asphalt.metallic = 0.08
    asphalt.metallic_specular = 0.62
    asphalt.normal_scale = 0.38
    box(Vector3(0, -0.16, -34), Vector3(12, 0.3, 132), asphalt)
    var curb := mat("curb", Color("7d8584"), 0.05, 0.78)
    var pavement := _plaster("concrete", Color("868b87"))
    var seam := mat("pavement_seam", Color("363f43"), 0.05, 0.76)
    for side in [-1, 1]:
        box(Vector3(side * 5.03, 0.12, -34), Vector3(2.05, 0.25, 132), pavement)
        box(Vector3(side * 3.99, 0.09, -34), Vector3(0.2, 0.2, 132), curb)
        box(Vector3(side * 3.8, -0.008, -34), Vector3(0.22, 0.028, 132), mat("gutter", Color("242e34"), 0.5, 0.22))
        for z in range(-96, 31, 2):
            box(Vector3(side * 5.0, 0.251, z), Vector3(2.0, 0.008, 0.016), seam)
        for x in [4.58, 5.38]:
            box(Vector3(side * x, 0.251, -34), Vector3(0.012, 0.008, 132), seam)
        for z in [-4, -23, -43, -64]:
            box(Vector3(side * 3.8, 0.009, z), Vector3(0.26, 0.018, 0.72), mat("drain", Color("161f24"), 0.72, 0.3))
            for gap in range(6):
                box(Vector3(side * 3.8, 0.022, z - 0.3 + gap * 0.12), Vector3(0.2, 0.02, 0.018), curb)
    var road_paint := mat("road_paint", Color("92988b"), 0.0, 0.84)
    road_paint.albedo_texture = asphalt.albedo_texture
    road_paint.uv1_triplanar = true
    road_paint.uv1_world_triplanar = true
    road_paint.uv1_scale = asphalt.uv1_scale
    for z in range(-88, 24, 7):
        box(Vector3(0, 0.012, z), Vector3(0.11, 0.014, 2.15), road_paint)
    # Two junctions create obvious changes of scene while keeping a clear run lane.
    for z in [-11.5, -43.0]:
        for stripe in range(9):
            box(Vector3(-3.2 + stripe * 0.8, 0.016, z), Vector3(0.47, 0.015, 4.4), road_paint)
        box(Vector3(0, 0.012, z + 3.2), Vector3(7.0, 0.012, 0.2), road_paint)
    for z in [-8, -33, -60]:
        var cover := pipe(Vector3(2.3, 0.015, z), 0.43, 0.025, mat("manhole", Color("3b4549"), 0.72, 0.42))
        cover.mesh.radial_segments = 24
        for i in range(7):
            box(Vector3(2.3, 0.034, z - 0.28 + i * 0.09), Vector3(0.6, 0.012, 0.015), mat("cover_slit", Color("17212a")))
    # Irregular puddles show the street's sheen, never solid glowing floor bars.
    var wet := mat("puddle", Color("181f25"), 0.0, 0.075)
    wet.metallic_specular = 0.92
    for i in range(29):
        var side := -1.0 if i % 2 == 0 else 1.0
        var puddle := pipe(Vector3(side * (2.5 + _rng.randf() * 1.05), 0.006, 14.0 - i * 3.8), 1.0, 0.01, wet)
        puddle.scale = Vector3(0.2 + _rng.randf() * 0.5, 0.01, 0.6 + _rng.randf() * 1.4)
        puddle.rotation.y = _rng.randf_range(-0.5, 0.5)
    for i in range(52):
        var x := _rng.randf_range(-3.5, 3.5)
        if absf(x) < 2.7 and i % 3 != 0: continue
        var z := _rng.randf_range(-82, 14)
        var paper := box(Vector3(x, 0.036, z), Vector3(0.1 + _rng.randf() * 0.14, 0.012, 0.13 + _rng.randf() * 0.16), mat("discarded_paper", Color("9b9b88"), 0.0, 0.95))
        paper.rotation.y = _rng.randf() * TAU

func _shopping_blocks() -> void:
    var names := ["喫茶 あかり", "KISARAGI BOOKS", "みなと薬局", "古道具 つばめ", "BREAD & BUTTER", "さくら写真館", "MIDORI MARKET", "花屋 こもれび", "時計・修理", "NORTHSIDE RECORDS"]
    var accents := [Color("4f7169"), Color("604239"), Color("b9b7a0"), Color("293f47"), Color("8a6651"), Color("545054"), Color("6c7463"), Color("716353"), Color("4c606b"), Color("694f45")]
    for side in [-1, 1]:
        for row in range(10):
            var z := 9.0 - row * 9.2
            if (side == -1 and row == 5) or (side == 1 and row == 3):
                _side_street(side, z)
                continue
            var index: int = (row + (3 if side == 1 else 0)) % names.size()
            var height := 9.6 + float((row * 3 + (2 if side == 1 else 0)) % 4) * 2.5
            var wall_color: Color = [Color("929084"), Color("82705e"), Color("596b77"), Color("4d635b")][row % 4]
            var wall := _plaster("plaster_%d" % (row % 4), wall_color)
            var front_x: float = side * 6.55
            var hero_shop: bool = side == -1 and row == 1
            if hero_shop:
                box(Vector3(side * 10.1, 3.55 + (height - 3.55) * 0.5, z), Vector3(7.0, height - 3.55, 8.85), wall)
            else:
                box(Vector3(side * 10.1, height * 0.5, z), Vector3(7.0, height, 8.85), wall)
            box(Vector3(side * 6.47, 0.48, z), Vector3(0.2, 0.5, 8.9), mat("stone_base", Color("3d4648"), 0.0, 0.8))
            for y in [3.5, height - 0.17]:
                box(Vector3(side * 6.36, y, z), Vector3(0.4, 0.22, 9.02), mat("cornice", Color("777d73"), 0.05, 0.72))
            for edge in [-4.3, 4.3]:
                box(Vector3(side * 6.3, 1.65, z + edge), Vector3(0.36, 3.3, 0.34), mat("pilaster", Color("929386"), 0.05, 0.74))
            var shutter := _textured("shutter_%d" % index, "worn_shutter", accents[index] * 1.15, 0.74, 0.35)
            var open_store := (row % 3 == 0 or row == 1) if side == -1 else (row % 4 == 2)
            if hero_shop:
                _hero_bookshop(z)
            elif open_store:
                _shop_window(side, z, index)
            else:
                box(Vector3(front_x - side * 0.12, 1.6, z), Vector3(0.14, 2.8, 7.8), shutter)
                for ridge in range(17):
                    box(Vector3(front_x - side * 0.24, 0.46 + ridge * 0.143, z), Vector3(0.025, 0.023, 7.75), mat("shutter_ridge", Color("6c7471"), 0.5, 0.64))
                box(Vector3(front_x - side * 0.25, 0.32, z), Vector3(0.04, 0.13, 7.76), mat("shutter_bottom", Color("2c393c"), 0.5, 0.6))
                box(Vector3(front_x - side * 0.32, 1.36, z), Vector3(0.06, 0.12, 0.42), mat("door_handle", Color("b9bbaa"), 0.8, 0.24))
            var sign_back := mat("shop_sign_%d" % index, accents[index], 0.2, 0.58)
            var sign_height: float = [2.98, 3.18, 2.94][row % 3]
            var sign_width := 5.7 if row % 3 == 1 else 8.0
            box(Vector3(side * 6.16, sign_height, z), Vector3(0.18, 0.59 if row % 3 == 1 else 0.69, sign_width), sign_back)
            var is_jp: bool = index in [0, 2, 3, 5, 7, 8]
            var facade_label := _sign(Vector3(side * 6.04, sign_height + 0.025, z), names[index], Color("e2d5b5"), (0.007 if is_jp else 0.0055) if row % 3 == 1 else (0.009 if is_jp else 0.007), -side * PI / 2.0, is_jp)
            facade_label.shaded = not open_store
            # Canvas awnings, scalloped dark edge and slim warm under-light.
            if row % 2 == 0 or hero_shop:
                var awning := box(Vector3(side * 5.99, 2.73, z), Vector3(1.15, 0.1, 8.3), mat("awning_%d" % index, accents[index] * 0.62, 0.0, 0.94))
                awning.rotation.z = side * 0.11
                box(Vector3(side * 5.43, 2.63, z), Vector3(0.08, 0.22, 8.3), mat("awning_%d" % index))
                for stripe in range(13):
                    var fabric := box(Vector3(side * 5.99, 2.79, z - 3.9 + stripe * 0.64), Vector3(1.13, 0.014, 0.21), mat("awning_stripe", Color("a6a08a"), 0.0, 0.95))
                    fabric.rotation.z = side * 0.11
            if open_store or row % 4 == 0:
                box(Vector3(side * 6.07, 2.78, z), Vector3(0.08, 0.048, 5.2), mat("store_lamp", Color("ffe0a1"), 0.0, 0.5, true))
            if row % 4 == 0:
                _local_light(Vector3(side * 5.7, 2.8, z), Color("ffd29a"), 1.05, 7.0)
                _reflected_streaks(side * 3.0, z, Color("816b4b"), 3 + row % 2)
            # Upper-floor apartments add mundane life to the otherwise abandoned block.
            for floor_i in range(2, int(height / 2.7)):
                var y := floor_i * 2.65 - 0.3
                for col in range(4):
                    var window_z := z - 3.1 + col * 2.08
                    var is_lit: bool = (col + floor_i * 3 + row * 2 + (1 if side == 1 else 0)) % 6 < 2
                    _apartment_window(side, y, window_z, is_lit, floor_i + row)
            # Simple service details break the regularity of the main facade.
            pipe(Vector3(side * 6.14, height * 0.5, z - 4.03), 0.044, height - 0.6, mat("downpipe", Color("4f5653"), 0.7, 0.55))
            if row % 3 == 1:
                box(Vector3(side * 6.15, 4.12, z + 2.6), Vector3(0.6, 0.7, 1.05), mat("aircon", Color("94988d"), 0.45, 0.67))
                for vent in range(6):
                    box(Vector3(side * 5.83, 3.91 + vent * 0.072, z + 2.6), Vector3(0.022, 0.021, 0.85), mat("ac_vent", Color("313a3a"), 0.5, 0.7))
            if (row in [0, 1, 6] and side == -1) or (row in [2, 5] and side == 1):
                _blade_sign(side, z - 3.65, names[index], accents[index], is_jp)
            _roof_details(side, z, height, row)
            _shop_debris(side, z, row)

func _hero_bookshop(z: float) -> void:
    # This storefront is an actual 5m-deep open room, not a flat luminous facade.
    var interior_wall := mat("bookshop_wall", Color("b9a687"), 0.0, 0.93)
    var wood := mat("bookshop_oak", Color("786049"), 0.0, 0.87)
    box(Vector3(-9.15, 0.22, z), Vector3(5.7, 0.16, 8.4), wood)
    box(Vector3(-12.05, 1.86, z), Vector3(0.17, 3.4, 8.4), interior_wall)
    box(Vector3(-9.15, 3.47, z), Vector3(5.9, 0.17, 8.5), interior_wall)
    for end in [-4.14, 4.14]:
        box(Vector3(-9.17, 1.8, z + end), Vector3(5.72, 3.1, 0.16), interior_wall)
        for shelf in range(5):
            box(Vector3(-9.3, 0.74 + shelf * 0.44, z + end - signf(end) * 0.23), Vector3(4.35, 0.07, 0.5), wood)
            for book in range(12):
                var color: Color = [Color("626d5d"), Color("956e47"), Color("555f6a"), Color("ad9b79")][book % 4]
                box(Vector3(-11.2 + book * 0.34, 0.93 + shelf * 0.44, z + end - signf(end) * 0.21), Vector3(0.13, 0.33, 0.37), mat("book_spines_%d" % (book % 4), color, 0.0, 0.94))
    box(Vector3(-9.7, 0.85, z - 1.5), Vector3(1.4, 1.1, 2.4), wood)
    box(Vector3(-9.7, 1.43, z - 1.5), Vector3(1.61, 0.09, 2.62), mat("counter_top", Color("423c31"), 0.0, 0.75))
    box(Vector3(-9.15, 3.31, z), Vector3(2.2, 0.065, 0.32), mat("bookshop_ceiling_lamp", Color("ffd197"), 0.0, 0.45, true))
    _local_light(Vector3(-8.8, 2.8, z), Color("ffd097"), 2.6, 9.0)
    _local_light(Vector3(-10.7, 2.7, z + 2.1), Color("f6bd7e"), 1.4, 6.0)
    # A few slim door/window frames articulate the opening without closing it.
    for zz in [-3.9, -1.95, 1.95, 3.9]:
        box(Vector3(-6.46, 1.65, z + zz), Vector3(0.12, 2.8, 0.065), mat("bookshop_frame", Color("273834"), 0.4, 0.64))
    _sign(Vector3(-11.9, 2.55, z), "OLD BOOKS / RECORDS", Color("5c5141"), 0.006, PI / 2.0)

func _shop_window(side: int, z: float, index: int) -> void:
    var warm := mat("shop_interior", Color("e6bd81"), 0.0, 0.7, true)
    box(Vector3(side * 6.51, 1.58, z), Vector3(0.1, 2.57, 7.68), warm)
    box(Vector3(side * 6.29, 0.48, z), Vector3(0.25, 0.4, 7.68), mat("shop_panels", Color("293c40"), 0.0, 0.8))
    var glass := mat("shop_glass", Color(0.28, 0.43, 0.44, 0.24), 0.3, 0.18)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    for col in range(4):
        var zz := z - 2.92 + col * 1.94
        box(Vector3(side * 6.24, 1.64, zz), Vector3(0.045, 2.26, 1.77), glass)
        box(Vector3(side * 6.18, 1.66, zz - 0.94), Vector3(0.12, 2.38, 0.065), mat("window_frame", Color("243133"), 0.6, 0.4))
        # Silhouetted shelves and merchandise inside the warm glazing.
        for shelf in range(3):
            box(Vector3(side * 6.14, 0.89 + shelf * 0.48, zz), Vector3(0.08, 0.045, 1.66), mat("shelf", Color("49473b"), 0.0, 0.7))
            for item in range(3):
                box(Vector3(side * 6.11, 1.04 + shelf * 0.48, zz - 0.53 + item * 0.48), Vector3(0.09, 0.23, 0.18), mat("merch_%d" % ((item + shelf + index) % 3), [Color("c5ab75"), Color("77867b"), Color("ab7a54")][(item + shelf + index) % 3], 0.05, 0.7))
    box(Vector3(side * 6.14, 2.81, z), Vector3(0.08, 0.08, 7.8), mat("window_frame"))
    _local_light(Vector3(side * 5.75, 1.6, z), Color("ffcf90"), 1.2, 6.0)

func _apartment_window(side: int, y: float, z: float, lit: bool, variant: int) -> void:
    var frame := mat("upper_frame", Color("333d3e"), 0.3, 0.6)
    box(Vector3(side * 6.42, y, z), Vector3(0.16, 1.6, 1.3), frame)
    var color := Color("d6ac73") if lit else Color("20323d")
    if lit and variant % 3 == 0: color = Color("b6c5bf")
    box(Vector3(side * 6.31, y + 0.015, z), Vector3(0.055, 1.37, 1.08), mat("upper_glass_%d_%d" % [int(lit), int(lit and variant % 3 == 0)], color, 0.18, 0.28, lit))
    box(Vector3(side * 6.26, y, z), Vector3(0.06, 1.46, 0.035), frame)
    box(Vector3(side * 6.21, y - 0.79, z), Vector3(0.3, 0.095, 1.49), mat("window_sill", Color("888b7e"), 0.0, 0.8))
    if lit:
        material_cache["upper_glass_%d_%d" % [int(lit), int(lit and variant % 3 == 0)]].emission_energy_multiplier = 0.27
        box(Vector3(side * 6.24, y, z - 0.37), Vector3(0.045, 1.32, 0.2), mat("curtain", Color("776f5d"), 0.0, 1.0))

func _blade_sign(side: int, z: float, text: String, color: Color, japanese: bool) -> void:
    box(Vector3(side * 5.83, 4.33, z), Vector3(1.6, 2.17, 0.22), mat("blade_%d" % int(z), color, 0.2, 0.7))
    box(Vector3(side * 5.83, 4.33, z + 0.13), Vector3(1.4, 1.97, 0.026), mat("blade_face", Color("aba88f"), 0.0, 0.75, false))
    var short_text := text.split(" ")[0]
    _sign(Vector3(side * 5.83, 4.34, z + 0.154), short_text, Color("313c37"), 0.0054, 0.0, japanese)
    box(Vector3(side * 6.38, 5.4, z), Vector3(0.7, 0.065, 0.06), mat("sign_bracket", Color("252f32"), 0.7, 0.55))

func _shop_debris(side: int, z: float, row: int) -> void:
    var wood := mat("packing_wood", Color("887157"), 0.0, 0.91)
    if row % 3 == 0:
        for i in range(3):
            var crate := box(Vector3(side * (5.35 + i * 0.23), 0.5 + i * 0.19, z + 3.0), Vector3(0.5, 0.5, 0.62), wood)
            crate.rotation.y = i * 0.19
            box(Vector3(side * (5.35 + i * 0.23) - side * 0.26, 0.5 + i * 0.19, z + 3.0), Vector3(0.03, 0.04, 0.53), mat("crate_band", Color("514b3d"), 0.0, 0.85))
    if row % 3 == 1:
        # A-board menu leans naturally outside a shuttered cafe.
        var board := box(Vector3(side * 5.05, 0.92, z + 2.6), Vector3(0.7, 1.32, 0.09), mat("menu_board", Color("1e2b2b"), 0.0, 0.88))
        board.rotation.x = -0.1
        _sign(Vector3(side * 5.05, 1.09, z + 2.67), "本日休業", Color("d8d1b5"), 0.0038, 0.0, true)
        for x in [-0.33, 0.33]:
            box(Vector3(side * 5.05 + x, 0.75, z + 2.63), Vector3(0.04, 1.5, 0.075), wood)
    if row % 4 == 2:
        pipe(Vector3(side * 5.28, 0.57, z + 3.3), 0.34, 0.64, mat("terracotta", Color("755640"), 0.0, 0.88))
        for leaf in range(5):
            var frond := box(Vector3(side * 5.28 + sin(leaf * 1.9) * 0.16, 1.14, z + 3.3 + cos(leaf * 1.9) * 0.16), Vector3(0.12, 0.72, 0.09), mat("foliage", Color("3a5148"), 0.0, 0.9))
            frond.rotation.z = sin(leaf * 2.4) * 0.3

func _roof_details(side: int, z: float, height: float, row: int) -> void:
    var iron := mat("roof_metal", Color("48524f"), 0.45, 0.7)
    # Roof parapets, staggered stair housings and aerials remove a box skyline.
    box(Vector3(side * 6.49, height + 0.31, z), Vector3(0.19, 0.62, 8.88), iron)
    if row % 3 != 1:
        box(Vector3(side * 9.1, height + 1.03, z + 1.65), Vector3(2.5, 2.0, 2.8), mat("roof_house", Color("505e5b"), 0.0, 0.91))
        box(Vector3(side * 9.1, height + 2.09, z + 1.65), Vector3(2.8, 0.14, 3.06), iron)
    if row % 2 == 1:
        pipe(Vector3(side * 7.9, height + 1.7, z - 1.8), 0.038, 3.4, iron)
        for crossbar in range(3):
            box(Vector3(side * 7.9, height + 2.2 + crossbar * 0.37, z - 1.8), Vector3(1.4 - crossbar * 0.25, 0.026, 0.026), iron)
    if side == 1 and row == 2:
        # One projecting apartment balcony is a strong asymmetric mid-distance shape.
        box(Vector3(5.8, 5.2, z - 1.4), Vector3(1.7, 0.19, 4.45), mat("balcony", Color("6d786d"), 0.1, 0.78))
        for railing in range(11):
            box(Vector3(5.03, 5.7, z - 3.42 + railing * 0.4), Vector3(0.032, 1.0, 0.032), iron)
        box(Vector3(5.03, 6.2, z - 1.4), Vector3(0.055, 0.06, 4.5), iron)

func _side_street(side: int, z: float) -> void:
    # A real dark service alley interrupts the building rhythm and opens the view.
    box(Vector3(side * 14.0, -0.12, z), Vector3(20.0, 0.2, 8.85), mat("alley_asphalt", Color("202a32"), 0.05, 0.75))
    var brick := _plaster("alley_wall", Color("535e5b"))
    for dz in [-4.48, 4.48]:
        box(Vector3(side * 13.2, 4.2, z + dz), Vector3(13.4, 8.4, 0.25), brick)
        for seam in range(13):
            box(Vector3(side * 13.2, 0.3 + seam * 0.62, z + dz - signf(dz) * 0.14), Vector3(13.35, 0.02, 0.035), mat("alley_mortar", Color("343f40"), 0.0, 0.9))
    box(Vector3(side * 20.0, 1.45, z), Vector3(0.12, 2.6, 2.0), mat("alley_service_door", Color("243e42"), 0.45, 0.8))
    box(Vector3(side * 19.5, 3.15, z), Vector3(0.36, 0.11, 0.7), mat("alley_lamp", Color("86aeb7"), 0.0, 0.5, true))
    _local_light(Vector3(side * 18.8, 3.2, z), Color("6fa6b4"), 1.5, 9.0)
    box(Vector3(side * 7.3, 1.9, z - 4.05), Vector3(0.18, 0.73, 2.5), mat("alley_plate", Color("504b3d"), 0.2, 0.9))
    _sign(Vector3(side * 7.19, 1.91, z - 4.05), "駐輪禁止", Color("b9b09a"), 0.0055, -side * PI / 2.0, true)

func _sedan_cabin(material: Material) -> MeshInstance3D:
    var points := [Vector3(-0.74, 0.96, 0.47), Vector3(0.74, 0.96, 0.47), Vector3(0.74, 0.96, -1.37), Vector3(-0.74, 0.96, -1.37), Vector3(-0.63, 1.55, 0.02), Vector3(0.63, 1.55, 0.02), Vector3(0.63, 1.55, -1.08), Vector3(-0.63, 1.55, -1.08)]
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in [[0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7], [4,5,6,7]]:
        for i in [0,1,2,0,2,3]:
            tool.add_vertex(points[face[i]])
    tool.generate_normals()
    var node := MeshInstance3D.new()
    node.mesh = tool.commit()
    node.material_override = material
    add_child(node)
    return node

func _local_light(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = pos
    light.light_color = color
    light.light_energy = energy
    light.omni_range = reach
    light.omni_attenuation = 1.4
    add_child(light)
    light.set_meta("base_energy", energy)
    lamps.append(light)
    return light

func _reflected_streaks(x: float, z: float, color: Color, count: int) -> void:
    for i in range(count):
        var streak_mat := mat("reflection_%s_%d" % [color.to_html(), i % 3], color * (0.24 + (i % 3) * 0.035), 0.4, 0.15, true)
        box(Vector3(x + _rng.randf_range(-0.35, 0.35), 0.016, z + _rng.randf_range(-1.2, 1.2)), Vector3(0.025 + _rng.randf() * 0.09, 0.006, 0.6 + _rng.randf() * 2.0), streak_mat)

func _street_furniture() -> void:
    var iron := mat("street_iron", Color("293332"), 0.65, 0.52)
    for side in [-1, 1]:
        for z in [3.0, -15.0, -34.0, -53.0, -73.0]:
            var x: float = side * 4.45
            pipe(Vector3(x, 2.19, z), 0.065, 4.12, iron)
            pipe(Vector3(x, 0.35, z), 0.115, 0.38, iron)
            box(Vector3(x - side * 0.18, 4.22, z), Vector3(0.55, 0.1, 0.15), iron)
            box(Vector3(x - side * 0.37, 4.08, z), Vector3(0.25, 0.34, 0.29), mat("lantern", Color("ffe3a5"), 0.0, 0.4, true))
            box(Vector3(x - side * 0.37, 4.31, z), Vector3(0.39, 0.09, 0.43), iron)
            box(Vector3(x - side * 0.37, 3.87, z), Vector3(0.32, 0.07, 0.36), iron)
            var light := _local_light(Vector3(x - side * 0.5, 3.96, z), Color("ffd8a2"), 2.1, 11.0)
            light.shadow_enabled = false
            _reflected_streaks(side * 2.6, z, Color("96764c"), 4)
        for z in [-7.0, -25.0, -47.0, -69.0]:
            pipe(Vector3(side * 4.0, 0.55, z), 0.052, 0.8, iron)
            pipe(Vector3(side * 4.0, 0.94, z), 0.067, 0.07, mat("bollard_cap", Color("9ca18c"), 0.6, 0.4))
        for z in [-18.0, -55.0]:
            box(Vector3(side * 5.2, 0.67, z), Vector3(0.64, 0.12, 1.95), mat("bench_wood", Color("6f6753"), 0.0, 0.85))
            for zz in [-0.69, 0.69]:
                box(Vector3(side * 5.2, 0.45, z + zz), Vector3(0.48, 0.45, 0.06), iron)
            box(Vector3(side * 5.48, 0.94, z), Vector3(0.075, 0.52, 1.95), mat("bench_wood"))
    _car(Vector3(-4.08, 0.0, -2.8), 0.08, Color("626f72"), false)
    _car(Vector3(4.08, 0.0, -25.0), -0.12, Color("9b9985"), true)
    _car(Vector3(-4.08, 0.0, -51.0), PI + 0.04, Color("655953"), false)
    # Utility pole, sagging wires and ordinary crossing signal identify a city.
    for side in [-1, 1]:
        var x: float = side * 5.75
        pipe(Vector3(x, 4.65, -12.4), 0.105, 9.3, mat("utility_pole", Color("615e52"), 0.1, 0.86))
        box(Vector3(x, 8.38, -12.4), Vector3(2.6, 0.14, 0.17), iron)
        box(Vector3(side * 3.83, 4.85, -12.4), Vector3(3.0, 0.1, 0.1), iron)
        box(Vector3(side * 2.42, 4.58, -12.4), Vector3(0.57, 0.35, 0.3), mat("signal_housing", Color("222f34"), 0.45, 0.58))
        for dot in range(3):
            var lens := pipe(Vector3(side * 2.42 - 0.18 + dot * 0.18, 4.59, -12.22), 0.061, 0.033, mat("signal_%d" % dot, [Color("822e2c"), Color("776130"), Color("34594d")][dot], 0.2, 0.45, dot == 0), Vector3(PI / 2.0, 0, 0))
            lens.mesh.radial_segments = 12
    for wire in range(3):
        var previous := Vector3(-6.5, 8.5, -12.4 + wire * 0.25)
        for segment in range(1, 13):
            var t := segment / 12.0
            var next := Vector3(lerpf(-6.5, 6.5, t), 8.5 - sin(t * PI) * 0.6, -12.4 + wire * 0.25)
            _rod(previous, next, 0.012, mat("wire", Color("19242b"), 0.1, 0.9))
            previous = next
    # Authored arcade entrance; its silhouette survives the full route.
    for side in [-1, 1]:
        pipe(Vector3(side * 5.8, 3.8, -66.0), 0.16, 7.5, mat("arch_metal", Color("858674"), 0.55, 0.45))
    box(Vector3(0, 7.29, -66.0), Vector3(12.0, 1.05, 0.45), mat("arch_sign", Color("344d4e"), 0.2, 0.55))
    station_sign = _sign(Vector3(0, 7.3, -65.74), "きさらぎ商店街", Color("e9d7aa"), 0.014, 0.0, true)
    _sign(Vector3(0, 6.61, -65.74), "K I S A R A G I   A R C A D E", Color("d7c8a5"), 0.0047)

func _rod(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
    var node := pipe((a + b) * 0.5, radius, a.distance_to(b), material)
    node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _car(pos: Vector3, yaw: float, color: Color, taxi: bool) -> void:
    # A deliberately mundane compact sedan assembled as one coherent silhouette.
    var root := Node3D.new()
    root.name = "AbandonedSedan"
    root.position = pos
    root.rotation.y = yaw
    add_child(root)
    var paint := mat("car_%s" % color.to_html(), color, 0.6, 0.29)
    var steel := mat("car_trim", Color("8b9796"), 0.85, 0.2)
    var glass := mat("car_glass", Color("233943"), 0.68, 0.14)
    var tire := mat("tire", Color("172026"), 0.03, 0.94)
    var parts: Array[MeshInstance3D] = []
    parts.append(box(Vector3(0, 0.61, 0), Vector3(1.68, 0.59, 3.95), paint))
    parts.append(box(Vector3(0, 0.95, 0.55), Vector3(1.55, 0.11, 1.5), paint))
    var cabin := _sedan_cabin(glass)
    cabin.reparent(root, false)
    parts.append(box(Vector3(0, 1.58, -0.52), Vector3(1.3, 0.07, 1.1), paint))
    for side in [-1, 1]:
        for z in [-1.32, 1.28]:
            var wheel := pipe(Vector3(side * 0.83, 0.42, z), 0.37, 0.19, tire, Vector3(0, 0, PI / 2.0))
            wheel.reparent(root, false)
            var hub := pipe(Vector3(side * 0.94, 0.42, z), 0.21, 0.018, steel, Vector3(0, 0, PI / 2.0))
            hub.reparent(root, false)
        parts.append(box(Vector3(side * 0.75, 1.24, -0.36), Vector3(0.065, 0.72, 0.08), paint))
        parts.append(box(Vector3(side * 0.78, 1.1, -0.24), Vector3(0.06, 0.06, 1.7), steel))
        parts.append(box(Vector3(side * 0.78, 0.94, -0.45), Vector3(0.04, 0.047, 0.18), steel))
        parts.append(box(Vector3(side * 0.92, 1.15, 0.42), Vector3(0.25, 0.16, 0.25), paint))
        parts.append(box(Vector3(side * 0.52, 0.72, 2.01), Vector3(0.45, 0.21, 0.06), mat("headlamp", Color("d4d9c5"), 0.2, 0.18)))
        parts.append(box(Vector3(side * 0.55, 0.72, -2.01), Vector3(0.4, 0.17, 0.055), mat("tail_lens", Color("782e2b"), 0.1, 0.28)))
    parts.append(box(Vector3(0, 0.42, 2.0), Vector3(1.58, 0.15, 0.11), steel))
    parts.append(box(Vector3(0, 0.44, -2.0), Vector3(1.58, 0.14, 0.1), steel))
    parts.append(box(Vector3(0, 0.68, 2.025), Vector3(0.53, 0.17, 0.03), mat("numberplate", Color("b9bdb0"), 0.0, 0.7)))
    if taxi:
        parts.append(box(Vector3(0, 1.79, -0.4), Vector3(0.45, 0.16, 0.22), mat("taxi_roof", Color("d6c793"), 0.0, 0.65)))
    for part in parts:
        part.reparent(root, false)

func _horizon() -> void:
    for i in range(13):
        var x := -36.0 + i * 6.1
        var height := 12.0 + float((i * 7) % 5) * 6.0
        var z := -103.0 - float((i * 3) % 4) * 5.0
        box(Vector3(x, height * 0.5, z), Vector3(5.4, height, 9.5), mat("skyline_%d" % (i % 3), [Color("303f49"), Color("34414a"), Color("273843")][i % 3], 0.1, 0.83))
        for floor_i in range(2, int(height / 3.0)):
            for col in range(3):
                if (floor_i + col + i * 2) % 4 != 0: continue
                box(Vector3(x - 1.7 + col * 1.7, floor_i * 3.0, z + 4.78), Vector3(0.65, 1.2, 0.035), mat("skyline_window", Color("928c6e"), 0.0, 0.8, true))
    box(Vector3(0, 3.0, -98.0), Vector3(20, 6.0, 4.0), mat("distant_station", Color("455159"), 0.1, 0.79))
    box(Vector3(0, 5.25, -95.95), Vector3(15.0, 0.83, 0.14), mat("station_face", Color("222f39"), 0.1, 0.65))
    _sign(Vector3(0, 5.25, -95.8), "東口  /  EAST EXIT", Color("b4c5c2"), 0.012, 0.0, true)
    end_door = Node3D.new()
    add_child(end_door)
    # A distant lit passage remains open rather than ending in a mechanical wall.
    for x in [-4.3, 4.3]:
        box(Vector3(x, 2.55, -95.8), Vector3(0.23, 4.7, 0.25), mat("station_column", Color("8b9891"), 0.3, 0.65))
    box(Vector3(0, 4.72, -95.6), Vector3(8.2, 0.1, 0.16), mat("exit_light", Color("b8cac1"), 0.0, 0.6, true))
    _local_light(Vector3(0, 4.2, -91), Color("b4d3cf"), 2.0, 15.0)

func _consolidate_geometry() -> void:
    _batch_geometry(_static_boxes, false)
    _batch_geometry(_static_pipes, true)
    _static_boxes.clear()
    _static_pipes.clear()
    for child in get_children():
        if child is Label3D:
            child.visibility_range_end = 100.0
        elif child is GeometryInstance3D and not child.is_queued_for_deletion():
            var center_z: float = child.global_position.z + child.get_aabb().get_center().z if child is MultiMeshInstance3D else child.global_position.z
            child.visibility_range_end = 155.0 if center_z < -90.0 else (86.0 if child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON else 48.0)
            child.visibility_range_end_margin = 4.0

func _batch_geometry(nodes: Array[MeshInstance3D], cylinders: bool) -> void:
    var groups := {}
    var signatures := {}
    for node in nodes:
        if not is_instance_valid(node): continue
        var world_transform := node.global_transform
        var material := node.material_override as StandardMaterial3D
        var id := material.get_instance_id()
        if not signatures.has(id):
            var casts := false
            for material_name in material_cache:
                if material_cache[material_name] == material:
                    casts = material_name.begins_with("plaster_") or material_name.begins_with("car_") or material_name.begins_with("awning_") or material_name in ["pilaster", "roof_house", "arch_sign", "arch_metal", "station_column"]
                    break
            var vertex_tint := not material.emission_enabled and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
            var signature := str(id)
            var batch_material := material
            if vertex_tint:
                var albedo_id := material.albedo_texture.get_instance_id() if material.albedo_texture else 0
                var normal_id := material.normal_texture.get_instance_id() if material.normal_texture else 0
                var rough_id := material.roughness_texture.get_instance_id() if material.roughness_texture else 0
                signature = "%d_%d_%d_%.3f_%.3f_%.3f_%s_%s_%s_%s" % [albedo_id, normal_id, rough_id, material.metallic, material.roughness, material.normal_scale, str(material.uv1_scale), str(material.uv1_triplanar), str(material.uv1_world_triplanar), str(casts)]
                batch_material = material.duplicate()
                batch_material.albedo_color = Color.WHITE
                batch_material.vertex_color_use_as_albedo = true
            signatures[id] = {"signature":signature, "material":batch_material, "tint":vertex_tint, "casts":casts}
        var info: Dictionary = signatures[id]
        var segments: int = (node.mesh as CylinderMesh).radial_segments if cylinders else 0
        var key := "%s_%d_%d" % [info.signature, int(floor(world_transform.origin.z / 24.0)), segments]
        if not groups.has(key):
            groups[key] = {"material":info.material, "transforms":[], "colors":[], "segments":segments, "bounds":world_transform * node.get_aabb(), "tint":info.tint, "casts":info.casts}
        groups[key].transforms.append(world_transform)
        groups[key].colors.append(material.albedo_color)
        groups[key].bounds = groups[key].bounds.merge(world_transform * node.get_aabb())
        node.queue_free()
    for key in groups:
        var group: Dictionary = groups[key]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.use_colors = group.tint
        var mesh: PrimitiveMesh
        if cylinders:
            var cylinder := CylinderMesh.new()
            cylinder.top_radius = 1.0
            cylinder.bottom_radius = 1.0
            cylinder.height = 1.0
            cylinder.radial_segments = group.segments
            mesh = cylinder
        else:
            var cube := BoxMesh.new()
            cube.size = Vector3.ONE
            mesh = cube
        mesh.material = group.material
        multi.mesh = mesh
        multi.instance_count = group.transforms.size()
        var bounds: AABB = group.bounds
        var center := bounds.get_center()
        for i in range(multi.instance_count):
            var transform: Transform3D = group.transforms[i]
            transform.origin -= center
            multi.set_instance_transform(i, transform)
            if group.tint: multi.set_instance_color(i, group.colors[i])
        var instances := MultiMeshInstance3D.new()
        instances.multimesh = multi
        instances.name = "StreetBatch_" + str(groups.size()) + "_" + str(center.z)
        instances.position = center
        instances.custom_aabb = AABB(bounds.position - center, bounds.size)
        instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group.casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(instances)
        instances.visibility_range_end = 155.0 if center.z < -90.0 else (86.0 if group.casts else 48.0)
        instances.visibility_range_end_margin = 4.0

func _make_static_reflection() -> void:
    # Compatibility supports ReflectionProbe (Godot4.3+). Bake one six-face
    # cubemap once; it is never moved/updated along the player rail.
    # Static world is layer2, excluding later-created enemies and viewmodel.
    _mark_static_reflection_layer(self)
    var reflection := ReflectionProbe.new()
    reflection.name = "BakedWetStreetReflection"
    reflection.position = Vector3(0, 2.4, -16.0)
    reflection.size = Vector3(17.0, 10.0, 68.0)
    reflection.update_mode = ReflectionProbe.UPDATE_ONCE
    reflection.box_projection = true
    reflection.enable_shadows = false
    reflection.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
    reflection.max_distance = 42.0
    reflection.intensity = 0.72
    reflection.cull_mask = 2
    reflection.reflection_mask = 1
    add_child(reflection)

func _mark_static_reflection_layer(parent: Node) -> void:
    for child in parent.get_children():
        if child is VisualInstance3D: child.set_layer_mask_value(2, true)
        if child.get_child_count() > 0: _mark_static_reflection_layer(child)

func _route_position(progress: float) -> Vector3:
    var t := clampf(progress, 0.0, 1.0)
    # Gentle right bend at the second half, visible in the passing curb/parallax.
    var bend := smoothstep(0.3, 0.85, t) * 1.28
    return Vector3(bend, camera_height, lerpf(7.0, -40.0, t))

func _set_camera(progress: float, bob: float) -> void:
    var origin := _route_position(progress)
    var ahead := _route_position(minf(1.0, progress + 0.19))
    if progress > 0.82:
        ahead = Vector3(1.28, camera_height - 0.17, origin.z - 12.0)
    else:
        ahead.y = camera_height - 0.17
    camera.position = origin + Vector3(0, bob, 0)
    camera.look_at(ahead)

func _process(delta: float) -> void:
    # Main owns route_progress. Pausing freezes camera, lights and fragments.
    if not running and not intro_pan:
        return
    time += delta
    var motion := 0.0 if reduced_motion else 1.0
    _set_camera(route_progress, sin(time * 6.1) * 0.012 * motion if running else 0.0)
    if intro_pan and not reduced_motion:
        camera.position.x += sin(time * 0.13) * 0.18
        camera.rotation.y += sin(time * 0.1) * 0.011
    if screen_shake > 0:
        camera.position += Vector3(sin(time * 92), cos(time * 105), 0) * screen_shake * motion
        screen_shake = maxf(0.0, screen_shake - delta * 0.8)
    var fill := get_node_or_null("SoftNightFill") as OmniLight3D
    if fill:
        fill.position = camera.position + Vector3(0, 1.3, 1.4)
    if _key_light:
        _key_light.position = camera.position + Vector3(-3.5, 2.9, -0.8)
        _key_light.look_at(camera.position + Vector3(0.0, -1.25, -8.0))
    _update_local_lights(delta)
    if muzzle:
        muzzle.position = shot_origin_camera
        muzzle.light_energy = maxf(0.0, muzzle.light_energy - delta * 48.0)
    for i in range(fragments.size() - 1, -1, -1):
        var fragment: Dictionary = fragments[i]
        fragment.life -= delta
        fragment.node.position += fragment.velocity * delta
        fragment.velocity.y -= delta * 7.0
        fragment.node.rotate_x(delta * 4.0)
        fragment.node.rotate_z(delta * 5.0)
        fragment.node.scale = Vector3.ONE * clampf(fragment.life * 1.8, 0, 1)
        if fragment.life <= 0:
            fragment.node.queue_free()
            fragments.remove_at(i)

func _update_local_lights(delta: float, snap := false) -> void:
    if not camera: return
    var candidates: Array[Dictionary] = []
    for light in lamps:
        var distance := camera.position.distance_to(light.position)
        var ahead_distance: float = camera.position.z - light.position.z
        if ahead_distance > -6.0 and ahead_distance < 24.0:
            candidates.append({"light":light, "distance":distance})
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
    var active: Array[OmniLight3D] = []
    var cap := 3 if OS.has_feature("web") else 5
    for i in range(mini(cap, candidates.size())): active.append(candidates[i].light)
    for light in lamps:
        var selected := active.has(light)
        var distance := camera.position.distance_to(light.position)
        var falloff := pow(clampf(1.0 - distance / 29.0, 0.0, 1.0), 0.6)
        var target_energy: float = float(light.get_meta("base_energy", 1.0)) * falloff if selected else 0.0
        light.light_energy = target_energy if snap else lerpf(light.light_energy, target_energy, 1.0 - exp(-delta * 3.0))
        # Emissive fixtures remain, while at most five real local lights shade a frame.
        light.visible = selected and light.light_energy > 0.015

func fire(target_pos: Vector3, strength := 1.0) -> void:
    if not is_instance_valid(camera): return
    muzzle.light_energy = 4.0 * strength
    screen_shake = maxf(screen_shake, 0.019 * strength)
    var start := camera.to_global(shot_origin_camera)
    var line := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.005 * strength
    mesh.bottom_radius = 0.013 * strength
    mesh.height = start.distance_to(target_pos)
    mesh.radial_segments = 5
    line.mesh = mesh
    line.material_override = mat("shot_tracer", Color("ffcf8d"), 0, 0.5, true)
    add_child(line)
    line.position = (start + target_pos) * 0.5
    line.quaternion = Quaternion(Vector3.UP, (target_pos - start).normalized())
    get_tree().create_timer(0.045).timeout.connect(line.queue_free)

func burst(pos: Vector3, color: Color, count: int) -> void:
    var shard := BoxMesh.new()
    shard.size = Vector3(0.032, 0.085, 0.023)
    var shared_mat := mat("impact_" + color.to_html(), color, 0, 0.5, true)
    for i in range(mini(count, 18)):
        var fragment := MeshInstance3D.new()
        fragment.mesh = shard
        fragment.material_override = shared_mat
        fragment.position = pos
        add_child(fragment)
        var angle := i * 2.399963
        var velocity := Vector3(cos(angle) * (0.6 + i % 3), 0.8 + (i % 4) * 0.5, sin(angle) * 1.3)
        fragments.append({"node":fragment, "velocity":velocity, "life":0.45 + (i % 3) * 0.11})

func set_stage(index: int) -> void:
    stage = index
    route_progress = 0.0
    camera_height = 1.7
    screen_shake = 0.0
    time = 0.0
    for fragment in fragments:
        if is_instance_valid(fragment.node): fragment.node.queue_free()
    fragments.clear()
    if camera: _set_camera(0.0, 0.0)
    if _key_light and camera:
        _key_light.position = camera.position + Vector3(-3.5, 2.9, -0.8)
        _key_light.look_at(camera.position + Vector3(0.0, -1.25, -8.0))
    _update_local_lights(0.0, true)
    if muzzle: muzzle.light_energy = 0.0

# Legacy helper signatures remain available to the main orchestrator.
func lamp(pos: Vector3, color: Color) -> void:
    _local_light(pos, color, 1.5, 8.0)
func dbox(pos: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    return box(pos, dimensions, material)
func dpipe(pos: Vector3, radius: float, height: float, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
    return pipe(pos, radius, height, material, rot)
func dlight(pos: Vector3, color: Color, energy: float, reach: float) -> void:
    _local_light(pos, color, energy, reach)
func dsign(pos: Vector3, message: String, color := Color("f2b461"), pixel := 0.01) -> void:
    _sign(pos, message, color, pixel)
