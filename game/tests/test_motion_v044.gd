extends SceneTree
const Model = preload("res://scripts/core/joust_match.gd")
const Gait = preload("res://scripts/visual/horse_gait.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
var failures: Array[String] = []
var trace: Array = []
var ranges: Array = []

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 if not value and message not in failures:
  failures.append(message)
  push_error(message)

func mouse(point: Vector2, down: bool) -> void:
 var event = InputEventMouseButton.new()
 event.position = point
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = down
 root.push_input(event,true)

func run() -> void:
 var state = root.get_node("GameState")
 if not state.save_path.contains("qa_"):
  quit(1)
  return
 state.profile = state.default_profile()
 state.profile.settings.sound = false
 state.profile.settings.slow_motion = false
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_match("arena",true)
 await process_frame
 var battle = main.battle
 battle.set_physics_process(false)
 # A click during the countdown must not become a two-second spur later.
 mouse(Vector2(900,420),true)
 mouse(Vector2(900,420),false)
 battle._physics_process(1.0/120)
 check(not battle.match_model.fighters[0].boost,"Released countdown click must not queue acceleration")
 battle.match_model.phase = "charge"
 for f in battle.match_model.fighters:
  f.acted = true
  f.x *= 3
 var fighter = battle.match_model.fighters[0]
 check(fighter.speed==0,"Charge begins from rest, not instant cruising speed")
 mouse(Vector2(900,420),true)
 for tick in range(240):
  battle._physics_process(1.0/120)
  if tick in [0,11,29,59,119,179,239]:
   trace.append({"tick":tick+1,"speed":fighter.speed,"boost":fighter.boost})
  if tick==0:
   check(fighter.speed>0 and fighter.speed<10,"First held tick responds without jumping to a gallop")
 check(fighter.speed>475 and fighter.boost,"Holding must reach and maintain gallop from rest within two seconds")
 var before = float(fighter.speed)
 mouse(Vector2(900,420),false)
 battle._physics_process(1.0/120)
 check(not fighter.boost and fighter.speed<before,"Releasing must stop urging and start slowing on the next physics tick")
 var first_release_speed = float(fighter.speed)
 for tick in range(240):
  var old = float(fighter.speed)
  battle._physics_process(1.0/120)
  check(fighter.speed<=old+.001,"Released speed cannot rise")
 check(is_equal_approx(fighter.speed,Model.TROT_SPEED),"Release returns smoothly to automatic cruise within two seconds")
 trace.append({"release_first":first_release_speed,"release_end":fighter.speed})
 var point = battle.guard_buttons[0].get_global_rect().get_center()
 mouse(point,true)
 battle._physics_process(1.0/120)
 check(not fighter.boost,"Clicking shield must not urge the horse")
 mouse(point,false)
 mouse(Vector2(900,420),true)
 battle._on_focus_lost()
 check(not battle.mouse_held and battle.paused,"Focus loss cancels physical hold and pauses")
 mouse(Vector2(900,420),false)
 main._close_battle()
 main.queue_free()
 await process_frame
 # Body movement must distinguish actual gaits while preserving ground support.
 for speed in [110.0,210.0,340.0,480.0]:
  var low = INF
  var high = -INF
  var min_contacts = 4
  var max_contacts = 0
  var flight = 0
  for sample in range(240):
   var phase = TAU*sample/240.0
   var pose = Gait.body(phase,speed,true)
   low = minf(low,pose.offset.y)
   high = maxf(high,pose.offset.y)
   var contacts = 0
   for leg_index in range(4):
    var leg = Gait.leg(leg_index,phase,speed,true)
    check(leg.foot.y<=Gait.GROUND+.01,"Hoof must not penetrate ground")
    check(absf(leg.hip.distance_to(leg.knee)-Gait.UPPER)<.01,"Upper limb does not stretch")
    check(absf(leg.knee.distance_to(leg.ankle)-Gait.LOWER)<.05,"Lower limb does not stretch")
    if leg.contact:
     contacts += 1
     check(absf(leg.foot.y-Gait.GROUND)<.01,"Supporting hoof must be on ground")
   min_contacts = mini(min_contacts,contacts)
   max_contacts = maxi(max_contacts,contacts)
   if contacts==0:
    flight += 1
  ranges.append({"speed":speed,"body_range":high-low,"min_contacts":min_contacts,"max_contacts":max_contacts,"flight_samples":flight})
  if speed==110:
   check(min_contacts>=2,"Walk must keep two or more supporting feet")
  if speed==480:
   check(flight>10,"Gallop must have a readable suspension period")
 for i in range(1,ranges.size()):
  check(ranges[i].body_range>ranges[i-1].body_range+2,"Gait tiers must have visibly distinct trunk amplitudes")
 # Both anatomical arms use the same lengths and local shoulder convention.
 var model = Model.new()
 var f = model.fighters[0]
 f.x = 0
 f.speed = 480
 f.gait_moving = true
 for direction in [-1,1]:
  f.direction = direction
  for lean in [-1.0,0.0,1.0]:
   f.lean = lean
   for guard in [0.0,.43,1.0]:
    f.guard = guard
    for sample in range(16):
     f.gait_phase = TAU*sample/16
     var pivot = Model.HIP+Model.saddle_offset(f)
     var angle = Model.pose_angle(f)
     var hand = (Model.hand_position(f)-Vector2(f.x,f.lane_y))*Vector2(direction,1)
     var shoulder = pivot+Rider.LANCE_SHOULDER.rotated(angle)
     var elbow = Rider.arm_elbow(shoulder,hand,Rider.ARM_UPPER,Rider.ARM_LOWER)
     check(absf(elbow.distance_to(hand)-Rider.ARM_LOWER)<.05,"Right lance arm remains reachable")
     var shield_local = ((Model.shield_position(f)-Vector2(f.x,f.lane_y))*Vector2(direction,1)-pivot).rotated(-angle)
     var shield_hand = shield_local+Vector2(-7,9)
     var shield_elbow = Rider.arm_elbow(Rider.SHIELD_SHOULDER,shield_hand,Rider.ARM_UPPER,Rider.ARM_LOWER)
     check(absf(shield_elbow.distance_to(shield_hand)-Rider.ARM_LOWER)<.05,"Left shield arm remains reachable")
     var drawn = Rider.mirrored_transform(pivot,angle,direction)*Vector2(0,-111)+Vector2(f.x,f.lane_y)
     check(drawn.distance_to(Model.head_position(f))<.01,"Moving rider and real head collision share their anchor")
 var result = {"passed":failures.is_empty(),"failures":failures,"speed_trace":trace,"gaits":ranges,"scope":"engine injected hold/release, cancelled countdown, UI/focus, real model movement, gait support and anatomical arm anchors; not human play"}
 var file = FileAccess.open("E:/GALUMU/docs/development/logs/v044/motion-controls-01.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"\t"))
 file.close()
 print("MOTION_V044 "+JSON.stringify(result))
 await create_timer(.3,true,false,true).timeout
 quit(0 if failures.is_empty() else 1)
