extends GutTest
## Battle with its phase banners on (and sped up), plus the end screen. The other
## Battle tests turn the banners off so phases change instantly.

const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")
const LEVEL_PATH := "res://resources/levels/test_level.json"
const SLIDE_TIME := 0.02
const HOLD_TIME := 0.05

var battle: Battle
var banner: PhaseBanner


func before_each() -> void:
	battle = BattleScene.instantiate()
	(battle.get_node("Level") as Level).level_path = LEVEL_PATH
	banner = battle.get_node("%PhaseBanner") as PhaseBanner
	banner.slide_time = SLIDE_TIME
	banner.hold_time = HOLD_TIME
	add_child_autofree(battle)
	battle.turn_loop.enemy_controller.set_strategy(&"bandit", EnemyAI.Strategy.STATIONARY)


# Tweens and queue_freed nodes settle at the end of a frame.
func after_each() -> void:
	await get_tree().process_frame


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	battle._unhandled_input(event)


func _wait_for_banner() -> void:
	if banner.is_playing():
		await wait_for_signal(banner.finished, 1.0)


func _units(faction: UnitReference.Faction) -> Array[LevelUnitState]:
	var units: Array[LevelUnitState] = []
	for value: Variant in battle.level.level_state.level_units.values():
		var state := value as LevelUnitState
		if state.unit_ref.faction == faction:
			units.append(state)
	return units


# --- Phase banner --------------------------------------------------------------


func test_the_level_opens_with_the_player_phase_banner() -> void:
	assert_true(banner.is_playing())
	assert_eq((banner.get_node("%Title") as TextureRect).texture, PhaseBanner.ART[TurnLoop.Phase.PLAYER])


func test_the_map_ignores_input_while_the_banner_plays() -> void:
	var cell := battle.cursor.cell
	_press(&"ui_right")
	assert_eq(battle.cursor.cell, cell)
	await _wait_for_banner()
	_press(&"ui_right")
	assert_ne(battle.cursor.cell, cell, "the cursor moves once the banner is gone")


func test_the_panels_hide_until_the_banner_is_gone() -> void:
	assert_false(battle.terrain_panel.visible)
	assert_false(battle.unit_panel.visible)
	await _wait_for_banner()
	assert_true(battle.terrain_panel.visible)


func test_enemies_wait_for_the_enemy_phase_banner() -> void:
	await _wait_for_banner()
	var bandit: LevelUnitState = battle.level.level_state.level_units["bandit"]
	battle.turn_loop.end_player_turn()

	assert_eq(battle.turn_loop.phase, TurnLoop.Phase.ENEMY)
	assert_true(banner.is_playing())
	assert_eq((banner.get_node("%Title") as TextureRect).texture, PhaseBanner.ART[TurnLoop.Phase.ENEMY])
	assert_false(bandit.has_acted, "nobody acts under the banner")

	await wait_for_signal(banner.finished, 1.0)
	await wait_for_signal(banner.finished, 1.0)  # the player phase's banner
	assert_true(bandit.has_acted)
	assert_eq(battle.turn_loop.phase, TurnLoop.Phase.PLAYER)


# --- End screen ----------------------------------------------------------------


func test_beating_every_enemy_shows_stage_clear() -> void:
	await _wait_for_banner()
	for enemy in _units(UnitReference.Faction.ENEMY):
		enemy.current_hp = 0
	await battle.turn_loop.on_player_action_completed()

	assert_true(battle.end_screen.visible)
	assert_eq((battle.end_screen.get_node("%Title") as TextureRect).texture, EndScreen.CLEAR_ART)
	assert_false(battle.terrain_panel.visible)
	assert_false(battle.unit_panel.visible)


func test_losing_every_player_unit_shows_defeat() -> void:
	await _wait_for_banner()
	for unit in _units(UnitReference.Faction.PLAYER):
		unit.current_hp = 0
	await battle.turn_loop.on_player_action_completed()

	assert_true(battle.end_screen.visible)
	assert_eq((battle.end_screen.get_node("%Title") as TextureRect).texture, EndScreen.DEFEAT_ART)


func test_the_end_screen_is_hidden_during_play() -> void:
	await _wait_for_banner()
	assert_false(battle.end_screen.visible)


func test_the_end_screen_waits_for_confirm_before_the_battle_ends() -> void:
	await _wait_for_banner()
	battle.ended.connect(func(_won: bool) -> void: pass)  # as GameFlow would
	watch_signals(battle)
	for enemy in _units(UnitReference.Faction.ENEMY):
		enemy.current_hp = 0
	await battle.turn_loop.on_player_action_completed()
	assert_signal_not_emitted(battle, "ended", "not while Stage Clear is up")

	battle.end_screen.continue_requested.emit()
	assert_signal_emitted_with_parameters(battle, "ended", [true])


func test_a_defeat_hands_on_a_loss() -> void:
	await _wait_for_banner()
	battle.ended.connect(func(_won: bool) -> void: pass)
	watch_signals(battle)
	for unit in _units(UnitReference.Faction.PLAYER):
		unit.current_hp = 0
	await battle.turn_loop.on_player_action_completed()

	battle.end_screen.continue_requested.emit()
	assert_signal_emitted_with_parameters(battle, "ended", [false])


func test_the_prompt_says_continue_or_retry() -> void:
	var prompt := battle.end_screen.get_node("%Prompt") as Label
	battle.end_screen.show_result(true)
	assert_eq(prompt.text, "Press Z to continue")
	battle.end_screen.show_result(false)
	assert_eq(prompt.text, "Press Z to retry")


func test_victory_music_plays_only_on_a_win() -> void:
	await _wait_for_banner()
	for enemy in _units(UnitReference.Faction.ENEMY):
		enemy.current_hp = 0
	await battle.turn_loop.on_player_action_completed()
	assert_eq(battle.music.stream, Battle.VICTORY_MUSIC)
	assert_true(battle.music.playing)


func test_a_defeat_stops_the_music() -> void:
	await _wait_for_banner()
	for unit in _units(UnitReference.Faction.PLAYER):
		unit.current_hp = 0
	await battle.turn_loop.on_player_action_completed()
	assert_false(battle.music.playing)
