extends SceneTree
## ART-063 anatomy study: the v050 checks (test_horse_anatomy_v050.gd, kept as
## history) on the six-joint limb hip/shoulder, stifle/elbow, hock/carpus,
## fetlock, coronet, sole. Adds: a supporting hoof stays flat while the
## fetlock sinks, the sink is continuous and returns to zero before lift-off.
## Engine geometry with the real RiderView; not OS input or human approval.
## Run only with -- --test-profile through Start-MemoryBound.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const JOINTS = ["hip","proximal","knee","ankle","coronet","foot"]
var failures: Array[String] = []
var rest_rows: Array = []
var steady_rows: Array = []
var transition_rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func new_metrics() -> Dictionary:
	return {"maximum_root_error":0.0,"maximum_bone_error":0.0,"maximum_support_slide":0.0,
		"maximum_hoof_velocity":0.0,"maximum_local_joint_velocity":0.0,"maximum_reference_joint_velocity":0.0,
		"maximum_toe_velocity_rad_s":0.0,"maximum_bone_turn_rad":0.0,"maximum_scapula_x":0.0,"maximum_scapula_y":0.0,
		"fore_support_wrist_flex_max":0.0,"hind_femur_local_min":INF,"hind_femur_local_max":-INF,
		"maximum_support_hoof_tilt_rad":0.0,"maximum_sink_rad":0.0,"maximum_sink_step_rad":0.0,"maximum_swing_sink_rad":0.0,
		"reach_releases":0,"previous":[],"previous_body_x":0.0}

func inspect_pose(fighter: Dictionary, view, dt: float, metrics: Dictionary, label: String) -> void:
	var body: Dictionary = Model.gait_pose(fighter)
	var facing = int(fighter.direction)
	var current: Array = []
	for index in range(4):
		var leg: Dictionary = view.leg_poses[index]
		var front = bool(leg.front)
		var lengths: Dictionary = Gait.segment_lengths(front)
		for key in JOINTS:
			check(leg.has(key) and Vector2(leg[key]).is_finite(),label+": non-finite or missing "+key)
		var root_offset: Vector2 = leg.root_offset
		var expected_root = Model.HIP+(Gait.HIP_POINTS[index]-Model.HIP).rotated(body.pitch)+body.offset+root_offset.rotated(body.pitch)
		metrics.maximum_root_error = maxf(metrics.maximum_root_error,Vector2(leg.hip).distance_to(expected_root))
		var expected = [float(lengths.proximal),float(lengths.upper),float(lengths.lower),float(lengths.pastern_bone),float(lengths.hoof)]
		for part in range(5):
			metrics.maximum_bone_error = maxf(metrics.maximum_bone_error,absf(Vector2(leg[JOINTS[part]]).distance_to(leg[JOINTS[part+1]])-expected[part]))
		metrics.maximum_scapula_x = maxf(metrics.maximum_scapula_x,absf(root_offset.x))
		metrics.maximum_scapula_y = maxf(metrics.maximum_scapula_y,absf(root_offset.y))
		check(leg.foot.y<=Gait.GROUND+.02,label+": hoof penetrated ground")
		var sink = float(leg.get("sink",0.0))
		if leg.contact:
			check(absf(leg.foot.y-Gait.GROUND)<.02,label+": supporting hoof floated")
			# Flat hoof: the coronet-to-sole capsule keeps its rest direction.
			var rest_hoof: Vector2 = Gait.FORE_HOOF if front else Gait.HIND_HOOF
			var tilt = absf(rest_hoof.angle_to(Vector2(leg.foot)-Vector2(leg.coronet)))
			metrics.maximum_support_hoof_tilt_rad = maxf(metrics.maximum_support_hoof_tilt_rad,tilt)
			metrics.maximum_sink_rad = maxf(metrics.maximum_sink_rad,sink)
		else:
			metrics.maximum_swing_sink_rad = maxf(metrics.maximum_swing_sink_rad,absf(sink))
		var upper: Vector2 = leg.knee-leg.proximal
		var lower: Vector2 = leg.ankle-leg.knee
		var turn = upper.angle_to(lower)
		check(turn>=-.001 if front else turn<=.001,label+": wrist/hock crossed its anatomical IK branch")
		if front and leg.contact:
			metrics.fore_support_wrist_flex_max = maxf(metrics.fore_support_wrist_flex_max,absf(turn))
			check(absf(turn)<deg_to_rad(20),label+": weight-bearing fore wrist visibly buckled")
		if not front:
			var femur_angle = angle_difference(float(body.pitch),Vector2(leg.proximal-leg.hip).angle())
			metrics.hind_femur_local_min = minf(metrics.hind_femur_local_min,femur_angle)
			metrics.hind_femur_local_max = maxf(metrics.hind_femur_local_max,femur_angle)
			check(femur_angle>=deg_to_rad(50)-.001 and femur_angle<=deg_to_rad(105)+.001,label+": hind thigh left the compact muscular envelope")
		if bool(leg.reach_limited):
			metrics.reach_releases += 1
		var world = Vector2(float(fighter.x)+leg.foot.x*facing,leg.foot.y)
		var record = {"world":world,"contact":leg.contact,"toe_angle":leg.toe_angle,"sink":sink,"joints":[],"bone_angles":[]}
		for key in JOINTS:
			record.joints.append(Vector2(float(fighter.x)+leg[key].x*facing,leg[key].y))
		for part in range(5):
			record.bone_angles.append((Vector2(leg[JOINTS[part+1]])-Vector2(leg[JOINTS[part]])).angle())
		if not metrics.previous.is_empty():
			var previous: Dictionary = metrics.previous[index]
			metrics.maximum_hoof_velocity = maxf(metrics.maximum_hoof_velocity,world.distance_to(previous.world)/dt)
			metrics.maximum_toe_velocity_rad_s = maxf(metrics.maximum_toe_velocity_rad_s,absf(angle_difference(previous.toe_angle,leg.toe_angle))/dt)
			metrics.maximum_sink_step_rad = maxf(metrics.maximum_sink_step_rad,absf(sink-float(previous.sink)))
			if leg.contact and previous.contact:
				metrics.maximum_support_slide = maxf(metrics.maximum_support_slide,world.distance_to(previous.world))
			var body_delta = float(fighter.x)-float(metrics.previous_body_x)
			var reference_body_delta = clampf(body_delta,-Model.GALLOP_SPEED*dt,Model.GALLOP_SPEED*dt)
			for part in range(JOINTS.size()):
				var joint_delta = Vector2(record.joints[part])-Vector2(previous.joints[part])
				metrics.maximum_local_joint_velocity = maxf(metrics.maximum_local_joint_velocity,(joint_delta-Vector2(body_delta,0)).length()/dt)
				metrics.maximum_reference_joint_velocity = maxf(metrics.maximum_reference_joint_velocity,(joint_delta-Vector2(body_delta-reference_body_delta,0)).length()/dt)
			for part in range(5):
				metrics.maximum_bone_turn_rad = maxf(metrics.maximum_bone_turn_rad,absf(angle_difference(previous.bone_angles[part],record.bone_angles[part])))
		current.append(record)
	metrics.previous = current
	metrics.previous_body_x = float(fighter.x)

