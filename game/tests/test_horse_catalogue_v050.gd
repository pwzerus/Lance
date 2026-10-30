extends "test_horse_anatomy_v050.gd"
## Reuses the unchanged anatomy/continuity limits; skips the 24 steady cases.
## Source AND exported EXE can load this external script next to its base.
const Catalogue = preload("res://scripts/core/catalogue.gd")
var active_horse: Dictionary = {}
var active_stats: Dictionary = {}

func check(ok: bool, message: String) -> void:
	super.check(ok,"["+str(active_horse.get("id","catalogue"))+"] "+message)

func make_fixture(facing: int, speed: float) -> Dictionary:
	var model = Model.new("arena",active_stats.duplicate(true),active_stats.duplicate(true),5050)
	model.phase = "charge"
	model.fighters[0].x = -50000.0
	model.fighters[1].x = 50000.0
	for member in model.fighters:
		member.acted = true
	var index = 0 if facing==1 else 1
	var fighter: Dictionary = model.fighters[index]
	fighter.speed = speed*float(active_stats.get("speed",1.0))
	fighter.gait_phase = 0.0
	fighter.gait_moving = true
	fighter.lane_y = 0.0
	model._cache_pose(fighter)
	var view = Rider.new()
	view.fighter = fighter
	view.moving = true
	root.add_child(view)
	view.set_process(false)
	return {"model":model,"index":index,"fighter":fighter,"view":view}

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
		push_error("Catalogue anatomy study requires -- --test-profile")
		quit(1)
		return
	var path = "E:/GALUMU/docs/development/logs/v050/catalogue-anatomy-01.json"
	var selected_ids: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			path = arg.trim_prefix("--report-path=")
		if arg.begins_with("--horse-ids="):
			for id in arg.trim_prefix("--horse-ids=").split(",",false):
				selected_ids.append(str(id))
	var items = Catalogue.load_items()
	var horses: Array[Dictionary] = []
	# Exercise the known fastest and most stable configurations first.
	for id in ["horse_courser","horse_steady"]:
		var item: Dictionary = Catalogue.find(items,id)
		if not item.is_empty() and (selected_ids.is_empty() or id in selected_ids):
			horses.append(item)
	for item in items:
		if item.get("slot","")=="horse" and item.id not in ["horse_courser","horse_steady"] and (selected_ids.is_empty() or str(item.id) in selected_ids):
			horses.append(item)
	check(not horses.is_empty(),"No catalogue horses selected")
	for id in selected_ids:
		check(not Catalogue.find(items,id).is_empty(),"Unknown selected horse "+id)
	var horse_rows: Array = []
	for horse in horses:
		active_horse = horse
		active_stats = Catalogue.stats(items,{"horse":str(horse.id)})
		var cruise = Model.TROT_SPEED*float(active_stats.get("speed",1.0))
		var gallop = Model.GALLOP_SPEED*float(active_stats.get("speed",1.0))
		horse_rows.append({"id":horse.id,"stats":active_stats.duplicate(true),"expected_cruise":cruise,"expected_gallop":gallop})
		for hz in [30,60,120]:
			for facing in [1,-1]:
				await super.transition_trial(facing,hz)
				var row: Dictionary = transition_rows[-1]
				row.horse_id = horse.id
				row.stats = active_stats.duplicate(true)
				row.expected_cruise = cruise
				row.expected_gallop = gallop
				check(float(row.speed_max)>=gallop*.98,"Actual held model failed to approach configured gallop")
				var held_sample: Dictionary = row.samples[2]
				var released_sample: Dictionary = row.samples[3]
				check(bool(held_sample.held) and not bool(released_sample.held),"Release comparison did not straddle actual control change")
				check(float(released_sample.speed)<float(held_sample.speed)-20.0,"Actual model did not slow after release")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write catalogue anatomy report: "+path)
		quit(1)
		return
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"selected_ids":selected_ids,"horses":horse_rows,"transitions":transition_rows,
		"scope":"Actual Catalogue stats and production Model hold/release drive world-translated RiderView, both directions at 30/60/120Hz. Reuses anatomy/support-lock, bone, hoof, toe and shape limits. Joint raw world peaks are preserved; only rigid body.x transport above the original 480 reference is subtracted for the same 2600 bound, while independent local articulation also retains a 2600 bound. Articulation is not divided by horse speed. Default covers every catalogue horse, fastest/most stable first; --horse-ids selects explicit subset. No repeated steady suite, render capture, OS events or human motion-quality claim."},"\t"))
	file.close()
	print("HORSE_CATALOGUE_V050 "+str(failures.is_empty())+" failures="+str(failures))
	quit(0 if failures.is_empty() else 1)
