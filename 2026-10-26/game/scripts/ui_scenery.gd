extends Control
## Decorative sky/sea motion; never reads or writes expedition state.
var scene := "title"
var reduced := false
var paused := false
var clock := 0.0
var celebration := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(which: String, reduce: bool, celebrate: bool = false) -> void:
	scene = which
	reduced = reduce
	celebration = celebrate
	clock = 0.0
	set_process(not reduced and not paused)
	queue_redraw()

func set_presentation_paused(value: bool) -> void:
	paused = value
	set_process(not reduced and not paused)

func _process(delta: float) -> void:
	clock += minf(delta, 0.05)
	queue_redraw()

func _draw() -> void:
	if scene == "expedition":
		return
	for i: int in 5:
		var x := fposmod(0.15 + i * 0.217 + clock * (0.008 + i * 0.0005), 1.3) - 0.1
		var p := Vector2(x * size.x, size.y * (0.14 + 0.022 * i) + sin(clock * 0.7 + i) * 7)
		var wing := 4.0 + sin(clock * 2.1 + i) * 2.0
		draw_polyline(PackedVector2Array([p + Vector2(-9, -wing), p + Vector2(-4, -3), p, p + Vector2(4, -3), p + Vector2(9, -wing)]), Color(1, 1, 0.94, 0.8), 1.7, true)
	for i: int in 12:
		var p := Vector2(size.x * (0.22 + fposmod(i * 0.137, 0.7)), size.y * (0.58 + fposmod(i * 0.087, 0.35)))
		var alpha := (sin(clock * 1.5 + i * 1.7) + 1.0) * 0.18
		draw_line(p - Vector2(4 + i % 3, 0), p + Vector2(4 + i % 3, 0), Color(1, 1, 0.86, alpha), 1.6, true)
	if scene == "result" and celebration and clock < 3.4:
		for i: int in 24:
			var life := fposmod(clock * 0.36 + i * 0.071, 1.0)
			var p := Vector2(size.x * fposmod(i * 0.618, 1), size.y * life)
			var colors := [Color("f4c05d"), Color("ef9580"), Color("75c9bc")]
			draw_set_transform(p, clock * 0.7 + i, Vector2.ONE)
			draw_rect(Rect2(-2.5, -4, 5, 8), colors[i % 3] * Color(1, 1, 1, minf(1, (3.4 - clock) * 2)))
			draw_set_transform(Vector2.ZERO)
