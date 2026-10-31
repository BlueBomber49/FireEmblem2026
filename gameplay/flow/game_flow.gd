extends Node
## Plays the campaign in order: each chapter's intro cutscene, its battle, then
## its outro. Scenes only say when they're done (Cutscene.finished,
## Battle.ended); this decides what comes next and swaps it in.
##
## Autoloaded as GameFlow (so no class_name: it would clash with the autoload).
## Nothing happens until start_chapter(), so running one scene on its own with
## F6 still works.

signal campaign_finished

enum Step { INTRO, BATTLE, OUTRO, DONE }

const CutsceneScene: PackedScene = preload("res://gameplay/cutscene/cutscene.tscn")
const BattleScene: PackedScene = preload("res://gameplay/battle.tscn")
const TitleScene: PackedScene = preload("res://gameplay/flow/title_screen.tscn")

var campaign: Campaign
var chapter_index := 0
var step := Step.DONE


## Shows the title. It isn't a Step: it sits outside the chapter order, so
## `step` is DONE while it's up.
func show_title() -> void:
	step = Step.DONE
	var title: TitleScreen = TitleScene.instantiate()
	title.new_game_chosen.connect(start_chapter.bind(0), CONNECT_DEFERRED)
	title.quit_chosen.connect(get_tree().quit, CONNECT_DEFERRED)
	_swap_to(title)


func start_chapter(index: int) -> void:
	if campaign == null:
		campaign = Campaign.read()
	chapter_index = index
	step = Step.INTRO
	_skip_empty_steps()
	_show_current()


## Called when the scene on screen is done. [param won] is the battle's result
## when that scene was a battle; cutscenes always pass true.
func advance(won := true) -> void:
	advance_state(won)
	_show_current()


## advance() without showing anything, so tests can check the order.
func advance_state(won := true) -> void:
	_next_step(won)
	_skip_empty_steps()


func current_chapter() -> Campaign.Chapter:
	if campaign == null or chapter_index < 0 or chapter_index >= campaign.chapters.size():
		return null
	return campaign.chapters[chapter_index]


## Moves `step` (and `chapter_index`) one place on from the step that just
## ended. Empty intros and outros are skipped by the caller, not here.
func _next_step(won: bool) -> void:
	match step:
		Step.INTRO:
			step = Step.BATTLE
		Step.BATTLE when won:
			step = Step.OUTRO
		Step.BATTLE when not won:
			#retry level
			step = Step.BATTLE
		Step.OUTRO:
			if chapter_index + 1 < campaign.chapters.size():
				step = Step.INTRO
				chapter_index += 1
			else:
				step = Step.DONE
		
			


func _skip_empty_steps() -> void:
	while step != Step.DONE and _current_is_empty():
		_next_step(true)


func _current_is_empty() -> bool:
	var chapter := current_chapter()
	if chapter == null:
		return false
	match step:
		Step.INTRO:
			return chapter.intro.is_empty()
		Step.OUTRO:
			return chapter.outro.is_empty()
	return false


func _show_current() -> void:
	var chapter := current_chapter()
	if step == Step.DONE or chapter == null:
		step = Step.DONE
		campaign_finished.emit()
		show_title()
		return
	match step:
		Step.INTRO:
			_swap_to(_make_cutscene(chapter.intro))
		Step.BATTLE:
			_swap_to(_make_battle(chapter))
		Step.OUTRO:
			_swap_to(_make_cutscene(chapter.outro))


func _make_cutscene(dialogue_id: StringName) -> Cutscene:
	var cutscene: Cutscene = CutsceneScene.instantiate()
	cutscene.play(DialogueData.read(DialogueData.path_for(dialogue_id)))
	# Deferred: the swap frees the scene that's still emitting.
	cutscene.finished.connect(advance.bind(true), CONNECT_DEFERRED)
	return cutscene


func _make_battle(chapter: Campaign.Chapter) -> Battle:
	var battle: Battle = BattleScene.instantiate()
	# Set before it enters the tree: Level loads its file in _ready.
	(battle.get_node("Level") as Level).level_path = chapter.level_path()
	battle.ended.connect(advance, CONNECT_DEFERRED)
	return battle


## Takes the old scene out of the tree before the new one enters it, so the two
## never run side by side (the new one's _ready can't see the old one).
func _swap_to(scene: Node) -> void:
	var tree := get_tree()
	var old := tree.current_scene
	if old != null:
		tree.root.remove_child(old)
		old.queue_free()
	tree.root.add_child(scene)
	tree.current_scene = scene
