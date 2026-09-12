# Native-only visual QA. Drives the real growth/choice/result screens without writing progress.
extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
	var game: KaijuGame = load("res://main.tscn").instantiate()
	game.test_mode = true
	add_child(game)
	await get_tree().process_frame
	game.start()
	for enemy in get_tree().get_nodes_in_group("targets"):
		if enemy is TownEnemy:enemy.awareness_radius = 0
	game.feed(100,0)
	while game.state != "mutation":await get_tree().process_frame
	while game.state == "mutation":await get_tree().process_frame
	game.feed(340,0)
	while game.state != "mutation":await get_tree().process_frame
	while game.state == "mutation":await get_tree().process_frame
	game.finish(true)
