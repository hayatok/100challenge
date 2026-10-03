extends Control

# A compact 1280x720 safe-frame HUD. The street remains the main image.
const INK := Color("080e11")
const IVORY := Color("f1eee4")
const MUTED := Color("a2b0b1")
const AMBER := Color("ffc26b")
const CYAN := Color("92e3d7")
const CORAL := Color("ff715f")
const ASSET_CREDIT := "Rosswet Mobile · Thin Zombie / Vincent Sevedge · Gunshot Sounds (CC BY 3.0)"
const MONO = preload("res://assets/fonts/DejaVuSansMono.ttf")
const JP = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")
var game
var buttons: Array[Rect2] = []
var button_state := ""
const PAUSE_HITBOX := Rect2(1056,648,200,64)
var ui_scale := 1.0
var origin := Vector2.ZERO
var t := 0.0
var game_properties: Dictionary = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if game != null:
        for property in game.get_property_list():
            game_properties[String(property.name)] = true

func _value(property: String, fallback):
    return game.get(property) if game_properties.has(property) else fallback

func _draw() -> void:
    if game == null: return
    t = Time.get_ticks_msec()/1000.0
    ui_scale = minf(size.x/1280.0,size.y/720.0)
    origin = (size-Vector2(1280,720)*ui_scale)*0.5
    draw_set_transform(origin,0,Vector2.ONE*ui_scale)
    buttons.clear()
    button_state = game.state
    _edge_shading()
    match game.state:
        "title": _title()
        "settings": _settings()
        "paused":
            _gameplay()
            _pause()
        "intermission": _briefing()
        "victory", "defeat": _results()
        "ending": _ending()
        _: _gameplay()
    if game.damage_flash > 0:
        # Damage lives at the edges, never over the word being typed.
        var alpha: float = game.damage_flash*0.65
        draw_rect(Rect2(0,0,1280,720),Color(CORAL,alpha),false,5)
        draw_rect(Rect2(0,0,1280,7),Color(CORAL,alpha*0.6))

func _edge_shading() -> void:
    for i in range(8):
        draw_rect(Rect2(i*5,i*4,1280-i*10,720-i*8),Color(0.01,0.018,0.023,0.025),false,12)
    # Small local veils keep the two corner readouts scene-independent.
    for i in range(8):
        draw_rect(Rect2(0,i*10,285,10),Color(INK,0.72*(1-i/8.0)))
        draw_rect(Rect2(960,i*10,320,10),Color(INK,0.72*(1-i/8.0)))

