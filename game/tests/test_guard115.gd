extends SceneTree
## Physical guard response and coverage; optional isolated GPU pose sheet.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
var failures=[]
func _initialize() -> void:call_deferred("run")

func run() -> void:
	var path="";var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if path.is_empty() or FileAccess.file_exists(path) or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty() and (DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless"):quit(2);return
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		root.size=Vector2i(1440,1000);root.content_scale_size=root.size
		RenderingServer.set_default_clear_color(Color("21382f"))
	var rows=[]
	for speed in [0.0,400.0]:
		var stages=[]
		for facing in [1,-1]:
			for guard in [0.0,.5,1.0]:
				var model=Model.new()
				var f:Dictionary=model.fighters[0]
				f.x=0.0;f.direction=facing;f.speed=speed;f.gait_moving=speed>0;f.lane_y=0.0;f.guard=.5
				model._ensure_body115(0)
				var max_step=0.0;var angle=Model.shield_angle(f)
				for tick in range(360):
					model.set_controls(0,-.08,0.0,false,1.0/120.0,guard)
					f.x+=speed*facing/120.0
					f.gait_phase+=TAU*Model.Gait.frequency(speed)/120.0
					model._advance_body115(0,1.0/120.0)
					max_step=maxf(max_step,absf(wrapf(Model.shield_angle(f)-angle,-PI,PI)))
					angle=Model.shield_angle(f)
				var desired=Model.physical_targets115(f)
				var error=Model.shield_position(f).distance_to(desired.pose.shield_center)
				var expected=desired.pose.torso_transform.get_rotation()*facing
				var angle_error=absf(wrapf(angle-expected,-PI,PI))
				var outline=PackedVector2Array()
				var frame=Model.shield_transform(f)
				for point in Model.Shield.polygon():outline.append(frame*point)
				var coverage={}
				for zone in ["head","body","flank"]:
					var centre=Model.head_position(f) if zone=="head" else Model.body_position(f) if zone=="body" else Model.flank_position(f)
					coverage[zone]=Model.Shield.segment_fraction(centre+Vector2(160*facing,0),centre,outline)>=0
				var row={"speed":speed,"facing":facing,"guard":guard,"position_error":error,"angle_error":angle_error,"max_angle_step":max_step,
					"shield_angle":angle,"coverage":coverage,"unseated":f.unseated,"shield":[frame.origin.x,frame.origin.y]}
				rows.append(row)
				if f.unseated:failures.append("Calm guard change ejects rider: "+str(row))
				if max_step>.15:failures.append("Shield snaps during ordinary guard control: "+str(row))
				if angle_error>deg_to_rad(40.0):failures.append("Shield cannot maintain its protective face: "+str(row))
				if not folder.is_empty():
					var n=stages.size();var stage=Node2D.new();root.add_child(stage)
					stage.position=Vector2(240+(n%3)*480-float(f.x)*.9,420+(n/3)*500);stage.scale=Vector2.ONE*.9
					var rider=Rider.new();rider.fighter=f;rider.moving=speed>0;stage.add_child(rider);rider.set_process(false);rider.position.x=f.x;rider._process(0)
					var label=Label.new();label.text="guard %.1f / facing %d / %.0f px/s\nerror %.1f px / %.1f deg" % [guard,facing,speed,error,rad_to_deg(angle_error)]
					label.position=Vector2(20+(n%3)*480,20+(n/3)*500);root.add_child(label)
					stages.append({"stage":stage,"label":label})
		if not folder.is_empty():
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/guard_%d.png" % int(speed))
			for entry in stages:entry.stage.free();entry.label.free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows},"\t"))
	print("GUARD115 ",failures)
	quit(0 if failures.is_empty() else 1)
