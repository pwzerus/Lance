extends "test_fall_v057.gd"
## Derive the boot's visible alpha hull from the atlas, independently of the
## physics envelope. The old endpoint circles missed the stretched toe.
func visible_boot_hull113() -> PackedVector2Array:
	var image=Rider.ATLAS.get_image()
	var points=PackedVector2Array()
	for y in range(736,933):
		var first=-1;var last=-1
		for x in range(744,892):
			if image.get_pixel(x,y).a>=16.0/255:
				if first<0:first=x
				last=x
		if first>=0:
			for x in [first,last]:
				for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:points.append(Vector2(x,y)+offset)
	return Geometry2D.convex_hull(points)

func boot_point113(pixel:Vector2,pose:Dictionary)->Vector2:
	var source=Vector2(-19,114)
	var current:Vector2=pose.ankle-pose.knee
	var offset=pixel-Vector2(823,748)
	var axis=current.normalized();var normal=Vector2(-axis.y,axis.x)
	return pose.knee+axis*offset.dot(source.normalized())*current.length()/source.length()+normal*offset.dot(Vector2(-source.y,source.x).normalized())*.29

func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in root.get_node("GameState").save_path:quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	var hull=visible_boot_hull113();var rows=[]
	for facing in [-1,1]:
		for zone in ["head","body","flank"]:
			var stage=Node2D.new();root.add_child(stage)
			var actor=make_actor(stage,zone,facing,false,zone=="flank")
			var worst=0.0;var at=0.0;var worst_side=""
			for tick in range(481):
				for side in ["near","far"]:
					for pixel in hull:
						var point=(boot_point113(pixel,actor.visual.detached_legs[side])*Vector2(facing,1)).rotated(actor.rotation)+actor.position
						var penetration=point.y-actor.ground_y
						if penetration>worst:worst=penetration;at=actor.age;worst_side=side
				if tick<480:actor.advance(1.0/120)
			check(worst<.03,"Visible boot must remain above the ground: "+zone+str(facing),{"depth":worst,"time":at,"side":worst_side})
			check(actor.settled and actor.support_gap()<14.0,"Boot clearance must preserve stable torso support")
			rows.append({"zone":zone,"facing":facing,"maximum_visible_penetration":worst,"time":at,"side":worst_side,"settled":actor.settled,"support_gap":actor.support_gap()})
			remove_stage(stage)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"atlas_alpha_threshold":16,"source_hull":vector_rows(hull),"scope":"Atlas alpha-derived boot silhouette transformed by the actual skin's measured joints, checked through six 120Hz falls. No edited texture or human naturalness claim."},"\t"))
	print("BOOT113 ",failures);quit(0 if failures.is_empty() else 1)
