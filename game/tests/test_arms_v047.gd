extends SceneTree
## Shared rendered arm anchors plus bounded, time-taking control transitions.
## Does not assert that a mathematically connected arm is anatomically good art.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
var failures: Array[String] = []
var examples: Array = []
var rows: Array = []
var motion_cases: Array = []
var grid_poses = 0
var report_path = "E:/GALUMU/docs/development/logs/v047/arms-01.json"
var capture_dir = ""
var page: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size() < 36:
		examples.append({"issue": message, "context": context.duplicate(true)})

func pose_context(fighter: Dictionary) -> Dictionary:
	return {"facing": fighter.direction, "lean": fighter.lean,
		"guard": fighter.guard, "aim": fighter.aim, "speed": fighter.speed,
		"phase": fighter.gait_phase}

func validate_pose(fighter: Dictionary) -> Dictionary:
	var pose: Dictionary = Rider.arm_pose(fighter)
	var context = pose_context(fighter)
	if not pose.has_all(["right", "left", "torso_transform", "shield_center", "shield_grip"]):
		check(false, "arm_pose is missing a documented anchor", context)
		return {}
	var torso: Transform2D = pose.torso_transform
	var inverse = torso.affine_inverse()
	check(is_finite(torso.get_rotation()) and torso.origin.is_finite(), "Torso transform is finite", context)
	check(absf(torso.determinant()-1.0) < .001, "Camera-facing torso does not exchange anatomical left and right by reflection", context)
	var expected_origin = Model.mount_origin(fighter)+Model.HIP*Vector2(int(fighter.direction),1)
	check(torso.origin.distance_to(expected_origin) < .02, "Arm torso origin remains sewn to the shared rider mount", context)
	check((torso*Vector2(0,-111)).distance_to(Model.head_position(fighter)) < .02, "Arm transform and actual rider head use the same torso pose", context)
	for side in ["right", "left"]:
		var arm: Dictionary = pose[side]
		if not arm.has_all(["shoulder", "elbow", "hand"]):
			check(false, "Arm is missing shoulder, elbow or hand", context)
			return {}
		for joint in ["shoulder", "elbow", "hand"]:
			check(Vector2(arm[joint]).is_finite(), "Arm joint remains finite", context)
		var upper_length = Vector2(arm.shoulder).distance_to(arm.elbow)
		var lower_length = Vector2(arm.elbow).distance_to(arm.hand)
		var reach = Vector2(arm.shoulder).distance_to(arm.hand)
		check(reach <= Rider.ARM_UPPER+Rider.ARM_LOWER+.02,
			"Requested grip is reachable without stretching a human arm", context.merged({"side":side,"reach":reach}))
		check(absf(upper_length-Rider.ARM_UPPER) < .03,
			"Upper arm length remains fixed", context.merged({"side":side,"measured":upper_length}))
		check(absf(lower_length-Rider.ARM_LOWER) < .03,
			"Forearm length remains fixed; unreachable states must be reported", context.merged({"side":side,"measured":lower_length}))
		var expected_shoulder = Vector2(-25,-64) if side=="right" else Vector2(25,-64)
		check((inverse*Vector2(arm.shoulder)).distance_to(expected_shoulder) < .02,
			"Anatomical shoulder stays on its authored side of the camera-facing chest", context.merged({"side":side}))
	check(Vector2(pose.right.hand).distance_to(Model.hand_position(fighter)) < .02,
		"Visible right grip coincides with the actual lance hand", context)
	check(Vector2(pose.shield_center).distance_to(Model.shield_position(fighter)) < .02,
		"Shield drawing and collision use the same center", context)
	var expected_grip = Model.shield_position(fighter)+Vector2(-10*int(fighter.direction),4).rotated(Model.pose_angle(fighter)*int(fighter.direction))
	check(Vector2(pose.shield_grip).distance_to(expected_grip) < .02,
		"Left grip remains in the documented shield-back mounting position", context)
	check(Vector2(pose.left.hand).distance_to(pose.shield_grip) < .02,
		"Left forearm terminates at the shield-back grip", context)
	var expected_tip = Vector2(pose.right.hand)+Vector2(cos(float(fighter.aim))*int(fighter.direction),sin(float(fighter.aim)))*Model.lance_length(fighter)
	check(expected_tip.distance_to(Model.tip_position(fighter)) < .02,
		"Arm integration preserves the real lance tip", context)
	return pose

