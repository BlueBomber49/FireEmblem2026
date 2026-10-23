class_name EnemyAICombatResult
extends RefCounted
## Combat numbers supplied by the future battle calculator to help the AI rank
## an attack. Damage is per hit; attack_count is the number of strikes.

var damage_per_hit: int = 0
var hit_chance: int = 0
var attack_count: int = 1
var can_counter: bool = true
var counter_damage_per_hit: int = 0
var counter_hit_chance: int = 0
var counter_attack_count: int = 1


func effective_damage_dealt() -> float:
	return float(damage_per_hit * attack_count * hit_chance) / 100.0


func effective_damage_taken() -> float:
	if not can_counter:
		return 0.0
	return float(counter_damage_per_hit * counter_attack_count * counter_hit_chance) / 100.0


func can_one_shot(target: Unit) -> bool:
	return target != null \
		and damage_per_hit * attack_count >= target.current_hp \
		and hit_chance >= 50
