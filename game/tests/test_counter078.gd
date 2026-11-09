extends "test_head076.gd"

func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	for facing in [1,-1]:
		for helmet in [.08]:
			for guard in [0.0,1.0]:
				for seed_value in range(1):
					var model=Model.new("war",{"helmet":helmet,"power":1.4},{"helmet":helmet,"power":1.4},7700+seed_value)
					var attacker=0 if facing==1 else 1
					var defender=1-attacker
					# Mirror the entire geometry, not just exchange the attacker label.
					if facing==-1:
						var lane=model.fighters[0].lane_y
						var gait=model.fighters[0].gait_phase
						model.fighters[0].lane_y=model.fighters[1].lane_y
						model.fighters[0].gait_phase=model.fighters[1].gait_phase
						model.fighters[1].lane_y=lane
						model.fighters[1].gait_phase=gait
						for f in model.fighters: model._cache_pose(f)
					var hits=[]
					for tick in range(120*30):
						var target=Model.head_position(model.fighters[defender])
						var hand=Model.hand_position(model.fighters[attacker])
						model.set_controls(attacker,atan2(target.y-hand.y,maxf(1,absf(target.x-hand.x))),0,true,1.0/120)
						model.set_controls(defender,0,0,true,1.0/120,guard)
						model.step(1.0/120)
						for e in model.drain_events():
							if e.type=="hit": hits.append(e)
						if model.pass_number>1 or model.phase=="ended": break
					rows.append({"facing":facing,"helmet":helmet,"guard":guard,"seed":seed_value,"hits":hits,"dead":model.fighters[defender].dead,"hp":model.fighters[defender].hp,"attacker_hp":model.fighters[attacker].hp,"phase":model.phase,"attacker":attacker})
	for i in range(2):
		check(is_equal_approx(rows[i].hp,rows[i+2].hp) and is_equal_approx(rows[i].attacker_hp,rows[i+2].attacker_hp),"Mirrored outcome differs")
		check(rows[i].hits.size()==rows[i+2].hits.size(),"Mirrored contact count differs")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Four complete-geometry mirrored trials; records BOTH attacks to distinguish preemption from misses","rows":rows,"passed":failures.is_empty(),"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
