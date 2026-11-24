extends "test_campaign_probe107.gd"
## Isolate the light-shield capacity change under identical current mechanics.
## The optional old-capacity arm is a counterfactual, not an old build replay.
func simulate(level:Dictionary,stats:Dictionary,enemy_stats:Dictionary,seed_value:int,side:int,strategy:String,fixed_guard:bool)->Dictionary:
	stats=stats.duplicate(true);enemy_stats=enemy_stats.duplicate(true)
	var old_capacity="--old-shield-capacity" in OS.get_cmdline_user_args()
	if old_capacity:
		for kit in [stats,enemy_stats]:
			if kit.get("shield_class","")=="light":kit.shield_capacity=100.0+50.0*int(kit.get("shield_line_tier",1))
	var result=super.simulate(level,stats,enemy_stats,seed_value,side,strategy,fixed_guard)
	result.shield_capacity_variant="old_capacity_only" if old_capacity else "current"
	result.actual_shield_capacities=[stats.shield_capacity,enemy_stats.shield_capacity]
	return result
