extends Node3D

const Enemy = preload("res://scripts/enemy.gd")
const World = preload("res://scripts/world.gd")
const Hud = preload("res://scripts/hud.gd")
const Romaji = preload("res://scripts/romaji.gd")
const WebInput = preload("res://scripts/web_input.gd")
const WORDS := [
{"text":"残響","kana":"ざんきょう","en":"echo"}, {"text":"空白","kana":"くうはく","en":"hollow"},
{"text":"無言","kana":"むごん","en":"unheard"}, {"text":"断線","kana":"だんせん","en":"signal"},
{"text":"消失","kana":"しょうしつ","en":"vanish"}, {"text":"残留","kana":"ざんりゅう","en":"remnant"},
{"text":"記憶","kana":"きおく","en":"memory"}, {"text":"静寂","kana":"せいじゃく","en":"silence"},
{"text":"電波","kana":"でんぱ","en":"static"}, {"text":"暗闇","kana":"くらやみ","en":"darkness"},
{"text":"警報","kana":"けいほう","en":"warning"}, {"text":"反射","kana":"はんしゃ","en":"reflect"},
{"text":"鉄塔","kana":"てっとう","en":"tower"}, {"text":"深海","kana":"しんかい","en":"abyss"},
{"text":"夜明け","kana":"よあけ","en":"daybreak"}, {"text":"回線","kana":"かいせん","en":"channel"},
{"text":"遮断","kana":"しゃだん","en":"sever"}, {"text":"復旧","kana":"ふっきゅう","en":"restore"},
{"text":"共鳴","kana":"きょうめい","en":"resonate"}, {"text":"終点","kana":"しゅうてん","en":"terminal"},
{"text":"非常回線","kana":"ひじょうかいせん","en":"deadchannel"}, {"text":"残留思念","kana":"ざんりゅうしねん","en":"afterimage"},
{"text":"逆位相","kana":"ぎゃくいそう","en":"interference"}, {"text":"共鳴遮断","kana":"きょうめいしゃだん","en":"disconnect"},
{"text":"終端抵抗","kana":"しゅうたんていこう","en":"termination"}, {"text":"信号消失","kana":"しんごうしょうしつ","en":"lostcarrier"},
{"text":"故障検出","kana":"こしょうけんしゅつ","en":"corruption"}, {"text":"緊急復旧","kana":"きんきゅうふっきゅう","en":"restoration"}
]
const BASE_WORD_COUNT := 20
const CUTS := [
{"text":"糸","kana":"いと","en":"wire"}, {"text":"霧","kana":"きり","en":"arc"},
{"text":"針","kana":"はり","en":"pin"}, {"text":"音","kana":"おと","en":"tap"},
{"text":"影","kana":"かげ","en":"node"}, {"text":"錆","kana":"さび","en":"seal"}]
const STAGES := [
{"name":"黒雨商店街","en":"KUROAME SHOPPING STREET","subtitle":"避難信号まで、あと75秒。","total":24,"interval":2.8}]
# Authored tension curve: first contact, shop exits, short breath, crossing, final crowd.
const ENCOUNTERS := [1.4, 6.0, 10.0, 12.8, 15.6, 18.4, 21.5, 28.0, 30.3, 32.6, 35.0, 37.4, 40.0, 42.5, 45.0, 52.0, 54.2, 56.4, 58.6, 60.8, 63.0, 65.2, 67.4, 69.6]
const SLICE_SECONDS := 75.0

