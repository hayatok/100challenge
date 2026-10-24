extends SceneTree
## Run from the game project with --script ../docs/verification/prototype/ui-web-logical/capture_ui.gd.
## Uses the real interface scene and synthetic values; never writes player records.
var _failures: Array[String] = []
var _rows: Array = []
var _ui: CanvasLayer

func _initialize() -> void:
	_run.call_deferred()

func _expect(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
		push_error(message)

func _controls(node: Node) -> Array[Control]:
	var values: Array[Control] = []
	if node is Control and node.is_visible_in_tree():
		values.append(node)
	for child in node.get_children():
		values.append_array(_controls(child))
	return values

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://../docs/verification/prototype/ui-web-logical/").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	_ui = load("res://scenes/interface.tscn").instantiate()
	root.add_child(_ui)
	var data := {"time": 94.56, "score": 120450, "falls": 2, "best_time": 92.32,
		"best_score": 150200, "saved": false, "speed": 31.4, "energy": 68,
		"section": "2 / 3", "progress": 0.45, "flow": 1.75, "count": 3}
	for viewport_size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = viewport_size
		for screen in ["title", "countdown", "run", "pause", "results", "settings", "error"]:
			_ui.set_screen(screen, data)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var pixels := root.get_texture().get_image()
			var logical_size := root.get_visible_rect().size
			_expect(logical_size.is_equal_approx(Vector2(viewport_size)), "Fixture logical size must equal actual window size")
			_expect(_ui._root.size.is_equal_approx(logical_size), "UI root must fill the true logical viewport")
			var css_scale := Vector2(viewport_size) / logical_size
			var legend_rect: Rect2 = _ui._legend.get_global_rect()
			var legend_text_size: Vector2 = _ui._legend.get_minimum_size()
			var legend_text_rect := Rect2(legend_rect.get_center() - legend_text_size / 2, legend_text_size)
			var countdown_overlap := 0.0
			if screen == "countdown":
				var countdown_panel: Rect2 = _ui._count.get_parent().get_parent().get_global_rect()
				countdown_overlap = countdown_panel.intersection(legend_text_rect).size.y
				_expect(not countdown_panel.intersects(legend_text_rect), "countdown at %s: panel overlaps control legend text" % viewport_size)
			var controls: Array = []
			var panels: Array = []
			var labels: Array = []
			for control in _controls(_ui):
				var rect := control.get_global_rect()
				if control is BaseButton or control is Slider:
					var physical := rect.size * css_scale
					controls.append({"name": control.name, "logical_size": [rect.size.x, rect.size.y],
						"window_point_size": [physical.x, physical.y]})
					_expect(physical.y >= 44.0, "%s at %s: control shorter than 44 window points" % [screen, viewport_size])
					_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= logical_size.x and rect.end.y <= logical_size.y,
						"%s at %s: control outside viewport" % [screen, viewport_size])
					if control is Button and not control is CheckButton:
						var text_width := control.get_theme_font("font").get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x
						_expect(text_width <= rect.size.x - 74, "%s: button text clipped" % screen)
				if control is Label:
					var minimum := control.get_minimum_size()
					var font_size := control.get_theme_font_size("font_size")
					var font := control.get_theme_font("font")
					var text_width := 0.0
					for line in control.text.split("\n"):
						text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
					labels.append({"text": control.text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "font_size": font_size, "minimum_height": minimum.y, "unwrapped_text_width": text_width})
					_expect(rect.size.y >= minimum.y, "%s: label height clipped" % screen)
					if control.autowrap_mode == TextServer.AUTOWRAP_OFF and control.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
						_expect(rect.size.x + 0.5 >= text_width, "%s: label text width clipped" % screen)
				if control is PanelContainer:
					panels.append({"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]})
					_expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= logical_size.x and rect.end.y <= logical_size.y,
						"%s at %s: panel outside viewport" % [screen, viewport_size])
			var filename := "%s-%dx%d.png" % [screen, viewport_size.x, viewport_size.y]
			_expect(pixels.save_png(output.path_join(filename)) == OK, "Capture failed: " + filename)
			_rows.append({"screen": screen, "window_size": [viewport_size.x, viewport_size.y],
				"logical_viewport": [logical_size.x, logical_size.y],
				"ui_root_size": [_ui._root.size.x, _ui._root.size.y],
				"image_size": [pixels.get_width(), pixels.get_height()],
				"logical_to_window_points": [css_scale.x, css_scale.y],
				"legend_text_rect": [legend_text_rect.position.x, legend_text_rect.position.y, legend_text_rect.size.x, legend_text_rect.size.y],
				"countdown_legend_text_overlap_height": countdown_overlap,
				"controls": controls, "labels": labels, "panels": panels, "file": filename})
	var evidence := {"godot": Engine.get_version_info().string, "fixture": "Native simulation of Web DPR1 logical UI with Window stretch disabled; real interface scene, synthetic data, engine clear-color backdrop",
		"project_stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode"),
		"fixture_content_scale_mode": root.content_scale_mode,
		"fixture_content_scale_factor": root.content_scale_factor,
		"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect"),
		"cases": _rows, "failures": _failures}
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()
	print("UI_WEB_LOGICAL_CAPTURE: %d cases, %d failures" % [_rows.size(), _failures.size()])
	root.remove_child(_ui)
	_ui.free()
	quit(0 if _failures.is_empty() else 1)
