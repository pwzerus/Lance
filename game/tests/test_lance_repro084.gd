extends SceneTree
const Lance=preload("res://scripts/visual/lance_art.gd")
class CaseDrawer extends Node2D:
	var fixture: Dictionary
	func _draw() -> void:
		Lance.draw(self,fixture.stats,fixture.hand,fixture.angle,fixture.length,false,fixture.recoil,"war",Lance.Layer.REAR)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024": quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var fixture={"stats":{"lance_quality":3,"lance_type":"light"},"hand":Vector2(76.83026,-267.2264),"angle":-2.23117637634277,"length":217.475219726563,"recoil":-.718263030052185}
	var upper=[]
	var lower=[]
	for i in range(25):
		var d=lerpf(-67,0,i/24.0)
		var radius=Lance.radius(fixture.stats,d,fixture.length)
		upper.append(Vector2(d,-radius))
		lower.push_front(Vector2(d,radius))
	var found=false
	for x in range(-40,41):
		for y in range(-40,41):
			fixture.hand=Vector2(76.83026+x*.00000762939453125,-267.2264+y*.000030517578125)
			var points=Lance._mapped(upper+lower,fixture.hand,fixture.angle,fixture.length,false,fixture.recoil)
			if Geometry2D.triangulate_polygon(points).is_empty():
				fixture.points=[]
				for p in points: fixture.points.append([p.x,p.y])
				found=true
				break
		if found: break
	if not found: push_error("No exact fixture found");quit(1);return
	root.size=Vector2i(640,480)
	var canvas=CaseDrawer.new()
	canvas.fixture=fixture
	canvas.position=Vector2(100,600)
	canvas.scale=Vector2.ONE*2
	root.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/shaft.png")
	fixture.hand=[fixture.hand.x,fixture.hand.y]
	fixture.original_triangulation_fails=found
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(fixture,"\t"))
	print("REPRO084 original triangulation fails ",found)
	quit()
