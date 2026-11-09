extends "test_head076.gd"

func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2); return
	for facing in [1,-1]:
		for helmet in [.08,.41]:
			for guard in [0.0,1.0]:
				for seed_value in range(2):
					var model=Model.new("war",{"helmet":helmet,"power":1.4},{"helmet":helmet,"power":1.4},7700+seed_value)
					var attacker=0 if facing==1 else 1
					var defender=1-attacker
					var hits=[]
					for tick in range(120*30):
						var target=Model.head_position(model.fighters[defender])
						var hand=Model.hand_position(model.fighters[attacker])
						model.set_controls(attacker,atan2(target.y-hand.y,maxf(1,absf(target.x-hand.x))),0,true,1.0/120)
						model.set_controls(defender,0,0,true,1.0/120,guard)
						model.step(1.0/120)
						for e in model.drain_events():
							if e.type=="hit" and e.attacker==attacker: hits.append(e)
						if model.pass_number>1 or model.phase=="ended": break
					rows.append({"facing":facing,"helmet":helmet,"guard":guard,"seed":seed_value,"hits":hits,"dead":model.fighters[defender].dead,"hp":model.fighters[defender].hp})
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"scope":"16 first-pass finite-control continuous head tracking trials; defender holds guard, not adaptive AI or human balance validation","rows":rows},"\t"))
	quit(0)


