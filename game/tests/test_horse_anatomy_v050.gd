extends SceneTree
## Engine geometry/actual RiderView study, not OS input or human art approval.
## Run only with -- --test-profile; root coordinates all shared QA runs.
## Anatomy references (not empirical measurements of this authored rig):
## https://open.lib.umn.edu/largeanimalanatomy/chapter/thoracic-limb-forelimb/
## https://open.lib.umn.edu/largeanimalanatomy/chapter/pelvic-limb/
## https://extension.umn.edu/agriculture/animals-and-livestock/horse/conformation-of-the-horse
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const JOINTS = ["hip","proximal","knee","ankle","foot"]
var failures: Array[String] = []
var rest_rows: Array = []
var steady_rows: Array = []
var transition_rows: Array = []
var swing_rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func new_metrics() -> Dictionary:
	return {"maximum_root_error":0.0,"maximum_bone_error":0.0,"maximum_support_slide":0.0,
		"maximum_hoof_velocity":0.0,"maximum_joint_velocity":0.0,"maximum_toe_velocity_rad_s":0.0,
		"maximum_reference_joint_velocity":0.0,"maximum_local_joint_velocity":0.0,"reference_transport_speed":Model.GALLOP_SPEED,
		"maximum_bone_turn_rad":0.0,"maximum_scapula_x":0.0,"maximum_scapula_y":0.0,
		"fore_support_wrist_flex_max":0.0,"hind_femur_local_min":INF,"hind_femur_local_max":-INF,
		"reach_releases":0,"first_early_releases":[],"worst_hoof":{},"worst_joint":{},"worst_reference_joint":{},"worst_local_joint":{},"previous":[],"previous_body_x":0.0}

