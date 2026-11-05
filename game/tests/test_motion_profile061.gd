extends SceneTree
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
class ProfileRider extends Rider:
	var draw_samples: Array[float] = []
	func _draw() -> void:
		var begin = Time.get_ticks_usec()
		super._draw()
		if draw_samples.size()<360: draw_samples.append(float(Time.get_ticks_usec()-begin))

func _initialize() -> void: call_deferred("run")

func summary(values: Array) -> Dictionary:
	values.sort()
	var total = 0.0
	for value in values: total+=value
	return {"count":values.size(),"mean_us":total/maxi(1,values.size()),"median_us":values[values.size()/2],"p95_us":values[int(values.size()*.95)]}

func run() -> void:
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.trim_prefix("--report=")
	if OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_") or path.is_empty() or FileAccess.file_exists(path):
		quit(2)
		return
	root.size=Vector2i(640,480)
	Engine.max_fps=60
	var model=Model.new("arena")
	var views=[]
	var updates=[]
	var wall=[]
	for side in range(2):
		var view=ProfileRider.new()
		view.fighter=model.fighters[side]
		view.fighter.speed=480.0
		view.fighter.gait_moving=true
		view.moving=true
		root.add_child(view)
		view.scale=Vector2.ONE*.7
		view.position=Vector2(320,230+side*230)
		view.set_process(false)
		views.append(view)
	var prior=Time.get_ticks_usec()
	for frame in range(300):
		await process_frame
		var now=Time.get_ticks_usec()
		if frame>60: wall.append(float(now-prior))
		prior=now
		for view in views:
			view.fighter.gait_phase+=TAU*Gait.frequency(480.0)/60
			var begin=Time.get_ticks_usec()
			view._process(1.0/60)
			if frame>60: updates.append(float(Time.get_ticks_usec()-begin))
		await RenderingServer.frame_post_draw
	var draws=[]
	for view in views:
		for sample in view.draw_samples.slice(61): draws.append(sample)
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"process_per_rider":summary(updates),"draw_per_rider":summary(draws),"frame_wall":summary(wall),"scope":"Actual two RiderViews, 640x480 offscreen desktop, 300 frames. No Main/Battle and no human input. Gait placement is diagnostic, not world-locked locomotion evidence."},"\t"))
	file.close()
	print("MOTION_PROFILE061_COMPLETE")
	quit()
