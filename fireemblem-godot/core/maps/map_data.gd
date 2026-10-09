class_name MapData
extends RefCounted
## Everything authored for a map: its terrain layers and the units placed on it.

var layerData: MapLayersData = MapLayersData.new()
## id -> UnitReference
var units: Dictionary = {}


static func fromJson(d: Dictionary) -> MapData:
	var data := MapData.new()
	data.layerData = MapLayersData.fromJson(d)
	var raw_units: Dictionary = d.get("units", {})
	for id in raw_units:
		data.units[id] = UnitReference.fromJson(id, raw_units[id])
	return data


func toJson() -> Dictionary:
	var d := layerData.toJson()
	var raw_units := {}
	for id in units:
		raw_units[id] = units[id].toJson()
	d["units"] = raw_units
	return d
