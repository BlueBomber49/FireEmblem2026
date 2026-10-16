extends GutTest

const ForecastScene: PackedScene = preload("res://scenes/ui/combat_forecast.tscn")

var _forecast: CombatForecast


func before_each() -> void:
	_forecast = ForecastScene.instantiate() as CombatForecast
	add_child_autofree(_forecast)


func _side(unit_name: String) -> ForecastSide:
	var side := ForecastSide.new()
	side.unit_name = unit_name
	side.weapon_name = "Iron Sword"
	side.hp = 20
	side.damage = 7
	side.hit = 85
	side.crit = 5
	return side


func _label(unique_name: String) -> Label:
	return _forecast.get_node("%" + unique_name) as Label


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_forecast._unhandled_input(event)


func test_starts_hidden() -> void:
	assert_false(_forecast.visible)


func test_open_shows_both_sides() -> void:
	var enemy := _side("Bandit")
	enemy.hp = 25
	enemy.hit = 62
	_forecast.open(_side("Eirika"), enemy)
	assert_true(_forecast.visible)
	assert_eq(_label("PlayerName").text, "Eirika")
	assert_eq(_label("PlayerWeapon").text, "Iron Sword")
	assert_eq(_label("PlayerHp").text, "20")
	assert_eq(_label("PlayerDamage").text, "7")
	assert_eq(_label("EnemyName").text, "Bandit")
	assert_eq(_label("EnemyHp").text, "25")
	assert_eq(_label("EnemyHit").text, "62")


func test_count_shows_only_when_attacking_more_than_once() -> void:
	var player := _side("Eirika")
	player.attack_count = 2
	_forecast.open(player, _side("Bandit"))
	assert_true(_label("PlayerCount").visible)
	assert_eq(_label("PlayerCount").text, "x2")
	assert_false(_label("EnemyCount").visible)


func test_no_counter_shows_dashes() -> void:
	var enemy := _side("Archer")
	enemy.can_counter = false
	enemy.attack_count = 2
	_forecast.open(_side("Eirika"), enemy)
	assert_eq(_label("EnemyDamage").text, "--")
	assert_eq(_label("EnemyHit").text, "--")
	assert_eq(_label("EnemyCrit").text, "--")
	assert_false(_label("EnemyCount").visible)


func test_advantage_markers() -> void:
	var player := _side("Eirika")
	player.advantage = 1
	var enemy := _side("Bandit")
	enemy.advantage = -1
	_forecast.open(player, enemy)
	assert_eq(_label("PlayerAdvantage").text, "+")
	assert_eq(_label("EnemyAdvantage").text, "-")

	_forecast.open(_side("Eirika"), _side("Bandit"))
	assert_false(_label("PlayerAdvantage").visible)
	assert_false(_label("EnemyAdvantage").visible)


func test_confirm_closes_and_emits_confirmed() -> void:
	watch_signals(_forecast)
	_forecast.open(_side("Eirika"), _side("Bandit"))
	_press(&"confirm")
	assert_signal_emitted(_forecast, "confirmed")
	assert_false(_forecast.visible)


## The real keys, not just the action, so a missing binding in project.godot fails here.
func test_every_accept_key_confirms() -> void:
	watch_signals(_forecast)
	var keys: Array[Key] = [KEY_Z, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	for i in keys.size():
		var key := keys[i]
		_forecast.open(_side("Eirika"), _side("Bandit"))
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = true
		_forecast._unhandled_input(event)
		assert_signal_emit_count(_forecast, "confirmed", i + 1, OS.get_keycode_string(key))
		assert_false(_forecast.visible, OS.get_keycode_string(key))


func test_cancel_closes_and_emits_cancelled() -> void:
	watch_signals(_forecast)
	_forecast.open(_side("Eirika"), _side("Bandit"))
	_press(&"cancel")
	assert_signal_emitted(_forecast, "cancelled")
	assert_false(_forecast.visible)


func test_set_side_moves_panel_to_right_corner() -> void:
	_forecast.open(_side("Eirika"), _side("Bandit"))
	_forecast.set_side(CombatForecast.ScreenSide.RIGHT)
	assert_eq(_forecast.anchor_left, 1.0)
	assert_eq(_forecast.anchor_right, 1.0)
	_forecast.set_side(CombatForecast.ScreenSide.LEFT)
	assert_eq(_forecast.anchor_left, 0.0)
