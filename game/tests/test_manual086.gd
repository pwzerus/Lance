extends SceneTree
var main
var trace
var started=0
func _initialize():call_deferred("run")
func run():
 var state=root.get_node("GameState")
 var folder=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
 if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
 state.profile=state.default_profile()
 root.size=Vector2i(1280,720)
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main);current_scene=main
 trace=FileAccess.open(folder+"/trace.jsonl",FileAccess.WRITE)
 started=Time.get_ticks_msec()
 var last=0
 while Time.get_ticks_msec()-started<480000:
  await process_frame
  if not is_instance_valid(main):break
  var now=Time.get_ticks_msec()
  if now-last<100:continue
  last=now
  var row={"wall_ms":now-started,"page":main.page,"fps":Engine.get_frames_per_second(),"left":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)}
  if is_instance_valid(main.battle):
   row["phase"]=main.battle.match_model.phase
   row["fighters"]=main.battle.match_model.fighters
  trace.store_line(JSON.stringify(row));trace.flush()
 quit()
