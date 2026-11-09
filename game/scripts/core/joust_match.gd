class_name JoustMatch
extends RefCounted

const MAX_PASSES = 3
# EQUIP-069: post-armour damage a body/helm strike needs to score in full.
# Estimated from balance068 hit data: helm hits on light kit average ~24-29,
# on top plate ~19; 17 turns roughly a third of hits on heavy plate into touches.
const ATTAINT_DAMAGE = 17.0
const START_X = 2200.0
const EXIT_X = 850.0
const TROT_SPEED = 210.0
const GALLOP_SPEED = 480.0
const SURGE_SPEED = 515.0
const SPUR_DURATION = 0.0 # Compatibility only; urging now follows the physical hold.
const ACCELERATION = 330.0
const COAST_DECELERATION = 220.0
const START_ACCELERATION = 180.0
const ACCELERATION_SLEW = 950.0
const GROUND_Y = 0.0
const HIP = Vector2(-18, -168)
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Shield = preload("res://scripts/core/shield_geometry.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
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
	return {"x": x, "prev_x": x, "direction": direction, "speed": TROT_SPEED, "stamina": 100.0,
		"hp": 100.0, "shield": float(stats.get("shield_capacity",78.0)), "lean": 0.0, "aim": -0.08, "boost": false,
		"broken": false, "durability": float(stats.get("durability", 100.0)), "acted": false,
		"ko": false, "dead": false, "stats": stats.duplicate(true), "prev_tip": Vector2.ZERO,
		"prev_head": Vector2.ZERO, "prev_body": Vector2.ZERO, "prev_shield": Vector2.ZERO,
		"prev_hand": Vector2.ZERO, "prev_aim": -0.08, "prev_length": 247.0,
		"surge": 0.0, "last_hit": "", "damage_total": 0.0, "wounds": [], "score": 0, "arm": 100.0, "aim_rate": 0.0, "guard_rate": 0.0,
		"balance":100.0,"lean_velocity":0.0,"prev_flank":Vector2.ZERO,
		"guard":0.0,"guard_target":0.0,"lance_stability":.85,"aim_velocity":0.0,
		"reaction_angle":0.0,"reaction_angular_velocity":0.0,"reaction_shift":0.0,"reaction_shift_velocity":0.0,
		"shield_compression":0.0,"shield_compression_velocity":0.0,"lance_compression":0.0,"lance_compression_velocity":0.0,
		"gait_phase":0.0,"gait_moving":false,"acceleration":0.0,"accel_command":0.0,"motion_drive":0.0,"mount_velocity_y":0.0,"lane_y":32.0 if direction==1 else -32.0}

func _reset_positions() -> void:
	for i in range(2):
		var fighter = fighters[i]
		fighter.x = -START_X if i == 0 else START_X
		fighter.prev_x = fighter.x
		fighter.direction = 1 if i == 0 else -1
		fighter.speed = 0.0
		fighter.acceleration = 0.0
		fighter.accel_command = 0.0
		fighter.motion_drive = 0.0
		fighter.mount_velocity_y = 0.0
		fighter.balance = minf(100.0,float(fighter.balance)+8.0)
		fighter.acted = false
		fighter.surge = 0.0
		fighter.boost = false
		fighter.gait_phase = 0.0 if i==0 else 1.1
		fighter.gait_moving = false
		for key in ["reaction_angle","reaction_angular_velocity","reaction_shift","reaction_shift_velocity","shield_compression","shield_compression_velocity","lance_compression","lance_compression_velocity"]:
			fighter[key] = 0.0
		if mode == "arena":
			fighter.broken = false
			fighter.durability = float(fighter.stats.get("durability", 100.0))
		_cache_pose(fighter)

static func pose_angle(fighter: Dictionary) -> float:
	return float(fighter.lean)*(deg_to_rad(25.0) if float(fighter.lean)>=0 else deg_to_rad(45.0))+gait_pose(fighter).rider_pitch+float(fighter.get("reaction_angle",0.0))

static func rider_origin(fighter: Dictionary) -> Vector2:
	return mount_origin(fighter)+(HIP+Vector2(float(fighter.get("reaction_shift",0.0)),0))*Vector2(int(fighter.direction),1)

static func gait_pose(fighter: Dictionary) -> Dictionary:
	# Fatigue only lowers neck/head carriage; it never moves the saddle, rider
	# pitch or any hit anchor.
	return Gait.body(float(fighter.get("gait_phase",0.0)),float(fighter.get("speed",0.0)),bool(fighter.get("gait_moving",false)),float(fighter.stats.get("stability",1.0)),float(fighter.get("motion_drive",0.0)),Condition.fatigue(float(fighter.get("stamina",100.0))))

static func saddle_offset(fighter: Dictionary) -> Vector2:
	var pose = gait_pose(fighter)
	return pose.offset+pose.rider_offset

static func mount_origin(fighter: Dictionary) -> Vector2:
	return Vector2(float(fighter.x),float(fighter.get("lane_y",0.0)))+saddle_offset(fighter)*Vector2(int(fighter.direction),1)

static func body_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	return rider_origin(fighter)+Vector2(sin(angle)*44.0*int(fighter.direction),-cos(angle)*44.0)

static func head_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	return rider_origin(fighter)+Vector2(sin(angle)*111.0*int(fighter.direction),-cos(angle)*111.0)

static func hand_position(fighter: Dictionary) -> Vector2:
	var angle = pose_angle(fighter)
	var ray = Vector2(cos(float(fighter.aim))*int(fighter.direction),sin(float(fighter.aim)))
	return rider_origin(fighter)+Vector2(48,-53).rotated(angle)*Vector2(int(fighter.direction),1)-ray*float(fighter.get("lance_compression",0.0))

static func shield_position(fighter: Dictionary) -> Vector2:
	# Forward bracing raises the left-chest shield; leaning back withdraws
	# the head, but exposes the abdomen and compromises saddle stability.
	var guard = float(fighter.get("guard",0.0))
	var local = Vector2(lerpf(44,55,smoothstep(0,.43,guard))-float(fighter.get("shield_compression",0.0)),lerpf(-4.0,-109.0,guard))
	return rider_origin(fighter)+local.rotated(pose_angle(fighter))*Vector2(int(fighter.direction),1)

static func reaction_strength(event: Dictionary) -> float:
	# Presentation loading, separate from injury: a solid shield transfers
	# little damage but must visibly take the arriving lance's momentum.
	var transfer = .48 if bool(event.get("glanced",false)) else .75
	return clampf(maxf(float(event.get("impulse",0.0))/85.0,clampf(float(event.get("speed",0.0))/900.0,0,1)*transfer),0,1)

static func advance_reaction(fighter: Dictionary, delta: float) -> void:
	# Same constrained spring pose drives visible shoulders, grips AND targets.
	# Impacts add velocity only, never a new position or a free aim command.
	var remaining = maxf(0.0,minf(delta,.25))
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		for config in [["reaction_angle","reaction_angular_velocity",160.0,16.0,-.34,.28],
			["reaction_shift","reaction_shift_velocity",400.0,24.0,-6.0,3.0],
			["shield_compression","shield_compression_velocity",330.0,24.0,-3.0,24.0],
			["lance_compression","lance_compression_velocity",360.0,24.0,-2.0,12.0]]:
			var position_key = str(config[0])
			var velocity_key = str(config[1])
			var displacement = float(fighter.get(position_key,0.0))
			var velocity = float(fighter.get(velocity_key,0.0))
			velocity += (-float(config[2])*displacement-float(config[3])*velocity)*dt
			var next = clampf(displacement+velocity*dt,float(config[4]),float(config[5]))
			if next==float(config[4]) and velocity<0.0 or next==float(config[5]) and velocity>0.0:
				velocity = 0.0
			fighter[position_key] = next
			fighter[velocity_key] = velocity
		remaining -= dt

static func flank_position(fighter: Dictionary) -> Vector2:
	return body_position(fighter)+Vector2(-6.0*int(fighter.direction),34.0)

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
	fighter.prev_shield_angle = pose_angle(fighter)
	fighter.prev_flank = flank_position(fighter)

func set_controls(index: int, aim: float, lean: float, boost: bool, delta: float, guard: float = -1.0) -> void:
	var fighter = fighters[index]
	var distance = absf(float(fighters[0].x)-float(fighters[1].x))
	var committed = phase=="charge" and distance<1100 and float(fighters[0].x)<float(fighters[1].x)
	var previous_aim = float(fighter.aim)
	# EQUIP-066: armour weight slows lance redirection, guard moves and the
	# recovery of lance support (light kit = quicker hands, heavy = slower).
	var agility = Condition.agility(fighter.stats)
	# EQUIP-068: tired arms (from waving lance and shield) move slower too.
	var arm_factor = Condition.arm_factor(float(fighter.get("arm",100.0)))
	# EQUIP-068 (user request): the lance and shield ease in and out like the
	# lean, instead of starting and stopping at full speed in one frame.
	var aim_max = (.95 if committed else 2.2)*float(fighter.stats.get("lance_handling",1.0))*agility*arm_factor
	var aim_motion = eased(previous_aim,clampf(aim,-.68,.58),float(fighter.get("aim_rate",0.0)),aim_max,delta)
	fighter.aim = aim_motion.x
	fighter.aim_rate = aim_motion.y
	fighter.aim_velocity = absf(float(fighter.aim)-previous_aim)/maxf(delta,.00001)
	var movement = float(fighter.aim_velocity)
	# Holding a relative angle OR compensating for the horse's vertical
	# travel is a stable carry. Only the remaining intentional redirection
	# pays the feint cost; otherwise the stronger gait punishes bracing.
	var signed_turn = (float(fighter.aim)-previous_aim)/maxf(delta,.00001)
	var mount_compensation = float(fighter.get("mount_velocity_y",0.0))/maxf(40,cos(float(fighter.aim))*lance_length(fighter))
	movement = minf(movement,absf(signed_turn+mount_compensation))
	# Small corrections are free. Large late redirects sacrifice the support
	# behind the lance; the player keeps control instead of hitting an input lock.
	if movement>.24:
		fighter.lance_stability = maxf(.12,float(fighter.lance_stability)-(movement-.24)*delta*1.9)
	else:
		fighter.lance_stability = minf(1.0,float(fighter.lance_stability)+delta*.72*agility)
	if guard>=0:
		fighter.guard_target = clampf(guard,0,1)
	var previous_guard = float(fighter.guard)
	var guard_motion = eased(previous_guard,float(fighter.guard_target),float(fighter.get("guard_rate",0.0)),2.8*float(fighter.stats.get("shield_handling",1.0))*agility*arm_factor,delta)
	fighter.guard = guard_motion.x
	fighter.guard_rate = guard_motion.y
	# EQUIP-068 arm fatigue: big lance redirects and shield swings tire the arms
	# (heavier lance/shield tire faster); holding still lets them recover.
	var guard_speed = absf(float(fighter.guard)-previous_guard)/maxf(delta,.00001)
	fighter.arm = clampf(float(fighter.get("arm",100.0))+Condition.arm_rate(fighter.stats,movement,guard_speed)*delta,0.0,100.0)
	var difference = clampf(lean,-1,1)-float(fighter.lean)
	# EQUIP-067 (user approved): lean switches faster, 1.6->2.3/s top speed and
	# 6->9/s^2 build-up; still eased in and out, never an instant snap.
	var target_velocity = clampf(difference*5.5,-2.3,2.3)
	fighter.lean_velocity = move_toward(float(fighter.lean_velocity),target_velocity,delta*9.0)
	if absf(difference)<.004 and absf(float(fighter.lean_velocity))<.06:
		fighter.lean = clampf(lean,-1,1)
		fighter.lean_velocity = 0.0
	else:
		fighter.lean = clampf(float(fighter.lean)+float(fighter.lean_velocity)*delta,-1,1)
	fighter.boost = boost

## Critically damped-ish follower used for lance aim and shield guard:
## desired speed shrinks near the target (ease-out) and speed changes at a
## limited rate (ease-in). Returns Vector2(new value, new velocity).
static func eased(value: float, target: float, velocity: float, max_speed: float, delta: float) -> Vector2:
	var difference = target-value
	# equip068-arm01: gain 9 made a full sweep ~80% slower than the old linear
	# motion; 16/14 keeps the ease while staying close to the old response.
	var desired = clampf(difference*16.0,-max_speed,max_speed)
	velocity = move_toward(velocity,desired,maxf(.5,max_speed*14.0)*delta)
	var next = value+velocity*delta
	if signf(target-next)!=signf(difference) or (absf(target-next)<.0015 and absf(velocity)<.04):
		return Vector2(target,0.0)
	return Vector2(next,velocity)

func step(delta: float) -> void:
	for fighter in fighters:
		advance_reaction(fighter,delta)
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
			# HORSE-065: the horse gets its breath back between passes, partly.
			fighter.stamina = minf(100.0,float(fighter.stamina)+Condition.rest_rate(fighter.stats)*delta)
			fighter.arm = minf(100.0,float(fighter.get("arm",100.0))+Condition.ARM_REST*delta)
			# The inactive turn phase still shows the horses riding out.
			# No contacts are evaluated here; reracking resets all anchors.
			fighter.gait_moving = phase=="turn" and float(fighter.speed)>.5
			if fighter.gait_moving:
				fighter.x += int(fighter.direction)*float(fighter.speed)*delta
				fighter.gait_phase += delta*TAU*Gait.frequency(float(fighter.speed))
			_cache_pose(fighter)
		return
	for fighter in fighters:
		var old_mount_hand = hand_position(fighter)
		# HORSE-065: load (rider, armour, helmet, shield, lance) against the
		# horse's capacity sets drain, recovery and a small speed factor. A tired
		# horse can still be urged, but its gallop ceiling sinks toward a canter
		# instead of the old hard stop at 1% stamina.
		var multiplier = float(fighter.stats.get("speed", 1.0))*Condition.load_speed_factor(fighter.stats)
		var accelerating = bool(fighter.boost)
		var stamina_rate = -Condition.drain_rate(fighter.stats) if accelerating else Condition.recovery_rate(fighter.stats,float(fighter.speed),GALLOP_SPEED*multiplier,TROT_SPEED*multiplier)
		fighter.stamina = clampf(float(fighter.stamina)+stamina_rate*delta,0.0,100.0)
		var ceiling = Condition.gallop_ceiling(float(fighter.stamina))
		var target_speed = (maxf(GALLOP_SPEED*ceiling,TROT_SPEED) if accelerating else TROT_SPEED) * multiplier
		if float(fighter.surge) > 0.0 and not time_effect_active:
			if accelerating:
				target_speed = SURGE_SPEED * multiplier * ceiling
			fighter.surge = maxf(0.0, float(fighter.surge) - delta)
		var difference = target_speed-float(fighter.speed)
		var accel_factor = Condition.acceleration_factor(fighter.stats,float(fighter.stamina))
		var desired_acceleration = (ACCELERATION*accel_factor if accelerating else START_ACCELERATION) if difference>0 else -COAST_DECELERATION
		if absf(difference)<.001:
			desired_acceleration = 0
		fighter.accel_command = move_toward(float(fighter.get("accel_command",0.0)),desired_acceleration,ACCELERATION_SLEW*delta)
		# Releasing the spur starts deceleration on this tick, even during a
		# rising acceleration envelope. The horse still coasts with inertia.
		if difference<0 and float(fighter.accel_command)>0:
			fighter.accel_command = -COAST_DECELERATION*.45
		elif difference>0 and float(fighter.accel_command)<0:
			fighter.accel_command = ACCELERATION*.28
		var old_speed = float(fighter.speed)
		fighter.speed = move_toward(old_speed,target_speed,absf(float(fighter.accel_command))*delta)
		fighter.acceleration = (float(fighter.speed)-old_speed)/maxf(.00001,delta)
		fighter.motion_drive = move_toward(float(fighter.get("motion_drive",0.0)),clampf(float(fighter.acceleration)/ACCELERATION,-1,1),delta*5)
		fighter.x += int(fighter.direction) * float(fighter.speed) * delta
		fighter.gait_moving = true
		fighter.gait_phase += delta*TAU*Gait.frequency(float(fighter.speed))
		fighter.mount_velocity_y = (hand_position(fighter).y-old_mount_hand.y)/maxf(.00001,delta)
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
	elif float(fighters[0].x) > EXIT_X and float(fighters[1].x) < -EXIT_X:
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
		{"zone": "body", "center": body_position(defender), "old": defender.prev_body, "radius": 30.0},
		{"zone":"flank","center":flank_position(defender),"old":defender.prev_flank,"radius":22.0}]
	if float(defender.shield) > 0.0:
		# The circle is only a cheap broad phase; the shared outline resolves contact.
		targets.append({"zone": "shield", "center": shield_position(defender), "old": defender.prev_shield, "radius": 60.0})
	var earliest = 2.0
	var found: Dictionary = {}
	var sweep: Dictionary = {}
	for target in targets:
		var candidate = swept_lance(attacker.prev_hand,hand_position(attacker),attacker.prev_aim,attacker.aim,attacker.prev_length,lance_length(attacker),int(attacker.direction),target.old,target.center,target.radius,delta)
		if target.zone=="shield" and not candidate.is_empty():
			candidate = Shield.sweep(attacker.prev_hand,hand_position(attacker),attacker.prev_aim,attacker.aim,attacker.prev_length,lance_length(attacker),int(attacker.direction),target.old,target.center,float(defender.get("prev_shield_angle",pose_angle(defender))),pose_angle(defender),int(defender.direction),str(defender.stats.get("shield_shape","kite")),delta)
		if not candidate.is_empty() and float(candidate.fraction) < earliest:
			earliest = candidate.fraction
			found = target
			sweep = candidate
	if found.is_empty():
		return {}
	var tip_velocity = Vector2(sweep.velocity)
	var target_velocity = (Vector2(found.center) - Vector2(found.old)) / maxf(delta, 0.0001)
	var shaft = Vector2(cos(float(attacker.aim))*int(attacker.direction),sin(float(attacker.aim)))
	# A sideways flick must not manufacture the axial force of a full charge.
	var relative_speed = clampf((tip_velocity-target_velocity).dot(shaft),30.0,1050.0)
	return {"attacker": index, "defender": 1 - index, "zone": found.zone, "speed": relative_speed,
		"position": sweep.point, "type": "hit"}

