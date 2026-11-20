extends "test_fit086.gd"
## Reuse the actual moving RiderView and bounded viewport. Contact sheets
## are evidence for inspection, not an automatic declaration of good art.
const Campaign108=preload("res://scripts/core/campaign.gd")
const Appearance108=preload("res://scripts/core/character_appearance.gd")
var caption:Label
func fit_sheet()->void:
	caption=Label.new();caption.position=Vector2(258,26);caption.z_index=100;caption.add_theme_font_size_override("font_size",13);root.add_child(caption)
	if selection=="identities":await identity_sheets()
	elif selection=="mixed":await mixed_sheets()
	elif selection=="faces":await face_sheets()
	else:failures.append("Unknown ART108 selection")
	caption.queue_free();await process_frame
func sample(stats:Dictionary,facing:int,lean:float,title:String)->Image:
	var rider=new_rider(stats,facing)
	rider.fighter.lean=lean
	rider.position=Vector2(384,130)-Model.head_position(rider.fighter)
	caption.text=title
	var frame=await capture(rider)
	var crop=frame.get_region(Rect2i(256,25,256,220))
	var pose=Rider.arm_pose(rider.fighter);var neck=Rider.neck_geometry(pose,rider.fighter)
	if not Vector2(neck.base).is_finite() or not Vector2(neck.top).is_finite():failures.append("Nonfinite neck "+title)
	trace.append({"case":title,"facing":facing,"lean":lean,"appearance":stats.get("appearance",{}),"neck_length":Vector2(neck.base).distance_to(neck.top)})
	rider.queue_free();await process_frame
	return crop
func identity_sheets()->void:
	# Same open helmet/chest deliberately isolates faces from equipment. These
	# are campaign identities in a comparison outfit, not actual level kits.
	for facing in [1,-1]:
		for page in range(4):
			var sheet=Image.create_empty(4*256,5*220,false,Image.FORMAT_RGBA8)
			for index in range(20):
				var n=page*20+index+1;var level=Campaign108.level(items,n)
				var stats=Catalogue.stats(items,{"armor":"eng_armor_0","helmet":"fr_helmet_0","horse":"horse_bay"})
				stats.appearance=level.appearance.duplicate()
				var frame=await sample(stats,facing,0.0,"ID %02d / %s"%[n,"R" if facing==1 else "L"])
				sheet.blit_rect(frame,Rect2i(0,0,256,220),Vector2i((index%4)*256,(index/4)*220))
			sheet.save_png(folder+"/identity-%d-%d.png"%[page,facing])
func mixed_sheets()->void:
	var armours=["eng_armor_0","it_armor_0","fr_armor_4","it_armor_5"]
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			var helmet="%s_helmet_%d"%[region,tier]
			var sheet=Image.create_empty(4*256,6*220,false,Image.FORMAT_RGBA8)
			for column in range(armours.size()):
				var row=0
				for facing in [1,-1]:
					for lean in [1.0,0.0,-1.0]:
						var stats=Catalogue.stats(items,{"armor":armours[column],"helmet":helmet,"horse":"horse_bay"})
						stats.appearance={"face_shape":column,"skin":(tier+column)%6,"brows":tier%4,"beard":(tier+column)%5,"eyes":tier%5,"hair":column}
						var title="%s / %s / %d"%[helmet,armours[column],facing]
						var frame=await sample(stats,facing,lean,title)
						sheet.blit_rect(frame,Rect2i(0,0,256,220),Vector2i(column*256,row*220));row+=1
				sheet.save_png(folder+"/mixed-"+helmet+".png")
func face_sheets()->void:
	# Every open-faced helmet, all six palettes and four skull outlines. Beard
	# and gaze vary too, without changing the underlying fitting rectangle.
	for region in ["eng","fr","de","it"]:
		for tier in range(6):
			var helmet="%s_helmet_%d"%[region,tier]
			var base=Catalogue.stats(items,{"armor":region+"_armor_0","helmet":helmet,"horse":"horse_bay"})
			if not Rider.Art.descriptor(base,"helmet").get("open_face",false):continue
			for facing in [1,-1]:
				var sheet=Image.create_empty(4*256,6*220,false,Image.FORMAT_RGBA8)
				for skin in range(6):
					for shape in range(4):
						var stats=base.duplicate(true)
						stats.appearance={"face_shape":shape,"skin":skin,"brows":shape,"beard":(skin+shape)%5,"eyes":skin%5,"hair":shape}
						var frame=await sample(stats,facing,0.0,"%s / face%d skin%d"%[helmet,shape,skin])
						sheet.blit_rect(frame,Rect2i(0,0,256,220),Vector2i(shape*256,skin*220))
				sheet.save_png(folder+"/faces-%s-%d.png"%[helmet,facing])
