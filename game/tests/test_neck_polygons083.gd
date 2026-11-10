extends SceneTree
const Rider=preload("res://scripts/visual/rider_view.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
const Model=preload("res://scripts/core/joust_match.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"): quit(2);return
	var items=Catalogue.load_items()
	var failures=[]
	var checked=0
	var bad=0
	for region in ["eng","fr","de","it"]:
		for q in range(6):
			var stats=Catalogue.stats(items,{"horse":"horse_bay","armor":"%s_armor_%d"%[region,q],"helmet":"%s_helmet_%d"%[region,q]})
			var f=Model.new("war",stats,stats).fighters[0]
			for facing in [-1,1]:
				f.direction=facing
				for tilt in range(-10,11):
					f.lean=tilt*.1
					for reaction in range(-6,7):
						f.reaction_neck=reaction*.03
						var n=Rider.neck_geometry({},f)
						var top:Vector2=n.top
						var base:Vector2=n.base
						var across:Vector2=n.across
						var down:Vector2=n.down
						var half=float(n.half)
						var width=float(n.collar_half)
						var polygons=[PackedVector2Array([top-across*(half+1)-down*3,top+across*(half+1)-down*3,base+Vector2(width-3,-4),base+Vector2(width,0),base+Vector2(-width,0),base+Vector2(-width+3,-4)]),PackedVector2Array([top-across*half-down*3,top+across*half-down*3,base+Vector2(width-4,-4),base+Vector2(width-2,-1),base+Vector2(-width+2,-1),base+Vector2(-width+4,-4)]),PackedVector2Array([top-across*half-down*2,top-across*(half-4)-down*2,base+Vector2(-width+6,-1),base+Vector2(-width+2,-1)])]
						for i in range(polygons.size()):
							checked+=1
							if Geometry2D.triangulate_polygon(polygons[i]).is_empty():
								bad+=1
								if failures.size()<20: failures.append({"region":region,"q":q,"facing":facing,"lean":f.lean,"reaction":f.reaction_neck,"part":i,"points":str(polygons[i])})
	var data={"checked":checked,"invalid":bad,"examples":failures}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("NECK_POLYGONS083 ",checked," invalid=",bad)
	quit(0 if bad==0 else 1)