func text(value: String, pos: Vector2, font_size := 20, color := IVORY, mono := false) -> void:
    draw_string(MONO if mono else JP,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func centered(value: String, y: float, font_size := 20, color := IVORY, mono := false, x := 640.0) -> void:
    var font: Font = MONO if mono else JP
    var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    text(value,Vector2(x-width*0.5,y),font_size,color,mono)

func right(value: String, pos: Vector2, font_size := 20, color := IVORY, mono := false) -> void:
    var font: Font = MONO if mono else JP
    var width: float = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
    text(value,pos-Vector2(width,0),font_size,color,mono)

func rule(a: Vector2,b: Vector2,color := Color("455258")) -> void:
    draw_line(a,b,color,1,true)

func panel(rect: Rect2, accent := AMBER, alpha := 0.95) -> void:
    draw_rect(rect,Color(INK,1.0 if game.high_contrast else alpha))
    draw_rect(rect,Color("77878a") if game.high_contrast else Color("3b4a4d"),false,1)
    draw_line(rect.position,rect.position+Vector2(38,0),accent,2)

func button(label: String, rect: Rect2, index: int, primary := false, locked := false) -> void:
    var selected: bool = game.menu_hover == index or (game.menu_hover < 0 and game.menu_index == index)
    var base := AMBER if primary else Color("142126")
    if selected and not primary: base = Color("263a40")
    if locked: base = Color("142025")
    draw_rect(rect,base)
    draw_rect(rect,IVORY if selected else Color("506267"),false,2 if selected else 1)
    if selected:
        draw_line(rect.position+Vector2(-8,0),rect.position+Vector2(-8,rect.size.y),AMBER,3)
    text(label,rect.position+Vector2(18,rect.size.y*0.5+7),18,INK if primary else (MUTED if locked else IVORY))
    if locked:
        right("LOCK",rect.end-Vector2(16,rect.size.y*0.5-5),11,MUTED,true)
    else:
        right("ENTER" if selected else "›",rect.end-Vector2(16,rect.size.y*0.5-5),11 if selected else 22,INK if primary else AMBER,true)
    buttons.append(rect)

func menu_actions() -> Array:
    match game.state:
        "title": return ["start","settings"]
        "intermission": return ["begin"]
        "settings": return ["difficulty","language","volume","motion","contrast","back"]
        "paused": return ["resume","settings","checkpoint","title"]
        "victory": return ["retry","title"]
        "defeat": return ["checkpoint","retry","title"]
    return []

func menu_labels() -> Array[String]:
    match game.state:
        "title": return ["脱出を始める / START RUN", "設定 / SETTINGS"]
        "intermission": return ["街へ出る / START"]
        "paused": return ["再開 / RESUME", "設定 / SETTINGS", "このルートをやり直す", "タイトルへ戻る"]
        "victory": return ["もう一度 / RETRY", "タイトルへ戻る"]
        "defeat": return ["このルートをやり直す", "最初から / RETRY", "タイトルへ戻る"]
        "settings":
            var locked: bool = game.settings_origin == "paused"
            return [
                "難易度: タイトルで変更" if locked else "難易度: " + ["ASSIST", "STANDARD", "OVERDRIVE"][game.difficulty],
                "入力: タイトルで変更" if locked else "入力: " + ["日本語ローマ字", "ENGLISH WORDS"][game.language],
                "音量: %d%%" % roundi(game.volume * 100),
                "動きを減らす: " + ("ON" if game.reduced_motion else "OFF"),
                "文字コントラスト: " + ("HIGH" if game.high_contrast else "STANDARD"),
                "戻る / BACK"]
    return []

func button_at(pos: Vector2) -> int:
    if button_state != game.state: return -1
    var point := (pos-origin)/maxf(ui_scale,0.001)
    for i in range(buttons.size()):
        if buttons[i].has_point(point): return i
    return -1

func pause_at(pos: Vector2) -> bool:
    # Make the existing footer action tappable without adding another panel.
    return PAUSE_HITBOX.has_point((pos-origin)/maxf(ui_scale,0.001))

func _title() -> void:
    draw_rect(Rect2(0,0,550,720),Color(INK,0.85))
    for i in range(24):
        draw_rect(Rect2(550+i*12,0,12,720),Color(INK,0.85*(1-i/24.0)))
    draw_rect(Rect2(56,45,8,8),AMBER)
    text("AN URBAN TYPING SHOOTER",Vector2(76,55),13,MUTED,true)
    text("BLACK",Vector2(51,233),93,IVORY,true)
    text("RELAY",Vector2(51,333),93,IVORY,true)
    rule(Vector2(58,362),Vector2(492,362),AMBER)
    text("黒雨の街",Vector2(57,412),32,IVORY)
    text("街は、もう人のものじゃない。",Vector2(59,453),18,MUTED)
    text("一語、一発。この街を抜けろ。",Vector2(59,484),17,IVORY)
    button("脱出を始める  /  START RUN",Rect2(58,527,452,57),0,true)
    button("設定  /  SETTINGS",Rect2(58,599,452,49),1)
    text("↑ ↓ 選択   ENTER 決定",Vector2(58,685),12,MUTED)
    right("TYPE. FIRE. ESCAPE.",Vector2(1224,628),23,IVORY,true)
    right("3 ENCOUNTERS  /  ONE ESCAPE",Vector2(1224,655),12,AMBER,true)
    right("KEYBOARD + HEADPHONES",Vector2(1224,685),11,MUTED,true)
    text("IME をオフにして入力",Vector2(58,712),11,MUTED)
    # Short licensed-asset credit; full source and license links accompany the build.
    var credit: String = ASSET_CREDIT
    if not credit.is_empty(): right(credit,Vector2(1224,712),9,MUTED)

func _settings() -> void:
    draw_rect(Rect2(0,0,1280,720),Color(INK,0.9))
    panel(Rect2(322,64,636,592),CYAN)
    text("SETTINGS",Vector2(364,118),30,IVORY,true)
    text("設定はこの端末に保存されます",Vector2(365,151),15,MUTED)
    var locked: bool = game.settings_origin == "paused"
    var labels: Array[String] = [
        "難易度    " + ["ASSIST / 余裕あり","STANDARD / 標準","OVERDRIVE / 高難度"][game.difficulty],
        "入力      " + ["日本語ローマ字","ENGLISH WORDS"][game.language],
        "音量      %d%%" % roundi(game.volume*100),
        "動きを減らす      " + ("ON" if game.reduced_motion else "OFF"),
        "文字コントラスト  " + ("HIGH" if game.high_contrast else "STANDARD"),
        "戻る  /  BACK"]
    if locked:
        labels[0] = "難易度    タイトルで変更できます"
        labels[1] = "入力      タイトルで変更できます"
    for i in range(labels.size()):
        button(labels[i],Rect2(364,180+i*69,552,51),i,i==5,locked and i<2)
    text("↑ ↓ 選択   ENTER / ← → 変更   ESC 戻る",Vector2(364,639),13,MUTED)
    text(game.render_profile,Vector2(364,668),11,MUTED,true)

func _briefing() -> void:
    draw_rect(Rect2(0,0,1280,720),Color(INK,0.75))
    text("BLACK RELAY / STREET ESCAPE",Vector2(76,76),14,AMBER,true)
    text("黒雨の街から、抜けろ。",Vector2(73,179),43,IVORY)
    text("ONE WORD. ONE SHOT. KEEP MOVING.",Vector2(77,225),19,MUTED,true)
    rule(Vector2(76,266),Vector2(1204,266))
    text("01",Vector2(77,333),15,AMBER,true)
    text("白い単語を最後まで入力すると、一発で撃破",Vector2(124,333),23,IVORY)
    text("02",Vector2(77,404),15,AMBER,true)
    text("切迫した敵には、短い CUT で足止めもできる",Vector2(124,404),20,MUTED)
    text("03",Vector2(77,475),15,AMBER,true)
    text("TAB で標的変更。ミスしても入力の進みは残る",Vector2(124,475),20,MUTED)
    draw_rect(Rect2(76,525,1128,1),Color("455258"))
    text("出口まで進み、残った影をすべて倒せ。",Vector2(77,571),18,IVORY)
    button("街へ出る  /  START",Rect2(76,608,550,58),0,true)
    text("クリック / タップ / SPACE / ENTER",Vector2(77,694),13,MUTED)
    right("ESC 一時停止  /  IME をオフ",Vector2(1204,649),13,MUTED)

func _gameplay() -> void:
    var info: Dictionary = game.STAGES[game.stage]
    text("VITALS",Vector2(32,29),11,MUTED,true)
    for i in range(game.max_hp):
        var color := IVORY if i < game.hp else Color("334044")
        if game.hp <= 2 and i < game.hp: color = CORAL
        draw_rect(Rect2(32+i*24,41,18,9),color)
    text("%d / %d" % [game.hp,game.max_hp],Vector2(32,72),11,CORAL if game.hp <= 2 else MUTED,true)
    right("%07d" % game.score,Vector2(1248,44),27,IVORY,true)
    right("SCORE",Vector2(1248,65),10,MUTED,true)
    var multiplier: int = 1 + mini(4,int(game.combo/3))
    if game.combo > 0:
        right("%d COMBO  ×%d" % [game.combo,multiplier],Vector2(1136,70),17,AMBER,true)
        var chain: float = float(_value("chain_timer",0.0))
        if chain > 0:
            draw_rect(Rect2(1022,80,114,2),Color("334044"))
            draw_rect(Rect2(1022,80,114*clampf(chain/4.0,0,1),2),AMBER)
    _route_strip(info)
    # Quiet sightline rather than a large decorative crosshair.
    var sight := Color(IVORY,0.55)
    rule(Vector2(636,329),Vector2(644,329),sight)
    rule(Vector2(640,325),Vector2(640,333),sight)
    var live := 0
    for enemy in game.enemies:
        if not is_instance_valid(enemy) or enemy.dead: continue
        live += 1
        _enemy_marker(enemy)
    var remaining: int = maxi(live,int(info.get("total",0))-int(game.stage_kills))
    centered("%02d / %02d KILLS  ·  %02d ACTIVE  ·  %02d LEFT" % [game.stage_kills,int(info.get("total",24)),live,remaining],99,11,MUTED,true)
    _combat_feedback()
    _kill_feed()
    _target_card()
    text("TAB  標的変更",Vector2(32,698),12,MUTED)
    text("BACKSPACE  リセット",Vector2(181,698),12,MUTED)
    right("ESC / TAP  一時停止",Vector2(1248,698),12,MUTED)

func _route_strip(info: Dictionary) -> void:
    var progress: float = clampf(float(_value("route_progress",game.elapsed/75.0)),0,1)
    var distance: int = ceili(47.0*(1.0-progress))
    centered("EXIT %02dm" % distance if distance>0 else "EXIT AHEAD",36,17,IVORY,true)
    var start := Vector2(526,50)
    draw_rect(Rect2(start,Vector2(228,2)),Color("425056"))
    draw_rect(Rect2(start,Vector2(228*progress,2)),AMBER)
    for mark in [0.0,0.33,0.67,1.0]:
        draw_rect(Rect2(start+Vector2(228*mark-1,-2),Vector2(3,6)),AMBER if progress>=mark else MUTED)
    centered(str(info.get("en","BLACK RAIN STREET")),72,10,MUTED,true)

func _enemy_marker(enemy: RelayEnemy) -> void:
    var camera: Camera3D = game.world.camera
    if camera.is_position_behind(enemy.global_position): return
    var point: Vector2 = camera.unproject_position(enemy.global_position+Vector3(0,enemy.label_height(),0))
    point = (point-origin)/maxf(ui_scale,0.001)
    point.x = clampf(point.x,100,1180)
    point.y = clampf(point.y-20,154,463)
    var selected: bool = enemy == game.selected
    var seconds: float = maxf(0,enemy.urgency())
    var attacking: bool = enemy.phase == "attack"
    var color := CORAL if attacking else (AMBER if selected else MUTED)
    if selected:
        var marker := Rect2(point-Vector2(85,30),Vector2(170,49))
        panel(marker,color,0.9)
        centered("TARGET %02d" % enemy.identifier,point.y-11,11,color,true,point.x)
        centered("IMPACT %.1fs" % seconds,point.y+8,12,IVORY,true,point.x)
        draw_line(point+Vector2(0,20),point+Vector2(0,29),color,1,true)
        draw_circle(point+Vector2(0,31),2,color)
    else:
        draw_circle(point,3,color)
        if seconds < 7:
            centered("! %.1fs" % seconds,point.y-12,11,CORAL,true,point.x)
    if enemy.stun > 0:
        centered("STAGGER",point.y+47,10,CYAN,true,point.x)
    elif attacking:
        centered("ATTACK",point.y+47,10,CORAL,true,point.x)

func _kill_feed() -> void:
    var entries: Array = _value("kill_feed",[])
    for i in range(mini(3,entries.size())):
        var entry: Dictionary = entries[i]
        var alpha: float = clampf(float(entry.get("time",0.0))*1.5,0,1)
        text(str(entry.get("text","")),Vector2(32,110+i*19),10,Color(CYAN if i==0 else MUTED,alpha),true)

func _combat_feedback() -> void:
    if float(_value("chain_clear_flash",0.0)) > 0:
        var alpha: float = minf(1,float(_value("chain_clear_flash",0.0))*1.5)
        var count: int = int(_value("chain_count",2))
        centered("CHAIN CLEAR",205,30,Color(AMBER,alpha),true)
        centered("%d KILLS  +%d" % [count,count*100],234,15,Color(IVORY,alpha),true)
    elif game.kill_flash > 0:
        var alpha: float = minf(1,game.kill_flash*1.5)
        var award: int = int(_value("last_award",0))
        centered("KILL" + ("  +%d" % award if award>0 else ""),213,34,Color(IVORY,alpha),true)
        if game.combo >= 2:
            centered("%d COMBO" % game.combo,242,17,Color(AMBER,alpha),true)
        # Completion tick is offset from both the sightline and typed word.
        draw_line(Vector2(624,176),Vector2(634,185),Color(CYAN,alpha),2,true)
        draw_line(Vector2(634,185),Vector2(655,164),Color(CYAN,alpha),2,true)
    elif game.notice_time > 0:
        var alpha: float = minf(1,game.notice_time*2)
        draw_rect(Rect2(324,142,632,64),Color(INK,0.78*alpha))
        centered(game.notice,168,19,Color(game.notice_color,alpha))
        centered(game.notice_sub,191,11,Color(MUTED,alpha),true)

func _target_card() -> void:
    var enemy: RelayEnemy = game.selected
    if not is_instance_valid(enemy) or enemy.dead:
        centered("KEEP MOVING / 出口へ進め",674,12,MUTED)
        return
    var rect := Rect2(338,546,604,135)
    panel(rect,IVORY,0.95)
    var seconds: float = maxf(0,enemy.urgency())
    var threat_color := CORAL if seconds < 4 else MUTED
    text("TARGET %02d  /  %s" % [enemy.identifier,_kind_name(enemy.kind)],Vector2(355,568),10,MUTED,true)
    right("IMPACT %.1fs" % seconds,Vector2(925,568),11,threat_color,true)
    var active: bool = enemy.active_word == "purge" or enemy.active_word.is_empty()
    var caption: String = enemy.purge_text
    centered(caption,605,29,IVORY)
    if game.language == 0:
        centered(enemy.purge_kana,625,12,MUTED)
    _romaji_line(enemy.purge,Rect2(361,630,558,42),36,active,IVORY)
    var hint: String = enemy.purge.hint()
    var typed_ratio: float = float(enemy.purge.typed.length())/maxf(1,float(hint.length()))
    draw_rect(Rect2(355,677,570,2),Color("334044"))
    draw_rect(Rect2(355,677,570*typed_ratio,2),CYAN)
    if game.key_flash>0 and active:
        draw_line(Vector2(338,546),Vector2(338,681),Color(CYAN,game.key_flash*0.75),3)
    if game.key_error>0:
        draw_rect(rect,Color(CORAL,game.key_error*0.8),false,2)
        text("MISS",Vector2(355,605),11,CORAL,true)
    if _cut_available(enemy):
        _cut_card(enemy)
    text("一語、一発",Vector2(964,605),15,IVORY)
    text("TYPE TO KILL",Vector2(964,630),10,MUTED,true)

func _kind_name(kind: String) -> String:
    return {"hush":"WALKER","skip":"RUNNER","choir":"HEAVY","carrier":"LAST WAVE"}.get(kind,kind.to_upper())

func _cut_available(enemy: RelayEnemy) -> bool:
    if enemy.has_method("can_cut"):
        return enemy.can_cut()
    return not enemy.cut_used and (enemy.phase=="attack" or enemy.urgency()<=7.0 or enemy.active_word=="cut")

func _cut_card(enemy: RelayEnemy) -> void:
    var rect := Rect2(150,573,168,108)
    panel(rect,AMBER,0.96)
    text("SHORT CUT / 足止め",Vector2(163,594),10,AMBER)
    centered(enemy.cut_text,621,19,AMBER,false,234)
    _romaji_line(enemy.cut,Rect2(163,627,142,31),25,enemy.active_word=="cut",AMBER)
    centered("攻撃直前なら全体停止",672,9,MUTED,false,234)

func _romaji_line(matcher: RelayRomaji, rect: Rect2, font_size: int, active: bool, color: Color) -> void:
    var hint: String = matcher.hint()
    var prefix: String = matcher.typed
    var remaining: String = hint.substr(prefix.length())
    var actual_size: int = font_size
    while MONO.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size).x > rect.size.x and actual_size>17:
        actual_size -= 1
    var full_width: float = MONO.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size).x
    var prefix_width: float = MONO.get_string_size(prefix,HORIZONTAL_ALIGNMENT_LEFT,-1,actual_size).x
    var base := Vector2(rect.position.x+(rect.size.x-full_width)*0.5,rect.end.y-6)
    text(prefix,base,actual_size,CYAN,true)
    text(remaining,base+Vector2(prefix_width,0),actual_size,color,true)
    if active:
        var caret_color := CORAL if game.key_error>0 else color
        if game.reduced_motion or fmod(t,1.0)<0.65 or game.key_flash>0:
            draw_rect(Rect2(base+Vector2(prefix_width,4),Vector2(actual_size*0.58,2)),caret_color)

