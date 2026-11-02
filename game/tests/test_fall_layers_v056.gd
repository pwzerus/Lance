extends "test_fall_scene_v050.gd"
## Two genuine swept fatal-body contacts through the inherited formal scene.
## Keep the established age-zero pose and live fall/release observations, and
## catch a near leg hidden by its own horse despite correct joint coordinates.
var layer_rows: Array = []

func effective_z(item: CanvasItem) -> int:
	var result = item.z_index
	var current: CanvasItem = item
	while current.z_as_relative:
		var ancestor = current.get_parent()
		if not ancestor is CanvasItem:
			break
		current = ancestor as CanvasItem
		result += current.z_index
	return result

func layer_snapshot(battle, actor, defender: int) -> Dictionary:
	var mounted = battle.riders[defender]
	return {"lane_y":actor.fighter.lane_y,"facing":actor.fighter.direction,"age":actor.age,
		"effects_tree_index":battle.effects.get_index(),"mounted_tree_index":mounted.get_index(),
		"effects_z":battle.effects.z_index,"fallen_z":actor.z_index,
		"visual_local_z":actor.visual.z_index,"far_leg_local_z":actor.far_leg.z_index,
		"mounted_effective_z":effective_z(mounted),"visual_effective_z":effective_z(actor.visual),
		"far_leg_effective_z":effective_z(actor.far_leg),"rail_effective_z":effective_z(battle.rail),
		"loose_lance_effective_z":effective_z(actor.loose_lance) if is_instance_valid(actor.loose_lance) else null}

func assert_first_pose(battle, actor, defender: int, name: String) -> void:
	super.assert_first_pose(battle,actor,defender,name)
	var row = layer_snapshot(battle,actor,defender)
	row["case"] = name
	row["stage"] = "first_contact"
	layer_rows.append(row)
	# The rider has not crossed the horse at age zero: its visible near leg
	# must remain on top of this horse, while the captured far leg stays back.
	var same_world = battle.effects.get_parent()==battle.riders[defender].get_parent()
	var main_above_horse = int(row.visual_effective_z)>int(row.mounted_effective_z)
	if int(row.visual_effective_z)==int(row.mounted_effective_z):
		main_above_horse = same_world and int(row.effects_tree_index)>int(row.mounted_tree_index)
	check(main_above_horse,"Age-zero fallen near leg remains above its own horse",row)
	check(int(row.far_leg_effective_z)<int(row.mounted_effective_z),"Age-zero fallen far leg remains behind its horse",row)
	var rail_ok = int(row.visual_effective_z)<int(row.rail_effective_z) if float(actor.fighter.lane_y)<0 else int(row.visual_effective_z)>int(row.rail_effective_z)
	check(rail_ok,"Fallen body retains its own side of the tilt rail",row)

func capture(battle, actor, name: String, stage: String) -> void:
	battle._update_hud()
	battle.queue_redraw()
	# The inherited fixture disables mounted _process. Invalidate its old
	# draw list after KO so it cannot masquerade as the newly detached rider.
	for mounted in battle.riders:
		mounted.queue_redraw()
	if is_instance_valid(actor):
		actor.visual.queue_redraw()
		actor.far_leg.queue_redraw()
		var defender = 0 if int(actor.fighter.direction)==1 else 1
		var row = layer_snapshot(battle,actor,defender)
		row["case"] = name
		row["stage"] = stage
		layer_rows.append(row)
	await super.capture(battle,actor,name,stage)

func run() -> void:
	report_path = "E:/GALUMU/docs/development/logs/v056/fall-layers01.json"
	capture_dir = "E:/GALUMU/docs/development/screenshots/v056/fall-layers01"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--captures="): capture_dir = arg.trim_prefix("--captures=")
		elif arg=="--no-captures": captures_enabled = false
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Fall layering regression requires GPU and isolated -- --test-profile")
		quit(2)
		return
	if FileAccess.file_exists(report_path) or (captures_enabled and DirAccess.dir_exists_absolute(capture_dir)):
		push_error("Use fresh fall layering report and capture paths")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	if captures_enabled: DirAccess.make_dir_recursive_absolute(capture_dir)
	var original_profile: Dictionary = state.profile.duplicate(true)
	state.profile = state.default_profile()
	state.profile.settings.blood = false
	state.profile.settings.sound = false
	state.profile.settings.shake = false
	state.profile.settings.aim_cues = false
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for attacker in [0,1]:
		await run_case("war",attacker,"body",false,false)
	main._close_battle()
	main.queue_free()
	await process_frame
	await process_frame
	state.profile = original_profile
	check(is_equal_approx(Engine.time_scale,1.0) and not paused,"Fall layering teardown restores time and pause state")
	var result = {"passed":failures.is_empty() and cases.size()==2,"failures":failures,"examples":examples,
		"cases":cases,"layers":layer_rows,"captures":captures,
		"project_version":ProjectSettings.get_setting("application/config/version","unknown"),
		"scope":"Two production body KOs, one defender per lane/facing, using inherited finite-control swept contacts and real Battle consumers. Existing age-zero joint continuity, blood-off, live fall/weapon release, floor collision and scene replay checks remain. Added scene draw-order contract protects the visible near leg while preserving the far leg and tilt-rail side.",
		"fixture_limits":"Defender starts at 1HP with shield disabled; other rider already acted. QA camera fits body/held or loose weapon for screenshots. Not production framing/timing, autonomous AI balance, OS input or human gameplay. PNG review is required to confirm visible near thigh/shin before and after the exact switch, correct far-side occlusion and released lance; numerical joint continuity alone is insufficient."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write fall layering report")
		quit(3)
		return
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("FALL_LAYERS_V056 passed=",result.passed," cases=",cases.size()," failures=",failures)
	quit(0 if result.passed else 1)
