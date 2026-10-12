class_name PhysicsLayers
extends RefCounted
## DATA — the one place collision layer bits are defined.
##
## Every body and area sets collision_layer / collision_mask from these constants, never
## from raw numbers. Raw numbers already caused one bug: the interactables masked bit 2
## while the player sat on the default bit 1, so no interactable ever detected the
## player. The names also appear in project.godot under layer_names/3d_physics.
##
##   WORLD         walls, floor, furniture, statues: anything solid.
##   PLAYER        the player's CharacterBody3D.
##   INTERACTABLE  Area3D zones the player walks into (doors, props, anchors).

const WORLD := 1
const PLAYER := 2
const INTERACTABLE := 4


## Configure an Area3D that should notice only the player.
static func make_player_sensor(area: Area3D) -> void:
	area.collision_layer = INTERACTABLE
	area.collision_mask = PLAYER
