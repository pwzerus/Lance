extends SceneTree
## Production control/physics and RiderView, staged for close inspection.
## No OS input. Capture is disk-streamed; no unbounded image array.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder=""
	var coats=["bay","grey","black","flaxen"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a.begins_with("--coat="):coats=[a.trim_prefix("--coat=")]
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("334b40"))
	var trace=FileAccess.open(folder+"/trace.jsonl",FileAccess.WRITE)
	var label=Label.new();label.position=Vector2(40,30);label.add_theme_font_size_override("font_size",24);root.add_child(label)
	var floor_line=Line2D.new();floor_line.add_point(Vector2(0,779.2));floor_line.add_point(Vector2(1440,779.2));floor_line.width=2;floor_line.default_color=Color("92a28a");root.add_child(floor_line)
	var summary=[]
	for coat in coats:
		var equipment=state.default_profile().equipped.duplicate(true)
		if coat in ["black","flaxen"]:
			equipment.helmet="de_helmet_5";equipment.armor="de_armor_5"
		var stats=Catalogue.stats(Catalogue.load_items(),equipment);stats.horse_coat=coat
		var model=Model.new("arena",stats,stats,8501);model.phase="charge"
		var mounts=[];var views=[];var peak=0.0;var coast_end=0.0;var max_head_step=0.0;var previous=[]
		for i in range(2):
			var f=model.fighters[i];f.x=-40000.0 if i==0 else 40000.0;f.lane_y=0.0;f.acted=true
			var mount=Node2D.new();mount.scale=Vector2.ONE*1.6;root.add_child(mount);mounts.append(mount)
			var view=Rider.new();view.fighter=f;view.moving=true;view.mode="arena";mount.add_child(view);view.set_process(false);views.append(view)
			previous.append(Model.head_position(f)-Vector2(f.x,0))
		for tick in range(1440):
			var seconds=tick/120.0
			var boost=(seconds>=2.0 and seconds<6.0) or seconds>=10.0
			var lean=0.0 if seconds<10 else (.7 if seconds<11 else -.7)
			for i in range(2):model.set_controls(i,-.08,lean,boost,1.0/120,.43)
			model.step(1.0/120)
			for i in range(2):
				var f=model.fighters[i];var p=Model.gait_pose(f)
				var head=Model.head_position(f)-Vector2(f.x,0)
				max_head_step=maxf(max_head_step,head.distance_to(previous[i]));previous[i]=head
				if not head.is_finite() and "nonfinite" not in failures:failures.append("nonfinite")
				views[i].position=Vector2(f.x,0);mounts[i].position=Vector2(360+i*720-f.x*1.6,760)
				if tick%2==0:views[i]._process(1.0/60)
				if i==0:
					peak=maxf(peak,f.speed)
					if tick==1198:coast_end=f.speed
				if tick%2==0:trace.store_line(JSON.stringify({"coat":coat,"facing":f.direction,"seconds":seconds,"speed":f.speed,"boost":boost,"lean":f.lean,"phase":f.gait_phase,"horse_y":p.offset.y,"rider_y":p.offset.y+p.rider_offset.y,"pitch":p.rider_pitch,"head":[head.x,head.y]}))
			if tick%2==0:
				label.text="%s  %.2fs  %s  speed %.1f"%[coat,seconds,"SPUR" if boost else "COAST",model.fighters[0].speed]
				await process_frame;await RenderingServer.frame_post_draw
				if tick%8==0:root.get_texture().get_image().save_png(folder+"/%s-%04d.png"%[coat,tick/2])
		if not peak>coast_end+50:failures.append("Release did not reduce speed: "+coat)
		summary.append({"coat":coat,"peak_speed":peak,"coast_end_speed":coast_end,"max_head_step_120hz":max_head_step,"render_frames":720,"screenshots":180})
		for mount in mounts:mount.queue_free()
		await process_frame
	trace.close()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":summary,"scope":"Selected coat(s), two directions, light/heavy equipment, real model 120Hz controls/step, 60Hz RiderView with disk captures every fourth visual frame (15fps) of 12 game seconds each. Capture cost is not gameplay frame timing. Distant opponents disable contacts; staged views are not Battle camera or OS/human play."},"\t"))
	print("MOTION088 ",failures);quit(0 if failures.is_empty() else 1)
