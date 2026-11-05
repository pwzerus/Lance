extends SceneTree
const Rider=preload("res://scripts/visual/rider_view.gd")
const Model=preload("res://scripts/core/joust_match.gd")
const Gait=preload("res://scripts/visual/horse_gait.gd")
var folder=""
var render=false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-report="): folder=arg.trim_prefix("--motion-report=")
		if arg=="--capture-motion": render=true
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or folder.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	if FileAccess.file_exists(folder+"/trace.jsonl"):
		quit(2)
		return
	root.size=Vector2i(960,600)
	root.content_scale_size=Vector2i(960,600)
	RenderingServer.set_default_clear_color(Color("596365"))
	var out=FileAccess.open(folder+"/trace.jsonl",FileAccess.WRITE)
	var model=Model.new("arena")
	var mount=Node2D.new()
	root.add_child(mount)
	var rider=Rider.new()
	rider.fighter=model.fighters[0]
	rider.fighter.x=0
	rider.fighter.gait_moving=true
	rider.moving=true
	mount.add_child(rider)
	rider.set_process(false)
	var label=Label.new()
	label.position=Vector2(20,20)
	root.add_child(label)
	var speeds=[100.0,210.0,320.0,480.0,-1.0]
	for run_index in range(speeds.size()):
		var old_speed=0.0
		for tick in range(600):
			var speed=speeds[run_index]
			if speed<0: speed=600.0*sin(PI*tick/600.0)
			rider.fighter.speed=speed
			rider.fighter.motion_drive=clampf((speed-old_speed)*60/500,-1,1)
			old_speed=speed
			rider.fighter.gait_phase+=TAU*Gait.frequency(speed)/60
			rider.position.x+=speed/60
			mount.position=Vector2(480-rider.position.x,480)
			rider._process(1.0/60)
			var legs=[]
			for leg in rider.leg_poses:
				legs.append({"foot":[leg.foot.x,leg.foot.y],"knee":[leg.knee.x,leg.knee.y],"proximal":[leg.proximal.x,leg.proximal.y],"cycle":leg.cycle,"contact":leg.contact,"limited":leg.reach_limited})
			var pose=Gait.body(rider.stride_phase,speed,true,1,rider.fighter.motion_drive)
			out.store_line(JSON.stringify({"run":run_index,"tick":tick,"speed":speed,"x":rider.position.x,"phase":rider.stride_phase,"body":[pose.offset.x,pose.offset.y,pose.pitch],"legs":legs}))
			if render and tick>=300 and tick<360 and tick%3==0:
				label.text="%s  speed %.0f  frame %d"%[Gait.NAMES[Gait.gait_index(speed)],speed,tick]
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder+"/run%d-%03d.png"%[run_index,tick])
		out.flush()
	out.close()
	print("MOTION061_COMPLETE "+folder)
	quit()
