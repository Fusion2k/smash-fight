class_name PlayerInput
extends RefCounted
## Physical reads and edge ownership; raw fixtures cross the same sample seam.
const KEYBOARD := -1
const DUMMY := -2
var _previous := {}
var _down_latched := {}

func read_device(device: int) -> Dictionary:
	if device == DUMMY:
		return {}
	if device == KEYBOARD:
		return {"x": float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			"y": float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)),
			"jump": Input.is_physical_key_pressed(KEY_SPACE), "attack": Input.is_physical_key_pressed(KEY_J),
			"special": Input.is_physical_key_pressed(KEY_K), "start": Input.is_physical_key_pressed(KEY_ESCAPE)}
	return {"x": Input.get_joy_axis(device, JOY_AXIS_LEFT_X), "y": Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
		"jump": Input.is_joy_button_pressed(device, JOY_BUTTON_A), "attack": Input.is_joy_button_pressed(device, JOY_BUTTON_X),
		"special": Input.is_joy_button_pressed(device, JOY_BUTTON_Y), "start": Input.is_joy_button_pressed(device, JOY_BUTTON_START)}

func sample(device: int, raw: Dictionary) -> Dictionary:
	var previous: Dictionary = _previous.get(device, {})
	var x := clampf(float(raw.get("x", 0)), -1, 1)
	var y := clampf(float(raw.get("y", 0)), -1, 1)
	var down: bool = y >= 0.5 and not _down_latched.get(device, false)
	if y < 0.3:
		_down_latched[device] = false
	elif y >= 0.5:
		_down_latched[device] = true
	var frame := {"horizontal": signf(x) * maxf(0, (absf(x) - 0.2) / 0.8),
		"attack_direction": "up" if y <= -0.5 else ("down" if y >= 0.5 else "neutral"),
		"down_pressed": down, "jump_held": raw.get("jump", false)}
	for action in ["jump", "attack", "special", "start"]:
		frame[action + "_pressed"] = raw.get(action, false) and not previous.get(action, false)
	frame.left_pressed = x <= -0.5 and float(previous.get("x", 0)) > -0.5
	frame.right_pressed = x >= 0.5 and float(previous.get("x", 0)) < 0.5
	_previous[device] = raw.duplicate()
	return frame

func synchronize(samples: Dictionary) -> void:
	for device in samples:
		_previous[device] = samples[device].duplicate()
		_down_latched[device] = float(samples[device].get("y", 0)) >= 0.3
