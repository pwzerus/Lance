extends "test_icons085.gd"
const Compare=preload("res://scripts/ui/equipment_comparison.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var folder=""
var main
var rows=[]
func check(ok:bool,message:String) -> void:
	if not ok and message not in failures:failures.append(message)
func click(button:Button) -> void:
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=button.get_global_rect().get_center()
	root.push_input(e,true);e=e.duplicate();e.pressed=false;root.push_input(e,true)
func paragraphs(container:Node) -> Array:
	var result=[]
	for node in container.get_children():
		if node is Label:result.append(node.text)
	return result
func run() -> void:
	var compact=false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
		if a=="--compact":compact=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.load_profile();state.profile.settings.sound=false
	var original=state.profile.equipped.duplicate(true)
	var profile_snapshot=JSON.stringify(state.profile)
	for item in state.items:
		var summary=Compare.summarize(state.items,original,item)
		var replacement=original.duplicate();replacement[item.slot]=item.id
		check(summary.after==Catalogue.stats(state.items,replacement),"Comparison differs from actual equipped stats: "+item.id)
		check(summary.lines.size()>0 and summary.lines.size()<=5,"Unreadable comparison length: "+item.id)
		check(not ("nan" in str(summary) or "inf" in str(summary)),"Nonfinite comparison: "+item.id)
		if item.id=="de_armor_5":
			check(summary.changes.armor>0 and summary.changes.fatigue>0 and summary.changes.lance_handling<0 and summary.changes.shield_handling<0,"Heavy armor preview failed to show its actual costs")
		if item.slot=="crest":check(summary.changes.fatigue==0 and summary.changes.loaded_speed==0,"Crest invented physical changes")
		if item.slot=="horse":
			var art=load("res://scripts/visual/equipment_art.gd")
			var skin=load("res://scripts/visual/horse_skin.gd")
			check(art.item_icon(item)==skin.coat_texture(item.stats.horse_coat),"Horse icon differs from its actual coat: "+item.id)
		rows.append({"id":item.id,"lines":summary.lines,"changes":summary.changes})
	check(JSON.stringify(state.profile)==profile_snapshot,"Comparison mutated player profile")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(960,540) if compact else Vector2i(1280,720)
		main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
		await settle(.3)
		for id in ["de_armor_5","de_helmet_5","de_lance_stout_5","de_shield_5","horse_courser","horse_grey","horse_cob","caparison_velvet","crest_bend"]:
			var item=Catalogue.find(state.items,id)
			check(not item.is_empty(),"Missing test item "+id)
			main.selected_slot=item.slot;main.selected_era=-1;main.selected_item=item;main.show_armory()
			await settle(.65)
			var overview:ScrollContainer=main.info_panel.get_node("ComparisonScroll")
			var detail:ScrollContainer=main.info_panel.get_node("ProvenanceScroll")
			check(overview.visible and not detail.visible,"Overview is not default")
			var expected=Compare.summarize(state.items,original,item)
			var actual=paragraphs(overview.get_child(0))
			for line in expected.lines:check(line in actual,"Deferred comparison missing: "+line)
			check(overview.get_child(0).size.x<=overview.size.x,"Comparison overflowed horizontally")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+id+"-compare.png")
			click(main.info_panel.get_node("DetailsTab"));await settle(.35)
			check(detail.visible and not overview.visible,"Details tab click not effective")
			var details=paragraphs(detail.get_child(0))
			check("考据："+str(item.source) in details,"Historical source missing after tab activation")
			if not str(item.get("historical_note","")).is_empty():check(item.historical_note in details,"Detailed history missing")
			detail.scroll_vertical=9999;await settle(.1)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+id+"-source.png")
			click(main.info_panel.get_node("CompareTab"));await settle(.1)
			check(overview.visible and not detail.visible,"Compare tab failed to restore")
			check(JSON.stringify(state.profile)==profile_snapshot,"Inspecting gear mutated player profile")
		# Rapidly change selection with deferred comparison/source jobs pending.
		for item in state.items.slice(0,20):
			main.selected_item=item;main._update_item_panel()
		main.show_home();await settle(.3)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"items":rows,"rendered":DisplayServer.get_name()!="headless","scope":"Exact current-loadout comparison and real isolated GPU menu; viewport tab clicks, not OS or human assessment."},"\t"))
	print("COMPARE087 ",failures)
	if is_instance_valid(main):main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:quit(0 if failures.is_empty() else 1)
