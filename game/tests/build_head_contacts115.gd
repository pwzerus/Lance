extends SceneTree
## Offline contact hulls from the exact battle sprites. No per-frame image read.
func _initialize() -> void:
	if not "--test-profile" in OS.get_cmdline_user_args():quit(2);return
	var source="res://assets/art/battle090/helmet/"
	var items={}
	for name in DirAccess.get_files_at(source):
		if not name.ends_with(".png"):continue
		var image=Image.load_from_file(source+name)
		var points=PackedVector2Array()
		for y in range(image.get_height()):
			var left=-1;var right=-1
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a>=.1:
					if left<0:left=x
					right=x
			if left<0:continue
			for p in [Vector2(left,y),Vector2(left,y+1),Vector2(right+1,y),Vector2(right+1,y+1)]:points.append(p)
		var hull=Geometry2D.convex_hull(points)
		var normalized=[]
		for i in range(hull.size()-1):normalized.append([hull[i].x/image.get_width(),hull[i].y/image.get_height()])
		items[name.get_basename()]={"sha256":FileAccess.get_sha256(source+name),"points":normalized}
	if items.size()!=24:push_error("Expected all 24 existing helmet sprites");quit(1);return
	FileAccess.open("res://data/head_contacts_v115.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source,"alpha_threshold":.1,"helmets":items},"\t"))
	print("Generated exact convex contact outlines for ",items.size()," battle helmets")
	quit(0)