var world: RelayWorld
var hud: Control
var enemies: Array[RelayEnemy] = []
var selected: RelayEnemy
var state := "title"
var previous_state := "playing"
var settings_origin := "title"
var stage := 0
var difficulty := 1
var language := 0
var reduced_motion := false
var high_contrast := false
var volume := 0.72
var hp := 6
var max_hp := 6
var score := 0
var best_score := 0
var best_scores: Dictionary = {}
var combo := 0
var best_combo := 0
var total_keys := 0
var correct_keys := 0
var mistakes := 0
var kills := 0
var cuts := 0
var backfeeds := 0
var elapsed := 0.0
var stage_time := 0.0
var spawn_clock := 0.0
var spawned := 0
var stage_kills := 0
var intermission_time := 0.0
var notice := ""
var notice_sub := ""
var notice_time := 0.0
var notice_color := Color("ffad42")
var damage_flash := 0.0
var key_flash := 0.0
var key_error := 0.0
var kill_flash := 0.0
var boss_phase := 0
var boss_defeated := false
var menu_index := 0
var menu_hover := -1
var audio: Dictionary = {}
var ambience: AudioStreamPlayer
var typing_index := 0
var rng := RandomNumberGenerator.new()
var checkpoint: Dictionary = {}
var start_time := 0.0
var last_input := ""
var demo_mode := false
var auto_timer := 0.0
var screenshot_time := -1.0
var optional_n_time := 0.0
var record_remaining := 0.0
var record_clock := 0.0
var record_frame := 0
var capture_dir := ""
var route_progress := 0.0
var route_time := 0.0
var route_holding := false
var chain_timer := 0.0
var last_award := 0
var kill_feed: Array[Dictionary] = []
var chain_clear_flash := 0.0
var chain_count := 0
var weapon: Node3D
var weapon_muzzle: Node3D
var weapon_recoil := 0.0
var muzzle_sprite: MeshInstance3D
var crowd: Array[RelayEnemy] = []
var crowd_origin: Array[Vector3] = []
var native_quality := not OS.has_feature("web")
var render_profile := "NATIVE COMPATIBILITY"
var software_renderer := false
var foley_clock := 0.0
var breath_clock := 0.0
var demo_key_interval := 0.25
var qa_encounter := false
var spawn_serial := 0
const WEAPON_HOME := Vector3(0.23,-0.19,-0.18)
const WEAPON_ANGLE := Vector3(-0.035,0.22,0.0)

func _ready() -> void:
    rng.randomize()
    _load_settings()
    _configure_render_profile()
    world = World.new()
    add_child(world)
    world.reduced_motion = reduced_motion
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    hud = Hud.new()
    hud.game = self
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _load_audio()
    _make_weapon()
    _make_crowd()
    get_tree().root.focus_exited.connect(_focus_lost)
    if OS.has_feature("web"):
        var web_input := WebInput.new()
        web_input.game = self
        add_child(web_input)
    var qa_stage := -1
    for argument in OS.get_cmdline_user_args():
        if argument == "--qa-encounter":
            qa_encounter = true
            qa_stage = 0
        if argument.begins_with("--demo-cps="):
            demo_key_interval = 1.0 / clampf(float(argument.trim_prefix("--demo-cps=")),1,20)
        if argument == "--autoplay":
            demo_mode = true
            difficulty = 0
        if argument.begins_with("--qa-stage="):
            qa_stage = 0
        if argument.begins_with("--capture-dir="):
            capture_dir = argument.trim_prefix("--capture-dir=")
        if argument.begins_with("--record="):
            record_remaining = clampf(float(argument.split("=")[1]),0,20)
        if argument.begins_with("--screenshot="):
            screenshot_time = float(argument.split("=")[1])
    if demo_mode or qa_stage >= 0:
        start_run()
        if qa_stage >= 0: stage = qa_stage
        begin_stage()
        if qa_encounter:
            stage_time = 31.0
            route_time = 31.0
            route_progress = stage_time/SLICE_SECONDS
            world.route_progress = route_progress
            world.running = true
            world.intro_pan = false
            world._process(0)
            spawned = 10
            spawn_clock = 999
            for i in range(3):
                var foe := _spawn("hush" if i < 2 else "skip",i-1,WORDS[i*3])
                foe.position = world.camera.position+Vector3((i-1)*1.9,-world.camera.position.y,-5.0-i*1.5)
                foe.camera = world.camera
            notice_time = 0
    print("BLACK RELAY ready. Godot ",Engine.get_version_info().string)

func _load_audio() -> void:
    if DisplayServer.get_name() == "headless":
        return
    for sound in ["zombie_breath","footstep_wet","shot","impact_body","impact_metal","typing_01","typing_02","typing_03","typing_04","confirm","cut","purge","kill","attack","hurt","boss","transition","victory","error","defeat"]:
        var ext := ".mp3" if sound == "shot" else (".ogg" if sound.begins_with("impact_") else ".wav")
        var path: String = "res://assets/audio/" + sound + ext
        if ResourceLoader.exists(path):
            audio[sound] = load(path)
    if ResourceLoader.exists("res://assets/audio/ambience.wav"):
        ambience = AudioStreamPlayer.new()
        var stream: AudioStreamWAV = load("res://assets/audio/ambience.wav")
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = int(stream.get_length()*stream.mix_rate)
        ambience.stream = stream
        ambience.volume_db = -6
        add_child(ambience)
        ambience.play()
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.0001)))
    AudioServer.set_bus_mute(0,volume < 0.001)

