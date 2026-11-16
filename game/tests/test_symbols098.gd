extends SceneTree
## Actual GPU stress: all 12 family cards and 25 fixed shields, translated,
## mirrored, rotating and scaled. No desktop input or player save writes.
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Shield=preload("res://scripts/visual/shield_art.gd")
const Status=preload("res://scripts/ui/combat_status098.gd")
const Lance=preload("res://scripts/visual/lance_art.gd")
var folder=""
class PennonSample extends Node2D:
	var design="bend"
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1.25,1.8))
		draw_line(Vector2(20,0),Vector2(90,0),Color("aa7845"),2)
		Lance._draw_pennon(self,{"heraldry":design},func(x,y):return Vector2(x,y),100,5)
	func _process(_dt:float) -> void: queue_redraw()
class ShieldSample extends Node2D:
	var stats={}
	var phase=0.0
	var facing=1
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,sin(phase)*.6,Vector2(facing,1))
		Shield.draw(self,stats,Vector2.ZERO,true,Color.WHITE,0,.7+.4*sin(phase),facing,.3)
		draw_set_transform(Vector2.ZERO)
	func _process(dt:float) -> void:
		phase+=dt*1.3
		queue_redraw()
func _initialize() -> void: call_deferred("run")
func capture(label:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):folder=arg.trim_prefix("--report=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or DisplayServer.get_name()=="headless" or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not "qa_" in root.get_node("GameState").save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1440,810);root.content_scale_size=Vector2i(1440,810)
	RenderingServer.set_default_clear_color(Color("20362f"))
	var stage=Control.new();root.add_child(stage)
	# Load after autoload initialization, as actual Main startup does.
	var MainScript=load("res://scripts/main.gd")
	var families=[];var shields=[];var i=0
	for item in Catalogue.load_items():
		if item.slot=="crest":
			var icon=MainScript.FamilyIcon.new();icon.design=item.stats.heraldry
			icon.position=Vector2(30+families.size()%6*230,10+int(families.size()/6)*150)
			icon.size=Vector2(130,110);stage.add_child(icon);families.append(icon)
			var label=Label.new();label.text=item.name;label.position=icon.position+Vector2(0,112);label.add_theme_font_override("font",Status.FONT);stage.add_child(label)
			var pennon=PennonSample.new();pennon.design=item.stats.heraldry;pennon.position=icon.position+Vector2(100,65);stage.add_child(pennon)
		if item.slot=="shield":
			var sample=ShieldSample.new();sample.stats=item.stats;sample.phase=i*.25;sample.facing=1 if i%2==0 else -1
			sample.position=Vector2(65+i%13*105.123,440+int(i/13)*200);stage.add_child(sample);shields.append(sample);i+=1
	var start=Time.get_ticks_msec();var next=0;var samples=[]
	while Time.get_ticks_msec()-start<12000:
		await process_frame
		var elapsed=(Time.get_ticks_msec()-start)*.001
		for n in range(families.size()):
			families[n].size=Vector2(100+sin(elapsed+n)*30,100+cos(elapsed+n)*20)
			families[n].queue_redraw()
		if elapsed>=next:
			samples.append({"seconds":elapsed,"cache":Shield._geometry.size(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
			next+=3
			await capture("symbols-"+str(next))
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"families":families.size(),"shields":shields.size(),"samples":samples,"scope":"Actual GPU frames; engine log must also be scanned for drawing errors."},"\t"))
	stage.queue_free();await process_frame;quit(0)
