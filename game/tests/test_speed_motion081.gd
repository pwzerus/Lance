extends "test_exchange_v056.gd"
## Reuse real viewport press/hold/release, actual motion and projection tests.
## --suite=input. No OS input, no human listening or feel claim.
func projection(battle) -> Dictionary:
	var row = super.projection(battle)
	battle._update_hud()
	var f: Dictionary = battle.match_model.fighters[0]
	var pose: Dictionary = Model.gait_pose(f)
	row["gait"] = battle.Rider.Gait.NAMES[battle.Rider.Gait.gait_index(f.speed)]
	row["rider_pitch"] = pose.rider_pitch
	row["horse_y"] = pose.offset.y
	row["status"] = battle.speed_label.text
	row["particles"] = battle.effects.particles.size()
	if battle.match_model.phase=="charge":
		check(battle.speed_label.text.contains(row.gait),"Actual gait missing from HUD",row)
	check(battle.effects.particles.size()<160,"Hoof dust grows without clearing",row)
	return row
