extends SceneTree
var main: Node
var state: Node
var failures: Array[String] = []
var capture_dir = "E:/GALUMU/docs/development/screenshots/v043/candidate01/"

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var error = root.get_texture().get_image().save_png(capture_dir+label+".png")
	if error!=OK:
		failures.append("Capture failed: "+label)
	print("PRESENTATION_CAPTURE ",label," ",error)

func run() -> void:
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")+"/"
	state.profile = state.default_profile()
	state.profile.settings.sound = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await capture("01_home")
	main.show_match_setup()
	await capture("02_setup")
	state.save_slot(1)
	main.show_saves("已保存到存档 1")
	await capture("03_saves")
	main.show_settings()
	await capture("04_settings")
	main._begin_match("arena",true)
	await capture("05_brief")
	main._start_match("arena",true)
	var battle = main.battle
	battle.autoplay = true
	battle.set_physics_process(false)
	battle.set_process(false)
	battle.match_model.phase = "charge"
	battle.camera.position = Vector2(720,450)
	battle.camera.zoom = Vector2.ONE*1.65
	battle.camera.force_update_scroll()
	for guard in range(3):
		for i in range(2):
			var f = battle.match_model.fighters[i]
			f.x = -235 if i==0 else 235
			f.guard = battle.GUARD_VALUES[guard]
			f.guard_target = f.guard
			f.gait_moving = false
			f.aim = asin(clampf((battle.Model.shield_position(battle.match_model.fighters[1-i]).y-battle.Model.hand_position(f).y)/battle.Model.lance_length(f),-.629,.548))
			battle.match_model._cache_pose(f)
		battle.guard_slot = guard
		battle._update_views()
		battle._update_hud()
		await capture("06_shields_"+str(guard))
	var event = {"type":"hit","attacker":0,"defender":1,"zone":"body","position":battle.Model.body_position(battle.match_model.fighters[1]),"damage":25.0,"impulse":48.0,"broke":false,"ko":false,"dead":false}
	battle._handle_event(event)
	Engine.time_scale = 1.0
	battle._update_hud()
	await capture("07_impact")
	main._close_battle()
	main.queue_free()
	await process_frame
	await create_timer(.3,true,false,true).timeout
	print("PRESENTATION_V043 "+JSON.stringify({"failures":failures,"passed":failures.is_empty(),"scope":"engine rendering; staged poses, not gameplay balance"}))
	quit(0 if failures.is_empty() else 1)

