extends "test_impact_v057.gd"
## Production rendered Battle, genuine finite-control swept contacts.
## High seat stability keeps the shield cases mounted for comparison.
var kind102="center"
var prepared102: Node

func create_battle(_mode_name: String, _slow: bool):
	return prepared102

func stage_model(model, attacker: int, zone: String, fatal: bool, phase: float, solid: bool=false, broken_fixture: bool=false) -> void:
	super.stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
	# Keep torso examples mounted; standard-stability body impacts legitimately
	# unhorse in the current combat rules. This is a presentation fixture.
	if zone=="body":
		for f in model.fighters:
			f.stats.stability=3.0
			f.balance=300.0 # Full trunk blow otherwise legitimately empties balance.

func aim_for(model, attacker: int, zone: String) -> float:
	var d: Dictionary=model.fighters[1-attacker]
	var target=Model.shield_position(d) if zone=="shield" else Model.body_position(d)
	if zone=="shield" and kind102=="rim":target.y+=43.0
	return asin(clampf((target.y-Model.hand_position(model.fighters[attacker]).y)/Model.lance_length(model.fighters[attacker]),-.629,.548))

func find_stage(battle, attacker: int, zone: String, fatal: bool, solid: bool=false, broken_fixture: bool=false) -> Dictionary:
	for phase in [0.0,.55,1.2,2.2,3.4,4.5]:
		var model=Model.new(battle.mode,battle.match_model.fighters[0].stats,battle.match_model.fighters[1].stats,57051)
		stage_model(model,attacker,zone,fatal,phase,false,false)
		for tick in range(360):
			for e in step_staged(model,attacker,zone):
				if e.type=="hit" and int(e.attacker)==attacker and e.zone==zone and not e.ko:
					if zone!="shield" or bool(e.glanced)==(kind102=="rim"):
						return {"gait_phase":phase,"ticks":tick+1,"preview":e.duplicate(true)}
			if model.phase=="ended":break
	return {}

func snapshot(battle, actor, name: String, stage: String, elapsed: float) -> void:
	await super.snapshot(battle,actor,name+"_"+kind102,stage,elapsed)

func run() -> void:
	var folder="";var limit=6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--limit="):limit=int(a.trim_prefix("--limit="))
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in state.save_path or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);capture_dir=folder
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=true;state.profile.settings.shake=true
	state.profile.equipped.shield="eng_shield_5"
	state.profile.owned.append("eng_shield_5")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	for side in range(2):
		for kind in ["center","rim","body"]:
			if cases.size()>=limit:break
			kind102=kind
			capture_dir=folder+"/"+str(side)+"_"+kind
			DirAccess.make_dir_recursive_absolute(capture_dir)
			state.profile.settings.slow_motion=true
			main._start_match("arena",true)
			prepared102=main.battle
			prepared102.set_physics_process(false)
			prepared102.set_process_input(false);prepared102.set_process_unhandled_input(false)
			while not prepared102.presentation_ready:await process_frame
			configure(prepared102)
			var before=cases.size()
			await live_case(side,"body" if kind=="body" else "shield",false,true)
			if cases.size()>before:cases[-1].feedback_kind=kind
			for item in images:check(item.image.save_png(item.path)==OK,"Screenshot write")
			images.clear() # Bounded image memory per case.
	main.sounds.stop_all();main._close_battle();main.queue_free();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"examples":examples,"cases":cases,"version":ProjectSettings.get_setting("application/config/version"),"scope":"Isolated GPU Battle and real finite-control sweeps; shield seat stability 1.5, body seat 3.0 and balance 300 to isolate mounted follow-through; not balance, human play or performance benchmark."},"\t"))
	print("FEEDBACK102 ",failures);quit(0 if failures.is_empty() else 1)