func play_sound(sound: String, gain := 0.0) -> void:
    if not audio.has(sound) or volume < 0.001:
        return
    var player := AudioStreamPlayer.new()
    player.stream = audio[sound]
    player.volume_db = gain
    player.pitch_scale = rng.randf_range(0.96,1.04) if sound.begins_with("typing") else 1.0
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _process(delta: float) -> void:
    world.running = state in ["playing","ending"]
    if record_remaining > 0 and DisplayServer.get_name() != "headless":
        record_remaining -= delta
        record_clock -= delta
        if record_clock <= 0:
            record_clock = 0.125
            _save_record_frame()
    if state == "paused" or (state == "settings" and settings_origin == "paused"):
        hud.queue_redraw()
        return
    chain_timer = maxf(0,chain_timer-delta)
    chain_clear_flash = maxf(0,chain_clear_flash-delta*1.7)
    for entry in kill_feed: entry.time -= delta
    kill_feed = kill_feed.filter(func(entry): return entry.time > 0)
    if chain_timer <= 0: chain_count = 0
    breath_clock = maxf(0,breath_clock-delta)
    foley_clock = maxf(0,foley_clock-delta)
    _update_weapon(delta)
    _update_crowd(delta)
    notice_time = maxf(0,notice_time-delta)
    damage_flash = maxf(0,damage_flash-delta*1.7)
    key_flash = maxf(0,key_flash-delta*8)
    key_error = maxf(0,key_error-delta*5)
    kill_flash = maxf(0,kill_flash-delta*3)
    world.intro_pan = state in ["title","settings"]
    if state == "playing":
        elapsed += delta
        stage_time += delta
        route_holding = not _can_advance_route()
        if not route_holding: route_time += delta
        route_progress = clampf(route_time/SLICE_SECONDS,0,1)
        world.route_progress = route_progress
        spawn_clock -= delta
        _update_spawns()
        for enemy in enemies.duplicate():
            if not is_instance_valid(enemy) or enemy.dead:
                continue
            var old_phase: String = enemy.phase
            if enemy.tick(delta,enemy == selected):
                hurt(enemy)
                if state != "playing":
                    break
            if old_phase != "attack" and enemy.phase == "attack":
                if breath_clock <= 0:
                    play_sound("zombie_breath",-6)
                    breath_clock = 2.5
        if not is_instance_valid(selected) or selected.dead:
            _select_urgent()
        if enemies.is_empty() and spawned >= ENCOUNTERS.size() and route_time >= SLICE_SECONDS:
            state = "ending"
            intermission_time = 0
            toast("避難路、確保", "STREET CLEARED",Color("eaca8b"),2.2)
            play_sound("victory",-6)
        if is_instance_valid(selected) and selected.urgency() < 8 and foley_clock <= 0:
            play_sound("footstep_wet",-8)
            foley_clock = 1.2
        if demo_mode:
            _autoplay(delta)
    elif state == "intermission":
        intermission_time += delta
        if demo_mode and intermission_time > 1.5:
            begin_stage()
    elif state == "ending":
        intermission_time += delta
        if intermission_time > 2.5:
            finish_run(true)
    if screenshot_time > 0:
        screenshot_time -= delta
        if screenshot_time <= 0:
            _save_capture()
    hud.queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        menu_hover = hud.button_at(event.position)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var button: int = hud.button_at(event.position)
        if button >= 0:
            activate_menu(button)
        elif state == "playing":
            _select_at(event.position)
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if "--qa-input-log" in OS.get_cmdline_user_args(): print("NATIVE KEY code=",event.keycode," unicode=",event.unicode," state=",state)
    if event.keycode == KEY_F12:
        _save_capture()
        return
    if event.keycode == KEY_F11:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
        get_viewport().set_input_as_handled()
        return
    if event.keycode == KEY_ESCAPE:
        if state == "playing":
            previous_state = state
            state = "paused"
            menu_index = 0
        elif state == "paused":
            state = previous_state
        elif state == "settings":
            state = settings_origin
            _save_settings()
        elif state == "intermission":
            previous_state = state
            state = "paused"
        get_viewport().set_input_as_handled()
        return
    if state == "playing":
        if event.keycode == KEY_TAB:
            cycle_target()
            get_viewport().set_input_as_handled()
            return
        if event.keycode == KEY_BACKSPACE:
            reset_target_input()
            return
        if event.unicode > 0:
            var letter := String.chr(event.unicode).to_lower()
            if "abcdefghijklmnopqrstuvwxyz'-".contains(letter) and letter.length() == 1:
                type_letter(letter)
    elif state == "intermission" and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
        begin_stage()
    elif state in ["victory","defeat"] and event.keycode == KEY_R:
        start_run()
    elif state in ["title","paused","settings","victory","defeat"]:
        var count: int = hud.menu_actions().size()
        if event.keycode in [KEY_DOWN,KEY_TAB]:
            menu_index = (menu_index+1)%maxi(count,1)
        elif event.keycode == KEY_UP:
            menu_index = posmod(menu_index-1,maxi(count,1))
        elif event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
            activate_menu(menu_index)
        elif event.keycode in [KEY_LEFT,KEY_RIGHT] and state == "settings":
            activate_menu(menu_index)
        get_viewport().set_input_as_handled()

