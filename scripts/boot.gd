extends Control
## Startbildschirm mit Selbst-Update.
## Beim Start fragt das Spiel kurz bei GitHub nach, ob es eine neuere Spielversion gibt.
## Wenn ja, wird nur das Spielpaket (hofkueche.pck, wenige MB) geladen und sofort benutzt.
## Kein neues APK nötig. Ohne Internet startet das Spiel einfach mit dem, was da ist.
## Wichtig: Dieses Skript darf keine anderen Spiel-Skripte (Game, Util, ...) benutzen,
## sonst wären sie geladen, bevor das Update sie ersetzen kann.

const RELEASE_URL := "https://github.com/Lukas-sys/Base_Defense_App/releases/latest/download/"
const PACK_PATH := "user://update.pck"
const PACK_VERSION_PATH := "user://update_version.txt"
const MAIN_SCENE := "res://scenes/main.tscn"
const CHECK_TIMEOUT := 4.0
const DOWNLOAD_TIMEOUT := 60.0

var apk_version := 0
var http: HTTPRequest
var label: Label
var install_button: Button
var latest := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.55, 0.72, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(label)

	apk_version = _read_int("res://version.txt")
	if not _should_check():
		_start_game()
		return
	http = HTTPRequest.new()
	http.timeout = CHECK_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_version_loaded)
	if http.request(RELEASE_URL + "version.json") != OK:
		_start_game()


func _should_check() -> bool:
	if not OS.has_feature("android") or OS.has_feature("editor"):
		return false
	return apk_version > 0  # 0 = lokal gebaut, nicht von GitHub


func _on_version_loaded(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_start_game()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_start_game()
		return
	latest = data
	var newest := int(latest.get("version", 0))
	if int(latest.get("min_apk", 0)) > apk_version:
		_offer_new_apk()
		return
	if newest > maxi(apk_version, _read_int(PACK_VERSION_PATH)):
		label.text = "Update wird geladen …"
		http.request_completed.disconnect(_on_version_loaded)
		http.request_completed.connect(_on_pack_loaded)
		http.timeout = DOWNLOAD_TIMEOUT
		http.download_file = PACK_PATH + ".tmp"
		if http.request(RELEASE_URL + "hofkueche.pck") != OK:
			_start_game()
		return
	_start_game()


func _on_pack_loaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var dir := DirAccess.open("user://")
		dir.rename(PACK_PATH + ".tmp", PACK_PATH)
		var f := FileAccess.open(PACK_VERSION_PATH, FileAccess.WRITE)
		f.store_string(str(int(latest.get("version", 0))))
		f.close()
	_start_game()


## Größere Umbauten (z. B. neue Android-Einstellungen) brauchen einmal ein neues APK.
func _offer_new_apk() -> void:
	label.text = "Neue Version verfügbar"
	label.position.y -= 80
	install_button = Button.new()
	install_button.text = "Installieren"
	install_button.add_theme_font_size_override("font_size", 34)
	install_button.custom_minimum_size = Vector2(320, 90)
	install_button.set_anchors_preset(Control.PRESET_CENTER)
	install_button.position += Vector2(-160, 20)
	install_button.pressed.connect(func(): OS.shell_open(RELEASE_URL + "Hofkueche.apk"))
	add_child(install_button)
	var later := Button.new()
	later.text = "Später"
	later.add_theme_font_size_override("font_size", 28)
	later.custom_minimum_size = Vector2(320, 70)
	later.set_anchors_preset(Control.PRESET_CENTER)
	later.position += Vector2(-160, 130)
	later.pressed.connect(_start_game)
	add_child(later)


func _start_game() -> void:
	# Ein heruntergeladenes Spielpaket benutzen, wenn es neuer ist als das installierte APK.
	if _read_int(PACK_VERSION_PATH) > apk_version and FileAccess.file_exists(PACK_PATH):
		if not ProjectSettings.load_resource_pack(PACK_PATH, true):
			push_warning("Update-Paket konnte nicht geladen werden")
	get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)


func _read_int(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	return FileAccess.get_file_as_string(path).strip_edges().to_int()
