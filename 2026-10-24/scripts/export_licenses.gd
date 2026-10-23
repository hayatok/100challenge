extends SceneTree
## Run with the exact export binary: --script <this file> -- --licenses-dir <path>
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var destination := ""
	for i in range(arguments.size() - 1):
		if arguments[i] == "--licenses-dir":
			destination = arguments[i + 1]
	if destination.is_empty() or DirAccess.make_dir_recursive_absolute(destination) != OK:
		push_error("An accessible --licenses-dir is required")
		quit(1)
		return
	var version := Engine.get_version_info()
	var components := "Godot Engine " + String(version.string) + " — complete runtime component notices\n\n"
	for component in Engine.get_copyright_info():
		components += "COMPONENT: " + String(component.name) + "\n"
		for part in component.parts:
			components += "Files:\n" + "\n".join(part.files) + "\n"
			components += "Copyright:\n" + "\n".join(part.copyright) + "\n"
			components += "License expression: " + String(part.license) + "\n\n"
	components += "\nCOMPLETE LICENSE TEXTS REFERENCED ABOVE\n"
	var texts := Engine.get_license_info()
	var names := texts.keys()
	names.sort()
	for name in names:
		components += "\n============================================================\n" + String(name) + "\n============================================================\n" + String(texts[name]) + "\n"
	var font := FileAccess.get_file_as_string("res://assets/fonts/LICENSE.txt")
	if font.is_empty():
		push_error("Bundled font license is missing")
		quit(1)
		return
	var notices := "TENSAI third-party notices\n\nGodot Engine " + String(version.string) + "\nMIT license: GODOT_LICENSE.txt\nComplete engine component copyrights and license bodies: GODOT_COPYRIGHT.txt\nhttps://godotengine.org/license/\n\nNoto Sans CJK JP Medium, Version 2.004\nCopyright © 2014–2021 Adobe (http://www.adobe.com/).\nSIL Open Font License 1.1: NOTO_OFL.txt\nhttps://github.com/notofonts/noto-cjk/tree/main/Sans\n\nCharacter models and synthesized sound are original TENSAI assets.\n"
	var files := {"GODOT_LICENSE.txt":Engine.get_license_text(), "GODOT_COPYRIGHT.txt":components, "NOTO_OFL.txt":"Copyright © 2014–2021 Adobe (http://www.adobe.com/).\n\n" + font, "NOTICES.txt":notices, "index.html":"<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>TENSAI licenses</title><body><h1>TENSAI licenses</h1><ul><li><a href=\"NOTICES.txt\">Component notices</a></li><li><a href=\"GODOT_LICENSE.txt\">Godot MIT license</a></li><li><a href=\"GODOT_COPYRIGHT.txt\">Godot third-party copyrights and full licenses</a></li><li><a href=\"NOTO_OFL.txt\">Noto font copyright and SIL OFL</a></li></ul></body></html>\n"}
	for name in files:
		var file := FileAccess.open(destination.path_join(name), FileAccess.WRITE)
		if file == null:
			push_error("Cannot write license: " + String(name))
			quit(1)
			return
		file.store_string(String(files[name]))
		file.close()
	print("Exported complete runtime notices for ", version.string)
	quit()
