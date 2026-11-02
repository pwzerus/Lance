extends SceneTree
## Production contact application and reaction-pose checks. These are explicit
## authored contact fixtures, not a claim of swept collision or human play.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Lance = preload("res://scripts/visual/lance_art.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
var failures: Array[String] = []
var examples: Array = []
var rows: Array = []
var captures: Array = []
var sheets: Dictionary = {}
var run_dir = ""
var captures_enabled = true
var max_anchor_error = 0.0
var max_arm_error = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String, context: Dictionary = {}) -> void:
	if ok:
		return
	if message not in failures:
		failures.append(message)
		push_error(message)
	if examples.size()<40:
		examples.append({"message":message,"context":context})

func anchors(fighter: Dictionary) -> Dictionary:
	return {"head":Model.head_position(fighter),"body":Model.body_position(fighter),
		"hand":Model.hand_position(fighter),"shield":Model.shield_position(fighter),"tip":Model.tip_position(fighter)}

func validate_pose(fighter: Dictionary, context: Dictionary) -> void:
	var pose = Rider.arm_pose(fighter)
	var torso: Transform2D = pose.torso_transform
	var mirror = Vector2(int(fighter.direction),1)
	var error = torso.origin.distance_to(Model.rider_origin(fighter))
	error = maxf(error,(torso*Vector2(0,-111)).distance_to(Model.head_position(fighter)))
	error = maxf(error,(torso*Vector2(0,-44)).distance_to(Model.body_position(fighter)))
	error = maxf(error,Vector2(pose.right.hand).distance_to(Model.hand_position(fighter)))
	error = maxf(error,Vector2(pose.shield_center).distance_to(Model.shield_position(fighter)))
	error = maxf(error,Vector2(pose.left.hand).distance_to(pose.shield_grip))
	var grip: Vector2 = pose.right.hand*mirror
	var drawn_tip = Lance.surface(grip,float(fighter.aim),Model.lance_length(fighter),0,Model.lance_length(fighter),bool(fighter.broken),1.0)*mirror
	error = maxf(error,drawn_tip.distance_to(Model.tip_position(fighter)))
	error = maxf(error,(Lance.surface(grip,float(fighter.aim),0,0,Model.lance_length(fighter),bool(fighter.broken),1.0)*mirror).distance_to(Model.hand_position(fighter)))
	max_anchor_error = maxf(max_anchor_error,error)
	check(error<.025,"Head, chest, shield, grip and visible lance endpoint share the production reaction pose",context.merged({"error":error}))
	for side in ["left","right"]:
		var arm: Dictionary = pose[side]
		var upper_error = absf(Vector2(arm.shoulder).distance_to(arm.elbow)-Rider.ARM_UPPER)
		var lower_error = absf(Vector2(arm.elbow).distance_to(arm.hand)-Rider.ARM_LOWER)
		max_arm_error = maxf(max_arm_error,maxf(upper_error,lower_error))
		check(maxf(upper_error,lower_error)<.04,"Reaction keeps fixed arm lengths and attached grips",context.merged({"side":side,"upper_error":upper_error,"lower_error":lower_error}))
	var rest = fighter.duplicate(true)
	rest.reaction_shift = 0.0
	var legs = Rider.seated_leg_pose(fighter)
	var rest_legs = Rider.seated_leg_pose(rest)
	for side in ["near","far"]:
		var difference: Vector2 = legs[side].hip-rest_legs[side].hip
		check(difference.distance_to(Vector2(float(fighter.reaction_shift),0))<.01,"Both hips follow the shared saddle slide",context)
		check(Vector2(legs[side].knee).distance_to(rest_legs[side].knee)<.01 and Vector2(legs[side].ankle).distance_to(rest_legs[side].ankle)<.01,"Knees and stirrup support do not slide with torso recoil",context)

