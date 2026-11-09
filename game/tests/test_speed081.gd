extends "test_impact_v057.gd"
## Compare actual low/high speed sweeps with identical equipment/targets.
## --low-speed selects coasting; no event strengths or damage are injected.
var fast_charge = true

func _initialize() -> void:
	fast_charge = not "--low-speed" in OS.get_cmdline_user_args()
	super._initialize()

func stage_model(model, attacker: int, zone: String, fatal: bool, phase: float, solid: bool = false, broken_fixture: bool = false) -> void:
	super.stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
	for fighter in model.fighters:
		fighter.speed = Model.GALLOP_SPEED if fast_charge else Model.TROT_SPEED
		fighter.boost = fast_charge
	model.fighters[attacker].aim = aim_for(model,attacker,zone)
	for fighter in model.fighters: model._cache_pose(fighter)

func step_staged(model, attacker: int, zone: String) -> Array:
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		var before = float(fighter.aim)
		model.set_controls(index,aim_for(model,attacker,zone) if index==attacker else .58,0.0,fast_charge,PHYSICS_DT,float(fighter.guard_target))
		check(absf(float(fighter.aim)-before)<=2.2*PHYSICS_DT*float(fighter.stats.get("lance_handling",1.0))+.0001,"Speed fixture bypassed finite aim travel")
	model.step(PHYSICS_DT)
	return model.drain_events()

func observe(battle, actor, elapsed: float) -> Dictionary:
	var row = super.observe(battle,actor,elapsed)
	row["speed_mode"] = "high" if fast_charge else "low"
	row["actual_speeds"] = [battle.match_model.fighters[0].speed,battle.match_model.fighters[1].speed]
	row["particle_count"] = battle.effects.particles.size()
	check(battle.effects.particles.size()<160,"Contact particles accumulated beyond short-lived budget")
	if not battle.exchange_log.is_empty():
		var event: Dictionary = battle.exchange_log[-1]
		row["visual_strength"] = Exchange.contact_strength(event)
		var counters = battle.sound._impact_counters.duplicate(true)
		var cue: Dictionary = battle.sound.impact_cue(event,battle.match_model.fighters[int(event.defender)].stats)
		battle.sound._impact_counters = counters # Observation must not rotate audio variants.
		row["sound_strength"] = cue.strength
		row["sound_db"] = cue.db
		check(is_equal_approx(row.visual_strength,row.sound_strength),"Sound and visual force disagree")
	return row

func snapshot(battle, actor, name: String, stage: String, elapsed: float) -> void:
	battle._update_hud()
	if battle.match_model.phase=="charge":
		var gait = battle.Rider.Gait.NAMES[battle.Rider.Gait.gait_index(battle.match_model.fighters[0].speed)]
		check(battle.speed_label.text.contains(gait),"HUD shows spur input but hides actual gait")
	await super.snapshot(battle,actor,name,stage,elapsed)
