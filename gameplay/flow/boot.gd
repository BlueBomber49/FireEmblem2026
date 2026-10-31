extends Node
## The main scene: a launcher that hands over to GameFlow's title screen.
## (The title isn't the main scene itself: it would then have to call GameFlow,
## and scenes only signal.)


func _ready() -> void:
	# Deferred: swapping the current scene while it's still being added fails.
	GameFlow.show_title.call_deferred()
