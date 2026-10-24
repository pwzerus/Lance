class_name JoustMatch
extends RefCounted

const MAX_PASSES = 3
const START_X = 535.0
const GROUND_Y = 0.0
const HIP = Vector2(-18, -168)
var mode = "arena"
var phase = "ready"
var phase_time = 2.6
var pass_number = 1
var fighters: Array = []
var events: Array = []
var result: Dictionary = {}
var rng = RandomNumberGenerator.new()
var time_elapsed = 0.0
# The presentation layer supplies this flag from its real-time hitstop clock.
var time_effect_active = false

func _init(match_mode: String = "arena", player_stats: Dictionary = {}, opponent_stats: Dictionary = {}, seed_value: int = 12345) -> void:
	mode = match_mode
	rng.seed = seed_value
	fighters = [_make_fighter(-START_X, 1, player_stats), _make_fighter(START_X, -1, opponent_stats)]
	_reset_positions()

func _make_fighter(x: float, direction: int, stats: Dictionary) -> Dictionary:
	return {"x": x, "prev_x": x, "direction": direction, "speed": 165.0, "stamina": 100.0,
		"hp": 100.0, "shield": 78.0, "lean": 0.0, "aim": -0.08, "boost": false,
		"broken": false, "durability": float(stats.get("durability", 100.0)), "acted": false,
		"ko": false, "dead": false, "stats": stats.duplicate(true), "prev_tip": Vector2.ZERO,
		"prev_head": Vector2.ZERO, "prev_body": Vector2.ZERO, "prev_shield": Vector2.ZERO,
		"prev_hand": Vector2.ZERO, "prev_aim": -0.08, "prev_length": 247.0,
		"surge": 0.0, "last_hit": "", "damage_total": 0.0, "wounds": []}

func _reset_positions() -> void:
	for i in range(2):
		var fighter = fighters[i]
		fighter.x = -START_X if i == 0 else START_X
		fighter.prev_x = fighter.x
		fighter.direction = 1 if i == 0 else -1
		fighter.speed = 165.0 * float(fighter.stats.get("speed", 1.0))
		fighter.acted = false
		fighter.surge = 0.0
		fighter.boost = false
		if mode == "arena":
			fighter.broken = false
			fighter.durability = float(fighter.stats.get("durability", 100.0))
		_cache_pose(fighter)

static func body_position(fighter: Dictionary) -> Vector2:
	var angle = float(fighter.lean) * 0.45
	return Vector2(float(fighter.x) + (HIP.x + sin(angle) * 54.0) * int(fighter.direction), HIP.y - cos(angle) * 44.0)

static func head_position(fighter: Dictionary) -> Vector2:
	var angle = float(fighter.lean) * 0.45
	return Vector2(float(fighter.x) + (HIP.x + sin(angle) * 111.0) * int(fighter.direction), HIP.y - cos(angle) * 111.0)

static func hand_position(fighter: Dictionary) -> Vector2:
	var angle = float(fighter.lean) * 0.45
	return Vector2(float(fighter.x) + (HIP.x + 57.0 + sin(angle) * 58.0) * int(fighter.direction), HIP.y - cos(angle) * 54.0)

static func shield_position(fighter: Dictionary) -> Vector2:
	return body_position(fighter) + Vector2(22.0 * int(fighter.direction), 6.0)

static func lance_length(fighter: Dictionary) -> float:
	return 66.0 if fighter.broken else float(fighter.stats.get("reach", 247.0))

static func tip_position(fighter: Dictionary) -> Vector2:
	return hand_position(fighter) + Vector2(cos(float(fighter.aim)) * int(fighter.direction), sin(float(fighter.aim))) * lance_length(fighter)

func _cache_pose(fighter: Dictionary) -> void:
	fighter.prev_x = fighter.x
	fighter.prev_tip = tip_position(fighter)
	fighter.prev_hand = hand_position(fighter)
	fighter.prev_aim = fighter.aim
	fighter.prev_length = lance_length(fighter)
	fighter.prev_body = body_position(fighter)
	fighter.prev_head = head_position(fighter)
	fighter.prev_shield = shield_position(fighter)

func set_controls(index: int, aim: float, lean: float, boost: bool, delta: float) -> void:
	var fighter = fighters[index]
	fighter.aim = move_toward(float(fighter.aim), clampf(aim, -0.68, 0.58), delta * 4.5)
	fighter.lean = move_toward(float(fighter.lean), clampf(lean, -1.0, 1.0), delta * 5.0)
	fighter.boost = boost