func finish_metrics(metrics: Dictionary, label: String, hz: int) -> Dictionary:
	check(metrics.maximum_root_error<.02,label+": skin root detached from authored moving torso/scapula")
	check(metrics.maximum_bone_error<.05,label+": anatomical segment stretched or disconnected")
	check(metrics.maximum_support_slide<=.08,label+": planted hoof slipped")
	check(metrics.maximum_hoof_velocity<=2600,label+": hoof transition jumped")
	check(metrics.maximum_reference_joint_velocity<=2600,label+": joint transition jumped at reference transport speed")
	check(metrics.maximum_local_joint_velocity<=2600,label+": local articulation jumped")
	check(metrics.maximum_toe_velocity_rad_s<=12.0,label+": toe rotation snapped")
	check(metrics.maximum_bone_turn_rad<=PI*.5,label+": bone angle flipped in one frame")
	check(metrics.maximum_scapula_x<=8.501 and metrics.maximum_scapula_y<=6.501,label+": scapular glide exceeded its local envelope")
	check(metrics.maximum_support_hoof_tilt_rad<.002,label+": supporting hoof tilted instead of staying flat")
	check(metrics.maximum_swing_sink_rad<.0001,label+": fetlock sink leaked into the swing")
	# Continuity: the same 12 rad/s bound as the toe rotation.
	check(metrics.maximum_sink_step_rad<=12.0/hz+.001,label+": fetlock sink jumped between frames")
	var result = metrics.duplicate(true)
	result.erase("previous")
	result.erase("previous_body_x")
	return result

func inspect_rest() -> void:
	check(Gait.segment_lengths(true).lower<Gait.segment_lengths(false).lower,"Fore cannon must be shorter than hind cannon in this measured horse")
	for index in range(4):
		var leg: Dictionary = Gait.leg(index,0.0,0.0,false)
		var flex = absf(Vector2(leg.knee-leg.proximal).angle_to(leg.ankle-leg.knee))
		check(leg.contact and absf(leg.foot.y-Gait.GROUND)<.001,"All four standing soles must touch the common ground")
		check(Vector2(leg.foot).distance_to(Gait.rest_foot(index))<.01,"Standing hoof differs from measured rest sole")
		check(absf(float(leg.sink))<.0001,"A standing horse must not carry a fetlock sink")
		var legacy: Vector2 = Gait.PASTERN if leg.front else Gait.HIND_PASTERN
		check(Vector2(leg.foot-leg.ankle).distance_to(legacy)<.001,"Rest fetlock moved: pastern bone + hoof must equal the legacy distal vector")
		if leg.front:
			check(flex<deg_to_rad(12),"Standing fore wrist must be near straight, not a crouched frog knee")
			check(leg.proximal.x<leg.hip.x,"Standing elbow must lie behind the point of shoulder")
		else:
			check(leg.proximal.x>leg.hip.x and leg.knee.x<leg.proximal.x,"Standing stifle must point forward and hock backward")
			check(flex>deg_to_rad(20) and flex<deg_to_rad(65),"Standing hock has an implausible straight/frog fold")
		rest_rows.append({"index":index,"front":leg.front,"points":[leg.hip,leg.proximal,leg.knee,leg.ankle,leg.coronet,leg.foot],"distal_flex_deg":rad_to_deg(flex)})

