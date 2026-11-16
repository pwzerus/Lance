extends "test_fall_v057.gd"
## Same 120Hz input, old source captured from c27ce93 vs current, each pose.
func run() -> void:
	var path="";var old_path=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):path=a.trim_prefix("--report=")
		if a.begins_with("--old="):old_path=a.trim_prefix("--old=")
	if path.is_empty() or FileAccess.file_exists(path) or not root.get_node("GameState").save_path.contains("qa_"):quit(2);return
	var Old=load(old_path)
	var equipment=root.get_node("GameState").default_profile().equipped.duplicate(true)
	equipment.merge({"helmet":"de_helmet_1","armor":"de_armor_1","shield":"de_shield_0"},true)
	stress_stats=Catalogue.stats(Catalogue.load_items(),equipment)
	var rows=[]
	for shield_scale in [.85,1.18]:
		stress_stats.shield_scale=shield_scale
		for zone in ["head","body","flank"]:
			for facing in [-1,1]:
				for lean in [-1.0,1.0]:
					pose_config={"lean":lean,"guard":1.0}
					var stage=Node2D.new();root.add_child(stage)
					var current=make_actor(stage,zone,facing,false,zone=="flank")
					var old=Old.new();stage.add_child(old)
					old.setup(current.fighter,{"zone":zone,"impulse":105.0,"direction":-facing})
					old.set_process(false);old.visual.set_process(false);old.far_leg.set_process(false)
					var worst=0.0;var before_us=0;var after_us=0
					for tick in range(480):
						var start=Time.get_ticks_usec();old.advance(1.0/120);before_us+=Time.get_ticks_usec()-start
						start=Time.get_ticks_usec();current.advance(1.0/120);after_us+=Time.get_ticks_usec()-start
						worst=maxf(worst,points_error(global_points(old),global_points(current)))
						check(old.settled==current.settled,"Same settling tick")
					check(worst<.002,"Full body trajectory preserved",{"zone":zone,"facing":facing,"lean":lean,"error":worst})
					rows.append({"zone":zone,"facing":facing,"lean":lean,"scale":shield_scale,"max_point_error":worst,"old_us":before_us,"new_us":after_us,"settled":current.settled})
					stage.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"baseline":"c27ce93668802be46f548e719f5c73ed9142657c"},"\t"))
	print("FALL_EQ099 ",failures)
	quit(0 if failures.is_empty() else 1)
