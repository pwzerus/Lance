extends SceneTree

var main: Node
var state: Node

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png("E:/GALUMU/docs/development/screenshots/v04/"+name_value+".png")
	print("UI_STATE ",name_value," ",error)

func run() -> void:
	state = root.get_node("GameState")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	state.profile.renown = 48
	state.profile.coins = 9999
	for item in state.items:
		if item.id not in state.profile.owned:
			state.profile.owned.append(item.id)
	state.profile.equipped = {"armor":"armor_e4","helmet":"helm_e4","lance":"lance_e4","horse":"horse_e4","crest":"crest_cross"}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await capture("09_ornate_home")
	main._begin_match("arena")
	await capture("10_first_brief")
	main.show_settings()
	await capture("11_settings")
	main.selected_slot = "helmet"
	main.selected_era = 4
	main.show_armory()
	await capture("12_late_gear")
	main._start_match("war")
	main.battle.autoplay = true
	main.battle._toggle_pause()
	await capture("13_pause")
	main._close_battle()
	main._start_match("arena",true)
	await capture("14_practice_ready")
	main.battle.set_physics_process(false)
	main.battle.match_model.phase = "charge"
	main.battle.match_model.fighters[0].x = -250
	main.battle.match_model.fighters[1].x = 250
	main.battle.camera.zoom = Vector2.ONE*1.3
	main.battle.guard_high = true
	main.battle.match_model.fighters[0].guard = 1.0
	main.battle.match_model.fighters[1].guard = 0.0
	main.battle._update_views()
	await capture("15_practice_close")
	main._close_battle()
	state.profile = state.default_profile()
	state.save_profile()
	main.queue_free()
	await process_frame
	quit()
