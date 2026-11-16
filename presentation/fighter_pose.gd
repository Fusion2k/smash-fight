class_name FighterPose
extends Resource
## Editor-authored artwork transforms only. Simulation owns all timing/geometry.
@export var pose_name: StringName
@export var startup := Transform2D.IDENTITY
@export var active := Transform2D.IDENTITY
@export var recovery := Transform2D.IDENTITY
## Feet Y offsets for startup / active / recovery, in artwork coordinates.
@export var feet_y := Vector3.ZERO
