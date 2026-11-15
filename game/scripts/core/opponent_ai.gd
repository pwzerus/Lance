extends RefCounted
## Decisions consume delayed visible poses. Difficulty never changes combat stats.
const Model = preload("res://scripts/core/joust_match.gd")
const NAMES = ["初学骑手","正规骑士","老练对手"]
# LEVEL-092 (user: "the normal AI is still too hard"): the middle column is
# eased. Normal sees later (.38 -> .48 s), thinks less often, commits its
# lance earlier (less last-moment correction), aims looser, chooses targets
# with more noise and sometimes raises the shield to the wrong line.
# Beginner and veteran columns are unchanged except veteran's rare misread.
const REACTION = [.72,.48,.20]
const THINK = [.78,.50,.22]
const ATTACK_COMMIT = [.85,.60,.30]
const DEFENSE_COMMIT = [.65,.42,.18]
const AIM_JITTER = [22.0,15.0,4.0]
const TARGET_NOISE = [.55,.55,.18]
const MISREAD = [0.0,.20,.05]
const EFFORT_FLOOR = [24.0,18.0,12.0]
const PRESSURE_GAP = [4200.0,3000.0,2400.0]
const GUARDS = [1.0,.43,0.0]
## LEVEL-092: optional continuous profile from a campaign level:
## skill (0..2: aim, target choice, commitment), awareness (0..2: reaction,
## thinking rate, reading the incoming lance), aggression (0..1: when to
## spur), head_bias (prefers the helm), feint (shows one line, then changes).
## Without a profile the integer difficulty behaves exactly as its column.
## FEEL-095 (user: "make the veteran aim smoothly so it stops unsettling
## itself"): FEEL-094 charges every abrupt change of lance, shield and lean to
## the rider's seat. The veteran re-aimed in steps every 0.22 s, swung the
## shield whenever the incoming line crossed a boundary and could flip its
## lean, so it unsettled itself (unsteady at hit p90 .32). A skilled rider now
## carries the lance point to the target along a critically damped path,
## keeps a shield line until another is clearly better and holds a decided
## lean for the pass. Blended in by skill/awareness 1.0 -> 1.6, so normal and
## lower riders are unchanged. QA only: false replays the FEEL-094 behaviour.
static var steady_tracking: bool = true
const STEADY_RANGE = Vector2(1.0,1.6)
const TRACK_OMEGA = 13.0
const GUARD_MARGIN = 16.0
var profile: Dictionary = {}
var elapsed = 0.0
var next_think = 0.0
var pass_id = -1
var history: Array[Dictionary] = []
var last_seen: Dictionary = {}
var guard = .43
var lean = .12
var target_y = -212.0
var zone = "body"
var committed = false
var defense_committed = false
var decision_count = 0
var last_observation_time = -1.0
var feinted = false
var preferred_guard = .43
var observed_attack_sum = 0.0
var observed_attack_count = 0
var aim_point = -212.0
var aim_point_velocity = 0.0
var guard_line = -1
var lean_back = false

## Extra observation delay from the helmet: 0 with an open face, ~0.15 s in a
## great helm (vision .50). ART-090.
static func vision_delay(stats: Dictionary) -> float:
	return (1.0-clampf(float(stats.get("helmet_vision",1.0)),0.0,1.0))*.30

func configure(level_profile: Dictionary) -> void:
	profile = level_profile.duplicate(true)

## Linear interpolation across the three difficulty columns (x in 0..2).
static func curve(table: Array, x: float) -> float:
	x = clampf(x,0.0,2.0)
	var low = mini(int(floor(x)),1)
	return lerpf(float(table[low]),float(table[low+1]),x-low)