func activate_menu(index: int) -> void:
    var actions: Array = hud.menu_actions()
    if index < 0 or index >= actions.size():
        return
    play_sound("confirm",-6)
    var action: String = actions[index]
    if state == "settings" and settings_origin == "paused" and action in ["difficulty","language"]:
        play_sound("error")
        return
    match action:
        "start", "retry": start_run()
        "begin": begin_stage()
        "resume": state = previous_state
        "settings":
            settings_origin = state
            state = "settings"
            menu_index = 0
        "back":
            state = settings_origin
            menu_index = 0
            _save_settings()
        "title":
            _clear_enemies()
            state = "title"
            menu_index = 0
        "checkpoint": retry_checkpoint()
        "difficulty":
            difficulty = (difficulty+1)%3
            _refresh_record()
        "language":
            language = (language+1)%2
            _refresh_record()
        "motion":
            reduced_motion = not reduced_motion
            world.reduced_motion = reduced_motion
        "contrast": high_contrast = not high_contrast
        "volume":
            volume = float((roundi(volume*4)+1)%5)/4.0
            AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.0001)))
            AudioServer.set_bus_mute(0,volume < 0.001)
    menu_hover = -1

func reset_target_input() -> void:
    if state != "playing" or not is_instance_valid(selected) or selected.dead:
        return
    selected.active_word = ""
    selected.cut.clear()
    selected.purge.clear()
    toast("入力をリセット", "PROGRESS CLEARED",Color("8bc6c9"),1.0)

# The browser bridge uses the same actions and matcher as physical keyboards.
# Only committed ASCII is accepted: Japanese IME text is never transliterated
# into a free correct word, and input outside a running encounter is discarded.
func web_action(action: String, value := "") -> void:
    match action:
        "text":
            if state != "playing" or value.is_empty() or value.length() > 64: return
            var letters := value.to_lower()
            for letter in letters:
                if not "abcdefghijklmnopqrstuvwxyz'-".contains(letter): return
            for letter in letters:
                if state != "playing": break
                type_letter(letter)
        "begin":
            if state == "intermission": begin_stage()
        "menu":
            if value.is_valid_int(): activate_menu(int(value))
        "pause", "focus_lost":
            if state == "playing":
                previous_state = state
                state = "paused"
                menu_index = 0
        "cycle":
            if state == "playing": cycle_target()
        "reset": reset_target_input()

func web_snapshot() -> Dictionary:
    var actions: Array[Dictionary] = []
    var labels: Array[String] = hud.menu_labels()
    for i in range(labels.size()):
        actions.append({"label": labels[i], "enabled": not (state == "settings" and settings_origin == "paused" and i < 2)})
    var snapshot := {"state": state, "previous_state": previous_state, "actions": actions,
        "target": "", "typed": "", "remaining": "", "cut": "", "hp": hp, "score": score}
    if state in ["playing", "paused"] and is_instance_valid(selected) and not selected.dead:
        snapshot.target = selected.purge_text
        snapshot.typed = selected.purge.typed
        snapshot.remaining = selected.purge.hint().substr(selected.purge.typed.length())
        if selected.can_cut():
            snapshot.cut = "CUT: " + selected.cut.typed + " | " + selected.cut.hint().substr(selected.cut.typed.length())
    return snapshot

func start_run() -> void:
    _refresh_record()
    _clear_enemies()
    stage = 0
    max_hp = [8,6,4][difficulty]
    hp = max_hp
    score = 0
    combo = 0
    best_combo = 0
    kills = 0
    cuts = 0
    backfeeds = 0
    correct_keys = 0
    total_keys = 0
    mistakes = 0
    elapsed = 0
    boss_phase = 0
    boss_defeated = false
    route_progress = 0
    route_time = 0
    route_holding = false
    chain_timer = 0
    chain_count = 0
    kill_feed.clear()
    last_award = 0
    menu_index = 0
    world.set_stage(stage)
    state = "intermission"
    intermission_time = 0
    checkpoint = _snapshot()
    _save_settings()