func static_grid() -> void:
	var model = Model.new()
	var fighter: Dictionary = model.fighters[0]
	fighter.x = 47.0
	fighter.lane_y = 32.0
	for facing in [1,-1]:
		fighter.direction = facing
		for lean_value in [-1.0,-.5,0.0,.5,1.0]:
			fighter.lean = lean_value
			for guard_index in range(11):
				fighter.guard = guard_index/10.0
				for aim_value in [-.68,-.08,.58]:
					fighter.aim = aim_value
					for speed_value in [0.0,210.0,480.0]:
						fighter.speed = speed_value
						fighter.gait_moving = speed_value > 0
						for sample in range(8):
							fighter.gait_phase = TAU*sample/8.0
							validate_pose(fighter)
							grid_poses += 1

func control_trial(gap: float, facing: int, dt: float) -> Dictionary:
	var model = Model.new()
	model.phase = "charge"
	model.fighters[0].x = -gap*.5
	model.fighters[1].x = gap*.5
	var index = 0 if facing==1 else 1
	var fighter: Dictionary = model.fighters[index]
	fighter.aim = -.68
	fighter.guard = 0.0
	fighter.guard_target = 0.0
	fighter.lean = 0.0
	model.set_controls(index,.58,1.0,false,dt,1.0)
	return {"gap":gap,"facing":facing,"aim_delta":float(fighter.aim)+.68,
		"guard_delta":fighter.guard,"lean_delta":fighter.lean}

func rate_regression() -> void:
	var dt = 1.0/120.0
	for facing in [1,-1]:
		var far = control_trial(4000,facing,dt)
		var near = control_trial(800,facing,dt)
		check(far.aim_delta > 0 and far.aim_delta < .04, "A full-range aim request takes time", far)
		check(near.aim_delta > 0 and near.aim_delta < float(far.aim_delta)*.60,
			"Committed near-contact aiming remains slower than distant aiming", near)
		check(near.guard_delta > 0 and near.guard_delta < .04,
			"Near-contact shield raising does not teleport to the requested guard", near)
		check(absf(float(near.lean_delta)) < .02, "Leaning retains its existing acceleration limit", near)
		rows.append({"kind":"first_control_tick","far":far,"near":near})
		var model = Model.new()
		var index = 0 if facing==1 else 1
		var fighter: Dictionary = model.fighters[index]
		fighter.guard = 0
		fighter.guard_target = 0
		var elapsed = 0.0
		while fighter.guard < .9999 and elapsed < 1.0:
			model.set_controls(index,-.08,0.0,false,dt,1.0)
			elapsed += dt
		check(elapsed > .25 and elapsed < .60, "Full low-to-high shield motion has a visible travel interval", {"facing":facing,"seconds":elapsed})
		var lowering_time = 0.0
		while fighter.guard > .0001 and lowering_time < 1.0:
			model.set_controls(index,-.08,0.0,false,dt,0.0)
			lowering_time += dt
		check(lowering_time > .25 and lowering_time < .60, "Full high-to-low shield motion also takes time", {"facing":facing,"seconds":lowering_time})
		rows.append({"kind":"shield_travel","facing":facing,"raising_seconds":elapsed,"lowering_seconds":lowering_time})

