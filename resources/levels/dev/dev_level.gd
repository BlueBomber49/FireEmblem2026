extends Node
## Plays one of the dev test levels in this folder. Each level has its own
## scene (e.g. seize.tscn) that sets `level`; open it and run it with F6.

const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")

@export_file("*.json") var level := ""
## Enemy unit ids that hold their position until killed. Levels can't set
## enemy strategies yet, so this does it in code at startup.
@export var stationary: Array[String] = []


func _ready() -> void:
	var battle: Battle = BattleScene.instantiate()
	# Set before the battle enters the tree: its Level loads the file in _ready.
	(battle.get_node("Level") as Level).level_path = level
	add_child(battle)
	for unit_id in stationary:
		battle.turn_loop.enemy_controller.set_strategy(unit_id, EnemyAI.Strategy.STATIONARY)
