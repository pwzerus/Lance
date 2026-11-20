extends "test_fit086.gd"
## Full mounted outfit instead of face-only crop. Reuses production atlas,
## skin, shield and lance renderers; one bounded contact sheet at a time.
func fit_sheet()->void:
	var caption=Label.new();caption.position=Vector2(134,75);caption.z_index=100;caption.add_theme_font_size_override("font_size",14);root.add_child(caption)
	for style in ["linen","wool","velvet"]:
		for facing in [1,-1]:
			var sheet=Image.create_empty(3*500,4*350,false,Image.FORMAT_RGBA8)
			var index=0
			for family in Heraldry.ARMS:
				var stats=Catalogue.stats(items,{"helmet":"fr_helmet_0","armor":"eng_armor_1","horse":"horse_bay","caparison":"caparison_"+style,"crest":"crest_"+family,"shield":"fr_shield_1","lance":"eng_lance_long_5"})
				stats.horse_coat=["bay","black","grey","flaxen"][index%4]
				var rider=new_rider(stats,facing);rider.scale=Vector2.ONE*.85;rider.position=Vector2(384,360);rider.fighter.lean=0.0
				caption.text="%s / %s / %d"%[style,family,facing]
				var frame=await capture(rider)
				sheet.blit_rect(frame,Rect2i(134,75,500,350),Vector2i((index%3)*500,(index/3)*350))
				trace.append({"cloth":style,"family":family,"facing":facing,"coat":stats.horse_coat,"shield":stats.shield_heraldry})
				rider.queue_free();await process_frame;index+=1
			sheet.save_png(folder+"/cloth-%s-%d.png"%[style,facing])
	caption.queue_free();await process_frame
