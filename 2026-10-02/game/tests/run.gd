extends SceneTree
# Deterministic regressions for the urban slice. UI/rendering QA is recorded separately.
const Romaji = preload("res://scripts/romaji.gd")
var game
var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures.append(message)
        print("FAIL: ",message)

func _initialize() -> void:
    ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
    ProjectSettings.set_setting("application/config/custom_user_dir_name","black-relay-urban-tests/%d" % OS.get_process_id())
    DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
    var settings := ConfigFile.new()
    settings.set_value("settings","volume",0)
    settings.save("user://black_relay.cfg")
    call_deferred("run")

func key(code: int, unicode := 0) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = code
    event.unicode = unicode
    game._input(event)

func type_text(value: String) -> void:
    for letter in value: game.type_letter(letter)

func reset_fight() -> void:
    game.language = 0
    game.difficulty = 1
    game.start_run()
    game.begin_stage()
    game.spawn_clock = 9999.0
    game.world.set_process(false)

func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.world.set_process(false)
    game.volume = 0
    if game.ambience: game.ambience.stop()
    print("=== TOUCH / WEB INPUT ===")
    game.start_run()
    check(game.hud.menu_actions() == ["begin"], "Briefing has a real clickable start action")
    check(game.hud.menu_labels().size() == 1, "Briefing start has a touch-readable label")
    game.hud.ui_scale = 0.5
    game.hud.origin = Vector2(0,40)
    game.hud.buttons.assign([Rect2(76,608,550,58)])
    var start_click := InputEventMouseButton.new()
    start_click.pressed = true
    start_click.button_index = MOUSE_BUTTON_LEFT
    start_click.position = Vector2(180,360)
    game._input(start_click)
    check(game.state == "playing", "Clicking briefing start begins encounter without keyboard")
    game.hud.buttons.clear()
    check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "Touch emits the same clickable mouse action")
    game.web_action("pause")
    check(game.state == "paused", "Touch pause works")
    var paused_time: float = game.stage_time
    game._process(5)
    check(game.stage_time == paused_time, "Touch pause freezes encounter")
    game.web_action("text", "ame")
    check(game.total_keys == 0, "Soft keyboard text is ignored while paused")
    game.web_action("menu", "0")
    check(game.state == "playing", "Touch resume uses existing menu action")
    var before_restart: float = game.stage_time
    game.web_action("begin")
    check(game.stage_time == before_restart, "Repeated start does not restart running encounter")
    reset_fight()
    var touch_enemy = game._spawn("hush",0,{"text":"雨","kana":"あめ","en":"rain"})
    game.web_action("text", "a雨")
    game.web_action("text", "a m e")
    check(game.total_keys == 0, "Mixed IME and whitespace commits are rejected atomically")
    game.web_action("text", "A")
    check(touch_enemy.purge.typed == "a" and game.total_keys == 1, "Soft keyboard accepts uppercase once")
    var touch_snapshot: Dictionary = game.web_snapshot()
    check(touch_snapshot.target == "雨" and touch_snapshot.typed == "a" and touch_snapshot.remaining == "me", "Mobile target readout mirrors matcher progress")
    game.web_action("reset")
    check(touch_enemy.purge.typed.is_empty(), "Touch reset clears selected input")
    game.web_action("text", "ame")
    check(touch_enemy.dead and game.kills == 1, "Committed soft keyboard text completes same matcher")
    game.web_action("focus_lost")
    check(game.state == "paused", "Leaving mobile page pauses combat")
    game.web_action("menu", "1")
    var touch_settings: Dictionary = game.web_snapshot()
    check(not touch_settings.actions[0].enabled and not touch_settings.actions[1].enabled, "Paused difficulty and language remain locked on mobile")
    var touch_difficulty: int = game.difficulty
    game.web_action("menu", "0")
    check(game.difficulty == touch_difficulty, "Mobile bridge enforces locked settings")
    game.web_action("menu", "999")
    game.web_action("menu", "invalid")
    check(game.state == "settings", "Invalid mobile menu indices do nothing")
    game.web_action("menu", "5")
    game.web_action("menu", "2")
    check(game.state == "intermission" and game.kills == 0, "Touch retry rolls back checkpoint and returns to briefing")
    print("=== ROMAJI FAIRNESS ===")
    var aliases := 0
    for word in game.WORDS + game.CUTS + [{"kana":"あめ"},{"kana":"ろじ"}]:
        for spelling in Romaji.spellings(word.kana):
            aliases += 1
            var matcher := Romaji.new()
            matcher.reset(word.kana)
            var accepted := true
            for letter in spelling: accepted = matcher.accept(letter) and accepted
            check(accepted and matcher.complete,"Playable romaji alias %s / %s" % [word.kana,spelling])
            check(not spelling.begins_with("n"),"No prompt conflicts with terminal-n continuation")
    print("ROMAJI aliases=",aliases)
    for pair in [["しんかい","SINKAI"],["しょうしつ","SYOUSITU"],["ふっきゅう","HUKKYUU"],["でんぱ","DENNPA"]]:
        var matcher := Romaji.new()
        matcher.reset(pair[0])
        for letter in pair[1]: matcher.accept(letter)
        check(matcher.complete,"Common uppercase alias "+pair[1])
    reset_fight()
    var a = game._spawn("hush",-1,game.WORDS[2])
    var b = game._spawn("hush",1,game.WORDS[0])
    type_text("mugonn")
    check(a.dead and game.kills == 1 and game.mistakes == 0 and b.clean,"Terminal nn does not dirty next target")
    type_text("zankyou")
    check(b.dead and game.mistakes == 0,"Next word starts immediately after terminal nn")
    reset_fight()
    a = game._spawn("hush",-1,game.WORDS[2])
    b = game._spawn("hush",1,game.WORDS[0])
    type_text("mugon")
    game._process(0.8)
    type_text("nzankyou")
    check(a.dead and b.dead and game.mistakes == 0,"Slow nn continuation is not time gated")
    reset_fight()
    a = game._spawn("hush",-1,game.WORDS[4])
    b = game._spawn("hush",1,game.WORDS[0])
    game.selected = a
    type_text("shx")
    check(a.purge.typed == "sh","Wrong letter preserves accepted input")
    game.cycle_target()
    type_text("z")
    game.cycle_target()
    check(game.selected == a and a.purge.typed == "sh","Target switching preserves each partial word")
    check(game.total_keys == 4 and game.correct_keys == 3 and game.mistakes == 1 and is_equal_approx(game.accuracy(),75),"Accuracy counts normal and wrong input")
    key(KEY_BACKSPACE)
    check(a.purge.typed.is_empty() and a.cut.typed.is_empty() and a.active_word.is_empty(),"Backspace clears current target only")
    for letter in "SHOUSHITSU": key(0,letter.unicode_at(0))
    check(a.dead,"Uppercase input events complete a kill")
    var repeat := InputEventKey.new()
    repeat.pressed = true
    repeat.echo = true
    repeat.unicode = 122
    var count: int = game.total_keys
    game._input(repeat)
    repeat.echo = false
    repeat.pressed = false
    game._input(repeat)
    check(game.total_keys == count,"OS key repeat and release do not consume input")

    print("=== ONE WORD / CONTEXTUAL CUT ===")
    reset_fight()
    a = game._spawn("choir",0,game.WORDS[8])
    type_text(a.purge.hint())
    check(a.dead and game.kills == 1 and game.cuts == 0,"Even legacy armored type is killed with one word")
    reset_fight()
    a = game._spawn("hush",0,game.WORDS[8])
    a.position = game.world.camera.position+Vector3(0,-game.world.camera.position.y,-25)
    check(not a.can_cut(),"CUT is not offered for a distant target")
    a.position.z = game.world.camera.position.z-3
    check(a.can_cut(),"CUT becomes available near an attacking threat")
    a.phase = "attack"
    a.telegraph = a.telegraph_max-.2
    b = game._spawn("hush",1,game.WORDS[0])
    game.selected = a
    type_text(a.cut.hint())
    check(a.cut_used and not a.dead and game.backfeeds == 1 and a.stun >= 2.5 and b.stun >= 2.5,"Timed CUT counters and staggers whole crowd without a kill")
    var score_before: int = game.score
    var cut_hint: String = a.cut.hint()
    for i in range(4):
        key(KEY_BACKSPACE)
        type_text(cut_hint)
    check(game.cuts == 1 and game.score == score_before,"CUT cannot be farmed with backspace")
    key(KEY_BACKSPACE)
    type_text(a.purge.hint())
    check(a.dead,"The normal word kills after a CUT")
    for lang in range(2):
        game.language = lang
        for word in game.WORDS:
            a = game._spawn("hush",0,word)
            var overlap := false
            for kill_spelling in a.purge.candidates:
                for cut_spelling in a.cut.candidates:
                    overlap = overlap or kill_spelling.left(1)==cut_spelling.left(1)
            check(not overlap,"CUT and kill initials are disjoint")
            game._clear_enemies()

    reset_fight()
    game.spawn_clock = 0
    for i in range(500):
        game._process(.1)
        game.world._process(.1)
    check(game.enemies.size() == 1 and game.spawned == 1,"Safe first contact stays isolated for a slow typist")
    check(game.selected.global_position.z < game.world.camera.global_position.z-1.0,"Camera never passes an unfinished target")
    check(game.route_holding and game.route_time < game.elapsed,"Close enemies hold the rail without a typing timeout")
    type_text(game.selected.purge.hint())
    var old_route: float = game.route_time
    game._process(.2)
    game.world._process(.2)
    check(game.route_time > old_route,"Camera resumes once the close threat is cleared")

    print("=== SCORE / PAUSE / SAVE ===")
    reset_fight()
    for i in range(3):
        a = game._spawn("hush",0,game.WORDS[2])
        game.selected = a
        type_text("mugon")
    check(game.combo == 3 and game.best_combo == 3 and game.last_award == 400,"Clean kills build visible combo multiplier")
    check(game.chain_count == 3 and game.chain_clear_flash > 0,"Quick clear builds a graded chain reward")
    a = game._spawn("hush",0,game.WORDS[2])
    type_text("zmugon")
    check(game.combo == 0 and game.best_combo == 3,"Mistake breaks current combo but preserves best")
    a = game._spawn("skip",0,game.WORDS[0])
    a.phase = "attack"
    a.telegraph = .5
    a.stun = .5
    game.toast("TEST","Frozen",Color.WHITE,5)
    var before = [game.elapsed,game.stage_time,game.spawn_clock,a.position,a.telegraph,a.stun,game.notice_time,game.route_progress]
    key(KEY_ESCAPE)
    game._process(30)
    check(game.state == "paused" and before == [game.elapsed,game.stage_time,game.spawn_clock,a.position,a.telegraph,a.stun,game.notice_time,game.route_progress],"Pause freezes simulation, input notice and route")
    game.activate_menu(1)
    game._process(30)
    check(game.state == "settings" and game.elapsed == before[0],"Settings from pause keeps simulation frozen")
    var profile: String = game._record_key()
    game.activate_menu(0)
    game.activate_menu(1)
    check(game._record_key() == profile,"Difficulty/language locked during an active run")
    key(KEY_ESCAPE)
    key(KEY_ESCAPE)
    check(game.state == "playing","Settings and pause return cleanly")
    game.hp = 1
    game.hurt(a)
    check(game.state == "defeat","Fatal attack produces defeat")
    game.retry_checkpoint()
    check(game.state == "intermission" and game.hp == game.max_hp and game.enemies.is_empty() and game.score == game.checkpoint.score,"Retry restores exact checkpoint without farming")
    game.start_run()
    check(game.elapsed == 0 and game.score == 0 and game.kills == 0 and game.route_progress == 0,"Restart resets run/route counters")
    game.state = "settings"
    game.settings_origin = "title"
    game.volume = .72
    var muted := false
    for i in range(5):
        game.activate_menu(2)
        muted = muted or game.volume < .001
    check(muted,"Mute reachable through discrete volume settings")
    game.difficulty = 2
    game.language = 1
    game.volume = 0
    game.reduced_motion = true
    game.high_contrast = true
    game.best_score = 123456
    game._save_settings()
    game.difficulty = 0
    game.language = 0
    game._load_settings()
    check(game.difficulty == 2 and game.language == 1 and game.volume == 0 and game.reduced_motion and game.high_contrast and game.best_score == 123456,"Settings and high score round trip")
    check(game._record_key().begins_with("urban_"),"Urban score profile does not inherit incompatible old campaign scores")
    game.best_scores.clear()
    for difficulty in range(3):
        for lang in range(2):
            game.difficulty = difficulty
            game.language = lang
            game.best_score = (difficulty+1)*1000+lang*100
            game._save_settings()
    game.best_scores.clear()
    game._load_settings()
    check(game.best_scores.size() == 6 and game.best_score == 3100,"Six independent difficulty/language records persist")
    game.elapsed = 60
    game.correct_keys = 250
    check(game.wpm() == 50,"WPM uses active run time")

    print("=== AUTHORED ROUTE / SIX PLAYTHROUGHS ===")
    for lang in range(2):
        for difficulty in range(3):
            game.language = lang
            game.difficulty = difficulty
            game.start_run()
            game.begin_stage()
            game.reduced_motion = true
            game.world.reduced_motion = true
            var initial_position: Vector3 = game.world.camera.position
            var guard := 0
            while game.state not in ["victory","defeat"] and guard < 2200:
                guard += 1
                game._process(.1)
                game.world._process(.1)
                if game.state == "playing" and is_instance_valid(game.selected):
                    var matcher = game.selected.purge
                    var hint: String = matcher.hint()
                    if matcher.typed.length() < hint.length(): game.type_letter(hint.substr(matcher.typed.length(),1))
                if guard%60 == 0: await process_frame
            print("SLICE lang=",lang," difficulty=",difficulty," state=",game.state," kills=",game.kills," hp=",game.hp," elapsed=",game.elapsed," mistakes=",game.mistakes)
            check(game.state == "victory" and game.kills == 24,"Full street is winnable for every profile")
            check(game.mistakes == 0,"Every generated canonical prompt remains typeable")
            check(game.world.camera.position.distance_to(initial_position)>30,"Camera physically advances more than 30 metres")
            check(game.elapsed >= 75 and game.elapsed <= 90,"Fast clean play is a 75-90 second slice")
            var final_score: int = game.score
            game._process(60)
            check(game.score == final_score and game.state == "victory","Victory bonus is not awarded repeatedly")
    reset_fight()
    game.stage_time = 100
    game.route_time = 100
    game.spawned = 24
    a = game._spawn("hush",0,game.WORDS[0])
    game._process(.1)
    check(game.state == "playing" and game.route_progress == 1,"Path ending is not a typing time limit")
    game._clear_enemies()
    await process_frame
    game.world._process(2)
    await process_frame
    await create_timer(.3).timeout
    var baseline := get_node_count()
    for i in range(30):
        a = game._spawn("hush",0,game.WORDS[2])
        game.selected = a
        type_text("mugon")
        a._process(8)
        if i%5 == 0: await process_frame
    game._clear_enemies()
    game.world._process(2)
    await create_timer(.3).timeout
    check(game.world.fragments.is_empty(),"Transient hit particles expire")
    print("LIFECYCLE baseline=",baseline," after=",get_node_count())
    check(get_node_count() == baseline,"Repeated kills release corpses and transient effects")
    print("URBAN TEST SUMMARY checks=",checks," failures=",failures.size()," details=",failures)
    game.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://black_relay.cfg"))
    DirAccess.remove_absolute(OS.get_user_data_dir())
    quit(0 if failures.is_empty() else 1)
