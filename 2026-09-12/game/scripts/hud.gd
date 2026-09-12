extends CanvasLayer
var game: KaijuGame
var loadout_index: int = -1
func bind_game(owner_game: KaijuGame) -> void:
	game = owner_game
	%Start.pressed.connect(game.start)
	%Resume.pressed.connect(game.resume)
	%Retry.pressed.connect(game.retry)
	%ToTitle.pressed.connect(game.return_to_title)
	%Choose0.pressed.connect(func():game.set_mutation(0))
	%Choose1.pressed.connect(func():game.set_mutation(1))
	%Choose2.pressed.connect(func():game.set_mutation(2))
	%Evolve.pressed.connect(func():game.set_mutation(game.player.mutation))
	%Loadout.pressed.connect(cycle_loadout)
func hide_layers() -> void:
	%Title.hide()
	%Play.hide()
	%Menu.hide()
	%Mutation.hide()
func show_title() -> void:
	hide_layers()
	%Title.show()
	%Loadout.visible = not game.unlocked.is_empty()
	%Start.grab_focus()
func show_play() -> void:
	hide_layers()
	%Play.show()
func show_pause() -> void:
	hide_layers()
	%Menu.show()
	%MenuTitle.text = "ひとやすみ"
	%MenuText.text = "WASD：移動　マウス：向き\n左クリック：かじる\nSpace：突進　右クリック：変異技"
	%Resume.show()
	%Resume.grab_focus()
func show_result(won: bool) -> void:
	hide_layers()
	%Menu.show()
	%MenuTitle.text = "おなかいっぱい！" if won else "今日は、ここまで。"
	var duration := "%d分%02d秒" % [int(game.elapsed)/60,int(game.elapsed)%60]
	%MenuText.text = ("ドーザンを撃破！\n" if won else "射線を切って、隙に飛び込もう。\n")+"食べたもの  %d個　 /　%s\n" % [game.eaten,duration]
	if not game.unlocked.is_empty():%MenuText.text += "覚えた変異は、次の冒険の最初から選べます。"
	%Resume.hide()
	%Retry.grab_focus()
func show_mutation(evolution: bool) -> void:
	hide_layers()
	%Mutation.show()
	%MutationTitle.text = "さらに、大きく。さらに、強く。" if evolution else "どんな怪獣に育とう？"
	%MutationSub.text = "得意な壊し方が、もっと広がる。" if evolution else "姿も、街の壊し方も変わる。"
	for i in 3:
		get_node("Root/Mutation/Choose"+str(i)).visible = not evolution
		get_node("Root/Mutation/Card"+str(i)).visible = not evolution or game.player.mutation == i
		get_node("Root/Mutation/ChoiceTitle"+str(i)).visible = not evolution or game.player.mutation == i
		get_node("Root/Mutation/ChoiceBody"+str(i)).visible = not evolution or game.player.mutation == i
	%Evolve.visible = evolution
	if evolution:
		var descriptions := ["連鎖する相手が4体から6体へ。\nより遠くの金属まで雷が届く。","突き抜ける距離と装甲破壊が強化。\n硬い敵と建物を一列に崩す。","着地の衝撃波がさらに広がる。\n囲んだ敵をまとめて押し返す。"]
		get_node("Root/Mutation/ChoiceBody"+str(game.player.mutation)).text = descriptions[game.player.mutation]
		%Evolve.grab_focus()
	else:%Choose0.grab_focus()
func set_notice(message: String) -> void:%Notice.text = message
func refresh() -> void:
	%Health.text = "体力  %d" % ceili(game.health)
	%Size.text = ["ちび怪獣","まんぷく怪獣","大怪獣"][game.player.stage]
	%Growth.max_value = 100 if game.player.stage == 0 else 340
	%Growth.value = game.growth
	%GrowthText.text = "次の成長  %d / %d" % [game.growth,int(%Growth.max_value)] if game.player.stage < 2 else "街の主役は、きみだ。"
	%Dash.text = "突進  "+["○ ○","● ○","● ●"][game.player.charges]
	if game.player.mutation >= 0:
		%Ability.text = game.MUTATION_NAMES[game.player.mutation]+("  あと%.1f秒" % game.player.ability_cooldown if game.player.ability_cooldown > 0 else "  右クリック")
	%Objective.text = "食べて育って、工事広場へ" if game.player.stage < 2 else "大通りの奥へ。ドーザンを倒そう"
	if is_instance_valid(game.boss):%Boss.text = "ドーザン  "+("コア露出！" if game.boss.exposed else "突進を横へかわそう")+"  [%d]" % maxi(0,game.boss.cores_left)
func pulse_growth() -> void:
	var tween := create_tween()
	tween.tween_property(%Growth,"modulate",Color(1.5,1.4,1.1),.08)
	tween.tween_property(%Growth,"modulate",Color.WHITE,.24)
func cycle_loadout() -> void:
	loadout_index += 1
	if loadout_index >= game.unlocked.size():loadout_index = -1
	game.selected_start = -1 if loadout_index < 0 else game.unlocked[loadout_index]
	%Loadout.text = "最初のすがた："+("まっさら" if game.selected_start < 0 else game.MUTATION_NAMES[game.selected_start])
