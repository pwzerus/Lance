extends SceneTree
## ANIM-091 motion study (isolated desktop, QA profile). Uses the real match
## model (set_controls + step) for one rider whose opponent is parked far
## away, and the real RiderView for drawing.
##  metrics.json  - seat inertia, rider pitch/head travel from inertia, horse
##                  presentation pitch, planted-hoof slip/height, reach limits.
##  strip_*.png   - filmstrips: idle, spurred launch, steady gallop stride,
##                  release/check from the gallop, trot stride.
## Human review of the images is the visual check. Not OS input or a playtest.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const DT = 1.0/60.0
const ZOOM = 1.0
var folder = ""
var model
var fighter: Dictionary
var rider
var mount: Node2D
var metrics = {"ticks":0,"max_inertia":0.0,"min_inertia":0.0,"max_inertia_pitch":0.0,"max_inertia_head_shift":0.0,
	"max_extra_pitch":0.0,"planted_frames":0,"max_planted_slip":0.0,"max_planted_height":0.0,"reach_limited_frames":0,"leg_frames":0,"nonfinite":0}
var planted_world: Array = [INF,INF,INF,INF]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-report="): folder = arg.trim_prefix("--anim-report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DisplayServer.get_name()=="headless" or DirAccess.dir_exists_absolute(folder):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1440,1080)
	root.content_scale_size = Vector2i(1440,1080)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	var catalogue = load("res://scripts/core/catalogue.gd")
	var items = catalogue.load_items()
	var stats = catalogue.stats(items,{"horse":"horse_bay","armor":"eng_armor_3","helmet":"eng_helmet_1","crest":"crest_bend","lance":"eng_lance_long_3","shield":"eng_shield_3"})
	model = Model.new("arena",stats,stats)
	fighter = model.fighters[0]
	model.fighters[1].x = 99999.0
	model.phase = "charge"
	fighter.lane_y = 0.0
	mount = Node2D.new()
	root.add_child(mount)
	rider = Rider.new()
	rider.fighter = fighter
	rider.scale = Vector2.ONE*ZOOM
	mount.add_child(rider)
	rider.set_process(false)
	# 1. Idle: the standing horse fidgets on the presentation clock.
	rider.moving = false
	fighter.gait_moving = false
	var idle: Array[Image] = []
	for t in range(0,48):
		_place()
		rider._process(DT*8)
		if t%8==0:
			idle.append(await _shot())
	_save_strip(idle,"strip_idle.png")
	# 2. Spurred launch from a standstill (the real start of a pass).
	rider.moving = true
	var launch: Array[Image] = []
	var shots = [3,8,13,18,26,36,50,70]
	for tick in range(72):
		_tick(true)
		if tick in shots: launch.append(await _shot())
	_save_strip(launch,"strip_launch.png")
	# Run on to a full gallop.
	for tick in range(240):
		_tick(true)
	# 3. One steady gallop stride.
	var stride: Array[Image] = []
	var period = 1.0/Gait.frequency(float(fighter.speed))
	var per = maxi(1,roundi(period/DT/8.0))
	for tick in range(per*8):
		_tick(true)
		if tick%per==0: stride.append(await _shot())
	_save_strip(stride,"strip_gallop.png")
	# 4. Release the spur: the horse checks back toward a trot.
	var release: Array[Image] = []
	shots = [3,8,14,22,32,46,64,90]
	for tick in range(92):
		_tick(false)
		if tick in shots: release.append(await _shot())
	_save_strip(release,"strip_release.png")
	for tick in range(120):
		_tick(false)
	# 5. Trot stride.
	var trot: Array[Image] = []
	period = 1.0/Gait.frequency(float(fighter.speed))
	per = maxi(1,roundi(period/DT/8.0))
	for tick in range(per*8):
		_tick(false)
		if tick%per==0: trot.append(await _shot())
	_save_strip(trot,"strip_trot.png")
	var file = FileAccess.open(folder+"/metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("ANIM091 "+JSON.stringify(metrics))
	var ok = metrics.nonfinite==0 and metrics.max_inertia>.25 and metrics.min_inertia<-.15 and float(metrics.max_planted_slip)<1.0 and float(metrics.max_planted_height)<1.0
	print("ANIM091_RESULT "+("PASS" if ok else "FAIL")+" "+folder)
	mount.queue_free()
	await process_frame
	quit(0 if ok else 1)

func _place() -> void:
	rider.position = Vector2(float(fighter.x),0)
	mount.position = Vector2(720-float(fighter.x)*ZOOM,760)

func _tick(boost: bool) -> void:
	# A fresh horse for every strip: the study is about motion, not fatigue
	# (5 s of spurring would otherwise sink the gallop ceiling to a canter).
	fighter.stamina = 100.0
	model.set_controls(0,-.08,0.0,boost,DT)
	model.step(DT)
	_place()
	rider._process(DT)
	metrics.ticks += 1
	var inertia = Model.seat_inertia(fighter)
	metrics.max_inertia = maxf(metrics.max_inertia,inertia)
	metrics.min_inertia = minf(metrics.min_inertia,inertia)
	# Rule-pose contribution of the seat spring alone.
	var still = fighter.duplicate()
	still.seat_drive = fighter.motion_drive
	var pitch_delta = absf(Model.pose_angle(fighter)-Model.pose_angle(still))
	metrics.max_inertia_pitch = maxf(metrics.max_inertia_pitch,pitch_delta)
	metrics.max_inertia_head_shift = maxf(metrics.max_inertia_head_shift,Model.head_position(fighter).distance_to(Model.head_position(still)))
	var visual: Dictionary = rider.visual_pose
	var rule = Model.gait_pose(fighter)
	if not visual.is_empty():
		metrics.max_extra_pitch = maxf(metrics.max_extra_pitch,absf(float(visual.pitch)-float(rule.pitch)))
	for i in range(rider.leg_poses.size()):
		var leg: Dictionary = rider.leg_poses[i]
		metrics.leg_frames += 1
		for key in ["hip","knee","ankle","foot"]:
			if not Vector2(leg[key]).is_finite(): metrics.nonfinite += 1
		if bool(leg.get("reach_limited",false)): metrics.reach_limited_frames += 1
		var world_x = float(fighter.x)+float(leg.foot.x)*int(fighter.direction)
		if bool(leg.contact):
			metrics.planted_frames += 1
			metrics.max_planted_height = maxf(metrics.max_planted_height,absf(float(leg.foot.y)-Gait.GROUND))
			if is_finite(planted_world[i]):
				metrics.max_planted_slip = maxf(metrics.max_planted_slip,absf(world_x-float(planted_world[i])))
			else:
				planted_world[i] = world_x
		else:
			planted_world[i] = INF

func _shot() -> Image:
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_region(Rect2i(720-300,760-380,600,440))

func _save_strip(cells: Array[Image], name: String) -> void:
	metrics["speed_"+name.get_basename()] = float(fighter.get("speed",0.0))
	var columns = 4
	var rows = ceili(cells.size()/float(columns))
	var sheet = Image.create_empty(606*columns,446*rows,false,Image.FORMAT_RGBA8)
	sheet.fill(Color.BLACK)
	for i in range(cells.size()):
		sheet.blit_rect(cells[i],Rect2i(Vector2i.ZERO,cells[i].get_size()),Vector2i((i%columns)*606,(i/columns)*446))
	sheet.save_png(folder+"/"+name)
