class_name Effects
extends RefCounted
## The building blocks shared by skills and items.
##
## A skill or item is just a list of effects, e.g.
##   [{"type": "boost", "duration": 1.5}, {"type": "drop", "shape": "puddle"}]
##
## Effect types (all numbers optional):
##   boost      duration, power                 - speed up
##   hop        height, push                    - jump
##   shield     duration                        - block hits, soften wall bumps
##   shockwave  radius, color, hit               - hit everyone nearby
##   drop       shape, radius, lifetime, count, spread, color, hit, single_use
##                                              - leave a trap behind you
##   throw      homing, speed, color, count, lifetime, size, hit
##                                              - fire a projectile forward
##   zap        target ("next", "ahead", "leader", "all"), color, hit
##                                              - strike other racers anywhere
##   script     script (path to a .gd that extends KartEffect), plus any params
##
## "hit" describes what happens to a racer that gets hit:
##   {"spin": seconds, "slow": 0..1, "bounce": upward speed}

const DEFAULT_HIT := {"spin": 0.8, "slow": 0.4, "bounce": 4.0}

static var _script_cache: Dictionary = {}


static func run(user: Kart, effects: Array, mod_dir: String = "") -> void:
	for e in effects:
		if e is Dictionary:
			apply(user, e, mod_dir)


static func apply(user: Kart, e: Dictionary, mod_dir: String = "") -> void:
	var type := str(e.get("type", ""))
	match type:
		"boost":
			user.add_boost(_f(e, "duration", 1.5), _f(e, "power", 1.35))
		"hop":
			user.velocity.y = _f(e, "height", 10.0)
			user.speed += _f(e, "push", 4.0)
		"shield":
			user.shield_time = maxf(user.shield_time, _f(e, "duration", 3.0))
		"shockwave":
			var radius := _f(e, "radius", 12.0)
			for k in others(user):
				if k.global_position.distance_to(user.global_position) <= radius:
					hit(k, e.get("hit", DEFAULT_HIT), user)
			user.flash(_color(e, Color(0.6, 0.9, 1.0)), radius)
		"drop":
			_drop(user, e)
		"throw":
			_throw(user, e)
		"zap":
			_zap(user, e)
		"script":
			_script(user, e, mod_dir)
		_:
			push_warning("Unknown effect type '%s'." % type)


## Applies a hit to `target`. Returns false if a shield blocked it.
static func hit(target: Kart, h: Variant, source: Kart = null) -> bool:
	var data: Dictionary = h if h is Dictionary else DEFAULT_HIT
	if target.shield_time > 0.0:
		target.flash(Color(0.4, 0.8, 1.0), 2.5)
		return false
	target.speed *= 1.0 - clampf(float(data.get("slow", 0.4)), 0.0, 1.0)
	var spin := float(data.get("spin", 0.0))
	if spin > 0.0:
		target.spin(spin)
	var bounce := float(data.get("bounce", 0.0))
	if bounce > 0.0:
		target.velocity.y = bounce
	target.got_hit.emit(source)
	return true


static func others(user: Kart) -> Array[Kart]:
	var out: Array[Kart] = []
	for node in user.get_tree().get_nodes_in_group("karts"):
		if node != user and node is Kart:
			out.append(node)
	return out


static func race_of(user: Kart) -> Node:
	return user.get_parent()


static func clear_cache() -> void:
	_script_cache.clear()


# --------------------------------------------------------------------------

static func _f(e: Dictionary, key: String, fallback: float) -> float:
	return float(e.get(key, fallback))


static func _color(e: Dictionary, fallback: Color) -> Color:
	var c := str(e.get("color", ""))
	return Color.html(c) if Color.html_is_valid(c) else fallback


static func _drop(user: Kart, e: Dictionary) -> void:
	var count := maxi(int(e.get("count", 1)), 1)
	var spread := _f(e, "spread", 2.5)
	var back := user.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	var right := user.global_transform.basis.x
	for i in count:
		var hz := Hazard.new()
		hz.setup(user, e)
		race_of(user).add_child(hz)
		var lateral := (i - (count - 1) * 0.5) * spread
		hz.global_position = user.global_position + back * (2.8 + (i % 2) * 1.5) + right * lateral


static func _throw(user: Kart, e: Dictionary) -> void:
	var count := maxi(int(e.get("count", 1)), 1)
	var race := race_of(user)
	var homing: bool = e.get("homing", false)
	var targets: Array[Kart] = []
	if homing:
		targets = _karts_ahead(user, count)
	for i in count:
		var p := Projectile.new()
		var target: Kart = targets[i] if i < targets.size() else null
		p.setup(user, e, target, race.get("track"), (i - (count - 1) * 0.5) * 2.0)
		race.add_child(p)


static func _zap(user: Kart, e: Dictionary) -> void:
	var mode := str(e.get("target", "next"))
	var victims: Array[Kart] = []
	match mode:
		"next":
			victims = _karts_ahead(user, 1)
		"leader":
			for k in others(user):
				if k.place == 1:
					victims.append(k)
		"all":
			victims = others(user)
		_:  # "ahead"
			for k in others(user):
				if k.place < user.place:
					victims.append(k)
	var col := _color(e, Color(1.0, 0.95, 0.3))
	for k in victims:
		k.flash(col, 3.0)
		hit(k, e.get("hit", DEFAULT_HIT), user)


## The karts directly in front of `user`, closest place first.
static func _karts_ahead(user: Kart, n: int) -> Array[Kart]:
	var ahead: Array[Kart] = []
	for k in others(user):
		if k.place < user.place and not k.finished:
			ahead.append(k)
	ahead.sort_custom(func(a: Kart, b: Kart) -> bool: return a.place > b.place)
	return ahead.slice(0, n)


static func _script(user: Kart, e: Dictionary, mod_dir: String) -> void:
	var path := mod_dir.path_join(str(e.get("script", "")))
	var script: GDScript = _script_cache.get(path)
	if script == null:
		script = ScriptLoader.load_script(path)
		if script == null:
			return
		_script_cache[path] = script
	var inst = script.new()
	if not inst is KartEffect:
		push_warning("Effect script must start with 'extends KartEffect': " + path)
		return
	(inst as KartEffect).apply(user, e)
