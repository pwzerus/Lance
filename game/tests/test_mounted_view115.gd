extends SceneTree
## Actual background rendering of the shared mounted-to-fallen body.
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
const Body=preload("res://scripts/visual/rider_body114.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var folder=""
	var force=80.0
	var limp=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--force="):force=float(arg.trim_prefix("--force="))
		if arg=="--limp":limp=true
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,1000)
	root.content_scale_size=root.size
	RenderingServer.set_default_clear_color(Color("21382f"))
	var scenes=[]
	for facing in [1,-1]:
		for zone in ["head","body","flank"]:
			var index=scenes.size()
			var viewport=SubViewport.new()
			viewport.size=Vector2i(480,500)
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var image=TextureRect.new()
			image.texture=viewport.get_texture()
			image.position=Vector2((index%3)*480,(index/3)*500)
			image.size=Vector2(480,500)
			root.add_child(image)
			var label=Label.new()
			label.text="%s / %d / %.0f%s" % [zone,facing,force," limp" if limp else ""]
			label.position=image.position+Vector2(12,12)
			root.add_child(label)
			var world=Node2D.new();viewport.add_child(world)
			world.position=Vector2(240,420);world.scale=Vector2.ONE*.88
			var line=Line2D.new();line.points=PackedVector2Array([Vector2(-5000,12),Vector2(5000,12)]);line.width=2;line.default_color=Color("a99664");world.add_child(line)
			var model=Model.new()
			var f:Dictionary=model.fighters[0]
			f.x=0.0;f.direction=facing;f.lane_y=0.0;f.speed=380.0;f.gait_moving=true;f.guard=.5;f.aim=-.08
			model._ensure_body115(0)
			var rider=Rider.new();rider.fighter=f;rider.moving=true;world.add_child(rider);rider.set_process(false)
			scenes.append({"model":model,"f":f,"rider":rider,"world":world,"fall":null,"zone":zone,"detach":-1})
	var results=[]
	for tick in range(721):
		for scene in scenes:
			var f:Dictionary=scene.f
			if tick==120:
				var body=scene.model.bodies115[0].body
				var point=body.p[Body.HEAD] if scene.zone=="head" else body.pelvis_x if scene.zone=="flank" else body.x
				scene.model.bodies115[0].queue_hit({"zone":scene.zone,"position":point,"direction":-int(f.direction),"impulse":force})
				if limp:f.unconscious=true;f.ko=true
			f.x+=float(f.speed)*int(f.direction)/120.0
			f.gait_phase+=TAU*Model.Gait.frequency(float(f.speed))/120.0
			if scene.fall==null:
				scene.model._advance_body115(0,1.0/120.0)
				if scene.model.bodies115[0].detached:
					scene.detach=tick
					var payload=scene.model.take_body115(0)
					var actor=Fallen.new();scene.world.add_child(actor)
					actor.setup(f,{"zone":scene.zone,"direction":-int(f.direction),"impulse":force,"ko_reason":"impact"},scene.rider,payload)
					actor.set_process(false);actor.visual.set_process(false);actor.far_leg.set_process(false)
					scene.fall=actor
			else:scene.fall.advance(1.0/120.0)
			scene.rider.position=Vector2(f.x,0)
			scene.rider._process(1.0/120.0)
			scene.world.position.x=240-(scene.fall.position.x if scene.fall!=null else float(f.x))*.88
		if tick in [0,119,126,135,150,180,240,360,600,720]:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/t%03d.png" % tick)
	for scene in scenes:results.append({"facing":scene.f.direction,"zone":scene.zone,"detach_tick":scene.detach,"settled":scene.fall.settled if scene.fall!=null else false})
	FileAccess.open(folder+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit(0)