func dynamic_motion(facing: int, hz: int) -> void:
	var model = Model.new()
	model.phase = "charge"
	model.fighters[0].x = -50000
	model.fighters[1].x = 50000
	for member in model.fighters:
		member.acted = true
	var index = 0 if facing==1 else 1
	var fighter: Dictionary = model.fighters[index]
	var previous: Dictionary = {}
	var maximum_local_step = 0.0
	var previous_branches: Dictionary = {}
	var smallest_branch_sine = 1.0
	var dt = 1.0/hz
	for tick in range(hz*6):
		var seconds = tick*dt
		var stage = int(seconds/.75)%4
		var target_guard = [1.0,0.0,.43,1.0][stage]
		var target_aim = [.58,-.68,.12,-.2][stage]
		var target_lean = [1.0,-1.0,0.0,-1.0][stage]
		var previous_guard = float(fighter.guard)
		var previous_aim = float(fighter.aim)
		model.set_controls(index,target_aim,target_lean,seconds<3.0,dt,target_guard)
		check(absf(float(fighter.guard)-previous_guard) <= 3.0*dt+.0001, "Shield control retains its continuous movement limit", {"facing":facing,"hz":hz,"seconds":seconds})
		check(absf(float(fighter.aim)-previous_aim) <= 2.3*dt+.0001, "Lance control retains its continuous movement limit", {"facing":facing,"hz":hz,"seconds":seconds})
		model.step(dt)
		var pose = validate_pose(fighter)
		if pose.is_empty():
			continue
		var inverse: Transform2D = pose.torso_transform.affine_inverse()
		var local_points: Dictionary = {}
		for side in ["right","left"]:
			for joint in ["shoulder","elbow","hand"]:
				var key = side+"_"+joint
				local_points[key] = inverse*Vector2(pose[side][joint])
				if previous.has(key):
					var movement = Vector2(local_points[key]).distance_to(previous[key])
					maximum_local_step = maxf(maximum_local_step,movement)
			# A legal short ray near the chest can rotate the elbow faster than
			# the hand. Test IK branch identity, not an invented elbow-speed cap.
			var ray: Vector2 = local_points[side+"_hand"]-local_points[side+"_shoulder"]
			var upper: Vector2 = local_points[side+"_elbow"]-local_points[side+"_shoulder"]
			var branch_sine = ray.cross(upper)/maxf(.0001,ray.length()*upper.length())
			smallest_branch_sine = minf(smallest_branch_sine,absf(branch_sine))
			var nonsingular = ray.length()>absf(Rider.ARM_UPPER-Rider.ARM_LOWER)+.25 and ray.length()<Rider.ARM_UPPER+Rider.ARM_LOWER-.25 and absf(branch_sine)>.01
			if nonsingular and previous_branches.has(side):
				check(signf(branch_sine)==float(previous_branches[side]), "Elbow stays on the same IK branch away from a straight/folded singularity", {"facing":facing,"hz":hz,"seconds":seconds,"side":side,"branch_sine":branch_sine})
			if nonsingular:
				previous_branches[side] = signf(branch_sine)
		previous = local_points
		if hz==120 and tick in [12,36,72,132]:
			var saved = fighter.duplicate(true)
			saved.x = 0.0
			saved.lane_y = 0.0
			motion_cases.append({"fighter":saved,"label":"%s / %.2fs / 盾%.2f" % ["右向" if facing==1 else "左向",seconds,fighter.guard]})
	rows.append({"kind":"dynamic_arm_motion","facing":facing,"hz":hz,"seconds":6,"max_local_joint_step":maximum_local_step,"minimum_abs_ik_branch_sine":smallest_branch_sine})

func check_dynamic_convergence() -> void:
	for facing in [1,-1]:
		var steps: Dictionary = {}
		for record in rows:
			if record.kind=="dynamic_arm_motion" and int(record.facing)==facing:
				steps[int(record.hz)] = float(record.max_local_joint_step)
		var ratios: Array = []
		for coarse_hz in [30,60]:
			var coarse = float(steps[coarse_hz])
			var fine = float(steps[coarse_hz*2])
			if coarse > 1.0:
				# A bounded smooth path's chord shrinks towards 1/2 when dt is
				# halved. A finite branch jump remains roughly the same size.
				# .70 leaves room for curvature and discrete controller timing;
				# it is a convergence check, not a higher absolute speed limit.
				check(fine <= coarse*.70+.05, "Maximum arm step converges when the control timestep is halved", {"facing":facing,"coarse_hz":coarse_hz,"coarse_step":coarse,"fine_step":fine})
				ratios.append({"coarse_hz":coarse_hz,"ratio":fine/coarse})
		rows.append({"kind":"joint_timestep_convergence","facing":facing,"ratios":ratios})

