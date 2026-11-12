extends SceneTree
var failures=[]
var main
var folder=""
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
 if not ok and why not in failures:failures.append(why)
func settle()->void:
 for i in range(5):await process_frame
func prepared()->void:
 var began=Time.get_ticks_msec()
 while not main.battle.presentation_ready and Time.get_ticks_msec()-began<5000:await process_frame
 check(main.battle.presentation_ready,"Preparation timed out")
func run()->void:
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--folder="):folder=a.trim_prefix("--folder=")
 var state=root.get_node("GameState")
 if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or DisplayServer.get_name()=="headless":quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json";state.profile=state.default_profile()
 AudioServer.set_bus_mute(0,true)
 main=load("res://scenes/main.tscn").instantiate();main.smoke_mode=true;root.add_child(main);current_scene=main;main.set_process(false)
 await settle()
 var rows=[]
 for frames in range(6):
  main._start_match("arena",false)
  var old=weakref(main.battle)
  var initial_phase_time=main.battle.match_model.phase_time
  for i in range(frames):await process_frame
  if not main.battle.presentation_ready:
   check(main.battle.match_model.phase=="ready" and is_equal_approx(main.battle.match_model.phase_time,initial_phase_time),"Countdown advanced during preparation")
   for rider in main.battle.riders:check(not rider.is_processing(),"Rider animation enabled before presentation was ready")
  main._close_battle();main.show_home();await settle()
  check(old.get_ref()==null,"Cancelled preparation retained battle at slice "+str(frames))
  rows.append({"cancel_after_frames":frames,"released":old.get_ref()==null})
 # Focus loss and Esc must already work before the HUD exists.
 for trigger in ["focus","escape"]:
  main._start_match("arena",false)
  main.battle.autoplay=false
  if trigger=="focus":main.battle._on_focus_lost()
  else:
   var key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.physical_keycode=KEY_ESCAPE;key.pressed=true;root.push_input(key,true)
  await prepared()
  check(main.battle.paused and paused,"Preparation lost pause request: "+trigger)
  main.battle._toggle_pause();main._close_battle();main.show_home();await settle()
 # Hidden construction must stop, then require explicit Resume after restoring.
 main._start_match("war",false)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
 await settle()
 var count=main.battle.riders.size()
 var begun=Time.get_ticks_msec()
 while Time.get_ticks_msec()-begun<3000:await process_frame
 check(main.battle.riders.size()==count,"Hidden preparation kept building")
 check(not main.battle.presentation_ready,"Hidden preparation completed")
 check(main.battle.match_model.phase=="ready","Hidden match advanced")
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 await prepared()
 check(main.battle.paused and paused,"Restored preparation lost explicit Resume")
 main.battle._toggle_pause()
 check(not paused and not main.battle.paused,"Resume failed")
 await settle()
 check(main.battle.riders.size()==2 and is_instance_valid(main.battle.hud),"Incomplete battle presentation")
 check(main.battle.preparation_layer==null,"Preparation overlay remained")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/restored.png")
 # Restart through the production event, not only direct construction.
 var references=[]
 for i in range(12):
  references.append(weakref(main.battle));main.battle.replay_requested.emit();await prepared();await settle()
 check(AudioServer.bus_count==5,"Replays grew audio buses")
 for ref in references:check(ref.get_ref()==null,"Restart retained old battle")
 check(state.profile.matches==0,"Cancelled/restarted matches gave rewards")
 rows.append({"replays":references.size(),"buses":AudioServer.bus_count,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Actual GPU staging, 6 cancellation boundaries, minimized preparation/explicit resume and 12 real replay events; isolated QA, no OS input."},"\t"))
 print("PREPARATION088 ",failures)
 main.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
