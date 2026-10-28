extends SceneTree
## Actual RiderView support, not just the nominal Gait.leg duty schedule.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const HZ = 120.0
const DT = 1.0 / HZ
var failures: Array[String] = []
var rows: Array = []
var reset_rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func advance(fighter: Dictionary, view, speed: float) -> void:
	fighter.speed = speed
	fighter.x += speed * int(fighter.direction) * DT
	fighter.gait_phase += TAU * Gait.frequency(speed) * DT
	fighter.gait_moving = true
	view.position = Vector2(fighter.x, 0)
	view._process(DT)

func check_current_world_cache(fighter: Dictionary, view, label: String) -> void:
	for index in range(4):
		var foot: Vector2 = view.last_feet[index]
		check(foot.is_finite(), label + ": last foot must have a finite current location")
		check(absf(foot.x - float(fighter.x)) < 400.0, label + ": last foot still references the previous round's world position")
		var planted = float(view.planted_feet[index])
		if is_finite(planted):
			check(absf(planted - float(fighter.x)) < 400.0, label + ": planted foot still references the previous round")
		var swing_start: Vector2 = view.swing_starts[index]
		if swing_start.is_finite():
			check(absf(swing_start.x - float(fighter.x)) < 400.0, label + ": swing still starts in the previous round")

func run_case(speed: float, facing: int) -> void:
	var model = Model.new("arena", {"stability": 1.0}, {"stability": 1.0})
	var fighter = model.fighters[0]
	fighter.direction = facing
	fighter.x = 20000.0 * facing
	fighter.lane_y = 0.0
	fighter.speed = speed
	fighter.gait_phase = 0.0
	fighter.gait_moving = true
	var view = Rider.new()
	view.fighter = fighter
	view.moving = true
	root.add_child(view)
	view.set_process(false)
	var period = 1.0 / Gait.frequency(speed)
	var warm_ticks = ceili(2.0 * period * HZ)
	var observe_ticks = ceili(2.0 * period * HZ)
	var landings = [0, 0, 0, 0]
	view.hoof_contact.connect(func(index: int) -> void: landings[index] += 1)
	for tick in range(warm_ticks):
		advance(fighter, view, speed)
	for index in range(4):
		landings[index] = 0
	var counts = [0, 0, 0, 0]
	var runs = [0, 0, 0, 0]
	var longest = [0, 0, 0, 0]
	var min_support = 4
	var flight_frames = 0
	var support_deficit_frames = 0
	var first_deficit: Dictionary = {}
	for tick in range(observe_ticks):
		advance(fighter, view, speed)
		var support = 0
		for index in range(4):
			var pose: Dictionary = view.leg_poses[index]
			check(pose.foot.is_finite(), "Rendered support hoof must remain finite")
			check(pose.foot.y <= Gait.GROUND + .02, "Rendered hoof penetrated the ground in a steady gait")
			if pose.contact:
				support += 1
				counts[index] += 1
				runs[index] += 1
				longest[index] = maxi(longest[index], runs[index])
				check(absf(pose.foot.y - Gait.GROUND) < .02, "Rendered support hoof floated above ground")
			else:
				runs[index] = 0
		min_support = mini(min_support, support)
		if support == 0:
			flight_frames += 1
		if speed == 110.0 and support < 2:
			support_deficit_frames += 1
			if first_deficit.is_empty():
				first_deficit = {"tick": tick, "phase": fighter.gait_phase, "supports": support}
	for index in range(4):
		check(counts[index] > 0, "Steady %s leg %d never supported the body (facing %d)" % [speed, index, facing])
		check(longest[index] >= 2, "Steady %s leg %d had no two-frame support interval (facing %d)" % [speed, index, facing])
		check(landings[index] >= 1, "Steady %s leg %d emitted no new landing (facing %d)" % [speed, index, facing])
	if speed == 110.0:
		check(support_deficit_frames == 0, "Walking RiderView had fewer than two supporting feet")
	if speed == 480.0:
		check(flight_frames > 0, "Galloping RiderView had no suspension interval")
	rows.append({"speed": speed, "facing": facing, "hz": HZ, "warm_cycles": 2, "observed_cycles": 2, "observed_frames": observe_ticks, "support_frames": counts, "longest_support_run": longest, "landing_events": landings, "minimum_supports": min_support, "flight_frames": flight_frames, "walk_deficit_frames": support_deficit_frames, "first_deficit": first_deficit})
	# Simulate a new match's stationary interval after world repositioning.
	var old_x = float(fighter.x)
	fighter.x = -30000.0 * facing
	fighter.speed = 0.0
	fighter.gait_phase = 0.0
	fighter.gait_moving = false
	view.position = Vector2(fighter.x, 0)
	view.moving = false
	view._process(DT)
	for index in range(4):
		check(not is_finite(float(view.planted_feet[index])), "Stationary reset retained a planted hoof from the previous round")
		check(not view.swing_starts[index].is_finite(), "Stationary reset retained an old swing start")
	check_current_world_cache(fighter, view, "Stationary reset")
	view.moving = true
	advance(fighter, view, 210.0)
	check_current_world_cache(fighter, view, "Restart after stationary reset")
	# Also verify the direct phase-rewind path, without a stationary frame.
	for tick in range(80):
		advance(fighter, view, 210.0)
	fighter.x = 40000.0 * facing
	fighter.gait_phase = 0.0
	view.position = Vector2(fighter.x, 0)
	view._process(DT)
	check_current_world_cache(fighter, view, "Direct phase rewind")
	reset_rows.append({"speed_before_reset": speed, "facing": facing, "old_x": old_x, "stationary_restart_x": -30000.0 * facing, "direct_rewind_x": fighter.x})
	view.queue_free()
	await process_frame

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state == null or not state.save_path.contains("qa_"):
		push_error("Support study requires -- --test-profile")
		quit(1)
		return
	for speed in [110.0, 210.0, 340.0, 480.0]:
		for facing in [1, -1]:
			await run_case(speed, facing)
	var report_path = "E:/GALUMU/docs/development/logs/v045/support-rider-01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var report = {"passed": failures.is_empty(), "failures": failures, "rows": rows, "resets": reset_rows, "scope": "Actual RiderView world-translated at four steady speeds and both facings; two warm-up and two observed cycles; each leg lands and supports, walk support count, gallop suspension, reset world-cache isolation. Not human motion-quality evidence."}
	var file = FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SUPPORT_RIDER_V045 " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