func run_contact(zone: String, facing: int, lean: float, guard: float, stats: Dictionary) -> void:
	var model = Model.new("arena",stats,stats,5781)
	var attacker_index = 1 if facing==1 else 0
	var defender_index = 1-attacker_index
	var attacker: Dictionary = model.fighters[attacker_index]
	var defender: Dictionary = model.fighters[defender_index]
	defender.direction = facing
	defender.x = 0.0
	defender.lane_y = 0.0
	defender.lean = lean
	defender.guard = guard
	attacker.aim = 0.0
	var before = anchors(defender)
	var hand_before = Model.hand_position(attacker)
	var context = {"zone":zone,"facing":facing,"lean":lean,"guard":guard}
	# Damage/strength, glance and impulse are calculated by the real producer;
	# we do not directly inject a desired spring velocity or force a reaction.
	var contact = {"type":"hit","zone":zone,"speed":960.0,"attacker":attacker_index,"defender":defender_index,"position":before.shield if zone=="shield" else before.head if zone=="head" else before.body}
	model._apply_contact(contact)
	var after = anchors(defender)
	for key in ["head","body","hand","shield"]:
		check(Vector2(before[key]).distance_to(after[key])<.0001,"Contact frame zero adds momentum without teleporting any rider anchor",context.merged({"anchor":key}))
	check(hand_before.distance_to(Model.hand_position(attacker))<.0001,"Attacker grip does not teleport on contact",context)
	check(float(defender.reaction_angular_velocity)!=0.0 and float(attacker.lance_compression_velocity)>0.0,"Actual contact producer loads both defender and lance arm",context)
	var hp_after = float(defender.hp)
	var balance_after = float(defender.balance)
	var snapshots: Array = [{"time":0.0,"fighter":defender.duplicate(true)}]
	var at60 = {}
	var max_head_step = 0.0
	var previous_head = Model.head_position(defender)
	for tick in range(1,289):
		Model.advance_reaction(defender,1.0/240.0)
		Model.advance_reaction(attacker,1.0/240.0)
		var current_head = Model.head_position(defender)
		max_head_step = maxf(max_head_step,current_head.distance_to(previous_head))
		previous_head = current_head
		validate_pose(defender,context.merged({"tick":tick}))
		validate_pose(attacker,context.merged({"tick":tick,"attacker":true}))
		if tick==15:
			at60 = {"seconds":tick/240.0,"head_dx":(current_head.x-before.head.x)*facing,
				"body_dx":(Model.body_position(defender).x-before.body.x)*facing,
				"shield_compression":defender.shield_compression,"lance_compression":attacker.lance_compression,
				"angle":defender.reaction_angle,"shift":defender.reaction_shift}
			snapshots.append({"time":tick/240.0,"fighter":defender.duplicate(true)})
		if tick==43:
			snapshots.append({"time":tick/240.0,"fighter":defender.duplicate(true)})
	check(absf(float(at60.head_dx))>3.0,"A committed hit has visible shared head displacement by about 60ms",context.merged(at60))
	check(float(at60.lance_compression)>2.0,"The attacking grip takes a visible continuous load",context.merged(at60))
	if zone=="shield":
		check(float(at60.shield_compression)>4.0,"Shield contact compresses the actual shield and supporting arm",context.merged(at60))
	else:
		check(is_zero_approx(float(at60.shield_compression)),"Body/head contact does not invent an independent shield strike",context.merged(at60))
	check(max_head_step<5.0,"Reaction proceeds through small successive poses instead of one-frame repositioning",context.merged({"max_head_step":max_head_step}))
	check(absf(float(defender.reaction_angle))<.003 and absf(float(defender.reaction_shift))<.03 and absf(float(defender.shield_compression))<.08 and absf(float(attacker.lance_compression))<.05,"Reaction settles without leaving a permanent control offset",context)
	check(float(defender.hp)==hp_after and float(defender.balance)==balance_after,"Advancing reaction does not apply additional injury or balance damage",context)
	rows.append(context.merged({"actual_contact":contact,"at_62_5ms":at60,"max_head_step_240hz":max_head_step,"final_angle":defender.reaction_angle,"final_shift":defender.reaction_shift}))
	if lean==0.0 and is_equal_approx(guard,.43):
		if not sheets.has(zone): sheets[zone] = []
		sheets[zone].append({"facing":facing,"snapshots":snapshots})
	model._reset_positions()
	for fighter in model.fighters:
		for key in ["reaction_angle","reaction_angular_velocity","reaction_shift","reaction_shift_velocity","shield_compression","shield_compression_velocity","lance_compression","lance_compression_velocity"]:
			check(is_zero_approx(float(fighter[key])),"Next pass clears all reaction offsets and velocities",context.merged({"field":key}))

func neck_checks(stats: Dictionary) -> void:
	var model = Model.new("arena",stats,stats,92)
	for fighter in model.fighters:
		for lean in [-1.0,0.0,1.0]:
			fighter.lean = lean
			var pose = Rider.arm_pose(fighter)
			var fit = Rider.HeadFit.layout(fighter.stats)
			var original: Transform2D = pose.torso_transform
			original.x *= int(fighter.direction)
			original.origin += pose.torso_transform.x*float(fit.head_offset)
			var actual = Rider.head_transform(pose,fighter)
			check(actual.origin.distance_to(original.origin)<.01 and actual.x.distance_to(original.x)<.0001 and actual.y.distance_to(original.y)<.0001,"Zero detached head rotation preserves the existing fitted helmet matrix")
			var base_neck = Rider.neck_geometry(pose,fighter)
			for angle in [-.2,-.1,0.0,.1,.2]:
				pose.head_rotation = angle
				var neck = Rider.neck_geometry(pose,fighter)
				var transformed = Rider.head_transform(pose,fighter)
				check(Vector2(neck.base).distance_to(base_neck.base)<.0001,"Detached head articulation keeps the collar root fixed")
				check(Vector2(neck.top).distance_to(neck.base)>5 and Vector2(neck.top).distance_to(neck.base)<52,"Neck bridge remains short and non-inverted")
				check(is_finite(transformed.get_rotation()) and transformed.origin.is_finite(),"Detached head and helmet transform stays finite")

