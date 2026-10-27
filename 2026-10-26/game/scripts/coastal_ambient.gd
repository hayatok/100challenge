extends Node2D
## Decorative gulls have no relationship to explored cells or game state.
var reduced_motion := false
var area := Rect2(0, 0, 700, 700)
var _time := 0.0
var _gulls: Array[Node2D] = []
func _ready() -> void:
	for i in 3:
		var gull := Node2D.new()
		var shadow := Line2D.new()
		shadow.points = PackedVector2Array([Vector2(-10, 0), Vector2(-5, -3), Vector2(0, 1), Vector2(5, -3), Vector2(10, 0)])
		shadow.width = 3.2
		shadow.default_color = Color(0.18, 0.45, 0.49, 0.16)
		shadow.position = Vector2(2, 3)
		gull.add_child(shadow)
		var wings := Line2D.new()
		wings.name = "Wings"
		wings.points = shadow.points
		wings.width = 2.2
		wings.default_color = Color(1.0, 0.99, 0.9, 0.86)
		wings.antialiased = true
		gull.add_child(wings)
		gull.scale = Vector2.ONE * (0.7 + i * 0.15)
		add_child(gull)
		_gulls.append(gull)
	_update_gulls()
func _process(delta: float) -> void:
	if reduced_motion:
		return
	_time += delta
	_update_gulls()
func _update_gulls() -> void:
	for i in _gulls.size():
		var gull := _gulls[i]
		gull.position = area.position + Vector2(fposmod(_time * (14 + i * 3) + i * 183, area.size.x + 80) - 40, area.size.y * (0.18 + i * 0.19) + sin(_time * 0.2 + i) * 10)
		var flap := sin(_time * 2.0 + i * 1.8) * 3.0
		var wings: Line2D = gull.get_node("Wings")
		wings.points = PackedVector2Array([Vector2(-10, flap), Vector2(-5, -3), Vector2(0, 1), Vector2(5, -3), Vector2(10, flap)])
