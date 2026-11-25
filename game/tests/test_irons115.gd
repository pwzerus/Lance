extends SceneTree
## Separate moving horse supports from voluntary foot targets. The same
## spur request must not move the iron before the horse itself has moved.
const Model=preload("res://scripts/core/joust_match.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var rows=[]
	var stats=Catalogue.stats(Catalogue.load_items(),root.get_node("GameState").default_profile().equipped)
	for facing in [1,-1]:
		for phase in [.6,1.6,2.6,4.6]:
			var model=Model.new("arena",stats,stats)
			var f:Dictionary=model.fighters[0]
			f.direction=facing;f.speed=300.0;f.gait_moving=true;f.gait_phase=phase
			f.boost=false
			var calm=Model.physical_targets115(f)
			f.boost=true
			var urged=Model.physical_targets115(f)
			for side in ["near","far"]:
				var iron_change=Vector2(urged.legs[side].stirrup).distance_to(calm.legs[side].stirrup)
				var foot_change=Vector2(urged.legs[side].ankle).distance_to(calm.legs[side].ankle)
				if iron_change>.00001:failures.append("Spur teleports iron support: "+str([facing,phase,side,iron_change]))
				rows.append({"facing":facing,"phase":phase,"side":side,"iron_change":iron_change,"foot_target_change":foot_change})
	var rides=[]
	for aim in [-.08,.44]:
		var model=Model.new("arena",stats,stats)
		model.phase="charge"
		for index in range(2):
			var f:Dictionary=model.fighters[index]
			f.x=(-4500.0 if index==0 else 4500.0);f.acted=true
			model._cache_pose(f)
		var min_support=[1.0,1.0]
		for tick in range(14*120):
			for index in range(2):model.set_controls(index,aim,0.0,tick>=4*120 and tick<9*120,1.0/120.0,.43)
			model.step(1.0/120.0)
			for index in range(2):min_support[index]=minf(min_support[index],model.fighters[index].seat_support)
		for index in range(2):
			var f:Dictionary=model.fighters[index]
			if f.unseated:failures.append("Calm spur/coast cycle ejects rider: "+str([aim,index]))
			rides.append({"aim":aim,"side":index,"unseated":f.unseated,"minimum_support":min_support[index],"stamina":f.stamina})
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"support_cases":rows,"rides":rides,"scope":"Rule/physical support probe, no GPU or real input acceptance."},"\t"))
	print("IRONS115 ",failures)
	quit(0 if failures.is_empty() else 1)
