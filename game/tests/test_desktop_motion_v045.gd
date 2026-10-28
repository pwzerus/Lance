extends SceneTree
## Isolated observational window. Generates no synthetic input events.
var main: Node
var battle: Node

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var state = root.get_node("GameState")
 if not state.save_path.contains("qa_"):
  quit(1)
  return
 state.save_path = "user://qa_motion_desktop_v045.json"
 state.backup_path = "user://qa_motion_desktop_v045.backup.json"
 state.profile = state.default_profile()
 state.profile.settings.slow_motion = false
 state.profile.settings.shake = false
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_match("arena",true)
 battle = main.battle
 battle.set_process(false)
 battle.match_model.fighters[0].x = -2000
 battle.match_model.fighters[1].x = 100000
 for f in battle.match_model.fighters:
  f.acted = true
  battle.match_model._cache_pose(f)
 battle.riders[1].modulate.a = 0
 var audit = load("res://scripts/core/desktop_input_audit.gd").new()
 audit.main = main
 audit.log_path = "E:/GALUMU/docs/development/logs/v045/desktop-04.jsonl"
 main.add_child(audit)
 root.title = "GALUMU v045 QA Motion — hold/release observation"
 var start = Time.get_ticks_msec()
 while is_instance_valid(main) and Time.get_ticks_msec()-start<300000:
  await process_frame
  var f = battle.match_model.fighters[0]
  if f.x>4000:
   f.x -= 6000
   battle.riders[0].position.x -= 6000
   for i in range(4):
    if is_finite(battle.riders[0].planted_feet[i]):
     battle.riders[0].planted_feet[i] -= 6000
    if battle.riders[0].swing_starts[i].is_finite():
     battle.riders[0].swing_starts[i].x -= 6000
    if battle.riders[0].last_feet[i].is_finite():
     battle.riders[0].last_feet[i].x -= 6000
   battle.match_model._cache_pose(f)
  battle.camera.position = Vector2(battle.world.position.x+f.x+90,500)
  battle.camera.zoom = Vector2.ONE*1.3
  battle.camera.force_update_scroll()
  battle._update_hud()
 main._close_battle()
 main.queue_free()
 await process_frame
 await create_timer(.4,true,false,true).timeout
 quit()