func preview_cases(extremes: bool) -> Array:
	var cases: Array = []
	for facing in [1,-1]:
		for sample in range(4):
			var model = Model.new()
			var fighter: Dictionary = model.fighters[0]
			fighter.x = 0
			fighter.lane_y = 0
			fighter.direction = facing
			fighter.lean = (1.0 if sample%2==0 else -1.0) if extremes else 0.0
			fighter.guard = ([0.0,1.0,1.0,0.0] if extremes else [0.0,.43,1.0,.43])[sample]
			fighter.aim = -.68 if sample<2 else .58
			fighter.speed = 210
			fighter.gait_moving = true
			fighter.gait_phase = sample*TAU/4
			cases.append({"fighter":fighter,"label":"%s / 倾%.1f / 盾%.2f" % ["右向" if facing==1 else "左向",fighter.lean,fighter.guard]})
	return cases

func equipment_preview_cases() -> Array:
	var cases: Array = []
	for facing in [1,-1]:
		for tier in range(5):
			var model = Model.new()
			var fighter: Dictionary = model.fighters[0]
			fighter.x = 0.0
			fighter.lane_y = 0.0
			fighter.direction = facing
			fighter.lean = 0.0
			fighter.guard = .43
			fighter.aim = -.08
			fighter.speed = 210.0
			fighter.gait_moving = true
			fighter.gait_phase = .5
			fighter.stats.armor_tier = tier
			fighter.stats.helmet_tier = tier
			fighter.stats.armor_red = facing==-1
			cases.append({"fighter":fighter,"label":"%s / 胸甲tier%d / 中盾" % ["右向" if facing==1 else "左向",tier]})
	return cases

func render_page(title: String, cases: Array, name_value: String, columns: int = 4) -> void:
	page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var backdrop = ColorRect.new()
	backdrop.color = Color("14231c")
	backdrop.size = Vector2(1440,810)
	page.add_child(backdrop)
	UI.label(page,title+" · 上半身接缝观察，非正式HUD",Vector2(20,14),23,UI.GOLD)
	var cell_width = 1416.0/columns
	for sample in range(mini(cases.size(),columns*2)):
		var panel = UI.panel(page,Rect2(12+(sample%columns)*cell_width,64+(sample/columns)*366,cell_width-12,350))
		panel.clip_contents = true
		UI.label(panel,str(cases[sample].label),Vector2(10,10),15,UI.GOLD)
		var rider = Rider.new()
		rider.fighter = cases[sample].fighter
		rider.moving = true
		rider.position = Vector2((cell_width-12)*.5,440 if columns==5 else 480)
		rider.scale = Vector2.ONE*(.95 if columns==5 else 1.1)
		panel.add_child(rider)
		rider.set_process(false)
		rider._process(0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var error = root.get_texture().get_image().save_png(capture_dir+"/"+name_value+".png")
	check(error==OK,"Arm preview PNG saves successfully",{"name":name_value,"error":error})
	print("ARMS_V047_CAPTURE ",name_value," ",error)
	page.queue_free()
	await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-path="):
			report_path = arg.trim_prefix("--report-path=")
		elif arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var state = root.get_node_or_null("GameState")
	if state==null or not state.save_path.contains("qa_"):
		push_error("Arm study requires -- --test-profile")
		quit(1)
		return
	static_grid()
	rate_regression()
	for facing in [1,-1]:
		for hz in [30,60,120]:
			dynamic_motion(facing,hz)
	check_dynamic_convergence()
	if not capture_dir.is_empty():
		check(DisplayServer.get_name()!="headless", "Actual render previews require a rendered engine window")
		if DisplayServer.get_name()!="headless":
			await render_page("双向三档盾位与极限瞄准",preview_cases(false),"arms_guards")
			await render_page("前倾／后仰与高低盾",preview_cases(true),"arms_extremes")
			await render_page("实际限速控制的连续过程采样",motion_cases,"arms_motion")
			await render_page("五档胸甲双向肩口衔接",equipment_preview_cases(),"arms_equipment",5)
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,
		"grid_poses":grid_poses,"rows":rows,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),
		"scope":"Shared arm drawing anchors, both anatomical sides/facings, lean/guard/aim/gait extremes; actual limited controls, nonsingular IK branch identity and 30/60/120Hz timestep convergence. Optional guards/extremes/motion and torso-tier render previews. No absolute physical elbow-speed claim, OS input, human anatomy/art approval or fun claim."}
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		check(false,"QA arm report could not be written",{"path":report_path})
	print("ARMS_V047 ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
