extends SceneTree
## PROTOTYPE ONLY. Clicks "Run to end" through the real UI, then captures.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://prototype/animation_moves/animation_moves_lab.tscn") as PackedScene
	var lab := packed.instantiate()
	root.add_child(lab)
	var button := _find_button(lab, "Run to end")
	if button == null:
		push_error("PROTOTYPE: Run to end button missing")
		quit(1)
		return
	button.pressed.emit()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://prototype/animation_moves/lab_contact_capture.png"
	root.get_texture().get_image().save_png(path)
	var state: Label = _find_label(lab, "Contacts in steps:")
	print("PROTOTYPE: clicked Run to end; state=", state.text if state else "MISSING")
	print("PROTOTYPE: captured ", path)
	quit(0)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null

func _find_label(node: Node, fragment: String) -> Label:
	if node is Label and fragment in node.text:
		return node
	for child in node.get_children():
		var found := _find_label(child, fragment)
		if found:
			return found
	return null