func begin_stage() -> void:
    stage = 0
    state = "playing"
    stage_time = 0
    stage_kills = 0
    spawned = 0
    spawn_clock = 0
    route_progress = 0
    route_time = 0
    route_holding = false
    chain_timer = 0
    notice_time = 0
    world.set_stage(0)
    checkpoint = _snapshot()
    play_sound("transition",-7)
    toast("一語、一撃。", "TYPE THE WORD · CLEAR THE STREET",Color("eaca8b"),3.5)

func _snapshot() -> Dictionary:
    return {"stage":stage,"score":score,"kills":kills,"cuts":cuts,"backfeeds":backfeeds,"correct_keys":correct_keys,"total_keys":total_keys,"mistakes":mistakes,"elapsed":elapsed,"best_combo":best_combo}

func retry_checkpoint() -> void:
    _clear_enemies()
    for key in checkpoint:
        set(key,checkpoint[key])
    max_hp = [8,6,4][difficulty]
    hp = max_hp
    combo = 0
    boss_phase = 0
    boss_defeated = false
    state = "intermission"
    intermission_time = 0
    world.set_stage(stage)

func end_stage() -> void:
    state = "ending"
    intermission_time = 0

func _update_spawns() -> void:
    if spawn_clock > 0 or spawned >= ENCOUNTERS.size(): return
    if kills == 0 and spawned > 0: return
    if route_time < ENCOUNTERS[spawned]: return
    var cap := 1 if spawned == 0 else (3 if spawned < 7 else 4)
    if enemies.size() >= cap: return
    var type := "skip" if spawned in [5,10,13,18,21,23] else "hush"
    var path_lane: int = [-1,1,0,1,-1,0][spawned%6]
    var word: Dictionary = WORDS[(spawned*3)%BASE_WORD_COUNT].duplicate()
    if difficulty == 2 and spawned > 1:
        word = WORDS[BASE_WORD_COUNT+(spawned%8)].duplicate()
    if spawned == 0: word = {"text":"雨","kana":"あめ","en":"rain"}
    if spawned == 1: word = {"text":"路地","kana":"ろじ","en":"alley"}
    var foe := _spawn(type,path_lane,word)
    var ahead := 7.0 if spawned == 0 else (12.0 if type == "skip" else 9.0)
    var cam := world.camera.global_position
    var target_pos := Vector3(cam.x+path_lane*1.65,0.02,cam.z-ahead)
    var side := -1.0 if spawned%2 == 0 else 1.0
    var source_pos := Vector3(side*5.3,0.02,target_pos.z-0.8)
    if spawned == 0: source_pos = target_pos+Vector3(-0.8,0,-0.5)
    foe.set_entry(source_pos,target_pos,world.camera)
    spawned += 1
    if spawned == 3:
        toast("近づいた敵には、短い CUT で足止め", "CUT IS OPTIONAL · ONE FULL WORD KILLS",Color("eaca8b"),3)
    elif spawned == 8:
        toast("交差点を抜けろ", "KEEP YOUR CHAIN ALIVE",Color("eaca8b"),2)
    elif spawned == 16:
        toast("最後の群れ", "THE EXIT IS STRAIGHT AHEAD",Color("eaca8b"),2.5)

func _spawn(type: String, lane: int, word: Dictionary) -> RelayEnemy:
    var localized := word.duplicate()
    if language == 1:
        localized.kana = word.en
        localized.text = word.en.to_upper()
    var interrupt: Dictionary = CUTS[(spawned+stage)%CUTS.size()].duplicate()
    for cut_index in range(CUTS.size()):
        var candidate: Dictionary = CUTS[(spawned + stage + cut_index)%CUTS.size()]
        var candidate_word: String = candidate.en if language == 1 else candidate.kana
        var starts_overlap := false
        var a: Array[String] = Romaji.spellings(localized.kana)
        var b: Array[String] = Romaji.spellings(candidate_word)
        for x in a:
            for y in b:
                if x.left(1) == y.left(1): starts_overlap = true
        if not starts_overlap:
            interrupt = candidate.duplicate()
            break
    if language == 1:
        interrupt.kana = interrupt.en
        interrupt.text = interrupt.en.to_upper()
    var foe := Enemy.new()
    add_child(foe)
    spawn_serial += 1
    foe.setup(type,lane,localized,interrupt,difficulty,spawn_serial)
    foe.camera = world.camera
    if spawned == 0: foe.speed *= 0.55
    enemies.append(foe)
    if not is_instance_valid(selected):
        selected = foe
    return foe

