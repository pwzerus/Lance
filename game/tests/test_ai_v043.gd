extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Brain = preload("res://scripts/core/opponent_ai.gd")
var failures: Array = []
func _initialize() -> void:
	for difficulty in range(3):
		var model = Model.new()
		var brain = Brain.new()
		var rng = RandomNumberGenerator.new()
		rng.seed = 4301
		model.phase = "charge"
		for frame in range(240):
			brain.update(model,1,difficulty,1.0/120,rng)
			if brain.last_observation_time>=0 and brain.elapsed-brain.last_observation_time<Brain.REACTION[difficulty]-.0001:
				failures.append("AI observed information newer than its reaction delay")
		if brain.decision_count<1:
			failures.append("AI never made a delayed decision")
		var original = brain.target_y
		var defense = brain.guard
		model.fighters[0].x = -120
		model.fighters[1].x = 120
		model.fighters[0].guard = 1.0
		model.fighters[0].aim = .58
		model.fighters[0].lean = -1.0
		for frame in range(180):
			brain.update(model,1,difficulty,1.0/120,rng)
		if brain.target_y!=original or brain.guard!=defense:
			failures.append("Committed AI changed attack or defense using a late input")
		if model.fighters[1].hp!=100 or model.fighters[1].stats!={}:
			failures.append("Difficulty changed equipment or health")
		model.pass_number = 2
		model.fighters[0].x = -2200
		model.fighters[1].x = 2200
		brain.update(model,1,difficulty,1.0/120,rng)
		if brain.committed or brain.defense_committed or brain.history.size()!=1:
			failures.append("Round reset retained stale commitment/history")
	print("AI_V043 "+JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"delayed observations, immutable final commitments, no stat cheating, round resets"}))
	quit(0 if failures.is_empty() else 1)
