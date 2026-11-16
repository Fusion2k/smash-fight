@tool
extends Node2D
## PROTOTYPE ONLY. Visible rectangle that reads the SAME animated properties the
## simulation samples. One set of animation keys therefore moves the editor
## preview and gameplay geometry together — no duplicated tracks.

@export var source: NodePath = ^"../CombatSample"
@export var extent_property: StringName = &"hitbox_extent"
@export var offset_property: StringName = &"hitbox_offset"
@export var box_color: Color = Color(0.25, 0.6, 1.0, 0.45)

var _last_extent: Vector2 = Vector2.ZERO
var _last_offset: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	sync()

func sync() -> void:
	var node := get_node_or_null(source)
	if node == null:
		return
	var extent: Variant = node.get(extent_property)
	var offset: Variant = node.get(offset_property)
	if extent is Vector2 and offset is Vector2:
		if extent != _last_extent or offset != _last_offset:
			_last_extent = extent
			_last_offset = offset
			queue_redraw()

func _draw() -> void:
	var rect := Rect2(_last_offset - _last_extent * 0.5, _last_extent)
	draw_rect(rect, box_color)
	draw_rect(rect, Color(box_color.r, box_color.g, box_color.b, 1.0), false, 1.5)
