extends "test_fall_v057.gd"
## Hold the captured pose and momentum fixed while changing shield geometry.
## Uses production fall integration; no forced settling or enlarged limits.
func run() -> void:
	var path=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
	var state=root.get_node("GameState")
	if path.is_empty() or FileAccess.file_exists(path) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		quit(2)
		return
	var equipment=state.default_profile().equipped.duplicate(true)
	equipment.merge({"helmet":"de_helmet_1","armor":"de_armor_1","shield":"de_shield_0"},true)
	stress_stats=Catalogue.stats(Catalogue.load_items(),equipment)
	var rows=[]
	for shield_scale in [.85,1.0,1.18]:
		stress_stats.shield_scale=shield_scale
		for hit_zone in ["head","body","flank"]:
			for facing in [1,-1]:
				for lean in [-1.0,1.0]:
					for guard in [0.0,1.0]:
						pose_config={"lean":lean,"guard":guard}
						var stage=Node2D.new()
						root.add_child(stage)
						var actor=make_actor(stage,hit_zone,facing,false,hit_zone=="flank")
						var row={"zone":hit_zone,"facing":facing,"lean":lean,"guard":guard,"scale":shield_scale,"samples":[],"maximum_penetration":0.0,"maximum_bone_error":0.0,"landing_joint_motion":0.0}
						for tick in range(480):
							actor.advance(1.0/120)
							inspect(actor,row)
							if tick%30==29 and actor.age>2.9:
								var rates={"root":actor.angular_velocity}
								for name in actor.joints: rates[name]=actor.joints[name].velocity
								row.samples.append({"age":actor.age,"rates":rates,"targets":actor._joint_targets(),"gap":actor.support_gap()})
						row.settled=actor.settled
						row.settled_time=actor.age if actor.settled else -1
						row.final_gap=actor.support_gap()
						check(actor.settled,"Four-second rest: "+str([shield_scale,hit_zone,facing,lean,guard]))
						check(actor.support_gap()<14,"Torso support: "+str([shield_scale,hit_zone,facing,lean,guard]))
						rows.append(row)
						remove_stage(stage)
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows,"scope":"72 captured-pose production integrations: three shield scales, three hit regions, both facings and extreme lean/guard. No OS input or human quality verdict."},"  "))
	quit(0 if failures.is_empty() else 1)