func update(model: JoustMatch, index: int, difficulty: int, delta: float, rng: RandomNumberGenerator, practice: bool = false) -> Dictionary:
	difficulty = clampi(difficulty,0,2)
	var skill = clampf(float(profile.get("skill",difficulty)),0.0,2.0)
	var awareness = clampf(float(profile.get("awareness",difficulty)),0.0,2.0)
	var reaction = curve(REACTION,awareness)
	var ai = model.fighters[index]
	var enemy = model.fighters[1-index]
	if pass_id!=model.pass_number:
		if observed_attack_count>0 and awareness>=.5:
			preferred_guard = GUARDS[clampi(roundi(observed_attack_sum/observed_attack_count),0,2)]
		pass_id = model.pass_number
		elapsed = 0
		next_think = reaction+vision_delay(ai.stats)
		history.clear()
		last_seen.clear()
		last_observation_time = -1.0
		committed = false
		defense_committed = false
		feinted = false
		observed_attack_sum = 0
		observed_attack_count = 0
		guard = preferred_guard
		zone = "body"
		lean = .12
		target_y = Model.body_position(enemy).y
		aim_point = target_y
		aim_point_velocity = 0.0
		guard_line = -1
		lean_back = false
	var steady_aim = smoothstep(STEADY_RANGE.x,STEADY_RANGE.y,skill) if steady_tracking else 0.0
	var steady_read = smoothstep(STEADY_RANGE.x,STEADY_RANGE.y,awareness) if steady_tracking else 0.0
	elapsed += delta
	history.append({"time":elapsed,"head":Model.head_position(enemy).y,"body":Model.body_position(enemy).y,
		"flank":Model.flank_position(enemy).y,"shield":Model.shield_position(enemy).y,"shield_hp":enemy.shield,
		"tip":Model.tip_position(enemy).y,"speed":enemy.speed,"lean":enemy.lean})
	# ART-090: a closed helm narrows sight; the rider sees the opponent's line
	# later (equipment effect, same for every difficulty, not a stat cheat).
	var cutoff = elapsed-reaction-vision_delay(ai.stats)
	while history.size()>1 and float(history[1].time)<=cutoff:
		history.pop_front()
	var distance = absf(float(ai.x)-float(enemy.x))
	var approaching = (float(enemy.x)-float(ai.x))*int(ai.direction)>0
	var closing_speed = maxf(100,float(ai.speed)+float(last_seen.get("speed",Model.TROT_SPEED)))
	var contact_time = maxf(0,(distance-Model.lance_length(ai)-40)/closing_speed)
	if model.phase=="charge" and approaching:
		committed = committed or contact_time<curve(ATTACK_COMMIT,skill)
		defense_committed = defense_committed or contact_time<curve(DEFENSE_COMMIT,awareness)
	if elapsed>=next_think and not history.is_empty() and float(history[0].time)<=cutoff:
		last_seen = history[0].duplicate()
		last_observation_time = last_seen.time
		next_think = elapsed+curve(THINK,awareness)*rng.randf_range(.92,1.08)
		decision_count += 1
		if not committed:
			var desired_zone = _choose_target(last_seen,skill,rng)
			# A veteran may deliberately show a high line before moving once to
			# an exposed lower line. The actual weapon still obeys player limits.
			if bool(profile.get("feint",skill>=1.75)) and distance>1800:
				desired_zone = "head" if pass_id%2==1 else "body"
			if zone!=desired_zone and distance<1600:
				feinted = true
			zone = desired_zone
			target_y = float(last_seen[zone])+rng.randf_range(-1,1)*curve(AIM_JITTER,skill)
		if not defense_committed:
			var incoming = float(last_seen.tip)
			var options = [Model.head_position(ai).y,Model.body_position(ai).y,Model.flank_position(ai).y]
			var nearest = 0
			for i in range(1,3):
				if absf(options[i]-incoming)<absf(options[nearest]-incoming):
					nearest = i
			# FEEL-095: keep the current shield line unless another is clearly
			# closer, so a lance tip hovering on a boundary no longer swings it.
			var held = nearest
			if guard_line>=0 and absf(options[guard_line]-incoming)<absf(options[nearest]-incoming)+GUARD_MARGIN*steady_read:
				held = guard_line
			guard_line = held
			if awareness<.5:
				guard = .43 if pass_id%2==1 else 1.0
			else:
				# LEVEL-092: a less aware rider sometimes reads the line wrong.
				var raised = held
				if rng.randf()<curve(MISREAD,awareness):
					raised = 1 if held!=1 else (0 if rng.randf()<.5 else 2)
				guard = GUARDS[raised]
			if distance<1500:
				observed_attack_sum += nearest
				observed_attack_count += 1
			# FEEL-095: a steady rider who has decided to sit back for this pass
			# stays back instead of flipping with every read.
			lean_back = (lean_back and steady_read>.5) or (awareness>=1.75 and nearest==0 and distance<1100)
			lean = -.65 if lean_back else .18
	if practice:
		guard = GUARDS[(model.pass_number-1)%3]
		lean = 0
		zone = "body"
		target_y = float(last_seen.get("body",Model.body_position(enemy).y))+18
	# FEEL-095: the lance point follows the chosen target along a critically
	# damped path (no steps), blended in by skill. Fixed 1/120 s substeps.
	var remaining = clampf(delta,0.0,.25)
	while remaining>.000001:
		var dt = minf(remaining,1.0/120.0)
		aim_point_velocity += (TRACK_OMEGA*TRACK_OMEGA*(target_y-aim_point)-2.0*TRACK_OMEGA*aim_point_velocity)*dt
		aim_point += aim_point_velocity*dt
		remaining -= dt
	var aimed_y = lerpf(target_y,aim_point,steady_aim)
	var hand = Model.hand_position(ai)
	var aim = asin(clampf((aimed_y-hand.y)/Model.lance_length(ai),-.629,.548))
	# Reserve a finishing effort with the same stamina rules as the player.
	# Hysteresis prevents per-frame spur toggling at the exhaustion boundary.
	var effort_floor = curve(EFFORT_FLOOR,skill) if bool(ai.boost) else 55.0
	# React to the opponent's observed approach, not a universal late-sprint
	# marker. Normal opponents alternate pressure and measured approaches.
	# LEVEL-092: a level's aggression moves the spur point (0 waits, 1 rushes).
	var base_gap = lerpf(2200.0,4600.0,clampf(float(profile.aggression),0.0,1.0)) if profile.has("aggression") else PRESSURE_GAP[difficulty]
	var pressure_gap = base_gap+(450.0 if pass_id%2==1 else -250.0)
	var rush_seen = float(last_seen.get("speed",0))>Model.GALLOP_SPEED*.82
	var closing_window = contact_time<3.0 and rush_seen
	var boost = (distance<pressure_gap or closing_window) and float(ai.stamina)>effort_floor
	if practice:
		boost = distance>1200
	model.set_controls(index,aim,lean,boost,delta,guard)
	return {"zone":zone,"guard":guard,"lean":lean,"target_y":target_y,"committed":committed,"decisions":decision_count,"observation_age":elapsed-last_observation_time}

func _choose_target(seen: Dictionary, skill: float, rng: RandomNumberGenerator) -> String:
	if skill<.5:
		return "body" if pass_id%2==1 else "head"
	var best_zone = "body"
	var best_score = -INF
	var head_bias = float(profile.get("head_bias",0.0))
	for candidate in ["head","body","flank"]:
		var separation = absf(float(seen[candidate])-float(seen.shield))
		var exposure = clampf((separation-28)/42,0,1) if float(seen.shield_hp)>0 else 1.0
		var score = exposure*2.5+({"head":.35+head_bias,"body":.15,"flank":.05}[candidate])+rng.randf_range(0,curve(TARGET_NOISE,skill))
		if score>best_score:
			best_score = score
			best_zone = candidate
	return best_zone
