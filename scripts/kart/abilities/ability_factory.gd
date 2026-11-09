class_name AbilityFactory
extends RefCounted
## Turns a racer's "ability" JSON object into a KartAbility.
##
## Besides writing "tap"/"charged" effects by hand, a racer can use a preset:
##   "ability": {"type": "shockwave", "level": 2, "name": "My Quake"}
## Presets are also what the in-game racer creator offers.

const PRESETS := ["boost", "hop", "shockwave", "shield", "oil", "bolt", "storm", "cloud"]
const PRESET_INFO := {
	"boost": ["Turbo", "Tap: a burst of speed. Charged: a long boost with a shield."],
	"hop": ["Super Hop", "Tap: a jump. Charged: a huge leap plus a boost."],
	"shockwave": ["Shockwave", "Tap: slows nearby racers. Charged: spins them and leaves vines."],
	"shield": ["Bubble", "Tap: a shield. Charged: shield + a homing bubble at the racer ahead."],
	"oil": ["Oil Slick", "Tap: drop a slick. Charged: drop three slicks across the road."],
	"bolt": ["Bolt", "Tap: fire a bolt straight ahead. Charged: three homing bolts."],
	"storm": ["Storm", "Tap: zap the racer ahead. Charged: zap everyone ahead of you."],
	"cloud": ["Smoke Screen", "Tap: a boost and a smoke cloud. Charged: a bigger boost and a wall of smoke."],
}


static func create(kart: Kart, params: Dictionary, mod_dir: String) -> KartAbility:
	var type := str(params.get("type", ""))
	if type == "none":
		return null
	var ability: KartAbility
	if type == "script":
		var script := ScriptLoader.load_script(mod_dir.path_join(str(params.get("script", ""))))
		if script != null:
			var inst = script.new()
			if inst is KartAbility:
				ability = inst
			else:
				push_warning("Skill script must start with 'extends KartAbility'.")
	if ability == null:
		ability = KartAbility.new()
	var full := params.duplicate(true)
	if PRESETS.has(type) and not (full.has("tap") and full.has("charged")):
		var preset := preset(type, int(full.get("level", 2)))
		if full.has("name"):
			preset["tap"]["name"] = str(full["name"])
			preset["charged"]["name"] = "Charged " + str(full["name"])
		for key in preset.keys():
			if not full.has(key):
				full[key] = preset[key]
	elif type != "script" and not full.has("tap"):
		if type != "":
			push_warning("Unknown skill type '%s', using boost." % type)
		full.merge(preset("boost", 2))
	ability.setup(kart, full, mod_dir)
	return ability


## Built-in skills. `level` 1-3 scales their strength.
static func preset(type: String, level: int = 2) -> Dictionary:
	var s := 0.8 + 0.15 * clampi(level, 1, 3)
	var info: Array = PRESET_INFO.get(type, ["Skill", ""])
	var name: String = info[0]
	var tap: Array = []
	var charged: Array = []
	var cd := 8.0
	match type:
		"boost":
			tap = [{"type": "boost", "duration": 1.2 * s, "power": 1.35}]
			charged = [{"type": "boost", "duration": 2.4 * s, "power": 1.5}, {"type": "shield", "duration": 2.4 * s}]
		"hop":
			tap = [{"type": "hop", "height": 10.0 * s, "push": 4.0}]
			charged = [{"type": "hop", "height": 15.0 * s, "push": 9.0}, {"type": "boost", "duration": 1.0 * s, "power": 1.3}]
			cd = 6.0
		"shockwave":
			tap = [{"type": "shockwave", "radius": 10.0 * s, "hit": {"slow": 0.35, "bounce": 4.0}}]
			charged = [{"type": "shockwave", "radius": 17.0 * s, "hit": {"slow": 0.55, "spin": 0.8, "bounce": 7.0}},
				{"type": "drop", "shape": "vines", "radius": 3.0, "single_use": false, "lifetime": 12.0, "hit": {"slow": 0.4}}]
			cd = 9.0
		"shield":
			tap = [{"type": "shield", "duration": 2.5 * s}]
			charged = [{"type": "shield", "duration": 3.5 * s},
				{"type": "throw", "homing": true, "color": "#7fd8ff", "size": 0.8, "hit": {"slow": 0.5, "spin": 0.6, "bounce": 5.0}}]
		"oil":
			tap = [{"type": "drop", "shape": "puddle", "radius": 2.2 * s}]
			charged = [{"type": "drop", "shape": "puddle", "radius": 2.2 * s, "count": 3, "spread": 3.5}]
			cd = 7.0
		"bolt":
			tap = [{"type": "throw", "homing": false, "color": "#ff7a33"}]
			charged = [{"type": "throw", "homing": true, "count": 3, "color": "#ff4433", "hit": {"spin": 0.7 * s, "slow": 0.4}}]
			cd = 9.0
		"storm":
			tap = [{"type": "zap", "target": "next", "hit": {"slow": 0.4 * s, "spin": 0.4}}]
			charged = [{"type": "zap", "target": "ahead", "hit": {"slow": 0.45 * s, "spin": 0.7}}]
			cd = 12.0
		"cloud":
			tap = [{"type": "boost", "duration": 1.0 * s}, {"type": "drop", "shape": "cloud", "radius": 3.0, "single_use": false, "lifetime": 8.0, "hit": {"slow": 0.3}}]
			charged = [{"type": "boost", "duration": 1.8 * s, "power": 1.45},
				{"type": "drop", "shape": "cloud", "count": 3, "spread": 4.0, "radius": 3.0, "single_use": false, "lifetime": 10.0, "hit": {"slow": 0.4}}]
	return {
		"name": name,
		"cooldown": cd - level * 0.5,
		"charged_cooldown": (cd - level * 0.5) * 1.6,
		"tap": {"name": name, "effects": tap},
		"charged": {"name": "Charged " + name, "effects": charged},
	}