func type_letter(letter: String) -> void:
    if letter == "n" and optional_n_time > 0:
        optional_n_time = 0
        return
    optional_n_time = 0
    if not is_instance_valid(selected) or selected.dead:
        return
    total_keys += 1
    var foe := selected
    if foe.active_word.is_empty():
        if foe.can_cut() and foe.cut.can_start(letter):
            foe.active_word = "cut"
        elif foe.purge.can_start(letter):
            foe.active_word = "purge"
        else:
            _wrong_key(foe)
            return
    var matcher: RelayRomaji = foe.current_matcher()
    if not matcher.accept(letter):
        _wrong_key(foe)
        return
    last_input = letter
    correct_keys += 1
    key_flash = 1.0
    foe.hit_flash = 1.0
    typing_index = (typing_index+1)%4
    play_sound("typing_%02d" % (typing_index+1),-3)
    weapon_recoil = maxf(weapon_recoil,0.13)
    if matcher.complete:
        if matcher.typed.ends_with("n") and matcher.candidates.has(matcher.typed+"n"):
            optional_n_time = 1.0
        if foe.active_word == "cut":
            var feedback := foe.interrupt()
            cuts += 1
            score += 75
            play_sound("cut",-1)
            world.burst(foe.position+Vector3(0,1.1,0),Color("ffad42"),9)
            if feedback:
                backfeeds += 1
                score += 300
                for target in enemies:
                    target.stun = maxf(target.stun,2.5)
                toast("COUNTER", "群れを押し返した  +300",Color("eaca8b"),1.6)
                world.screen_shake = 0.11
            else:
                toast("STAGGER", "足止め成功 · 白い単語で撃破",Color("eaca8b"),1.0)
        else:
            _purge(foe)

func _wrong_key(foe: RelayEnemy) -> void:
    mistakes += 1
    foe.clean = false
    combo = 0
    key_error = 1.0
    play_sound("error")

func _purge(foe: RelayEnemy) -> void:
    combo = combo+1 if foe.clean else 0
    best_combo = maxi(best_combo,combo)
    var multiplier := 1 + mini(4,combo/3)
    last_award = (100+foe.purge.typed.length()*20)*multiplier
    score += last_award
    chain_count = chain_count+1 if chain_timer > 0 else 1
    chain_timer = 4.0
    weapon_recoil = 1.0
    world.fire(foe.position+Vector3(0,1.45,0),1.5)
    world.screen_shake = 0.055
    kill_flash = 1.0
    world.burst(foe.position+Vector3(0,1.45,0),Color("dfb486"),10)
    play_sound("shot",-5)
    play_sound("impact_body",-9)
    play_sound("kill",-12)
    kills += 1
    stage_kills += 1
    kill_feed.push_front({"text":"CLEAN KILL +%d" % last_award if foe.clean else "KILL +%d" % last_award,"time":1.5})
    if kill_feed.size() > 3: kill_feed.resize(3)
    _remove_enemy(foe)
    if enemies.is_empty() and chain_count >= 2:
        chain_clear_flash = 1.0
        var bonus := 100*chain_count
        score += bonus
        toast("CHAIN CLEAR", "%d連鎖  +%d" % [chain_count,bonus],Color("edc57c"),1.3)
        play_sound("confirm",-7)
    elif foe.clean and combo in [3,6,9,12,15,18,21,24]:
        toast("%d KILL COMBO" % combo, "×%d SCORE" % multiplier,Color("edc57c"),1.0)

func _advance_boss(_foe: RelayEnemy) -> void:
    pass

func _remove_enemy(foe: RelayEnemy) -> void:
    enemies.erase(foe)
    if selected == foe: selected = null
    foe.kill()
    _select_urgent()

func hurt(foe: RelayEnemy) -> void:
    if stage == 0 and kills == 0:
        toast("焦らなくていい。白い単語を入力", "FIRST CONTACT IS SAFE · TYPE THE WORD",Color("d8e2d6"),3)
        return
    hp -= 1
    combo = 0
    damage_flash = 0.8
    world.screen_shake = 0.22
    play_sound("hurt",-1)
    toast("DAMAGE", "間違えても入力は消えない。落ち着いて続けよう",Color("ff8064"),1.6)
    if hp <= 0:
        finish_run(false)

