class_name MoveDefinition
extends Resource
## One rectangular melee region in character-local coordinates, facing right.

@export var move_id: StringName
@export var hitbox: Shape2D
@export var hitbox_offset: Vector2
@export_range(0, 600, 1) var startup_steps: int
@export_range(1, 600, 1) var active_steps: int = 1
@export_range(0, 600, 1) var recovery_steps: int
@export var launch_direction: Vector2 = Vector2(1, -1)
@export var launch_strength: float = 300.0
## Presentation follows simulation phase; this name never enables collision.
@export var pose_name: StringName
