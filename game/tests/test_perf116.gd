extends SceneTree
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
class Reference extends Rider:
	var paint_us116=0
	func _process(_dt:float) -> void:pass
	func _draw() -> void:
		var stamp:int=Time.get_ticks_usec()
		_draw_impact_torso()
		paint_us116=Time.get_ticks_usec()-stamp
	func _draw_impact_torso() -> void:
		for row in range(6):
			var points = PackedVector2Array()
			var uv = PackedVector2Array()
			for corner in [Vector2(0,row/6.0),Vector2(1,row/6.0),Vector2(1,(row+1)/6.0),Vector2(0,(row+1)/6.0)]:
				points.append(_torso_surface_point(Vector2(-47,-94)+corner*Vector2(94,104)))
				uv.append(corner)
			# A waist bend can make a strip concave. Its two explicit triangles
			# retain the skin even when a four-corner polygon cannot triangulate.
			for triangle in [[0,1,2],[0,2,3]]:
				var vertices=PackedVector2Array([points[triangle[0]],points[triangle[1]],points[triangle[2]]])
				if absf((vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]))<.00001: continue
				var triangle_uv=PackedVector2Array([uv[triangle[0]],uv[triangle[1]],uv[triangle[2]]])
				draw_polygon(vertices,PackedColorArray([Color.WHITE]),triangle_uv,torso_texture)
class Candidate extends Rider:
	var paint_us116=0
	func _process(_dt:float) -> void:pass
	func _draw() -> void:
		var stamp:int=Time.get_ticks_usec()
		_draw_impact_torso()
		paint_us116=Time.get_ticks_usec()-stamp
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder="";var path="";var candidate=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
	if path.is_empty() or FileAccess.file_exists(path) or DisplayServer.get_name()=="headless" or not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	if not folder.is_empty():DirAccess.make_dir_recursive_absolute(folder)
	var views=[];var canvases=[]
	for i in range(2):
		var view=SubViewport.new();view.size=Vector2i(320,320);view.transparent_bg=true;view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
		var canvas=Reference.new() if i==0 else Candidate.new() if candidate.is_empty() else load(candidate).new()
		view.add_child(canvas);canvas.position=Vector2(160,216);canvases.append(canvas)
	var items=Catalogue.load_items();var rows=[];var passed=true
	for level in [1,25,49,72]:
		var stats=Catalogue.stats(items,Campaign.level(items,level).equipment)
		for facing in [-1,1]:
			for bend in [-.55,0.0,.68,1.15]:
				for recoil in [-1.0,1.0]:
					for canvas in canvases:
						canvas.fighter={"direction":facing,"stats":stats}
						canvas.torso_texture=Rider.Art.battle_torso_for(stats,"bend",facing,false)
						canvas.torso_deform115=Transform2D(bend,Vector2(0,-25)-Vector2(0,-25).rotated(bend))
						canvas.impact_recoil=recoil;canvas.rotation=.31 if facing==1 else -1.13;canvas.scale=Vector2(1.4*facing,1.4)
						canvas.queue_redraw()
					await process_frame;await process_frame;await RenderingServer.frame_post_draw
					var a=views[0].get_texture().get_image();var b=views[1].get_texture().get_image()
					var same=a.get_data()==b.get_data()
					var nonblank:bool=a.get_used_rect().get_area()>400 and b.get_used_rect().get_area()>400
					passed=passed and same and nonblank
					rows.append({"level":level,"facing":facing,"bend":bend,"recoil":recoil,"pixels_identical":same,"nonblank":nonblank,"old_us":canvases[0].paint_us116,"new_us":canvases[1].paint_us116})
					if not folder.is_empty() and (not same or rows.size() in [1,64]):
						a.save_png(folder+"/reference_%03d.png"%rows.size());b.save_png(folder+"/candidate_%03d.png"%rows.size())
	for view in views:view.queue_free()
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"rows":rows,"scope":"Protected isolated GPU, original/candidate torso draw paths, identical textures/shader/UV/topology. Exact rendered pixel comparison; not full-game FPS or human play."},"\t"))
	quit(0 if passed else 1)