func inspect_pose(fighter: Dictionary, view, dt: float, metrics: Dictionary, label: String) -> void:
	var body: Dictionary = Model.gait_pose(fighter)
	var facing = int(fighter.direction)
	var current: Array = []
	for index in range(4):
		var leg: Dictionary = view.leg_poses[index]
		var lengths: Dictionary = Gait.segment_lengths(bool(leg.front))
		for key in JOINTS:
			check(Vector2(leg[key]).is_finite(),label+": non-finite "+key)
		var root_offset: Vector2 = leg.root_offset
		var expected_root = Model.HIP+(Gait.HIP_POINTS[index]-Model.HIP).rotated(body.pitch)+body.offset+root_offset.rotated(body.pitch)
		metrics.maximum_root_error = maxf(metrics.maximum_root_error,Vector2(leg.hip).distance_to(expected_root))
		var expected = [float(lengths.proximal),float(lengths.upper),float(lengths.lower),float(lengths.pastern)]
		for part in range(4):
			metrics.maximum_bone_error = maxf(metrics.maximum_bone_error,absf(Vector2(leg[JOINTS[part]]).distance_to(leg[JOINTS[part+1]])-expected[part]))
		metrics.maximum_scapula_x = maxf(metrics.maximum_scapula_x,absf(root_offset.x))
		metrics.maximum_scapula_y = maxf(metrics.maximum_scapula_y,absf(root_offset.y))
		check(leg.foot.y<=Gait.GROUND+.02,label+": hoof penetrated ground")
		if leg.contact:
			check(absf(leg.foot.y-Gait.GROUND)<.02,label+": supporting hoof floated")
		var upper: Vector2 = leg.knee-leg.proximal
		var lower: Vector2 = leg.ankle-leg.knee
		var turn = upper.angle_to(lower)
		check(turn>=-.001 if leg.front else turn<=.001,label+": wrist/hock crossed its anatomical IK branch")
		if leg.front and leg.contact:
			metrics.fore_support_wrist_flex_max = maxf(metrics.fore_support_wrist_flex_max,absf(turn))
			check(absf(turn)<deg_to_rad(20),label+": weight-bearing fore wrist visibly buckled")
		if not leg.front:
			var femur_angle = angle_difference(float(body.pitch),Vector2(leg.proximal-leg.hip).angle())
			metrics.hind_femur_local_min = minf(metrics.hind_femur_local_min,femur_angle)
			metrics.hind_femur_local_max = maxf(metrics.hind_femur_local_max,femur_angle)
			check(femur_angle>=deg_to_rad(50)-.001 and femur_angle<=deg_to_rad(105)+.001,label+": hind thigh left the compact muscular envelope")
		if bool(leg.reach_limited):
			metrics.reach_releases += 1
		var world = Vector2(float(fighter.x)+leg.foot.x*facing,leg.foot.y)
		var record = {"world":world,"contact":leg.contact,"cycle":leg.cycle,"swing":leg.swing,"toe_angle":leg.toe_angle,"joints":[],"bone_angles":[]}
		for key in JOINTS:
			record.joints.append(Vector2(float(fighter.x)+leg[key].x*facing,leg[key].y))
		for part in range(4):
			record.bone_angles.append((Vector2(leg[JOINTS[part+1]])-Vector2(leg[JOINTS[part]])).angle())
		if not metrics.previous.is_empty():
			var previous: Dictionary = metrics.previous[index]
			if previous.contact and not leg.contact and leg.cycle<leg.duty and metrics.first_early_releases.size()<8:
				metrics.first_early_releases.append({"leg":index,"phase":fighter.gait_phase,"cycle":leg.cycle,"duty":leg.duty,"reach_limited":leg.reach_limited,"requested_reach":leg.requested_reach,"maximum_reach":leg.maximum_reach,"requested_foot":leg.requested_foot,"root_offset":leg.root_offset,"joints":[leg.hip,leg.proximal,leg.knee,leg.ankle,leg.foot]})
			var velocity = world.distance_to(previous.world)/dt
			if velocity>metrics.maximum_hoof_velocity:
				metrics.worst_hoof = {"leg":index,"speed":fighter.speed,"phase":fighter.gait_phase,"cycle":leg.cycle,"swing":leg.swing,"contact":leg.contact,"previous_contact":previous.contact}
			metrics.maximum_hoof_velocity = maxf(metrics.maximum_hoof_velocity,velocity)
			metrics.maximum_toe_velocity_rad_s = maxf(metrics.maximum_toe_velocity_rad_s,absf(angle_difference(previous.toe_angle,leg.toe_angle))/dt)
			if leg.contact and previous.contact:
				metrics.maximum_support_slide = maxf(metrics.maximum_support_slide,world.distance_to(previous.world))
			for part in range(JOINTS.size()):
				var joint_delta = Vector2(record.joints[part])-Vector2(previous.joints[part])
				var body_delta = float(fighter.x)-float(metrics.previous_body_x)
				# A faster catalogue horse adds rigid transport to EVERY joint.
				# Remove only transport above the original 480 reference; never
				# divide articulation by its speed multiplier or hide the raw peak.
				# <=480 cases are unchanged, so the original elbow singularity
				# would still fail. Local speed independently catches pose jumps.
				var reference_body_delta = clampf(body_delta,-Model.GALLOP_SPEED*dt,Model.GALLOP_SPEED*dt)
				var local_velocity = (joint_delta-Vector2(body_delta,0)).length()/dt
				var reference_velocity = (joint_delta-Vector2(body_delta-reference_body_delta,0)).length()/dt
				var joint_velocity = joint_delta.length()/dt
				if local_velocity>metrics.maximum_local_joint_velocity:
					metrics.worst_local_joint = {"leg":index,"joint":JOINTS[part],"dt":dt,"speed":fighter.speed,"phase":fighter.gait_phase,"cycle":leg.cycle,"previous_cycle":previous.cycle,"swing":leg.swing,"previous_swing":previous.swing,"contact":leg.contact,"previous_contact":previous.contact,"requested_reach":leg.requested_reach,"maximum_reach":leg.maximum_reach,"proximal_limited":leg.proximal_limited,"requested_flex":leg.requested_flex,"current_joints":record.joints.duplicate(),"previous_joints":previous.joints.duplicate(),"transport_velocity":body_delta/dt,"world_velocity":joint_velocity,"local_velocity":local_velocity,"reference_velocity":reference_velocity}
				metrics.maximum_local_joint_velocity = maxf(metrics.maximum_local_joint_velocity,local_velocity)
				if reference_velocity>metrics.maximum_reference_joint_velocity:
					metrics.worst_reference_joint = {"leg":index,"joint":JOINTS[part],"dt":dt,"phase":fighter.gait_phase,"cycle":leg.cycle,"swing":leg.swing,"speed":fighter.speed,"transport_velocity":body_delta/dt,"world_velocity":joint_velocity,"local_velocity":local_velocity,"reference_velocity":reference_velocity}
				metrics.maximum_reference_joint_velocity = maxf(metrics.maximum_reference_joint_velocity,reference_velocity)
				if joint_velocity>metrics.maximum_joint_velocity:
					metrics.worst_joint = {"leg":index,"joint":JOINTS[part],"dt":dt,"speed":fighter.speed,"phase":fighter.gait_phase,"cycle":leg.cycle,"previous_cycle":previous.cycle,"swing":leg.swing,"previous_swing":previous.swing,"contact":leg.contact,"previous_contact":previous.contact,"requested_reach":leg.requested_reach,"maximum_reach":leg.maximum_reach,"proximal_limited":leg.proximal_limited,"requested_flex":leg.requested_flex,"current_joints":record.joints.duplicate(),"previous_joints":previous.joints.duplicate(),"world_hoof_velocity":world.distance_to(previous.world)/dt}
				metrics.maximum_joint_velocity = maxf(metrics.maximum_joint_velocity,joint_velocity)
			for part in range(4):
				metrics.maximum_bone_turn_rad = maxf(metrics.maximum_bone_turn_rad,absf(angle_difference(previous.bone_angles[part],record.bone_angles[part])))
		current.append(record)
	metrics.previous = current
	metrics.previous_body_x = float(fighter.x)

