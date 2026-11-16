extends Node
## PROTOTYPE ONLY. Exists so Animation value-track paths resolve in the editor.
## The simulation never reads these fields; the pure sampler reads the Animation.

@export var hitbox_extent: Vector2 = Vector2(12, 8)
@export var hitbox_offset: Vector2 = Vector2(14, 0)
@export var hurtbox_extent: Vector2 = Vector2(30, 46)
@export var hurtbox_offset: Vector2 = Vector2.ZERO
@export var phase: int = 0
@export var hitbox_active: bool = false
