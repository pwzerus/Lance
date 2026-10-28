extends SceneTree
## Offline engine-rendered motion study; injected inputs, not a human recording.
const UI = preload("res://scripts/ui/ui_factory.gd")
var main: Node
var samples: Array = []

func _initialize() -> void:
 call_deferred("run")

func urge(down: bool) -> void:
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = Vector2(900,400)
 event.pressed = down
 root.push_input(event,true)

func run() -> void:
 var state = root.get_node("GameState")
 if not state.save_path.contains("qa_"):
  quit(1)
  return
 state.profile = state.default_profile()
 state.profile.settings.slow_motion = false
 state.profile.settings.shake = false
 state.profile.settings.aim_cues = false
 root.size = Vector2i(960,540)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_match("arena",true)
 var battle = main.battle
 battle.set_process(false)
 if root.focus_exited.is_connected(battle._on_focus_lost):
  root.focus_exited.disconnect(battle._on_focus_lost)
 battle.match_model.phase = "charge"
 battle.match_model.fighters[1].x = 100000
 for f in battle.match_model.fighters:
  f.acted = true
  battle.match_model._cache_pose(f)
 battle.riders[1].modulate.a = 0
 var caption = UI.label(battle.hud,"程序动作观察 · 非真人录像",Vector2(420,125),27,UI.GOLD,700)
 var capture_dir="E:/GALUMU/docs/development/screenshots/v044/film01"
 DirAccess.make_dir_recursive_absolute(capture_dir)
 for frame in range(360):
  await process_frame
  if frame==15 or frame==165:
   urge(true)
  if frame==105 or frame==270:
   urge(false)
  var f = battle.match_model.fighters[0]
  battle.camera.position = Vector2(battle.world.position.x+f.x+90,500)
  battle.camera.zoom = Vector2.ONE*1.3
  battle.camera.force_update_scroll()
  battle._update_hud()
  caption.text = ("按住左键 · 催马" if f.boost else "松开左键 · 减速 / 巡航")+"   ·   "+battle.Rider.Gait.NAMES[battle.Rider.Gait.gait_index(f.speed)]
  if frame%15==0:
   samples.append({"frame":frame,"seconds":frame/30.0,"speed":f.speed,"boost":f.boost,"gait":battle.Rider.Gait.gait_index(f.speed),"body_y":battle.Model.gait_pose(f).offset.y})
  if frame in [15,35,60,90,110,150,190,240,300,350]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(capture_dir+"/frame_%03d.png"%frame)
 var file = FileAccess.open("E:/GALUMU/docs/development/logs/v044/film-01.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Godot Movie Maker fixed-30FPS offline rendering, scripted viewport hold/release, QA profile, fixed following camera; not OS input or real-time performance evidence","samples":samples},"\t"))
 file.close()
 main._close_battle()
 main.queue_free()
 await process_frame
 print("MOTION_FILM_V044_COMPLETE")
 quit()