func step(delta: float) -> void:
	if phase == "ended":
		return
	time_elapsed += delta
	if phase == "ready" or phase == "turn":
		phase_time -= delta
		if phase_time <= 0.0:
			if phase == "turn":
				_reset_positions()
				phase = "ready"
				phase_time = 1.7
				events.append({"type": "rerack", "pass": pass_number})
			else:
				phase = "charge"
				events.append({"type": "charge"})
		for fighter in fighters:
			_cache_pose(fighter)
		return
	for fighter in fighters:
		var multiplier = float(fighter.stats.get("speed", 1.0))
		var accelerating = bool(fighter.boost) and float(fighter.stamina) > 1.0
		fighter.stamina = clampf(float(fighter.stamina) + (-23.0 if accelerating else 15.0) * delta, 0.0, 100.0)
		var target_speed = (310.0 if accelerating else 165.0) * multiplier
		if float(fighter.surge) > 0.0 and not time_effect_active:
			target_speed = 325.0 * multiplier
			fighter.surge = maxf(0.0, float(fighter.surge) - delta)
			fighter.speed = maxf(float(fighter.speed), target_speed)
		fighter.speed = move_toward(float(fighter.speed), target_speed, (110.0 if accelerating else 72.0) * delta)
		fighter.x += int(fighter.direction) * float(fighter.speed) * delta
	# Gather both candidates BEFORE applying either result, preserving simultaneous hits.
	var contacts: Array = []
	for i in range(2):
		if not fighters[i].acted:
			var contact = _detect_contact(i, delta)
			if not contact.is_empty():
				contacts.append(contact)
	for contact in contacts:
		_apply_contact(contact)
	for fighter in fighters:
		_cache_pose(fighter)
	if fighters[0].ko or fighters[1].ko or fighters[0].dead or fighters[1].dead:
		_finish("terminal")
	elif float(fighters[0].x) > START_X + 95.0 and float(fighters[1].x) < -START_X - 95.0:
		if pass_number >= MAX_PASSES:
			_finish("hp")
		else:
			pass_number += 1
			phase = "turn"
			phase_time = 1.6
			events.append({"type": "turn", "pass": pass_number})

static func swept_circle(old_tip: Vector2, new_tip: Vector2, old_center: Vector2, new_center: Vector2, radius: float) -> float:
	var start = old_tip - old_center
	var end = new_tip - new_center
	if start.length_squared() <= radius * radius:
		return 0.0
	return Geometry2D.segment_intersects_circle(start, end, Vector2.ZERO, radius)

static func swept_lance(old_hand: Vector2, new_hand: Vector2, old_angle: float, new_angle: float, old_length: float, new_length: float, direction: int, old_center: Vector2, new_center: Vector2, radius: float, delta: float) -> Dictionary:
	# Subdivide the rotational arc as well as sweeping relative translation.
	# At normal 120 Hz the angular step is <0.038 rad. Eight-pixel arc chords
	# also cover deliberately exaggerated test poses and longer shop lances.
	var angle_delta = new_angle - old_angle
	var segments = maxi(1, ceili(absf(angle_delta) * maxf(old_length,new_length) / 8.0))
	var previous = old_hand + Vector2(cos(old_angle)*direction,sin(old_angle))*old_length
	var arc_margin = maxf(old_length,new_length)*(1.0-cos(absf(angle_delta)/segments*.5))
	for segment in range(segments):
		var t0 = float(segment)/segments
		var t1 = float(segment+1)/segments
		var angle = lerpf(old_angle,new_angle,t1)
		var current = old_hand.lerp(new_hand,t1) + Vector2(cos(angle)*direction,sin(angle))*lerpf(old_length,new_length,t1)
		# Sagitta bounds the curved path outside each linear sweep chord.
		var fraction = swept_circle(previous,current,old_center.lerp(new_center,t0),old_center.lerp(new_center,t1),radius+maxf(.01,arc_margin))
		if fraction >= 0.0:
			return {"fraction":lerpf(t0,t1,fraction),"point":previous.lerp(current,fraction),
				"velocity":(current-previous)/maxf(delta/segments,0.000001)}
		previous = current
	return {}