func _apply_contact(contact: Dictionary) -> void:
	var attacker = fighters[int(contact.attacker)]
	var defender = fighters[int(contact.defender)]
	attacker.acted = true
	var speed = float(contact.speed)
	var support = lerpf(.38,1.0,float(attacker.get("lance_stability",1.0)))
	var power = float(attacker.stats.get("power",1.0))*(.66 if attacker.broken else 1.0)*(1.0+maxf(float(attacker.lean),0)*.08-maxf(-float(attacker.lean),0)*.28)*support
	power *= Condition.drive(float(attacker.speed),GALLOP_SPEED)
	contact["drive"] = Condition.drive(float(attacker.speed),GALLOP_SPEED)
	var alignment = clampf(cos(float(attacker.aim)), 0.4, 1.0)
	var impulse = speed * 0.085 * power * alignment
	var damage = 19.0 * pow(speed / 620.0, 1.25) * power * alignment
	var zone = str(contact.zone)
	var glanced = false
	var shield_before = float(defender.shield)
	if zone == "head":
		damage *= 1.38 * (1.0 - float(defender.stats.get("helmet", 0.08)))
		impulse *= 0.86
	elif zone in ["body","flank"]:
		damage *= 1.0 - float(defender.stats.get("armor", 0.10))
		impulse *= 1.28 if zone=="flank" else 1.18
	else:
		var angle_difference = absf(float(attacker.aim) - float(defender.lean) * 0.38)
		glanced = angle_difference > 0.16 or absf(float(defender.lean))>.35
		defender.shield = maxf(0.0, float(defender.shield) - damage * (0.7 if glanced else 1.15))
		damage *= 0.035 if glanced else 0.09
		impulse *= 0.16 if glanced else 0.28
	if mode == "war" and zone != "shield":
		damage *= 1.32
	defender.hp = maxf(0.0, float(defender.hp) - damage)
	attacker.damage_total += damage
	defender.last_hit = zone
	if zone != "shield" and damage > 11.0:
		defender.wounds.append({"zone":zone,"severity":damage})
	var brace = 1.0+maxf(float(defender.lean),0)*.14-maxf(-float(defender.lean),0)*.14
	# EQUIP-066: a heavier armoured rider sits more firmly (more inertia).
	var seat = Condition.seat(defender.stats)
	var threshold = 96.0 * float(defender.stats.get("stability", 1.0))*brace*seat
	defender.balance = maxf(0.0,float(defender.balance)-impulse*(.50 if zone=="head" else .82)/seat)
	defender.ko = impulse > threshold or float(defender.balance)<=0 or float(defender.hp) <= 0.0
	defender.dead = mode == "war" and float(defender.hp) <= 0.0
	var ko_reason = ""
	if defender.ko:
		ko_reason = "fatal" if defender.dead else ("health" if float(defender.hp)<=0 else ("impact" if impulse>threshold else "balance"))
	var stress = speed * 0.062 * (1.15 if zone == "shield" else 0.8)
	attacker.durability = maxf(0.0, float(attacker.durability) - stress)
	var break_probability = break_chance(mode, impulse, float(attacker.stats.get("durability", 100.0)))
	var broke_now = not attacker.broken and (float(attacker.durability) <= 0.0 or rng.randf() < break_probability)
	var old_tip = tip_position(attacker)
	var old_hand = hand_position(attacker)
	var old_reach = lance_length(attacker)
	if broke_now:
		attacker.broken = true
	# EQUIP-067 tournament score (arena), after historical score cheques:
	# a clean shield strike 1, body/flank 2, helm 3, +1 for breaking the
	# lance on the strike; a glancing blow scores nothing. Unhorsing still ends
	# the match at once. Before, three passes with no fall were decided by a
	# few points of hidden health, which read as random.
	var points = 0
	var attaint = false
	if not glanced:
		points = {"shield":1,"body":2,"flank":2,"head":3}.get(zone,0)
		# EQUIP-069 (user approved): armour earns its keep in the score. A body
		# or helm strike counts in full only if enough force gets through the
		# armour (an "attaint"); a weaker one is a mere touch worth 1. Before,
		# scores ignored armour, so heavy kit kept only its costs in the arena
		# and light kit won 66% at equal skill (balance068-v0427-m1).
		if zone!="shield":
			attaint = damage>=ATTAINT_DAMAGE
			if not attaint:
				points = 1
		if broke_now:
			points += 1
	attacker.score = int(attacker.get("score",0))+points
	attacker.surge = 0.20
	defender.surge = 0.20
	contact.merge({"damage": damage, "impulse": impulse, "glanced": glanced, "broke": broke_now, "points": points, "attaint": attaint, "dead": defender.dead, "ko": defender.ko,"ko_reason":ko_reason,"support":support,"balance_left":defender.balance,"shield_broke":shield_before>0 and float(defender.shield)<=0,
		"break_tip":old_tip,"break_hand":old_hand,"break_reach":old_reach,"break_angle":attacker.aim,"break_direction":attacker.direction})
	var loading = reaction_strength(contact)
	var angular_kick = -5.6 if zone=="head" else (4.5 if zone=="flank" else (-2.6 if zone=="shield" else -4.8))
	defender.reaction_angular_velocity = clampf(float(defender.get("reaction_angular_velocity",0.0))+angular_kick*loading,-6.0,5.0)
	defender.reaction_shift_velocity = maxf(-170.0,float(defender.get("reaction_shift_velocity",0.0))-145.0*loading)
	if zone=="shield":
		defender.shield_compression_velocity = minf(760.0,float(defender.get("shield_compression_velocity",0.0))+690.0*loading)
	attacker.lance_compression_velocity = minf(360.0,float(attacker.get("lance_compression_velocity",0.0))+320.0*loading)
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
		var score_a = int(fighters[0].get("score",0))
		var score_b = int(fighters[1].get("score",0))
		if mode=="arena" and score_a!=score_b:
			# Tournament: the score sheet decides; health only breaks a tie.
			winner = 0 if score_a>score_b else 1
			reason = "score"
		else:
			var difference = float(fighters[0].hp) - float(fighters[1].hp)
			if absf(difference) > 0.01:
				winner = 0 if difference > 0.0 else 1
	result = {"winner": winner, "reason": reason, "passes": pass_number, "mode": mode,
		"player_hp": fighters[0].hp, "enemy_hp": fighters[1].hp, "player_dead": fighters[0].dead, "enemy_dead": fighters[1].dead,
		"player_score": int(fighters[0].get("score",0)), "enemy_score": int(fighters[1].get("score",0))}
	events.append({"type": "end", "result": result.duplicate(true)})

func drain_events() -> Array:
	var pending = events
	events = []
	return pending
