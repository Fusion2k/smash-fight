extends Control
## PROTOTYPE ONLY. Draws the sampled rectangles at 2x so extent changes are visible.

const SCALE := 2.0
var sample: Dictionary = {}
var contact: bool = false

func _draw() -> void:
	if sample.is_empty():
		return
	var attacker := Vector2(120, 150)
	var target := Vector2(120 + 40 * SCALE, 150)
	var hit_center: Vector2 = attacker + (sample["hitbox_offset"] as Vector2) * SCALE
	var hurt_center: Vector2 = target + (sample["hurtbox_offset"] as Vector2) * SCALE
	draw_line(attacker, target, Color(0.45, 0.48, 0.55), 2.0)
	_draw_box(hit_center, sample["hitbox_extent"] as Vector2, Color(0.25, 0.6, 1.0, 0.55), Color(0.25, 0.6, 1.0))
	_draw_box(hurt_center, sample["hurtbox_extent"] as Vector2, Color(0.35, 0.85, 0.5, 0.45), Color(0.35, 0.85, 0.5))
	if contact:
		draw_circle((hit_center + hurt_center) * 0.5, 10.0, Color(1.0, 0.45, 0.25))

func _draw_box(center: Vector2, extent: Vector2, fill: Color, outline: Color) -> void:
	var size := extent * SCALE
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, fill)
	draw_rect(rect, outline, false, 2.0)
