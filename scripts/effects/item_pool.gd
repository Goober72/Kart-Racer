class_name ItemPool
extends RefCounted
## Picks random items. Items are JSON files in a mod's items/ folder:
##   {
##     "id": "nitro", "name": "Nitro Can", "label": "N", "color": "#ff9933",
##     "uses": 1,
##     "weights": [front, middle, back],   <- chance by race position
##     "effects": [ {"type": "boost", "duration": 1.5} ]
##   }


static func roll(place: int, total: int) -> Dictionary:
	var ids := ModLoader.items.keys()
	if ids.is_empty():
		return {}
	var group := 1
	if place <= 1:
		group = 0
	elif total > 2 and place > ceili(total * 0.6):
		group = 2
	var weights: Array[float] = []
	var sum := 0.0
	for id in ids:
		var w = ModLoader.items[id].get("weights", [1, 1, 1])
		var value := 1.0
		if w is Array and w.size() > group:
			value = maxf(float(w[group]), 0.0)
		elif w is float or w is int:
			value = float(w)
		weights.append(value)
		sum += value
	if sum <= 0.0:
		return {}
	var r := randf() * sum
	for i in ids.size():
		r -= weights[i]
		if r <= 0.0:
			return ModLoader.items[ids[i]]
	return ModLoader.items[ids[-1]]
