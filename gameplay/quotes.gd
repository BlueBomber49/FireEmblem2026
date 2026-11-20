class_name Quotes
extends RefCounted
## Which dialogue plays when, for battle quotes and death quotes (FE's boss
## quotes). Static helpers: Battle plays what these return.
##
## Battle quotes belong to enemies (UnitReference.quotes). When an enemy fights
## a player unit, whoever starts it, the enemy's quote for that character plays,
## else its quote for anyone. Each unit plays a given dialogue at most once per
## attempt at the level; if the quote that fits has already played, nothing does
## (no falling back to the anyone quote). Allies never trigger quotes.
##
## Death quotes (UnitReference.death_quote) play when their unit falls, whoever
## the killer was.
##
## `played` is LevelState.played_quotes: "unit_id/dialogue_id" -> true.


## The battle quote for a fight between `a` and `b` (either may have started
## it), or "" when none plays. Marks the one returned as played.
static func battle_quote(a: UnitReference, b: UnitReference, played: Dictionary) -> String:
	var enemy := a if a.faction == UnitReference.Faction.ENEMY else b
	var other := b if enemy == a else a
	if enemy.faction != UnitReference.Faction.ENEMY or other.faction != UnitReference.Faction.PLAYER:
		return ""
	var chosen := ""
	if not other.character_id.is_empty():
		chosen = _quote_with(enemy, other.character_id)
	if chosen.is_empty():
		chosen = _quote_with(enemy, "")
	return _mark(enemy, chosen, played)


## `unit`'s death quote, or "" when it has none or it already played.
static func death_quote(unit: UnitReference, played: Dictionary) -> String:
	if unit.faction == UnitReference.Faction.ALLY:
		return ""
	return _mark(unit, unit.death_quote, played)


## The dialogue of `unit`'s quote for `character_id` ("" = the anyone quote).
static func _quote_with(unit: UnitReference, character_id: String) -> String:
	for quote in unit.quotes:
		if str(quote.get("with", "")) == character_id:
			return str(quote["dialogue"])
	return ""


static func _mark(unit: UnitReference, dialogue_id: String, played: Dictionary) -> String:
	if dialogue_id.is_empty():
		return ""
	var key := "%s/%s" % [unit.id, dialogue_id]
	if played.has(key):
		return ""
	played[key] = true
	return dialogue_id
