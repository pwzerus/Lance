extends SceneTree
## Controlled production Model/RiderView playback. Never generates OS input.
## Use the same external script with old/new PCKs and fresh output paths.
const Model = preload("res://scripts/core/joust_match.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const UI = preload("res://scripts/ui/ui_factory.gd")
const DT = 1.0 / 60.0
const TOTAL_FRAMES = 720
const CAPTURE_FRAMES = [0,90,149,165,210,300,330,390,449,480,570,600,690]

class TrackFloor extends Node2D:
	var travel = 0.0
	func _draw() -> void:
		for row in range(8):
			for col in range(36):
				draw_rect(Rect2(col*40,30+row*34,40,34),Color("1b2d27") if (row+col)%2==0 else Color("23382f"))
		draw_rect(Rect2(0,296,1416,48),Color("514d3b"))
		draw_line(Vector2(0,296),Vector2(1416,296),Color("c5bd8d"),2.0)
		for index in range(-1,27):
			var x = index*56.0-fposmod(travel*.84,56.0)
			draw_line(Vector2(x,318),Vector2(x+18,318),Color("969073"),3.0)

var model
var views: Array = []
var holders: Array = []
var floors: Array = []
var labels: Array = []
var caption: Label
var failures: Array[String] = []
var rows: Array = []
var statistics: Dictionary = {}
var previous_feet: Array = [[],[]]
var speed_events: Array = []
var control_events: Array = []
var captures: Array = []
var capture_dir = ""
var report_path = ""
var horse_id = "horse_bay"
var maximum_support_slide = 0.0
var maximum_hoof_velocity = 0.0
var maximum_local_joint_velocity = 0.0
var maximum_ground_penetration = 0.0
var maximum_control_steps = {"aim":0.0,"guard":0.0,"lean":0.0}
var worst_foot: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures:
		failures.append(message)
		push_error(message)

func make_scene() -> void:
	var page = Control.new()
	page.theme = UI.theme()
	root.add_child(page)
	var background = ColorRect.new()
	background.color = Color("15221e")
	background.size = Vector2(1440,810)
	page.add_child(background)
	caption = UI.label(page,"DEV-056 · 连续催马与松手观察",Vector2(20,10),25,UI.GOLD)
	UI.label(page,"生产模型驱动 / 固定60步 · 非OS输入、非真人体验或实时帧率验收",Vector2(20,778),17,UI.MUTED)
	for index in range(2):
		var panel = UI.panel(page,Rect2(12,68+index*353,1416,344))
		panel.clip_contents = true
		var floor_view = TrackFloor.new()
		panel.add_child(floor_view)
		floors.append(floor_view)
		var holder = Node2D.new()
		holder.scale = Vector2.ONE*.84
		panel.add_child(holder)
		holders.append(holder)
		var view = Rider.new()
		view.fighter = model.fighters[index]
		view.moving = true
		holder.add_child(view)
		view.set_process(false)
		views.append(view)
		labels.append(UI.label(panel,"",Vector2(16,12),17,UI.INK,500))

func stage_at(seconds: float) -> String:
	if seconds<2.5: return "起步至巡航"
	if seconds<3.5: return "巡航开始催马"
	if seconds<5.5: return "持续疾驰"
	if seconds<7.5: return "松手回落"
	if seconds<9.5: return "再次催马"
	return "松手并连续调枪换盾"

func controls_at(seconds: float) -> Dictionary:
	var held = (seconds>=2.5 and seconds<5.5) or (seconds>=7.5 and seconds<9.5)
	var aim = .45 if seconds>=9.5 and seconds<10.25 else (-.55 if seconds>=10.25 and seconds<11.0 else -.08)
	var guard = 1.0 if seconds>=9.5 and seconds<10.25 else (0.0 if seconds>=10.25 and seconds<11.0 else .43)
	var lean = -.8 if seconds>=9.5 and seconds<10.25 else (.5 if seconds>=10.25 and seconds<11.0 else 0.0)
	return {"boost":held,"aim":aim,"guard":guard,"lean":lean}

func record(frame: int, index: int, stage: String, fighter: Dictionary, view, targets: Dictionary) -> Dictionary:
	var pose = Model.gait_pose(fighter)
	var key = stage+"/"+str(fighter.direction)
	if not statistics.has(key):
		statistics[key] = {"stage":stage,"direction":fighter.direction,"frames":0,"speed_sum":0.0,"speed_min":INF,"speed_max":-INF,"body_y_sum":0.0,"body_y_min":INF,"body_y_max":-INF,"rider_y_sum":0.0,"rider_y_min":INF,"rider_y_max":-INF,"pitch_min":INF,"pitch_max":-INF,"frequency_min":INF,"frequency_max":-INF,"flight_frames":0,"supported_frames":[0,0,0,0],"landings":[0,0,0,0],"release_limited_frames":0}
	var summary: Dictionary = statistics[key]
	summary.frames += 1
	summary.speed_sum += float(fighter.speed)
	summary.speed_min = minf(summary.speed_min,fighter.speed)
	summary.speed_max = maxf(summary.speed_max,fighter.speed)
	var body_y = float(pose.offset.y)
	var rider_y = body_y+float(pose.rider_offset.y)
	summary.body_y_sum += body_y
	summary.rider_y_sum += rider_y
	summary.body_y_min = minf(summary.body_y_min,body_y)
	summary.body_y_max = maxf(summary.body_y_max,body_y)
	summary.rider_y_min = minf(summary.rider_y_min,rider_y)
	summary.rider_y_max = maxf(summary.rider_y_max,rider_y)
	summary.pitch_min = minf(summary.pitch_min,pose.pitch)
	summary.pitch_max = maxf(summary.pitch_max,pose.pitch)
	summary.frequency_min = minf(summary.frequency_min,Gait.frequency(fighter.speed))
	summary.frequency_max = maxf(summary.frequency_max,Gait.frequency(fighter.speed))
	var supports = 0
	var foot_rows: Array = []
	var current_feet: Array = []
	for leg_index in range(view.leg_poses.size()):
		var leg: Dictionary = view.leg_poses[leg_index]
		var world_foot = Vector2(float(fighter.x)+leg.foot.x*int(fighter.direction),leg.foot.y)
		var previous = previous_feet[index][leg_index] if previous_feet[index].size()==4 else {}
		var penetration = maxf(0.0,leg.foot.y-Gait.GROUND)
		maximum_ground_penetration = maxf(maximum_ground_penetration,penetration)
		check(leg.foot.is_finite(),"Rendered hoof must remain finite")
		check(penetration<.03,"Rendered hoof penetrated the ground")
		if leg.contact:
			supports += 1
			summary.supported_frames[leg_index] += 1
			check(absf(leg.foot.y-Gait.GROUND)<.03,"A planted hoof floated above ground")
			if previous.is_empty() or not bool(previous.contact):
				summary.landings[leg_index] += 1
		if bool(leg.get("reach_limited",false)):
			summary.release_limited_frames += 1
		if not previous.is_empty():
			var hoof_velocity = world_foot.distance_to(previous.foot)/DT
			if hoof_velocity>maximum_hoof_velocity:
				maximum_hoof_velocity = hoof_velocity
				worst_foot = {"frame":frame,"direction":fighter.direction,"leg":leg_index,"speed":fighter.speed,"velocity":hoof_velocity,"previous":[previous.foot.x,previous.foot.y],"current":[world_foot.x,world_foot.y],"contact":leg.contact,"previous_contact":previous.contact}
			if leg.contact and previous.contact:
				var slide = absf(world_foot.x-previous.foot.x)
				maximum_support_slide = maxf(maximum_support_slide,slide)
				check(slide<=.08,"Planted hoof slid during real model acceleration or release")
		var joints: Dictionary = {}
		for joint in ["hip","proximal","knee","ankle"]:
			var point: Vector2 = leg[joint]
			check(point.is_finite(),"Rendered leg joint must remain finite")
			joints[joint] = point
			if not previous.is_empty():
				maximum_local_joint_velocity = maxf(maximum_local_joint_velocity,point.distance_to(previous.joints[joint])/DT)
		current_feet.append({"foot":world_foot,"joints":joints,"contact":leg.contact})
		foot_rows.append({"leg":leg_index,"world_foot":[world_foot.x,world_foot.y],"local_foot":[leg.foot.x,leg.foot.y],"contact":leg.contact,"toe_angle":leg.toe_angle,"cycle":leg.cycle,"swing":leg.swing,"reach_limited":leg.get("reach_limited",false)})
	previous_feet[index] = current_feet
	if supports==0: summary.flight_frames += 1
	return {"direction":fighter.direction,"speed":fighter.speed,"boost":fighter.boost,"acceleration":fighter.acceleration,"drive":fighter.motion_drive,"phase":fighter.gait_phase,"frequency":Gait.frequency(fighter.speed),"body_offset":[pose.offset.x,pose.offset.y],"rider_offset":[pose.rider_offset.x,pose.rider_offset.y],"body_pitch":pose.pitch,"rider_pitch":pose.rider_pitch,"neck":pose.neck,"aim":fighter.aim,"guard":fighter.guard,"lean":fighter.lean,"targets":targets.duplicate(),"feet":foot_rows}

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="): capture_dir = argument.trim_prefix("--captures=")
		if argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		if argument.begins_with("--horse-id="): horse_id = argument.trim_prefix("--horse-id=")
	var state = root.get_node_or_null("GameState")
	if state==null or not str(state.save_path).contains("qa_") or DisplayServer.get_name()=="headless":
		push_error("Charge motion requires GPU rendering and -- --test-profile")
		quit(2)
		return
	if capture_dir.is_empty() or report_path.is_empty() or FileAccess.file_exists(report_path) or DirAccess.dir_exists_absolute(capture_dir):
		push_error("Use fresh explicit --captures and --report paths; never overwrite old evidence")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	state.profile = state.default_profile()
	state.profile.equipped.horse = horse_id
	var stats: Dictionary = state.player_stats()
	model = Model.new("arena",stats,stats,5601)
	model.phase = "charge"
	for index in range(2):
		var fighter: Dictionary = model.fighters[index]
		fighter.x = -50000.0 if index==0 else 50000.0
		fighter.acted = true
		fighter.lane_y = 0.0
		fighter.gait_phase = 0.0
		model._cache_pose(fighter)
	root.size = Vector2i(1280,720)
	make_scene()
	for frame in range(TOTAL_FRAMES):
		await process_frame
		var seconds = frame*DT
		var targets = controls_at(seconds)
		var stage = stage_at(seconds)
		var old_speed = float(model.fighters[0].speed)
		for index in range(2):
			var fighter: Dictionary = model.fighters[index]
			var before = {"aim":float(fighter.aim),"guard":float(fighter.guard),"lean":float(fighter.lean)}
			model.set_controls(index,targets.aim,targets.lean,targets.boost,DT,targets.guard)
			for key in before:
				var step = absf(float(fighter[key])-float(before[key]))
				maximum_control_steps[key] = maxf(maximum_control_steps[key],step)
				check(step<.15,"Gun, shield or posture snapped across a large fraction of its range in one 60Hz step")
			if frame in [570,615,660]:
				control_events.append({"frame":frame,"direction":fighter.direction,"before":before,"after":{"aim":fighter.aim,"guard":fighter.guard,"lean":fighter.lean},"targets":targets.duplicate()})
		model.step(DT)
		if frame in [0,149,150,179,209,329,330,449,450,569,570,719]:
			speed_events.append({"frame":frame,"seconds":seconds,"held":targets.boost,"before":old_speed,"after":model.fighters[0].speed,"x":model.fighters[0].x})
		if frame in [330,570]: check(model.fighters[0].speed<old_speed,"Release did not begin reducing actual speed on the next simulation step")
		check(absf(model.fighters[0].speed-model.fighters[1].speed)<.001,"Same horse and inputs have different left/right speeds")
		caption.text = "DEV-056 · "+stage+" · %.2fs · %s" % [seconds,horse_id]
		var row = {"frame":frame,"seconds":seconds,"stage":stage,"fighters":[]}
		for index in range(2):
			var fighter: Dictionary = model.fighters[index]
			var view = views[index]
			view.position = Vector2(fighter.x,0)
			view._process(DT)
			holders[index].position = Vector2(708-fighter.x*.84,286)
			floors[index].travel = fighter.x
			floors[index].queue_redraw()
			var data = record(frame,index,stage,fighter,view,targets)
			row.fighters.append(data)
			labels[index].text = ("右向" if index==0 else "左向")+" · %s · 速度 %.0f · 步频 %.2f\n背高 %.1f / 骑手相对吸收 %.1f" % [Gait.NAMES[Gait.gait_index(fighter.speed)],fighter.speed,data.frequency,-data.body_offset[1],data.rider_offset[1]]
		if frame%3==0: rows.append(row)
		if frame in CAPTURE_FRAMES:
			await RenderingServer.frame_post_draw
			var path = capture_dir+"/frame_%03d.png" % frame
			var error = root.get_texture().get_image().save_png(path)
			check(error==OK,"Failed to save actual GPU frame")
			captures.append({"frame":frame,"path":path,"error":error})
	var summaries: Array = []
	for summary in statistics.values():
		summary.mean_speed = summary.speed_sum/maxi(1,summary.frames)
		summary.mean_body_y = summary.body_y_sum/maxi(1,summary.frames)
		summary.mean_rider_y = summary.rider_y_sum/maxi(1,summary.frames)
		summary.body_amplitude = summary.body_y_max-summary.body_y_min
		summary.rider_amplitude = summary.rider_y_max-summary.rider_y_min
		summaries.append(summary)
	var report = {"passed":failures.is_empty(),"failures":failures,"project_version":ProjectSettings.get_setting("application/config/version","unknown"),"horse_id":horse_id,"horse_speed_multiplier":stats.get("speed",1.0),"horse_stability":stats.get("stability",1.0),"fixed_simulation_hz":60,"duration_game_seconds":TOTAL_FRAMES*DT,"stage_statistics":summaries,"speed_events":speed_events,"control_events":control_events,"maximum_control_step":maximum_control_steps,"maximum_support_slide":maximum_support_slide,"maximum_hoof_velocity":maximum_hoof_velocity,"maximum_local_joint_velocity":maximum_local_joint_velocity,"maximum_ground_penetration":maximum_ground_penetration,"worst_foot":worst_foot,"samples":rows,"captures":captures,"visual_acceptance":"pending independent image/continuous playback review","scope":"Actual production model input setters and RiderView rendered continuously in a fixed following diagnostic frame. Both directions, start/cruise/hold/release/re-hold, finite weapon/shield/posture commands. Not Battle camera, OS input, naturalness proof or measured real-time FPS. Rule contacts disabled by explicit wide separation and acted=true. Existing v050 anatomy/catalogue suite remains the geometry/10-horse regression."}
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write motion report")
		quit(2)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CHARGE_MOTION_V056_COMPLETE passed=",failures.is_empty()," frames=",TOTAL_FRAMES," captures=",captures.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
