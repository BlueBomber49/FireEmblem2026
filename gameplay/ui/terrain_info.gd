class_name TerrainInfo
extends RefCounted
## What the terrain panel shows for one map cell. Map logic fills this in; the
## UI only reads it.

## [member move_cost] value for terrain the unit can't enter.
const IMPASSABLE := -1

var terrain_name: String = ""
var defense: int = 0
var avoid: int = 0
## Percent of max HP restored at the start of the turn; 0 means no healing.
var heal_percent: int = 0
## Move cost for the unit the caller cares about (the selected unit, or
## infantry when nothing is selected).
var move_cost: int = 1
