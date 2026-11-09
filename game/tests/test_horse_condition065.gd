extends SceneTree
## HORSE-065 rule study: fatigue from load and effort through the real match
## model (set_controls + step at 60Hz), no rendering. Compares a light kit and
## a heavy kit on the default horse and on the fastest and steadiest horses.
const Model = preload("res://scripts/core/joust_match.gd")
const Condition = preload("res://scripts/core/horse_condition.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="): path = arg.trim_prefix("--report-path=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var rows = []
	for horse in ["horse_bay","horse_courser","horse_steady"]:
		for kit in ["light","heavy"]:
			var equipped = {"horse":horse}
			var stats = catalogue.stats(items,equipped)
			if kit=="heavy":
				stats.armor_tier = 5
				stats.helmet_tier = 5
				stats.shield_capacity = 110.0
				stats.reach = 290.0
			else:
				stats.armor_tier = 0
				stats.helmet_tier = 0
			rows.append(_sustained(horse,kit,stats))
	# Light kit must outlast heavy kit on the same horse.
	for i in range(0,rows.size(),2):
		check(rows[i].seconds_to_tired>rows[i+1].seconds_to_tired,"Heavy kit did not tire %s sooner" % rows[i].horse)
		check(rows[i].speed_after_20s>=rows[i+1].speed_after_20s-.01,"Heavy kit kept more speed on %s" % rows[i].horse)
	for row in rows:
		check(row.min_speed_spent>=Model.TROT_SPEED*.98,"Spent horse fell below the trot")
		check(row.max_speed_step<=12.0,"Speed jumped between frames")
		check(row.recovered_after_rest>row.stamina_spent,"No recovery between passes")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	file.close()
	print("HORSE_CONDITION_065 "+str(failures.is_empty())+" "+str(failures))
	for row in rows:
		print(JSON.stringify(row))
	quit(0 if failures.is_empty() else 1)

func _sustained(horse: String, kit: String, stats: Dictionary) -> Dictionary:
	# Hold the spur for 30 seconds of open charge, far from the opponent.
	var model = Model.new("arena",stats,stats,5001)
	model.phase = "charge"
	model.fighters[0].x = -900000.0
	model.fighters[1].x = 900000.0
	var dt = 1.0/60.0
	var tired_at = -1.0
	var speed_20 = 0.0
	var peak = 0.0
	var min_spent = INF
	var max_step = 0.0
	var previous = float(model.fighters[0].speed)
	for tick in range(30*60):
		model.set_controls(0,-.08,0.0,true,dt,.43)
		model.set_controls(1,-.08,0.0,false,dt,.43)
		model.step(dt)
		var fighter: Dictionary = model.fighters[0]
		var speed = float(fighter.speed)
		peak = maxf(peak,speed)
		max_step = maxf(max_step,absf(speed-previous))
		previous = speed
		if tired_at<0.0 and float(fighter.stamina)<Condition.TIRED:
			tired_at = tick*dt
		if tick==20*60:
			speed_20 = speed
		if float(fighter.stamina)<=0.0:
			min_spent = minf(min_spent,speed)
	var spent = float(model.fighters[0].stamina)
	# Rest like a re-rack/countdown (about 4 seconds of turn + ready).
	model.phase = "ready"
	model.phase_time = 999.0
	for tick in range(4*60):
		model.step(dt)
	return {"horse":horse,"kit":kit,"load_kg":Condition.load_kg(stats),"capacity_kg":Condition.capacity_kg(stats),"burden":Condition.burden(stats),
		"peak_speed":peak,"seconds_to_tired":tired_at if tired_at>=0.0 else 999.0,"speed_after_20s":speed_20,"stamina_spent":spent,
		"min_speed_spent":min_spent if min_spent<INF else peak,"max_speed_step":max_step,"recovered_after_rest":float(model.fighters[0].stamina)}
