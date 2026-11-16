extends SceneTree
## Tests actual loaded engine/project interfaces, then native Character movement.

var failures := 0

func expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	print("CHECK %s expected=%s actual=%s" % [label, str(expected), str(actual)])
	if actual != expected:
		failures += 1
		push_error("Check failed: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("timeout"):
		print("CONTROLLED_TIMEOUT: waiting for the external wall-clock guard")
		return
	if args.has("engine-error"):
		push_error("CONTROLLED_ENGINE_ERROR: exit zero must still fail the wrapper")
		quit(0)
		return
	if args.has("failure"):
		expect_equal("controlled assertion", false, true)
	else:
		expect_equal("engine", Engine.get_version_info().string, "4.7.2-stable (official)")
		expect_equal("renderer", ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")
		expect_equal("logical width", root.content_scale_size.x, 1280)
		expect_equal("logical height", root.content_scale_size.y, 720)
		expect_equal("canvas items", root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
		expect_equal("keep aspect", root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_KEEP)
		expect_equal("fractional scaling", root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	if failures:
		quit(1)
	else:
		print("CHECKS_PASSED foundation")
		failures += await load("res://checks/movement.gd").new().run(self)
		quit(1 if failures else 0)