func make_fixture(facing: int, speed: float) -> Dictionary:
	var model = Model.new("arena",{"stability":1.0},{"stability":1.0},5001)
	model.phase = "charge"
	model.fighters[0].x = -50000.0
	model.fighters[1].x = 50000.0
	for member in model.fighters:
		member.acted = true
	var index = 0 if facing==1 else 1
	var fighter: Dictionary = model.fighters[index]
	fighter.speed = speed
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

func advance_steady(fighter: Dictionary, view, speed: float, dt: float) -> void:
	fighter.speed = speed
	fighter.x += speed*int(fighter.direction)*dt
	fighter.gait_phase += TAU*Gait.frequency(speed)*dt
	fighter.gait_moving = true
	view.position = Vector2(fighter.x,0)
	view._process(dt)

func steady_trial(speed: float, facing: int, hz: int) -> void:
	var fixture = make_fixture(facing,speed)
	var fighter: Dictionary = fixture.fighter
	var view = fixture.view
	var dt = 1.0/hz
	var cycle_ticks = ceili(2.0/Gait.frequency(speed)*hz)
	for tick in range(cycle_ticks):
		advance_steady(fighter,view,speed,dt)
	var landings = [0,0,0,0]
	view.hoof_contact.connect(func(index: int) -> void: landings[index]+=1)
	var support_frames = [0,0,0,0]
	var flight_frames = 0
	var minimum_support = 4
	var metrics = new_metrics()
	var label = "Steady %.0f / facing %d / %dHz" % [speed,facing,hz]
	for tick in range(cycle_ticks):
		advance_steady(fighter,view,speed,dt)
		inspect_pose(fighter,view,dt,metrics,label)
		var support = 0
		for index in range(4):
			if bool(view.leg_poses[index].contact):
				support += 1
				support_frames[index] += 1
		minimum_support = mini(minimum_support,support)
		if support==0:
			flight_frames += 1
	for index in range(4):
		check(support_frames[index]>=2,label+": leg %d never sustained support" % index)
		check(landings[index]>=1 and landings[index]<=3,label+": leg %d must land 1..3 times in two observed cycles" % index)
	if speed==110.0:
		check(minimum_support>=2,label+": walk has fewer than two supporting hooves")
	if speed==480.0:
		check(flight_frames>0,label+": gallop lacks suspension")
		check(metrics.maximum_sink_rad>.20,label+": gallop shows no loaded fetlock")
	var row_metrics = finish_metrics(metrics,label,hz)
	steady_rows.append({"speed":speed,"facing":facing,"hz":hz,"support_frames":support_frames.duplicate(),"landings":landings.duplicate(),"minimum_support":minimum_support,"flight_frames":flight_frames,"metrics":row_metrics})
	view.queue_free()
	await process_frame

func transition_trial(facing: int, hz: int) -> void:
	var fixture = make_fixture(facing,210.0)
	var model = fixture.model
	var fighter: Dictionary = fixture.fighter
	var view = fixture.view
	var dt = 1.0/hz
	var metrics = new_metrics()
	var label = "Hold/release / facing %d / %dHz" % [facing,hz]
	for tick in range(hz*10):
		var seconds = tick*dt
		var held = seconds<2.5 or (seconds>4.0 and seconds<6.0) or (seconds>7.5 and seconds<8.5)
		model.set_controls(fixture.index,-.08,0.0,held,dt,.43)
		model.step(dt)
		view.position = Vector2(fighter.x,0)
		view._process(dt)
		inspect_pose(fighter,view,dt,metrics,label)
	transition_rows.append({"facing":facing,"hz":hz,"metrics":finish_metrics(metrics,label,hz)})
	view.queue_free()
	await process_frame

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		push_error("Anatomy study requires -- --test-profile under Start-MemoryBound")
		quit(2)
		return
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			path = arg.trim_prefix("--report-path=")
	if path.is_empty() or FileAccess.file_exists(path):
		push_error("Give a new --report-path=<file>")
		quit(2)
		return
	inspect_rest()
	for hz in [30,60,120]:
		for facing in [1,-1]:
			for speed in [110.0,210.0,340.0,480.0]:
				await steady_trial(speed,facing,hz)
			await transition_trial(facing,hz)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var report = {"passed":failures.is_empty(),"failures":failures,"rest":rest_rows,"steady":steady_rows,"transitions":transition_rows,
		"scope":"Six-joint horse limbs in the real RiderView at 30/60/120Hz, both facings, four steady gaits and model hold/release. v050 bone, branch, support, slide and velocity bounds plus flat supporting hoof, fetlock sink bounded/continuous/zero in swing and present at gallop. Geometry only; not a render, OS input or human approval of natural motion."}
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HORSE_ANATOMY_063 "+str(failures.is_empty())+" failures="+str(failures))
	quit(0 if failures.is_empty() else 1)