func _detect_contact(index: int, delta: float) -> Dictionary:
	var attacker = fighters[index]
	var defender = fighters[1 - index]
	# Once well past a target, a lance pointing forward cannot hit backwards.
	if (float(defender.x) - float(attacker.x)) * int(attacker.direction) < -115.0:
		return {}
	var current_tip = tip_position(attacker)
	var targets = [
		{"zone": "head", "center": head_position(defender), "old": defender.prev_head, "radius": 24.0},
		{"zone": "body", "center": body_position(defender), "old": defender.prev_body, "radius": 33.0}]
	if float(defender.shield) > 0.0:
		targets.append({"zone": "shield", "center": shield_position(defender), "old": defender.prev_shield, "radius": 29.0})
	var earliest = 2.0
	var found: Dictionary = {}
	var sweep: Dictionary = {}
	for target in targets:
		var candidate = swept_lance(attacker.prev_hand,hand_position(attacker),attacker.prev_aim,attacker.aim,attacker.prev_length,lance_length(attacker),int(attacker.direction),target.old,target.center,target.radius,delta)
		if not candidate.is_empty() and float(candidate.fraction) < earliest:
			earliest = candidate.fraction
			found = target
			sweep = candidate
	if found.is_empty():
		return {}
	var tip_velocity = Vector2(sweep.velocity)
	var target_velocity = (Vector2(found.center) - Vector2(found.old)) / maxf(delta, 0.0001)
	var relative_speed = clampf((tip_velocity - target_velocity).length(), 50.0, 900.0)
	return {"attacker": index, "defender": 1 - index, "zone": found.zone, "speed": relative_speed,
		"position": sweep.point, "type": "hit"}

func _apply_contact(contact: Dictionary) -> void:
	var attacker = fighters[int(contact.attacker)]
	var defender = fighters[int(contact.defender)]
	attacker.acted = true
	var speed = float(contact.speed)
	var power = float(attacker.stats.get("power", 1.0)) * (0.66 if attacker.broken else 1.0)
	var alignment = clampf(cos(float(attacker.aim)), 0.4, 1.0)
	var impulse = speed * 0.117 * power * alignment
	var damage = 19.0 * pow(speed / 310.0, 1.40) * power * alignment
	var zone = str(contact.zone)
	var glanced = false
	if zone == "head":
		damage *= 1.65 * (1.0 - float(defender.stats.get("helmet", 0.08)))
		impulse *= 1.20
	elif zone == "body":
		damage *= 1.0 - float(defender.stats.get("armor", 0.10))
	else:
		var angle_difference = absf(float(attacker.aim) - float(defender.lean) * 0.38)
		glanced = angle_difference > 0.23
		defender.shield = maxf(0.0, float(defender.shield) - damage * 1.9)
		damage *= 0.11 if glanced else 0.22
		impulse *= 0.24 if glanced else 0.43
	if mode == "war" and zone != "shield":
		damage *= 1.28
	# A clearly heavy, unshielded head strike is dangerous; this is a GAME threshold.
	if mode == "war" and zone == "head" and impulse > 80.0 + float(defender.stats.get("helmet",0.08)) * 28.0:
		damage = maxf(damage, 110.0)
	defender.hp = maxf(0.0, float(defender.hp) - damage)
	attacker.damage_total += damage
	defender.last_hit = zone
	if zone != "shield" and damage > 11.0:
		defender.wounds.append({"zone":zone,"severity":damage})
	var threshold = 80.0 * float(defender.stats.get("stability", 1.0))
	defender.ko = impulse > threshold or float(defender.hp) <= 0.0
	defender.dead = mode == "war" and float(defender.hp) <= 0.0
	var stress = speed * 0.062 * (1.15 if zone == "shield" else 0.8)
	attacker.durability = maxf(0.0, float(attacker.durability) - stress)
	var break_probability = break_chance(mode, impulse, float(attacker.stats.get("durability", 100.0)))
	var broke_now = not attacker.broken and (float(attacker.durability) <= 0.0 or rng.randf() < break_probability)
	if broke_now:
		attacker.broken = true
	attacker.surge = 0.20
	defender.surge = 0.20
	contact.merge({"damage": damage, "impulse": impulse, "glanced": glanced, "broke": broke_now, "dead": defender.dead, "ko": defender.ko})
	events.append(contact)

static func break_chance(match_mode: String, impulse: float, durability: float = 100.0) -> float:
	var quality = clampf(100.0 / maxf(durability, 60.0), 0.55, 1.5)
	return clampf(((0.48 + impulse * 0.0030) if match_mode == "arena" else (0.055 + impulse * 0.0011)) * quality, 0.02, 0.94)

func _finish(reason: String) -> void:
	phase = "ended"
	var out_a = bool(fighters[0].ko) or bool(fighters[0].dead)
	var out_b = bool(fighters[1].ko) or bool(fighters[1].dead)
	var winner = -1
	if reason == "terminal":
		if out_a != out_b:
			winner = 1 if out_a else 0
	else:
		var difference = float(fighters[0].hp) - float(fighters[1].hp)
		if absf(difference) > 0.01:
			winner = 0 if difference > 0.0 else 1
	result = {"winner": winner, "reason": reason, "passes": pass_number, "mode": mode,
		"player_hp": fighters[0].hp, "enemy_hp": fighters[1].hp, "player_dead": fighters[0].dead, "enemy_dead": fighters[1].dead}
	events.append({"type": "end", "result": result.duplicate(true)})

func drain_events() -> Array:
	var pending = events
	events = []
	return pending
