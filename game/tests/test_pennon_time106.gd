extends SceneTree
const Rider106=preload("res://scripts/visual/rider_view.gd")
const Model106=preload("res://scripts/core/joust_match.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize()->void:call_deferred("run")
func shot(rider)->Image:
	rider.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or not "--test-profile" in OS.get_cmdline_user_args() or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(840,560);root.content_scale_size=root.size
	var stats=Catalogue.stats(Catalogue.load_items(),{"armor":"eng_armor_5","helmet":"eng_helmet_5","lance":"eng_lance_long_5","horse":"horse_bay"})
	var rows=[]
	for facing in [1,-1]:
		var fighter=Model106.new("arena",stats,stats).fighters[0];fighter.direction=facing;fighter.x=0;fighter.lane_y=0;fighter.speed=360;fighter.gait_moving=true;fighter.gait_phase=1.2
		var rider=Rider106.new();rider.fighter=fighter;rider.position=Vector2(420,490);rider.moving=true
		root.add_child(rider);rider.set_process(false);rider._process(.25)
		var a=await shot(rider)
		var until=Time.get_ticks_msec()+180
		while Time.get_ticks_msec()<until:await process_frame
		var b=await shot(rider)
		if a.get_data()!=b.get_data():failures.append("Wall-clock redraw moved paused rider/pennon: "+str(facing))
		rider.clock+=.18
		var c=await shot(rider)
		if b.get_data()==c.get_data():failures.append("Game-time pennon did not animate: "+str(facing))
		rows.append({"facing":facing,"pause_pixels_equal":a.get_data()==b.get_data(),"game_time_changes_pixels":b.get_data()!=c.get_data()})
		a.save_png(folder+"/%d_paused.png"%facing);c.save_png(folder+"/%d_advanced.png"%facing)
		rider.queue_free();await process_frame
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Isolated actual Rider GPU; redraw after 180ms wall time at fixed game pose, then .18 game-clock advance. No OS input."},"\t"))
	print("PENNON106 ",failures);quit(0 if failures.is_empty() else 1)