func finish_run(won: bool) -> void:
    state = "victory" if won else "defeat"
    if won: score += hp*500 + int(accuracy()*20)
    if score > best_score:
        best_score = score
        _save_settings()
    if not won: play_sound("defeat",-3)
    menu_index = 0
    print("RUN RESULT state=",state," kills=",kills," elapsed=",elapsed," score=",score," accuracy=",accuracy()," hp=",hp)
    if not capture_dir.is_empty(): _save_capture("result.png")

func _select_urgent() -> void:
    selected = null
    var earliest := INF
    for foe in enemies:
        if not foe.dead and foe.urgency() < earliest:
            earliest = foe.urgency()
            selected = foe

func cycle_target() -> void:
    optional_n_time = 0.0
    if enemies.is_empty(): return
    var index := enemies.find(selected)
    selected = enemies[(index+1)%enemies.size()]
    play_sound("confirm",-12)

func _select_at(screen_pos: Vector2) -> void:
    optional_n_time = 0.0
    var best := 10000.0
    var next: RelayEnemy
    for foe in enemies:
        var point := world.camera.unproject_position(foe.global_position+Vector3(0,1,0))
        var distance := point.distance_to(screen_pos)
        if distance < best and distance < 160:
            best = distance
            next = foe
    if is_instance_valid(next): selected = next

func _clear_enemies() -> void:
    for child in get_children():
        if child is RelayEnemy and not child.is_crowd: child.queue_free()
    enemies.clear()
    selected = null
    optional_n_time = 0.0

func toast(title: String, sub: String, color: Color, duration := 2.0) -> void:
    notice = title
    notice_sub = sub
    notice_color = color
    notice_time = duration

func accuracy() -> float:
    return 100.0*correct_keys/maxi(1,total_keys) if total_keys > 0 else 100.0

func wpm() -> float:
    return correct_keys*12.0/maxf(1,elapsed)

func rank_name() -> String:
    if accuracy() >= 97 and hp >= max_hp-1: return "S"
    if accuracy() >= 90 and hp >= 2: return "A"
    if accuracy() >= 80: return "B"
    return "C"

func _focus_lost() -> void:
    # Moving focus from the canvas into the mobile HTML input is not leaving
    # the game. Actual window blur / hidden-tab events are bridged separately.
    if OS.has_feature("web"):
        var document = JavaScriptBridge.get_interface("document")
        if document != null and document.hasFocus(): return
    if state == "playing" and not demo_mode:
        previous_state = state
        state = "paused"
        menu_index = 0

func _save_settings() -> void:
    var config := ConfigFile.new()
    config.load("user://black_relay.cfg")
    best_scores[_record_key()] = maxi(int(best_scores.get(_record_key(),0)),best_score)
    config.set_value("settings","difficulty",difficulty)
    config.set_value("settings","language",language)
    config.set_value("settings","volume",volume)
    config.set_value("settings","reduced_motion",reduced_motion)
    config.set_value("settings","high_contrast",high_contrast)
    config.set_value("records","profiles",best_scores)
    config.save("user://black_relay.cfg")

func _load_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://black_relay.cfg") == OK:
        difficulty = clampi(int(config.get_value("settings","difficulty",1)),0,2)
        language = clampi(int(config.get_value("settings","language",0)),0,1)
        volume = clampf(float(config.get_value("settings","volume",0.72)),0,1)
        reduced_motion = bool(config.get_value("settings","reduced_motion",false))
        high_contrast = bool(config.get_value("settings","high_contrast",false))
        best_scores = config.get_value("records","profiles",{})
        _refresh_record()

func _autoplay(delta: float) -> void:
    auto_timer -= delta
    if auto_timer > 0 or not is_instance_valid(selected): return
    auto_timer = demo_key_interval
    var target: RelayEnemy = selected
    if target.active_word.is_empty():
        target.active_word = "purge"
    var matcher: RelayRomaji = target.current_matcher()
    var hint := matcher.hint()
    if hint.length() > matcher.typed.length():
        type_letter(hint.substr(matcher.typed.length(),1))

func _exit_tree() -> void:
    if is_instance_valid(ambience):
        ambience.stop()
        ambience.stream = null
    for child in get_children():
        if child is AudioStreamPlayer:
            child.stop()
            child.stream = null
    audio.clear()

