extends Node2D
## Short, node-based responses. All tweens are bound to this presentation subtree.

var reduced_motion := false
var _font: Font = preload("res://assets/fonts/NotoSansCJKjp-Medium.otf")

func step(at: Vector2, flooded: bool, direction: Vector2) -> void:
	if reduced_motion:
		return
	if flooded:
		ripple(at + Vector2(0, 20), 0.55, Color(0.95, 1.0, 0.94, 0.85), 1.8)
	else:
		for i in 3:
			var dust := Polygon2D.new()
			dust.position = at + Vector2((i - 1) * 6, 21)
			dust.polygon = _diamond(3.5 + i, 2.0)
			dust.color = Color(0.94, 0.86, 0.65, 0.6)
			add_child(dust)
			var tween := dust.create_tween().set_parallel(true)
			tween.tween_property(dust, "position", dust.position - direction * (7 + i * 4) + Vector2((i - 1) * 8, -5), 0.3)
			tween.tween_property(dust, "scale", Vector2.ONE * 1.7, 0.3)
			tween.tween_property(dust, "modulate:a", 0.0, 0.3)
			tween.chain().tween_callback(dust.queue_free)

func schedule(delay: float, callback: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(0.0 if reduced_motion else delay)
	tween.tween_callback(func():
		if callback.is_valid():
			callback.call())

func strike(at: Vector2, direction: Vector2, heavy: bool = false) -> void:
	schedule(0.2 if heavy else 0.12, _strike_contact.bind(at, direction, heavy))

func _strike_contact(at: Vector2, direction: Vector2, heavy: bool) -> void:
	var slash := Node2D.new()
	slash.position = at + Vector2(0, -15)
	slash.rotation = direction.angle()
	add_child(slash)
	for layer in 2:
		var arc := Line2D.new()
		for i in 15:
			var angle := lerpf(-1.25, 1.25, float(i) / 14.0)
			arc.add_point(Vector2(cos(angle) * (31 + layer * 5), sin(angle) * (31 + layer * 5)))
		arc.width = (8.0 if heavy else 5.0) - layer * 2.0
		arc.default_color = Color("fff9d9") if layer == 0 else Color("efaa4e")
		arc.antialiased = true
		slash.add_child(arc)
	var tween := slash.create_tween()
	if not reduced_motion:
		slash.scale = Vector2(0.25, 0.7)
		tween.set_parallel(true)
		tween.tween_property(slash, "scale", Vector2(1.05, 1.0), 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "rotation", slash.rotation + 0.25, 0.16)
		tween.chain()
	tween.tween_property(slash, "modulate:a", 0.0, 0.13)
	tween.tween_callback(slash.queue_free)
	impact(at, Color("ffd17a"), 10 if heavy else 7)

func impact(at: Vector2, color: Color, count: int = 8) -> void:
	var duration := 0.22 if reduced_motion else 0.38
	for i in count:
		var particle := Polygon2D.new()
		particle.position = at + Vector2(0, -16)
		var direction := Vector2.from_angle(float(i) / count * TAU - PI * 0.5)
		particle.polygon = _diamond(3.0 if i % 2 else 5.0, 1.8)
		particle.rotation = direction.angle()
		particle.color = color if i % 2 else Color("fffceb")
		add_child(particle)
		var tween := particle.create_tween().set_parallel(true)
		if not reduced_motion:
			tween.tween_property(particle, "position", particle.position + direction * (29 + i % 3 * 8), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(particle, "scale", Vector2(0.2, 0.2), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(particle.queue_free)
	if not reduced_motion:
		ripple(at + Vector2(0, 18), 0.34, Color(color, 0.5), 2.0)

func loot(at: Vector2, amount: int, rare: bool) -> void:
	var rays := Node2D.new()
	rays.position = at + Vector2(0, -18)
	add_child(rays)
	for i in 8 if rare else 6:
		var ray := Polygon2D.new()
		var angle := float(i) / (8 if rare else 6) * TAU
		ray.polygon = PackedVector2Array([Vector2(14, -1.5), Vector2(47 if rare else 35, -3), Vector2(52 if rare else 40, 0), Vector2(47 if rare else 35, 3), Vector2(14, 1.5)])
		ray.rotation = angle
		ray.color = Color(1.0, 0.79, 0.32, 0.75)
		rays.add_child(ray)
	var token := Polygon2D.new()
	token.position = at + Vector2(0, -20)
	token.polygon = _diamond(9.0, 13.0)
	token.color = Color("ffd36a")
	add_child(token)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(0, -13), Vector2(9, 0), Vector2(0, 13), Vector2(-9, 0), Vector2(0, -13)])
	edge.width = 2
	edge.default_color = Color("9d6b30")
	token.add_child(edge)
	var tween := rays.create_tween().set_parallel(true)
	if not reduced_motion:
		rays.scale = Vector2.ONE * 0.3
		tween.tween_property(rays, "scale", Vector2.ONE * 1.2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(rays, "rotation", 0.3, 0.6)
	tween.tween_property(rays, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(rays.queue_free)
	var rise := token.create_tween()
	if not reduced_motion:
		rise.tween_property(token, "position:y", token.position.y - 44, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		rise.tween_interval(0.3)
	rise.tween_property(token, "modulate:a", 0.0, 0.2)
	rise.tween_callback(token.queue_free)
	number("+%d" % amount, at + Vector2(22, -38), Color("c37a1c"), 24)

func ripple(at: Vector2, duration: float = 0.65, color: Color = Color(0.95, 1.0, 0.96, 0.8), expansion: float = 3.0) -> void:
	if reduced_motion:
		return
	var ring := Line2D.new()
	for i in 33:
		var angle := float(i) / 32.0 * TAU
		ring.add_point(Vector2(cos(angle), sin(angle) * 0.45) * 15)
	ring.position = at
	ring.width = 1.8
	ring.default_color = color
	ring.antialiased = true
	add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * expansion, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)

func number(text: String, at: Vector2, color: Color, font_size: int = 28) -> void:
	var label := Label.new()
	label.text = text
	label.position = at - Vector2(48, 14)
	label.size = Vector2(96, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("fffbed"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween := label.create_tween()
	if not reduced_motion:
		label.scale = Vector2.ONE * 0.65
		tween.set_parallel(true)
		tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", label.position.y - 27, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain()
	else:
		tween.tween_interval(0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.18)
	tween.tween_callback(label.queue_free)

func wave(at: Vector2) -> void:
	if reduced_motion:
		ripple(at, 0.1)
		return
	for i in 3:
		ripple(at + Vector2((i - 1) * 40, 20), 0.85 + i * 0.12, Color(0.85, 1, 0.98, 0.8), 6.0)

func _diamond(horizontal: float, vertical: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-horizontal, 0), Vector2(0, -vertical), Vector2(horizontal, 0), Vector2(0, vertical)])
