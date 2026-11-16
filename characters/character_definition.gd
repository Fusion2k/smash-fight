class_name CharacterDefinition
extends Resource
## Editor-owned identity/content. Physics and damage have one authority: tuning_path.

@export var character_id: StringName
@export var display_name: String
@export var character_scene: PackedScene
@export_file("*.json") var tuning_path: String
@export var moves: Array[MoveDefinition] = []
