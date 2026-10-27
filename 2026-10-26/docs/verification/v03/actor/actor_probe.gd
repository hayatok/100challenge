extends SceneTree
const Actor = preload("res://scenes/actor.tscn")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func verify() -> void:
	var actor = Actor.instantiate()
	root.add_child(actor)
	await process_frame
	for character: String in ["isana","ritsu","kohaku","sui"]:
		actor.configure(null, character, true, false)
		check(actor.crew.visible and not actor.sprite.visible, character + " uses full directional art with null configure texture")
		check(not actor.has_node("Facing/BodyPivot/LeftFoot") and not actor.has_node("Facing/BodyPivot/RightFoot"), character + " has no rectangular foot slices")
		for direction: Vector2 in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
			actor.face(direction)
			var expected := "side" if direction.x != 0 else "up" if direction.y < 0 else "down"
			check(actor.crew.animation == expected, character + " actual directional source selected")
			check(actor.crew.sprite_frames.get_frame_count(expected) == 2, character + " two editable contact poses")
			check(actor.get_node("Facing").scale.x == (-1.0 if direction.x < 0 else 1.0), character + " only side-left mirrors")
		actor.face(Vector2.RIGHT)
		await process_frame
		await process_frame
		actor.position = Vector2.ZERO
		actor.move_to(Vector2(64,0))
		var step_count: int = actor._step_count
		actor.move_to(Vector2(64,0))
		check(actor._step_count == step_count, character + " repeated presentation of same resolved destination does not replay a step")
		await create_timer(0.18).timeout
		var first_contact: int = actor.crew.frame
		check(first_contact == 1, character + " first step lands opposite contact")
		await create_timer(0.12).timeout
		check(actor.position == Vector2(64,0), character + " movement settles at resolved cell")
		actor.move_to(Vector2(128,0))
		await create_timer(0.18).timeout
		check(actor.crew.frame != first_contact, character + " consecutive steps alternate contact")
		await create_timer(0.12).timeout
		var idle_feet: Vector2 = actor.body.position
		await create_timer(0.12).timeout
		check(actor.body.position == idle_feet and idle_feet == Vector2.ZERO, character + " idle keeps grounded feet")
		actor.play_reaction("attack")
		await create_timer(0.075).timeout
		check(actor.weapon_pivot.rotation < -0.8, character + " weapon anticipation is visible")
		await create_timer(0.075).timeout
		check(actor.crew.frame == 1 - actor._contact_index, character + " contact changes real arm and leg silhouette")
		check(actor.action_displacement > 0, character + " contact weight shifts toward actual target")
		await create_timer(0.24).timeout
		check(actor.body.position.is_equal_approx(Vector2.ZERO) and actor.body.scale.is_equal_approx(Vector2.ONE), character + " attack recovers to grounded stance")
		actor.play_reaction("hurt", Vector2.LEFT)
		await create_timer(0.065).timeout
		check(actor.body.position.x < -1, character + " recoil moves away from actual attacker")
		await create_timer(0.26).timeout
		actor.move_to(Vector2(192,0))
		await create_timer(0.055).timeout
		actor.set_presentation_paused(true)
		var snapshot := [actor.position,actor.crew.frame,actor.weapon_pivot.rotation,actor.animation.current_animation_position]
		await create_timer(0.18).timeout
		check(snapshot == [actor.position,actor.crew.frame,actor.weapon_pivot.rotation,actor.animation.current_animation_position], character + " local pause freezes move/contact/tool clips")
		actor.set_presentation_paused(false)
		await create_timer(0.3).timeout
		check(actor.position == Vector2(192,0), character + " resume completes same movement")
		actor.play_reaction("attack")
		await create_timer(0.04).timeout
		actor._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		var phase: float = actor.animation.current_animation_position
		await create_timer(0.12).timeout
		check(actor.animation.current_animation_position == phase, character + " focus loss freezes anticipation")
		actor._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await create_timer(0.4).timeout
		actor.play_arrival(false)
		await create_timer(0.18).timeout
		check(actor._stage_pose == "arrival_quiet" and actor.crew.frame == actor._contact_index, character + " empty arrival does not step or celebrate")
		await create_timer(0.3).timeout
		actor.play_loss()
		await create_timer(0.65).timeout
		check(actor._stage_pose == "loss" and actor.weapon_pivot.rotation < -0.5 and actor.body.modulate.r < 1, character + " loss holds restrained lowered-tool stance")
		actor.configure(null, character, true, true)
		actor.move_to(Vector2(256,0))
		actor.play_reaction("attack")
		check(actor.position == Vector2(256,0) and actor.body.position == Vector2.ZERO and not actor.animation.is_playing(), character + " reduced motion snaps resolved position and removes loops")
		actor.play_loss()
		check(is_equal_approx(actor.weapon_pivot.rotation, -0.65) and not actor.animation.is_playing(), character + " reduced loss keeps readable static outcome")
		# Reconfigure another identity before next case to exercise reset paths.
		actor.configure(null, "sui" if character != "sui" else "isana", true, true)
	# Same-turn attack/hurt queue keeps real recoil direction after contact.
	actor.configure(null,"isana",true,false)
	actor.face(Vector2.RIGHT)
	actor.play_reaction("attack")
	await create_timer(0.025).timeout
	actor.play_reaction("hurt",Vector2.LEFT)
	await create_timer(0.38).timeout
	check(actor._action_axis.x < 0, "queued same-turn hurt preserves supplied recoil direction")
	await create_timer(0.35).timeout
	check(actor.body.position == Vector2.ZERO, "queued hurt recovers")
	# Enemies retain distinct editable anticipation durations and silhouettes.
	for enemy: String in ["crab","wader","diver"]:
		var texture: Texture2D = load("res://assets/art/%s.tres" % enemy)
		actor.configure(texture,enemy,false,false)
		actor.play_reaction("attack")
		check(actor.animation.current_animation == enemy + "_attack", enemy + " uses species attack")
		await create_timer(0.08).timeout
		check(actor.body.position != Vector2.ZERO or actor.body.scale != Vector2.ONE, enemy + " anticipation changes stance")
		await create_timer(0.5).timeout
	actor.queue_free()
	await process_frame
	print("v0.3 actor probe: %d checks, %d failures. Native resources, direction/contact/tool/recoil/stage/pause/reduced behavior; no human playtest." % [checks,failures])
	quit(1 if failures else 0)