func label(parent: Node, value: String, point: Vector2) -> void:
	var text = Label.new()
	text.text = value
	text.position = point
	text.add_theme_font_size_override("font_size",17)
	parent.add_child(text)

func capture_sheets() -> void:
	if not captures_enabled:
		return
	root.size = Vector2i(1440,810)
	root.content_scale_size = Vector2i(1440,810)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for zone in sheets:
		var page = Node2D.new()
		root.add_child(page)
		var background = ColorRect.new()
		background.size = Vector2(1440,810)
		background.color = Color("333b3d")
		page.add_child(background)
		label(page,"Production contact reaction / "+str(zone)+" / anatomical pose sheet, not gameplay",Vector2(30,15))
		for row_index in range(sheets[zone].size()):
			var example: Dictionary = sheets[zone][row_index]
			for column in range(example.snapshots.size()):
				var sample: Dictionary = example.snapshots[column]
				var fighter: Dictionary = sample.fighter
				var view = Rider.new()
				view.fighter = fighter.duplicate(true)
				view.detached_pose = Rider.arm_pose(fighter)
				view.detached_legs = Rider.seated_leg_pose(fighter)
				view.position = Vector2(column*470+(145 if example.facing==1 else 325),row_index*370+355)
				view.scale = Vector2.ONE*.94
				page.add_child(view)
				view.set_process(false)
				label(page,"face %d | %.1f ms" % [example.facing,float(sample.time)*1000],Vector2(column*470+35,row_index*370+56))
		await process_frame
		await RenderingServer.frame_post_draw
		var path = run_dir.path_join("reaction_"+str(zone)+".png")
		check(root.get_texture().get_image().save_png(path)==OK,"Reaction pose sheet saves")
		captures.append(path)
		page.queue_free()
		await process_frame

func run() -> void:
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_"):
		push_error("Reaction test requires isolated -- --test-profile")
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-dir="): run_dir = arg.trim_prefix("--run-dir=")
		elif arg=="--no-captures": captures_enabled = false
	if run_dir.is_empty() or not run_dir.is_absolute_path() or DirAccess.dir_exists_absolute(run_dir) or FileAccess.file_exists(run_dir):
		push_error("Use a fresh absolute --run-dir; no old evidence will be overwritten")
		quit(2)
		return
	if captures_enabled and DisplayServer.get_name()=="headless":
		push_error("Captures need a renderer; use --no-captures for pure pose checks")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(run_dir)
	var items = Catalogue.load_items()
	var stats = Catalogue.stats(items,{"armor":"armor_e2","helmet":"helm_e2","shield":"shield_basic","lance":"lance_ash","horse":"horse_bay","crest":"crest_bend"})
	stats.stability = 2.0 # Keeps this isolated mounted-pose fixture seated.
	stats.durability = 10000.0
	for zone in ["head","body","shield","flank"]:
		for facing in [1,-1]:
			for lean in [-1.0,0.0,1.0]:
				for guard in [0.0,.43,1.0]:
					run_contact(zone,facing,lean,guard,stats)
	neck_checks(stats)
	await capture_sheets()
	var report = {"passed":failures.is_empty(),"failures":failures,"examples":examples,"rows":rows,"captures":captures,
		"max_anchor_error":max_anchor_error,"max_arm_error":max_arm_error,
		"scope":"Actual Model._apply_contact then production reaction springs and Rider/Lance shared geometry, 72 contact/pose cases. Explicit contact inputs; no swept-collision, OS-input or human-feel claim. Reaction sheet shows actual Rider drawing without horse/environment so joints can be compared.",
		"fixture":"960 incoming speed, arena, catalogue kit, stability2 and durability10000, x/lane held fixed, gait stopped, reaction advanced at240Hz. Does not alter player profile or production tuning."}
	var file = FileAccess.open(run_dir.path_join("report.json"),FileAccess.WRITE)
	if not file:
		push_error("Cannot write reaction report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("REACTION_V057 ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows.size(),"max_anchor_error":max_anchor_error,"max_arm_error":max_arm_error,"run_dir":run_dir}))
	quit(0 if failures.is_empty() else 1)
