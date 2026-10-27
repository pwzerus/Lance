extends RefCounted
## Decisions consume delayed visible poses. Difficulty never changes combat stats.
const Model = preload("res://scripts/core/joust_match.gd")
const NAMES = ["初学骑手","正规骑士","老练对手"]
const REACTION = [.72,.38,.20]
const THINK = [.78,.40,.22]
const ATTACK_COMMIT = [.85,.52,.30]
const DEFENSE_COMMIT = [.65,.35,.18]
const GUARDS = [1.0,.43,0.0]
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

func update(model: JoustMatch, index: int, difficulty: int, delta: float, rng: RandomNumberGenerator, practice: bool = false) -> Dictionary:
	difficulty = clampi(difficulty,0,2)
	var ai = model.fighters[index]
	var enemy = model.fighters[1-index]
	if pass_id!=model.pass_number:
		if observed_attack_count>0 and difficulty>0:
			preferred_guard = GUARDS[clampi(roundi(observed_attack_sum/observed_attack_count),0,2)]
		pass_id = model.pass_number
		elapsed = 0
		next_think = REACTION[difficulty]
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
	elapsed += delta
	history.append({"time":elapsed,"head":Model.head_position(enemy).y,"body":Model.body_position(enemy).y,
		"flank":Model.flank_position(enemy).y,"shield":Model.shield_position(enemy).y,"shield_hp":enemy.shield,
		"tip":Model.tip_position(enemy).y,"speed":enemy.speed,"lean":enemy.lean})
	var cutoff = elapsed-REACTION[difficulty]
	while history.size()>1 and float(history[1].time)<=cutoff:
		history.pop_front()
	var distance = absf(float(ai.x)-float(enemy.x))
	var approaching = (float(enemy.x)-float(ai.x))*int(ai.direction)>0
	var closing_speed = maxf(100,float(ai.speed)+float(last_seen.get("speed",Model.TROT_SPEED)))
	var contact_time = maxf(0,(distance-Model.lance_length(ai)-40)/closing_speed)
	if model.phase=="charge" and approaching:
		committed = committed or contact_time<ATTACK_COMMIT[difficulty]
		defense_committed = defense_committed or contact_time<DEFENSE_COMMIT[difficulty]
	if elapsed>=next_think and not history.is_empty() and float(history[0].time)<=cutoff:
		last_seen = history[0].duplicate()
		last_observation_time = last_seen.time
		next_think = elapsed+THINK[difficulty]*rng.randf_range(.92,1.08)
		decision_count += 1
		if not committed:
			var desired_zone = _choose_target(last_seen,difficulty,rng)
			# A veteran may deliberately show a high line before moving once to
			# an exposed lower line. The actual weapon still obeys player limits.
			if difficulty==2 and distance>1800:
				desired_zone = "head" if pass_id%2==1 else "body"
			if zone!=desired_zone and distance<1600:
				feinted = true
			zone = desired_zone
			target_y = float(last_seen[zone])+rng.randf_range(-1,1)*[22.0,10.0,4.0][difficulty]
		if not defense_committed:
			var incoming = float(last_seen.tip)
			var options = [Model.head_position(ai).y,Model.body_position(ai).y,Model.flank_position(ai).y]
			var nearest = 0
			for i in range(1,3):
				if absf(options[i]-incoming)<absf(options[nearest]-incoming):
					nearest = i
			if difficulty==0:
				guard = .43 if pass_id%2==1 else 1.0
			else:
				guard = GUARDS[nearest]
			if distance<1500:
				observed_attack_sum += nearest
				observed_attack_count += 1
			lean = -.65 if difficulty==2 and nearest==0 and distance<1100 else .18
	if practice:
		guard = GUARDS[(model.pass_number-1)%3]
		lean = 0
		zone = "body"
		target_y = float(last_seen.get("body",Model.body_position(enemy).y))+18
	var hand = Model.hand_position(ai)
	var aim = asin(clampf((target_y-hand.y)/Model.lance_length(ai),-.629,.548))
	var boost = float(ai.stamina)>[38,24,16][difficulty] and (distance>[1100,650,0][difficulty])
	if practice:
		boost = distance>1200
	model.set_controls(index,aim,lean,boost,delta,guard)
	return {"zone":zone,"guard":guard,"lean":lean,"target_y":target_y,"committed":committed,"decisions":decision_count,"observation_age":elapsed-last_observation_time}

func _choose_target(seen: Dictionary, difficulty: int, rng: RandomNumberGenerator) -> String:
	if difficulty==0:
		return "body" if pass_id%2==1 else "head"
	var best_zone = "body"
	var best_score = -INF
	for candidate in ["head","body","flank"]:
		var separation = absf(float(seen[candidate])-float(seen.shield))
		var exposure = clampf((separation-28)/42,0,1) if float(seen.shield_hp)>0 else 1.0
		var score = exposure*2.5+({"head":.35,"body":.15,"flank":.05}[candidate])+rng.randf_range(0,.40 if difficulty==1 else .18)
		if score>best_score:
			best_score = score
			best_zone = candidate
	return best_zone
