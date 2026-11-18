extends "test_scene104.gd"
## Four real swept fractures in the second-level production scene. Exhausted
## lance durability and one-HP defender force the event, not campaign difficulty.
func prepare(model, attacker:int, zone:String, c:Dictionary)->void:
	super.prepare(model,attacker,zone,c)
	model.fighters[attacker].durability=.001

func run_battle()->void:
	var state=root.get_node("GameState")
	state.save_path=report_path.get_base_dir()+"/qa_profile.json"
	state.backup_path=report_path.get_base_dir()+"/qa_backup.json"
	state.profile=state.default_profile();state.profile.settings.sound=true
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,810);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	report.battle=[]
	for c in [
		{"name":"fracture_right_fast","attacker":0,"zone":"body","att":480.0,"def":480.0,"gap":950.0,"ko":true},
		{"name":"fracture_left_fast","attacker":1,"zone":"head","att":480.0,"def":480.0,"gap":950.0,"ko":true},
		{"name":"fracture_right_slow","attacker":0,"zone":"body","att":190.0,"def":190.0,"gap":650.0,"ko":true},
		{"name":"fracture_left_slow","attacker":1,"zone":"body","att":190.0,"def":190.0,"gap":650.0,"ko":true}]:
		await run_battle_case(c)
	main._close_battle();main.queue_free();await process_frame;await process_frame

func after_result(c:Dictionary,b:Node)->void:
	var hits=report.battle[-1].hits
	check(hits.size()==1 and hits[0].broke,"Exactly one real fracture per case")
	if not hits.is_empty():
		check(hits[0].has("break_hand_velocity"),"Real render receives contact motion snapshot")
	check(b.match_model.fighters[int(c.attacker)].broken,"Mounted rider retains the short broken lance")
	check(b.effects.debris.size()==2,"Two physical fragments survive the short cinematic")
	var pieces=[]
	for body in b.effects.debris:
		if not is_instance_valid(body):continue
		check(body.position.is_finite() and body.linear_velocity.is_finite(),"Physical fragment remains finite")
		pieces.append({"position":body.position,"velocity":body.linear_velocity,"rotation":body.rotation})
	report.battle[-1].fragment_endpoints=pieces
	await super.after_result(c,b)
