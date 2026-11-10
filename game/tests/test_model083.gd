extends SceneTree
const Current = preload("res://scripts/core/joust_match.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2);return
	var before=load("E:/GALUMU/docs/development/logs/perf083-baseline/joust_match.gd")
	print("MODEL083 baseline loaded")
	var failure=""
	var ticks=0
	var events=0
	var pairs=0
	for mode in ["arena","war"]:
		for seed_value in range(2):
			var old=before.new(mode,{}, {},8310+seed_value)
			var now=Current.new(mode,{}, {},8310+seed_value)
			for step in range(24000):
				for i in range(2):
					var aim=sin(step*.0017+i)*.43-.07
					var lean=sin(step*.0023+i*.9)
					var boost=step%1100>300
					var guard=float((step/600+i)%3)*.5
					old.set_controls(i,aim,lean,boost,1.0/120.0,guard)
					now.set_controls(i,aim,lean,boost,1.0/120.0,guard)
				old.step(1.0/120.0)
				now.step(1.0/120.0)
				ticks+=1
				var prior_events=old.drain_events()
				var new_events=now.drain_events()
				events+=new_events.size()
				if old.fighters!=now.fighters or old.phase!=now.phase or prior_events!=new_events:
					failure="step differs "+mode+" seed="+str(seed_value)+" tick="+str(step)
					break
				if now.phase=="ended": break
			pairs+=1
			print("MODEL083 pair=",pairs," ticks=",ticks," phase=",now.phase)
			if now.phase!="ended" and failure.is_empty(): failure="Bounded match did not finish"
			if not failure.is_empty(): break
		if not failure.is_empty(): break
	var data={"passed":failure.is_empty(),"failure":failure,"ticks":ticks,"matches":pairs,"events":events,"scope":"Exact fighter dictionaries, phases and events against frozen v0.4.36 model each 120Hz tick; sinusoidal aim/posture, three shields and variable sprint, arena/war."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("MODEL083 ",JSON.stringify(data))
	quit(0 if failure.is_empty() else 1)
