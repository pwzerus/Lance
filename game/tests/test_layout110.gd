extends "test_ux_baseline110.gd"
## Actual GUI layout sweep. Profile unlocks are explicit layout fixtures.
var overlaps=[]
func label_nodes(node:Node)->Array:
	var result=[]
	for child in node.get_children():
		if child is Label and child.is_visible_in_tree():result.append(child)
		result.append_array(label_nodes(child))
	return result
func audit_rows(node:Node,tag:String)->void:
	var labels=label_nodes(node)
	for i in range(labels.size()):
		var a:Label=labels[i]
		if a.text.is_empty():continue
		for j in range(i+1,labels.size()):
			var b:Label=labels[j]
			if b.text.is_empty() or a.get_parent()!=b.get_parent():continue
			var overlap=a.get_global_rect().intersection(b.get_global_rect())
			if overlap.size.x>3 and overlap.size.y>3:overlaps.append({"tag":tag,"a":a.text,"b":b.text,"intersection":str(overlap)})
func run()->void:
	var folder="";var compact=false;var group="levels"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
		if arg.begins_with("--group="):group=arg.trim_prefix("--group=")
		if arg=="--compact":compact=true
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile()
	state.profile.campaign_cleared=range(1,81);state.profile.settings.mouse_only=true
	root.size=Vector2i(960,540) if compact else Vector2i(1280,720);AudioServer.set_bus_mute(0,true)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	for i in range(30):await process_frame
	var rows=[]
	if group=="levels":
		for n in range(1,81):
			main.level_selected=n;main.show_levels((n-1)/10)
			for i in range(15):await process_frame
			var before=overlaps.size();audit_rows(main.screen,"level"+str(n))
			rows.append({"level":n,"labels":labels110(main.screen),"new_overlaps":overlaps.size()-before})
			if n in [6,7,8,24,55] or n%10==0 or overlaps.size()>before:await capture(folder,"level%02d"%n)
	else:
		for item in state.items:
			main.selected_slot=item.slot;main.selected_era=-1;main.selected_quality=0;main.selected_region=0;main.selected_item=item;main.show_armory()
			for i in range(18):await process_frame
			var before=overlaps.size();audit_rows(main.info_panel,str(item.id))
			# Paragraphs inside separate scroll containers may extend vertically;
			# they are correctly clipped and are not compared to outer controls.
			var title=null;var desc=null
			for node in main.info_panel.get_children():
				if node is Label:
					if node.position.y==16:title=node
					if node.position.y==112:desc=node
			if title:check(title.position.y+title.size.y<=76,"Item title overlaps historical line "+str(item.id))
			if desc:check(desc.position.y+desc.size.y<=242,"Description overlaps comparison tabs "+str(item.id))
			rows.append({"item":item.id,"new_overlaps":overlaps.size()-before})
			if overlaps.size()>before or item.id in ["eng_helmet_5","de_lance_stout_5","caparison_velvet","crest_quarterly"]:await capture(folder,str(item.id))
	check(overlaps.is_empty(),"Actual text rows overlap; inspect details")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"overlaps":overlaps,"rows":rows,"compact":compact,"scope":"Actual isolated GPU menu layout, supplied all-unlocked profile only for display sweep; no earned progression or human readability claim."},"\t"))
	await main._shutdown_and_quit();quit(0 if failures.is_empty() else 1)
