extends SceneTree
var main: Node
var state: Node
var failures: Array[String] = []
var capture_dir = "E:/GALUMU/docs/development/screenshots/v042/final/"

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
	state.profile = state.default_profile()
	state.profile.renown = 100
	state.profile.coins = 20000
	state.profile.settings.sound = false
	for item in state.items:
		if item.id not in state.profile.owned:
			state.profile.owned.append(item.id)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for code in ["eng","fr","de","it"]:
		state.profile.equipped.armor = code+"_armor_4"
		state.profile.equipped.helmet = code+"_helmet_4"
		state.profile.equipped.shield = code+"_shield_4"
		state.profile.equipped.lance = code+"_lance_long_4"
		main.show_home()
		await capture("10_home_"+code)
	main.selected_slot = "lance"
	main.selected_era = -1
	main.selected_region = 3
	main.selected_quality = 6
	main.show_armory()
	await capture("11_three_lances")
	main.selected_slot = "horse"
	main.selected_region = 0
	main.selected_quality = 0
	main.show_armory()
	await capture("12_ten_horses")
	main._start_match("arena",true)
	var battle = main.battle
	battle.autoplay = true
	battle.match_model.phase = "charge"
	for i in range(2):
		battle.match_model.fighters[i].x = -1400 if i==0 else 1400
		battle.match_model._cache_pose(battle.match_model.fighters[i])
	await capture("13_lanes_wide")
	var captured = false
	var sampled = 0
	var max_slip = 0.0
	var worst_support: Dictionary = {}
	var previous: Dictionary = {}
	for frame in range(900):
		await process_frame
		await RenderingServer.frame_post_draw
		for i in range(2):
			var rider = battle.riders[i]
			for leg_index in range(rider.leg_poses.size()):
				var leg = rider.leg_poses[leg_index]
				var key = "%d/%d" % [i,leg_index]
				var world_x = rider.position.x+leg.foot.x*int(rider.fighter.direction)
				# Compare only one continuous moving stance, not the standing-to-
				# running pose transition or a round reset/teleport.
				if leg.contact and previous.has(key) and previous[key].contact and previous[key].moving and previous[key].pass==battle.match_model.pass_number and leg.cycle>previous[key].cycle and rider.moving:
					var slip = absf(world_x-previous[key].x)
					if slip>max_slip:
						worst_support = {"previous":previous[key],"x":world_x,"phase":battle.match_model.phase,"pass":battle.match_model.pass_number,"frame":frame,"key":key,"moving":rider.moving}
					max_slip = maxf(max_slip,slip)
					sampled += 1
				previous[key] = {"contact":leg.contact,"cycle":leg.cycle,"x":world_x,"phase":battle.match_model.phase,"pass":battle.match_model.pass_number,"moving":rider.moving}
		if not captured and absf(battle.match_model.fighters[0].x-battle.match_model.fighters[1].x)<660:
			captured = true
			await capture("14_lanes_close")
		if main.result_visible:
			await capture("15_result")
			break
	if not captured:
		failures.append("Did not reach close exchange")
	if max_slip>1.0:
		failures.append("Planted hoof slid in rendered acceleration sequence")
	print("PRESENTATION_V042 "+JSON.stringify({"failures":failures,"sampled_support_frames":sampled,"max_world_hoof_slip":max_slip,"worst_support":worst_support,"passed":failures.is_empty()}))
	main._close_battle()
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