func finish_metrics(metrics: Dictionary, label: String) -> Dictionary:
	check(metrics.maximum_root_error<.02,label+": skin root detached from authored moving torso/scapula")
	check(metrics.maximum_bone_error<.05,label+": anatomical segment stretched or disconnected")
	check(metrics.maximum_support_slide<=.08,label+": planted hoof slipped")
	check(metrics.maximum_hoof_velocity<=2600,label+": hoof transition jumped")
	check(metrics.maximum_reference_joint_velocity<=2600,label+": knee/elbow transition jumped at reference transport speed")
	check(metrics.maximum_local_joint_velocity<=2600,label+": local knee/elbow articulation jumped")
	check(metrics.maximum_toe_velocity_rad_s<=12.0,label+": toe rotation snapped")
	check(metrics.maximum_bone_turn_rad<=PI*.5,label+": bone angle flipped in one frame")
	check(metrics.maximum_scapula_x<=8.501 and metrics.maximum_scapula_y<=6.501,label+": scapular glide exceeded its local envelope")
	var result = metrics.duplicate(true)
	result.erase("previous")
	result.erase("previous_body_x")
	return result

func inspect_rest() -> void:
	var fore_lengths: Dictionary = Gait.segment_lengths(true)
	var hind_lengths: Dictionary = Gait.segment_lengths(false)
	check(fore_lengths.lower<hind_lengths.lower,"Fore cannon must be shorter than hind cannon in this measured horse")
	for index in range(4):
		var leg: Dictionary = Gait.leg(index,0.0,0.0,false)
		var flex = absf(Vector2(leg.knee-leg.proximal).angle_to(leg.ankle-leg.knee))
		check(leg.contact and absf(leg.foot.y-Gait.GROUND)<.001,"All four standing soles must touch the common ground")
		check(Vector2(leg.foot).distance_to(Gait.rest_foot(index))<.01,"Standing hoof differs from measured rest sole")
		if leg.front:
			check(flex<deg_to_rad(12),"Standing fore wrist must be near straight, not a crouched frog knee")
			check(leg.hip.x>50 and leg.hip.y<-125,"Fore attachment must originate at the chest/shoulder")
			check(leg.proximal.x<leg.hip.x,"Standing elbow must lie behind the point of shoulder")
		else:
			check(leg.hip.x<-80 and leg.hip.y<-135,"Hind attachment must originate in the hindquarter")
			check(leg.proximal.x>leg.hip.x and leg.knee.x<leg.proximal.x,"Standing stifle must point forward and hock backward")
			check(flex>deg_to_rad(20) and flex<deg_to_rad(65),"Standing hock has an implausible straight/frog fold")
		rest_rows.append({"index":index,"front":leg.front,"points":[leg.hip,leg.proximal,leg.knee,leg.ankle,leg.foot],"distal_flex_deg":rad_to_deg(flex),"lengths":Gait.segment_lengths(bool(leg.front))})

func inspect_swing_target() -> void:
	# Contract of Rider's predicted-world-landing interpolation, not an
	# assertion of the easing polynomial: no forward overshoot or pullback.
	for reach in [15.0,40.0,50.0]:
		for run in [0.0,1.0]:
			var previous = -reach
			var maximum = -INF
			var minimum = INF
			for tick in range(241):
				var point: Vector2 = Gait._swing_point(true,tick/240.0,reach,46.0,run)
				check(point.x>=-reach-.001 and point.x<=reach+.001,"Fore swing extrapolates past its world-landing endpoints")
				check(point.x>=previous-.001,"Fore swing pulls back from an overshot world landing")
				minimum = minf(minimum,point.x)
				maximum = maxf(maximum,point.x)
				previous = point.x
			swing_rows.append({"reach":reach,"run":run,"minimum_x":minimum,"maximum_x":maximum,"samples":241})

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
	var support_run = [0,0,0,0]
	var longest_run = [0,0,0,0]
	var minimum_support = 4
	var flight_frames = 0
	var first_deficit: Dictionary = {}
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
				support_run[index] += 1
				longest_run[index] = maxi(longest_run[index],support_run[index])
			else:
				support_run[index] = 0
		minimum_support = mini(minimum_support,support)
		if support==0:
			flight_frames += 1
		if speed==110.0 and support<2 and first_deficit.is_empty():
			var legs: Array = []
			for pose in view.leg_poses:
				legs.append({"cycle":pose.cycle,"duty":pose.duty,"contact":pose.contact,"nominal_contact":pose.nominal_contact,"reach_limited":pose.reach_limited,"requested_reach":pose.requested_reach,"maximum_reach":pose.maximum_reach,"root_offset":pose.root_offset,"joints":[pose.hip,pose.proximal,pose.knee,pose.ankle,pose.foot]})
			first_deficit = {"tick":tick,"phase":fighter.gait_phase,"support":support,"legs":legs}
	for index in range(4):
		check(support_frames[index]>0 and longest_run[index]>=2,label+": leg %d never sustained support" % index)
		check(landings[index]>=1 and landings[index]<=3,label+": leg %d must land 1..3 times in two observed cycles" % index)
	if speed==110.0:
		check(first_deficit.is_empty(),label+": walk has fewer than two supporting hooves")
	if speed==480.0:
		check(flight_frames>0,label+": gallop lacks suspension")
	steady_rows.append({"speed":speed,"facing":facing,"hz":hz,"warm_cycles":2,"observed_cycles":2,"frames":cycle_ticks,"support_frames":support_frames.duplicate(),"longest_support_runs":longest_run.duplicate(),"landings":landings.duplicate(),"minimum_support":minimum_support,"flight_frames":flight_frames,"first_walk_deficit":first_deficit,"metrics":finish_metrics(metrics,label)})
	view.queue_free()
	await process_frame

