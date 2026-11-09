extends "test_impact_v057.gd"
## Real GPU contacts with normal HUD. Numeric telemetry belongs to H only.
func snapshot(battle, actor, name: String, stage: String, elapsed: float) -> void:
	battle._update_hud()
	if not battle.training_zones:
		for label in [battle.tactics_label,battle.speed_label,battle.fatigue_label]:
			check(not label.text.contains("%") and not label.text.contains("/秒") and not label.text.contains("kg"),"Normal HUD leaked telemetry",{"text":label.text})
		check(not battle.speed_meter.visible,"Redundant speed gauge still shown")
	await super.snapshot(battle,actor,name,stage,elapsed)
