extends SceneTree
const Fit=preload("res://scripts/visual/head_fit.gd")
const ShieldArt=preload("res://scripts/visual/shield_art.gd")
const Shield=preload("res://scripts/core/shield_geometry.gd")
const Heraldry=preload("res://scripts/visual/heraldry.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report=""
	var baseline=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
		if arg.begins_with("--baseline="): baseline=arg.trim_prefix("--baseline=")
	if report.is_empty() or baseline.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="": quit(2);return
	var original=load(baseline)
	var failures=[]
	var checked=0
	for a in range(24):
		for b in range(24):
			var regions=["eng","fr","de","it"]
			var stats={"armor_art":"%s_armor_%d"%[regions[a/6],a%6],"helmet_art":"%s_helmet_%d"%[regions[b/6],b%6]}
			if Fit.layout(stats)!=original.layout(stats): failures.append("Layout mismatch "+str(stats))
			checked+=1
			if Fit._layouts.size()>64: failures.append("Layout cache unbounded")
	for shape in ["kite","heater","targe"]:
		for design in ["bend","chevron","cross","diamond"]:
			for facing in [-1,1]:
				for scale in [.4,.7,1.0,2.1]:
					var outline=Shield.outline(shape)
					var face=ShieldArt._scaled(outline,.87*scale)
					var actual=ShieldArt.geometry(shape,design,scale,facing)
					if actual.outline!=outline or actual.face!=face or actual.charges!=Heraldry.clipped_charges(design,face,scale,facing): failures.append("Shield geometry mismatch")
					var planks=[]
					for x in [-14.0,6.0,24.0]: planks.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x,-70)*scale,Vector2(x+3,70)*scale]),face))
					if actual.planks!=planks: failures.append("Plank geometry mismatch")
					var count=ShieldArt._geometry.size()
					ShieldArt.geometry(shape,design,scale,facing)
					if ShieldArt._geometry.size()!=count or count>48: failures.append("Geometry cache keys/capacity")
	var result={"passed":failures.is_empty(),"failures":failures,"layouts":checked,"shields":96,"layout_cache":Fit._layouts.size(),"shield_cache":ShieldArt._geometry.size()}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CACHE084 ",result)
	quit(0 if failures.is_empty() else 1)
