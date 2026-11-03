extends SceneTree
var main: Node
var rows: Array = []
var report_path = "E:/GALUMU/docs/development/logs/inc059/soak.json"
func _initialize() -> void:
 call_deferred("run")
func sample(stage: String) -> void:
 var row = {"stage":stage,"seconds":Time.get_ticks_msec()/1000.0,"static":OS.get_static_memory_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"frames":Engine.get_frames_drawn()}
 rows.append(row)
 print("MEMORY_QA ",JSON.stringify(row))
 var file = FileAccess.open(report_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "))
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--memory-report="):
   report_path = arg.trim_prefix("--memory-report=")
 if not root.get_node("GameState").save_path.contains("qa_"):
  quit(2)
  return
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 for i in range(12):
  await create_timer(2.0,true,false,true).timeout
  sample("home_%d" % i)
 for i in range(4):
  main.show_armory()
  await create_timer(1.0,true,false,true).timeout
  main._start_match("arena" if i%2==0 else "war",true)
  main.battle.autoplay = true
  for j in range(12):
   await create_timer(1.0,true,false,true).timeout
   sample("battle_%d_%d" % [i,j])
  main._close_battle()
  main.show_home()
  await create_timer(1.0,true,false,true).timeout
  sample("return_%d" % i)
 main.queue_free()
 await process_frame
 await create_timer(.2).timeout
 quit()