func _pause() -> void:
    draw_rect(Rect2(0,0,1280,720),Color(INK,0.91))
    panel(Rect2(392,112,496,518),CYAN)
    centered("STREET ON HOLD",174,29,IVORY,true)
    centered("一時停止",213,20,MUTED)
    var labels := ["再開 / RESUME","設定 / SETTINGS","このルートをやり直す","タイトルへ戻る"]
    for i in range(4):
        button(labels[i],Rect2(436,257+i*76,408,55),i,i==0)
    centered("ESC でも再開できます",603,13,MUTED)

func _results() -> void:
    var won: bool = game.state == "victory"
    draw_rect(Rect2(0,0,1280,720),Color(INK,0.92))
    text("BLACK RELAY / RUN REPORT",Vector2(76,74),14,AMBER,true)
    text("STREET CLEARED" if won else "OVERRUN",Vector2(71,152),44,IVORY if won else CORAL,true)
    text("黒雨の向こうに、出口があった。" if won else "まだ、この街を抜けられる。",Vector2(76,199),21,MUTED)
    rule(Vector2(76,239),Vector2(1204,239))
    centered(game.rank_name() if won else "×",451,143,AMBER if won else CORAL,true,210)
    centered("RUN RANK" if won else "TRY AGAIN",492,12,MUTED,true,210)
    var metrics := [
        ["SCORE","%07d" % game.score],["ACCURACY","%.1f%%" % game.accuracy()],
        ["KILLS","%d" % game.kills],["BEST CHAIN","%d" % game.best_combo],
        ["SPEED","%.1f WPM" % game.wpm()],["TIME","%04.1fs" % game.elapsed]]
    for i in range(metrics.size()):
        var x := 397.0 + (i%2)*370
        var y := 293.0 + int(i/2)*91
        text(metrics[i][0],Vector2(x,y),11,MUTED,true)
        text(metrics[i][1],Vector2(x,y+39),30,IVORY,true)
    var actions: Array = menu_actions()
    var labels: Array = ["もう一度 / RETRY","タイトルへ / TITLE"] if won else ["ルートを再開","最初から / RETRY","タイトルへ"]
    var width := 350.0 if won else 300.0
    var start := 274.0 if won else 163.0
    for i in range(actions.size()):
        button(labels[i],Rect2(start+i*(width+22),586,width,57),i,i==0)
    text("%s / %s  BEST %07d" % [["ASSIST","STANDARD","OVERDRIVE"][game.difficulty],["JP","EN"][game.language],game.best_score],Vector2(76,679),12,MUTED,true)
    right("R  最初から再挑戦",Vector2(1204,679),13,MUTED)
    var credit: String = ASSET_CREDIT
    if not credit.is_empty(): centered(credit,711,9,MUTED)

func _ending() -> void:
    var fade: float = clampf(game.intermission_time/5,0,1)
    draw_rect(Rect2(0,0,1280,720),Color(INK,fade*0.6))
    centered("OUT OF THE BLACK RAIN",316,31,IVORY,true)
    centered("この夜を、生きて抜けた。",362,24,CYAN)
    centered("STREET ESCAPE COMPLETE",405,12,MUTED,true)
