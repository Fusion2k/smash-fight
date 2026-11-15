extends Control
const Model = preload("res://chronology/model.gd")
var runs := []
var selected := 0
var frame := 0
var detail: RichTextLabel
var canvas: Control
var native_observations := []

func _ready() -> void:
	measure_native_boundaries()
	for f in Model.fixtures():
		if f.has("boundary"):
			var probe: Dictionary = native_observations[1 if f.boundary.get("landing",false) else 0]
			f.boundary.time = probe.fraction
		var result := Model.simulate(f.bodies, f.get("pause",false), f.get("boundary",{}))
		result.name = f.name
		runs.append(result)
	var evidence := {"engine":Engine.get_version_info().string,"tie_epsilon_normalized_step":Model.TIE_EPS,"type":"Analytic swept-AABB model executed in Godot; separate native surface probes", "native_surface_probes":native_observations,"runs":runs}
	var file := FileAccess.open("res://chronology/observations.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	if "--measure" in OS.get_cmdline_user_args():
		print(JSON.stringify({"scenario_count":runs.size(),"native_surface_probes":native_observations}))
		get_tree().quit()
		return
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",10)
	add_child(root)
	var title := Label.new()
	title.text = "THROWAWAY #13 â€” chronological contacts"
	root.add_child(title)
	var intro := Label.new()
	intro.text = "Analytic rectangles: distinct hits, true ties and changed future motion.\nNative probes measure wall/floor boundaries separately. Formula/tolerance provisional."
	root.add_child(intro)
	var picker := OptionButton.new()
	for run in runs: picker.add_item(run.name)
	picker.item_selected.connect(func(i): selected=i; frame=0; refresh())
	root.add_child(picker)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var reset := Button.new()
	reset.text = "Restart"
	reset.pressed.connect(func(): frame=0; refresh())
	buttons.add_child(reset)
	var next := Button.new()
	next.text = "Next event"
	next.pressed.connect(func(): frame=mini(frame+1,runs[selected].frames.size()-1); refresh())
	buttons.add_child(next)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(1000,230)
	canvas.draw.connect(draw_state)
	root.add_child(canvas)
	detail = RichTextLabel.new()
	detail.custom_minimum_size = Vector2(1000,350)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail)
	refresh()

func refresh() -> void:
	var run: Dictionary = runs[selected]
	var snapshot: Dictionary = run.frames[frame]
	var lines := "Completed: %s | Frame %d / %d | step fraction %.9f\n" % [run.completed,frame+1,run.frames.size(),snapshot.time]
	for b in snapshot.bodies:
		lines += "%s position %s velocity %s damage %.1f attack %s paused %s\n" % [b.id,b.p,b.v,b.damage,b.active,b.paused]
	lines += "\nInitial candidates (before hits change trajectories):\n" + JSON.stringify(run.initial_candidates) + "\n\nResolved events:\n" + JSON.stringify(run.events,"  ")
	detail.text = lines
	canvas.queue_redraw()

func draw_state() -> void:
	var run: Dictionary = runs[selected]
	var snapshot: Dictionary = run.frames[frame]
	var colors := [Color.CORAL,Color.SKY_BLUE,Color.GOLD]
	for i in range(snapshot.bodies.size()):
		var b: Dictionary = snapshot.bodies[i]
		var p: Vector2 = Vector2(420,90) + b.p*12
		var color: Color = colors[i%3]
		canvas.draw_rect(Rect2(p-Vector2(12,12),Vector2(24,24)),color,false,2)
		canvas.draw_string(ThemeDB.fallback_font,p+Vector2(0,-18),b.id,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		for n in range(1,frame+1):
			var from: Vector2 = run.frames[n-1].bodies[i].p
			var to: Vector2 = run.frames[n].bodies[i].p
			canvas.draw_line(Vector2(420,90)+from*12,Vector2(420,90)+to*12,color,2)

func measure_native_boundaries() -> void:
	for spec in [{"name":"wall","position":Vector2(6,0),"size":Vector2(2,100)}, {"name":"floor","position":Vector2(0,7),"size":Vector2(100,2)}]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size=spec.size
		shape.shape=rect
		wall.add_child(shape)
		wall.position=spec.position
		add_child(wall)
		var actor := CharacterBody2D.new()
		var actor_shape := CollisionShape2D.new()
		var actor_rect := RectangleShape2D.new()
		actor_rect.size=Vector2(2,2)
		actor_shape.shape=actor_rect
		actor.add_child(actor_shape)
		add_child(actor)
		var collision := actor.move_and_collide(Vector2(10,10),true,0.00001)
		native_observations.append({"fixture":spec.name,"hit":collision != null,"travel":collision.get_travel() if collision else Vector2.ZERO,"normal":collision.get_normal() if collision else Vector2.ZERO,"fraction":collision.get_travel().x/10 if collision else -1})
		actor.free()
		wall.free()
