extends SceneTree

const Model = preload("res://scripts/core/joust_match.gd")
var checks = 0
var failures: Array = []
var state: Node
var main: Node

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func wait(seconds: float) -> void:
	await create_timer(seconds,true,false,true).timeout

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/GALUMU/docs/development/screenshots/v042/"+name_value+".png")

func fixed_head_attack(defender_lean: float) -> String:
	var model = Model.new("arena")
	model.fighters[0].x = -500
	model.fighters[0].aim = asin((Model.head_position(model.fighters[1]).y-Model.hand_position(model.fighters[0]).y)/Model.lance_length(model.fighters[0]))
	model.fighters[1].x = 0
	model.fighters[1].lean = defender_lean
	model.fighters[1].guard = 1.0 if defender_lean>0 else 0.0
	model._cache_pose(model.fighters[0])
	model._cache_pose(model.fighters[1])
	for i in range(170):
		model.fighters[0].x += 4
		var contact = model._detect_contact(0,1.0/120)
		if not contact.is_empty():
			return str(contact.zone)
		model._cache_pose(model.fighters[0])
	return "miss"

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Game-feel capture requires a rendered window; do not run with --headless")
		quit(1)
		return
	state = root.get_node("GameState")
	check(state.save_path.contains("qa_"),"QA profile must isolate player data")
	if not state.save_path.contains("qa_"):
		quit(1)
		return
	state.profile = state.default_profile()
	var run_model = Model.new("arena")
	var trot = Model.new("arena")
	run_model.phase = "charge"
	trot.phase = "charge"
	for i in range(120):
		for index in range(2):
			run_model.set_controls(index,0,0,true,1.0/120)
			trot.set_controls(index,0,0,false,1.0/120)
		run_model.step(1.0/120)
		trot.step(1.0/120)
	check(float(run_model.fighters[0].speed)>float(trot.fighters[0].speed)*1.8,"Holding boost must visibly accelerate actual horse speed")
	check(float(run_model.fighters[0].x)-float(trot.fighters[0].x)>100,"Boost must change charge distance, not only animation")
	var first_hit = -1.0
	for tick in range(1000):
		for index in range(2):
			run_model.set_controls(index,0,0,true,1.0/120)
		run_model.step(1.0/120)
		for event in run_model.drain_events():
			if event.type=="hit" and first_hit<0:
				first_hit = run_model.time_elapsed
	check(first_hit>3.4,"Long charge must leave several seconds before first possible contact")
	var pose = Model.new()
	pose.set_controls(0,0,-1,true,.1)
	check(absf(float(pose.fighters[0].lean))<.1,"Posture must build momentum instead of snapping")
	for i in range(240):
		pose.set_controls(0,0,-1,false,1.0/120)
	check(absf(rad_to_deg(Model.pose_angle(pose.fighters[0]))+45)<.1,"Backward lean must reach 45 degrees")
	for i in range(300):
		pose.set_controls(0,0,1,false,1.0/120)
	check(absf(rad_to_deg(Model.pose_angle(pose.fighters[0]))-25)<.1,"Forward brace must reach 25 degrees")
	var defend = Model.new("war")
	defend._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"head","speed":620.0,"position":Vector2.ZERO})
	check(not defend.fighters[1].ko and not defend.fighters[1].dead,"An ordinary head hit must not be an unconditional instant kill")
	check(float(defend.fighters[1].hp)>50,"Head protection must leave a chance to continue")
	check(fixed_head_attack(0)=="head","A fixed high lance must actually hit an upright head")
	check(fixed_head_attack(1)=="shield","Forward brace must intercept the same high lance with its shield")
	check(fixed_head_attack(-1)=="miss","Full backward lean must move the head clear of that same committed attack")
	var brace = Model.new("arena")
	brace.fighters[1].lean = 1.0
	brace._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"shield","speed":960.0,"position":Vector2.ZERO})
	check(float(brace.fighters[1].hp)>97 and not brace.fighters[1].ko,"A raised shield must absorb a full charge")
	var abdomen = Model.new("arena")
	abdomen.fighters[1].lean = -1.0
	abdomen._apply_contact({"type":"hit","attacker":0,"defender":1,"zone":"flank","speed":960.0,"position":Vector2.ZERO})
	check(abdomen.fighters[1].ko and not abdomen.fighters[1].dead,"Exposed abdomen can unseat a leaning rider without making arena lethal")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main._start_match("arena")
	var battle = main.battle
	battle.autoplay = true
	await wait(.3)
	check(battle.camera.zoom.x<.4,"Opening camera must frame the long approach")
	await capture("01_long_charge")
	# Inject an actual click/release into the viewport. It should spur the horse
	# after release, rather than requiring the physical button to remain down.
	battle.autoplay = false
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(1100,450)
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await wait(.08)
	check(battle.match_model.fighters[0].boost and battle.spur_left>0,"A quick left click must deliver buffered acceleration")
	await wait(1.25)
	check(battle.match_model.fighters[0].boost and battle.spur_left>1,"A countdown tap must remain queued until the horse starts")
	battle.match_model.phase = "charge"
	var charge_start_x = float(battle.match_model.fighters[0].x)
	await wait(2.15)
	check(not battle.match_model.fighters[0].boost and battle.spur_left==0,"A released tap must expire after actual running time")
	check(float(battle.match_model.fighters[0].speed)>450 and float(battle.match_model.fighters[0].x)-charge_start_x>850,"Queued click must maintain a visible gallop and actual travel after launch")
	battle.match_model.phase = "ready"
	battle.autoplay = true
	# Place a controlled close encounter to verify actual projection, not a
	# camera-free algebra-only aim test. Freeze model translation, keep views.
	battle.match_model.phase_time = 20
	battle.match_model.fighters[0].x = -225
	battle.match_model.fighters[1].x = 225
	await wait(1.8)
	check(battle.camera.zoom.x>1.1,"Camera must approach riders for readable contact")
	# Stop the camera easing for this coordinate assertion so the stationary
	# screen point does not become a different world point while it settles.
	battle.camera.zoom = Vector2.ONE*clampf(.28*pow((Model.START_X*2.0)/450.0,.65),.28,1.65)
	battle.camera.force_update_scroll()
	battle.autoplay = false
	battle.ai_timer = 1000
	battle.ai_lean = 0
	for f in battle.match_model.fighters:
		f.lean = 0.0
		f.lean_velocity = 0.0
	var target_world = Model.head_position(battle.match_model.fighters[1])+battle.world.position
	var screen = battle.get_canvas_transform()*target_world
	var round_trip = battle.get_canvas_transform().affine_inverse()*screen
	check(round_trip.distance_to(target_world)<.01,"Zoomed camera projection must preserve world aim coordinates")
	var motion = InputEventMouseMotion.new()
	motion.position = screen
	root.push_input(motion,true)
	await wait(.3)
	var hand = Model.hand_position(battle.match_model.fighters[0])
	var target = Model.head_position(battle.match_model.fighters[1])
	var expected = asin(clampf((target.y-hand.y)/Model.lance_length(battle.match_model.fighters[0]),-.629,.548))
	print("ZOOM_AIM actual=",battle.match_model.fighters[0].aim," expected=",expected," pointer=",battle.aim_pointer," screen=",screen," paused=",battle.paused)
	check(absf(float(battle.match_model.fighters[0].aim)-expected)<.02,"Mouse must aim at the visible head after camera zoom")
	var held_angle = float(battle.pointer_aim)
	battle.camera.zoom = Vector2.ONE*.8
	battle.camera.force_update_scroll()
	await wait(.2)
	check(is_equal_approx(battle.pointer_aim,held_angle),"Camera zoom without mouse motion must not redirect the player's committed angle")
	var show_zones = InputEventKey.new()
	show_zones.physical_keycode = KEY_H
	show_zones.pressed = true
	root.push_input(show_zones,true)
	await physics_frame
	await process_frame
	check(battle.zone_overlay.visible and battle.zone_overlay.z_index>battle.riders[0].z_index,"H must show hit regions above the rider and shield textures")
	await capture("02_guard_and_arms")
	var break_event = {"break_angle":-.1,"break_direction":1,"break_hand":Model.hand_position(battle.match_model.fighters[0]),"break_reach":247.0}
	battle.effects.break_lance(break_event,"arena")
	await process_frame
	check(battle.effects.debris.size()==2,"Broken front shaft must leave two physical fragments")
	var fragment = battle.effects.debris[0]
	var start = fragment.position
	for i in range(16):
		await physics_frame
	await process_frame
	print("FRAGMENT start=",start," end=",fragment.position," velocity=",fragment.linear_velocity," scale=",Engine.time_scale," paused=",paused)
	check(fragment.position.distance_to(start)>5,"Fragments must fly instead of disappearing")
	await capture("03_flying_shaft")
	battle._toggle_pause()
	start = fragment.position
	await wait(.12)
	check(fragment.position.distance_to(start)<.01,"Broken shaft physics must stop during pause")
	battle._toggle_pause()
	# Separation after passing should widen the framing again.
	battle.match_model.fighters[0].x = 1500
	battle.match_model.fighters[1].x = -1500
	await wait(1)
	check(battle.camera.zoom.x<.6,"Camera must widen after the riders separate")
	await wait(3.3)
	check(not is_instance_valid(fragment),"Transient rigid fragments must clean themselves up")
	main._close_battle()
	check(Engine.time_scale==1 and not paused,"Leaving battle must restore global clock and pause state")
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty(),"first_contact_game_seconds":first_hit}
	print("GAME_FEEL_TEST_REPORT "+JSON.stringify(report))
	var file = FileAccess.open("res://tests/game_feel_v042_results.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
