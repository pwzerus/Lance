extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var folder=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--folder="): folder=a.trim_prefix("--folder=")
 var state=root.get_node("GameState")
 if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile();state.profile.settings.sound=false
 root.size=Vector2i(1280,720)
 var main=load(get_script().resource_path.get_base_dir()+"/profile_main085.gd").new();root.add_child(main)
 await process_frame;await RenderingServer.frame_post_draw
 await create_timer(.5).timeout
 var rows=[]
 for slot in ["armor","helmet","armor"]:
  main.selected_slot=slot;main.selected_item={};main.costs={}
  var t=Time.get_ticks_usec();main.show_armory();var sync=(Time.get_ticks_usec()-t)/1000.0
  var frames=[]
  for i in range(45):
   await process_frame
   var now=Time.get_ticks_usec();frames.append((now-t)/1000.0);t=now
  rows.append({"slot":slot,"sync_ms":sync,"costs":main.costs.duplicate(),"frames_ms":frames})
  main.show_home();await create_timer(.5).timeout
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
 print("PROFILE085 ",JSON.stringify(rows))
 main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
