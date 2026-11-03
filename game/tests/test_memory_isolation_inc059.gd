extends SceneTree
## Isolation harness: no input injection, no screenshots, no retained sample array.
var main: Node
var output: FileAccess
var scenario = "full"
var duration = 240.0
var started = 0
func _initialize() -> void:
 call_deferred("run")
func sample() -> void:
 var row = {"seconds":(Time.get_ticks_msec()-started)/1000.0,"scenario":scenario,"frames":Engine.get_frames_drawn(),"static_bytes":OS.get_static_memory_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}
 output.store_line(JSON.stringify(row))
 output.flush()
 print("ISOLATION ",JSON.stringify(row))
func run() -> void:
 var report = "E:/GALUMU/docs/development/logs/inc059b/isolation.jsonl"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--isolation="): scenario=arg.trim_prefix("--isolation=")
  if arg.begins_with("--duration="): duration=clampf(float(arg.trim_prefix("--duration=")),5,540)
  if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
 if not scenario in ["full","bare","freeze-rider","without-rider","without-ui"]:
  push_error("Unknown isolation scenario")
  quit(2)
  return
 var state = root.get_node("GameState")
 if not state.save_path.contains("qa_"):
  quit(2)
  return
 if FileAccess.file_exists(report):
  push_error("Use a fresh report path")
  quit(2)
  return
 output=FileAccess.open(report,FileAccess.WRITE)
 if output==null:
  quit(2)
  return
 if scenario!="bare":
  state.profile=state.default_profile()
  # Same decorated equipment as the incident's desktop observation fixture.
  state.profile.equipped.armor="de_armor_3"
  state.profile.equipped.helmet="it_helmet_3"
  main=load("res://scenes/main.tscn").instantiate()
  root.add_child(main)
  await process_frame
  await process_frame
  if scenario=="freeze-rider": main.preview.set_process(false)
  if scenario=="without-rider":
   main.preview.queue_free()
   main.preview=null
  if scenario=="without-ui": main.screen.visible=false
 started=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<duration*1000:
  await create_timer(5.0,true,false,true).timeout
  sample()
 if is_instance_valid(main): main.queue_free()
 await process_frame
 await create_timer(.2,true,false,true).timeout
 output.close()
 quit()