func transition_trial(facing: int, hz: int) -> void:
	var fixture = make_fixture(facing,210.0)
	var model = fixture.model
	var fighter: Dictionary = fixture.fighter
	var view = fixture.view
	var dt = 1.0/hz
	var metrics = new_metrics()
	var samples: Array = []
	var min_speed = INF
	var max_speed = 0.0
	var label = "Hold/release / facing %d / %dHz" % [facing,hz]
	for tick in range(hz*10):
		var seconds = tick*dt
		var held = seconds<2.5 or (seconds>4.0 and seconds<6.0) or (seconds>7.5 and seconds<8.5)
		model.set_controls(fixture.index,-.08,0.0,held,dt,.43)
		model.step(dt)
		view.position = Vector2(fighter.x,0)
		view._process(dt)
		inspect_pose(fighter,view,dt,metrics,label)
		min_speed = minf(min_speed,fighter.speed)
		max_speed = maxf(max_speed,fighter.speed)
		if tick%hz==0:
			samples.append({"seconds":seconds,"held":held,"speed":fighter.speed,"body_y":Model.gait_pose(fighter).offset.y})
	# A stationary/new-round interval must discard old world foot locks.
	fighter.x = 40000.0*facing
	fighter.speed = 0.0
	fighter.gait_phase = 0.0
	fighter.gait_moving = false
	view.position = Vector2(fighter.x,0)
	view.moving = false
	view._process(dt)
	for index in range(4):
		check(not is_finite(float(view.planted_feet[index])),label+": reset retained an old planted hoof")
		check(not Vector2(view.swing_starts[index]).is_finite(),label+": reset retained an old swing origin")
	view.moving = true
	advance_steady(fighter,view,210.0,dt)
	for index in range(4):
		check(absf(Vector2(view.last_feet[index]).x-fighter.x)<400,label+": restart references a previous round's world location")
	transition_rows.append({"facing":facing,"hz":hz,"seconds":10,"speed_min":min_speed,"speed_max":max_speed,"metrics":finish_metrics(metrics,label),"samples":samples,"reset_checked":true})
	view.queue_free()
	await process_frame

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
		push_error("Anatomy study requires -- --test-profile")
		quit(1)
		return
	inspect_rest()
	inspect_swing_target()
	for hz in [30,60,120]:
		for facing in [1,-1]:
			for speed in [110.0,210.0,340.0,480.0]:
				await steady_trial(speed,facing,hz)
			await transition_trial(facing,hz)
	var path = "E:/GALUMU/docs/development/logs/v050/anatomy-01.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			path = arg.trim_prefix("--report-path=")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var report = {"passed":failures.is_empty(),"failures":failures,"rest":rest_rows,"fore_swing_target":swing_rows,"steady":steady_rows,"transitions":transition_rows,
		"scope":"Measured whole-horse anatomical rest chain and real world-translated RiderView at 30/60/120Hz, both facings, four steady gaits and actual-model hold/release. Checks finite bone lengths, anatomical IK branches, near-straight load-bearing fore wrist, hoof grounding/lock and transition bounds, support/flight and new-round cache reset. Raw joint world velocity is retained; the 2600 joint bound applies at reference transport 480 (only excess body.x transport is removed), with an additional unscaled local-articulation bound 2600. No render captures or OS input generated by this script; passing geometry is not human approval of silhouette, skin seams or natural movement."}
	var file = FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write anatomy report: "+path)
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("HORSE_ANATOMY_V050 "+str(failures.is_empty())+" failures="+str(failures))
	quit(0 if failures.is_empty() else 1)