func _save_capture(filename := "black_relay_capture.png") -> void:
    if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
        return
    await RenderingServer.frame_post_draw
    var folder: String = _capture_folder()
    DirAccess.make_dir_recursive_absolute(folder)
    var path: String = folder.path_join(filename)
    var image: Image = get_viewport().get_texture().get_image()
    var result := image.save_png(path)
    print("GAME CAPTURE ",path," result=",result," fps=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," viewport=",get_viewport().get_visible_rect().size)

func _save_record_frame() -> void:
    if OS.has_feature("web"): return
    var index := record_frame
    record_frame += 1
    await RenderingServer.frame_post_draw
    var folder: String = _capture_folder().path_join("black_relay_recording")
    DirAccess.make_dir_recursive_absolute(folder)
    var output: String = folder.path_join("frame_%04d.png" % index)
    get_viewport().get_texture().get_image().save_png(output)
    var stamps := FileAccess.open(folder.path_join("timestamps.csv"),FileAccess.WRITE if index == 0 else FileAccess.READ_WRITE)
    if stamps:
        stamps.seek_end()
        stamps.store_line("%d,%f" % [index,Time.get_ticks_usec()/1000000.0])
        stamps.close()

func _record_key() -> String:
    return "urban_%d_%d" % [difficulty,language]

func _refresh_record() -> void:
    best_score = int(best_scores.get(_record_key(),0))

func _capture_folder() -> String:
    # Never modify an exported executable or a signed macOS app bundle.
    return capture_dir if not capture_dir.is_empty() else OS.get_user_data_dir().path_join("captures")

func _make_weapon() -> void:
    var path := "res://assets/models/city/pistol_hands.glb"
    if not ResourceLoader.exists(path): return
    weapon = load(path).instantiate()
    world.camera.add_child(weapon)
    weapon.position = WEAPON_HOME
    weapon.rotation = WEAPON_ANGLE
    weapon_muzzle = weapon.find_child("Muzzle",true,false) as Node3D

func _update_weapon(delta: float) -> void:
    weapon_recoil = maxf(0,weapon_recoil-delta*6.5)
    if not is_instance_valid(weapon): return
    weapon.visible = state in ["playing","paused","ending"] or (state == "settings" and settings_origin == "paused")
    var motion := 0.0 if reduced_motion else 1.0
    weapon.position = WEAPON_HOME + Vector3(sin(elapsed*3.3)*0.003*motion,-weapon_recoil*0.008,weapon_recoil*0.045)
    weapon.rotation = WEAPON_ANGLE + Vector3(weapon_recoil*0.065,0,weapon_recoil*-0.018)
    if is_instance_valid(weapon_muzzle):
        world.shot_origin_camera = world.camera.to_local(weapon_muzzle.global_position)

func _make_crowd() -> void:
    if DisplayServer.get_name() == "headless": return
    for i in range(5):
        var person := Enemy.new()
        add_child(person)
        person.is_crowd = true
        person.setup("hush",0,WORDS[0],CUTS[0],0,100+i)
        person.position = Vector3(-4.3 if i%2==0 else 4.5,0.02,-18.0-i*9.0)
        person.scale = Vector3.ONE*0.96
        person.rotation.y = -1.2 if i%2==0 else 1.0
        person.halo.hide()
        crowd.append(person)
        crowd_origin.append(person.position)

func _update_crowd(delta: float) -> void:
    for i in range(crowd.size()):
        var person := crowd[i]
        person._advance_animation(delta*0.6)
        person.position = crowd_origin[i]+Vector3(sin(elapsed*0.22+i)*0.7,0,cos(elapsed*0.18+i)*0.6)
        person.visible = person.global_position.z < world.camera.global_position.z-13.0

func _configure_render_profile() -> void:
    var adapter := RenderingServer.get_video_adapter_name().to_lower()
    software_renderer = "llvmpipe" in adapter or "softpipe" in adapter or "swiftshader" in adapter
    if "--native-quality" in OS.get_cmdline_user_args(): software_renderer = false
    if software_renderer:
        render_profile = "SOFTWARE · 70% 3D / FULL-RES TEXT"
        get_viewport().scaling_3d_scale = 0.70
        get_viewport().msaa_3d = Viewport.MSAA_DISABLED
        get_viewport().positional_shadow_atlas_size = 512
    elif OS.has_feature("web"):
        render_profile = "WEB COMPATIBILITY"
        get_viewport().scaling_3d_scale = 0.85
        get_viewport().msaa_3d = Viewport.MSAA_DISABLED
    else:
        get_viewport().msaa_3d = Viewport.MSAA_2X
    print("RENDER PROFILE ",render_profile," adapter=",adapter)

func _can_advance_route() -> bool:
    # A rail shooter must not drive past an unfinished word. Input remains live
    # while the camera holds and the nearest enemy continues its attack cycle.
    for foe in enemies:
        if not foe.dead and foe.global_position.z > world.camera.global_position.z-5.0:
            return false
    return true
