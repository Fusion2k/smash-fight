extends Node2D
## Export-only platform/content probe. No Match, combat or controller ownership claims.
const DEFINITIONS = [preload("res://characters/zip/zip.tres"), preload("res://characters/bramble/bramble.tres")]
var status: Label
var last_input := "Press a controller button / move a stick; Escape quits."

func _ready() -> void:
	var prepared := CharacterCatalog.new().prepare_match(DEFINITIONS)
	if not prepared.ok:
		push_error("EXPORT_SMOKE_FAILED content: " + str(prepared.errors))
		get_tree().quit(1)
		return
	if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "gl_compatibility":
		push_error("EXPORT_SMOKE_FAILED renderer configuration")
		get_tree().quit(1)
		return
	for index in prepared.characters.size():
		var snapshot: PreparedCharacter = prepared.characters[index]
		var character := snapshot.instantiate_scene()
		add_child(character)
		character.position = Vector2(480 + index * 320, 420)
		character.scale = Vector2(3, 3)
		print("EXPORT_CONTENT %s mass=%s" % [snapshot.identity().character_id, snapshot.settings().mass])
	status = Label.new()
	status.position = Vector2(64, 48)
	status.add_theme_font_size_override("font_size", 24)
	add_child(status)
	Input.joy_connection_changed.connect(_connection_changed)
	print("EXPORT_SMOKE_PASSED content=Zip,Bramble json=read renderer_config=gl_compatibility exported=%s os=%s display=%s" % [OS.has_feature("template"), OS.get_name(), DisplayServer.get_name()])
	if OS.get_cmdline_user_args().has("--verify-quit"):
		get_tree().quit(0)

func _process(_delta: float) -> void:
	if status:
		status.text = "SMASH FIGHT — EXPORT SMOKE ONLY\nPrepared character content; no gameplay / controller ownership.\nLogical 1280×720 / keep aspect / Compatibility\nWindow %s   Screen %s   Pads %s\n%s\nDeck/TV/controller/60 FPS acceptance requires physical review." % [get_window().size, DisplayServer.screen_get_size(), Input.get_connected_joypads(), last_input]

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		last_input = "Pad %d %s button %d pressed=%s" % [event.device, Input.get_joy_name(event.device), event.button_index, event.pressed]
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		last_input = "Pad %d axis %d value %.2f" % [event.device, event.axis, event.axis_value]
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func _connection_changed(device: int, connected: bool) -> void:
	last_input = "Pad %d connected=%s" % [device, connected]
