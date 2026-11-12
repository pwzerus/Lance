extends "test_feedback088.gd"
func find_stage(battle, attacker: int, zone: String, fatal: bool, solid: bool = false, broken_fixture: bool = false) -> Dictionary:
	for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
		var model=Model.new(battle.mode,battle.match_model.fighters[0].stats.duplicate(true),battle.match_model.fighters[1].stats.duplicate(true),57051)
		stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
		var found=false
		for tick in range(360):
			for event in step_staged(model,attacker,zone):
				if event.type=="hit":
					var diagnostic={"target":zone,"attacker":attacker,"phase":phase,"tick":tick,"event":event}
					print("PROBE088 ",JSON.stringify(diagnostic));found=true
					break
			if found or model.phase=="ended":break
	return super.find_stage(battle,attacker,zone,fatal,solid,broken_fixture)
