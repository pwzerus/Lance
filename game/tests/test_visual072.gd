extends SceneTree
## Bounded GPU evidence on a non-input desktop. One small viewport and one
## contact sheet at a time; do not retain a match's full-resolution frames.
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Heraldry = preload("res://scripts/visual/heraldry.gd")
var folder = ""
var suite = "fit"
var selection = ""
var items: Array = []
var failures: Array = []
var trace: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder = arg.trim_prefix("--folder=")
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg.begins_with("--selection="): selection = arg.trim_prefix("--selection=")
	if int(OS.get_environment("GALUMU_MEMORY_BOUND")) not in [512,1024] or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(768,512)
	root.content_scale_size = Vector2i(768,512)
	RenderingServer.set_default_clear_color(Color("4b5859"))
	items = Catalogue.load_items()
	if suite=="fit": await fit_sheet()
	elif suite=="motion": await motion_sheets()
	elif suite=="contact": await contact_sheets()
	else: failures.append("Unknown suite")
	var result = {"passed":failures.is_empty(),"failures":failures,"suite":suite,"trace":trace,"scope":"Actual GPU frames with scripted poses on isolated desktop, not OS input or human play. Inspect PNGs separately."}
	var file = FileAccess.open(folder+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("VISUAL072 "+suite+" passed="+str(failures.is_empty()))
	quit(0 if failures.is_empty() else 1)

func new_rider(stats: Dictionary, facing: int) -> RiderView:
	var model = Model.new("arena",stats,stats)
	var f: Dictionary = model.fighters[0 if facing==1 else 1]
	f.x = 0.0
	f.lane_y = 0.0
	f.guard = .43
	var rider = Rider.new()
	rider.fighter = f
	rider.position = Vector2(384,450)
	root.add_child(rider)
	rider.set_process(false)
	return rider

func capture(rider: RiderView, seconds: float = 0.0) -> Image:
	rider._process(seconds)
	rider.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func fit_sheet() -> void:
	# Each region: rows = right forward/upright/back, then left same sequence;
	# columns = six helmet/breastplate tiers. 144 fitted moving-neck poses.
	for region in ["eng","fr","de","it"]:
		if not selection.is_empty() and region!=selection: continue
		var sheet = Image.create_empty(6*256,6*220,false,Image.FORMAT_RGBA8)
		for quality in range(6):
			var stats = Catalogue.stats(items,{"helmet":"%s_helmet_%d"%[region,quality],"armor":"%s_armor_%d"%[region,quality],"horse":"horse_bay"})
			var row = 0
			for facing in [1,-1]:
				var rider = new_rider(stats,facing)
				for lean in [1.0,0.0,-1.0]:
					rider.fighter.lean = lean
					var pose = Rider.arm_pose(rider.fighter)
					var neck = Rider.neck_geometry(pose,rider.fighter)
					if Vector2(neck.base).distance_to(neck.top)>52: failures.append("Long neck "+region)
					# Keep the head in the same crop while retaining collar and shoulders.
					rider.position = Vector2(384,130)-Model.head_position(rider.fighter)
					var frame = await capture(rider)
					sheet.blit_rect(frame,Rect2i(256,25,256,220),Vector2i(quality*256,row*220))
					row += 1
				rider.queue_free()
				await process_frame
		sheet.save_png(folder+"/fit-"+region+".png")

func motion_sheets() -> void:
	# Four coats, three cloth weights and four crests, both facings; gait
	# sequence shows real planted-foot and swing integration, not pose lerp.
	var index = 0
	for coat in ["bay","black","grey","flaxen"]:
		if not selection.is_empty() and coat!=selection:
			index += 1
			continue
		for facing in [1,-1]:
			var stats = Catalogue.stats(items,{"helmet":"eng_helmet_3","armor":"eng_armor_3","horse":"horse_bay","caparison":"caparison_"+["linen","wool","velvet"][index%3],"crest":"crest_"+Heraldry.ARMS.keys()[index%4]})
			stats.horse_coat = coat
			var rider = new_rider(stats,facing)
			var mount = Node2D.new()
			root.add_child(mount)
			rider.reparent(mount)
			rider.moving = true
			rider.fighter.gait_moving = true
			var sheet = Image.create_empty(4*460,3*360,false,Image.FORMAT_RGBA8)
			for speed_index in range(3):
				var speed = [110.0,210.0,480.0][speed_index]
				rider.fighter.speed = speed
				rider.fighter.stamina = 15.0 if speed_index==2 else 100.0
				var ticks = maxi(4,roundi(120.0/Rider.Gait.frequency(speed)))
				for tick in range(ticks):
					rider.fighter.gait_phase += TAU*Rider.Gait.frequency(speed)/60.0
					rider.fighter.x += facing*speed/60.0
					# Parent compensates world translation after planted-foot math.
					rider.position.x = rider.fighter.x
					rider._process(1.0/60.0)
					if tick>=ticks/2 and (tick-ticks/2)%maxi(1,ticks/8)==0:
						var col = mini(3,int((tick-ticks/2)/maxi(1,ticks/8)))
						mount.position.x = 384-rider.fighter.x
						var frame = await capture(rider)
						sheet.blit_rect(frame,Rect2i(154,125,460,360),Vector2i(col*460,speed_index*360))
						trace.append({"coat":coat,"facing":facing,"speed":speed,"phase":rider.fighter.gait_phase,"stamina":rider.fighter.stamina})
				sheet.save_png(folder+"/motion-%s-%d.png"%[coat,facing])
			mount.queue_free()
			await process_frame
		index += 1

func contact_sheets() -> void:
	# Authored contact-application fixtures isolate six response types. They
	# complement test_contact072's actual sweep; not claimed as natural play.
	for facing in [1,-1]:
		if not selection.is_empty() and str(facing)!=selection: continue
		var sheet = Image.create_empty(4*360,6*300,false,Image.FORMAT_RGBA8)
		var row = 0
		for zone in ["center","upper_rim","lower_rim","head","body","flank"]:
			var stats = Catalogue.stats(items,{"helmet":"eng_helmet_3","armor":"eng_armor_3","shield":"eng_shield_3","horse":"horse_bay","crest":"crest_cross"})
			stats.stability = 2.0
			var model = Model.new("arena",stats,stats,7201)
			var di = 0 if facing==1 else 1
			var f: Dictionary = model.fighters[di]
			f.x = 0.0
			f.lane_y = 0.0
			f.guard = .43
			var rider = new_rider(stats,facing)
			rider.fighter = f
			var event_zone = "shield" if zone in ["center","upper_rim","lower_rim"] else zone
			var point = Model.shield_transform(f)*Vector2(18,-40 if zone=="upper_rim" else (40 if zone=="lower_rim" else 0)) if event_zone=="shield" else (Model.head_position(f) if zone=="head" else (Model.body_position(f) if zone=="body" else Model.flank_position(f)))
			var event = {"type":"hit","zone":event_zone,"position":point,"attacker":1-di,"defender":di,"speed":960.0}
			model.fighters[1-di].aim = 0.0
			model.fighters[1-di].speed = 480.0
			model._apply_contact(event)
			rider.receive_impact(Model.reaction_strength(event),event_zone=="shield")
			rider.receive_contact(event)
			for tick in range(61):
				Model.advance_reaction(f,1.0/120.0)
				rider._process(1.0/120.0)
				if tick in [0,7,21,60]:
					var col = [0,7,21,60].find(tick)
					var frame = await capture(rider)
					sheet.blit_rect(frame,Rect2i(204,100,360,300),Vector2i(col*360,row*300))
			row += 1
			rider.queue_free()
			await process_frame
		sheet.save_png(folder+"/contact-%d.png"%facing)
