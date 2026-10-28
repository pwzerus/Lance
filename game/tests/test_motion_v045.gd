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
 # Leaving an exchange is presentation movement, with combat inactive.
 for mode_value in ["arena","war"]:
  var leaving = Model.new(mode_value)
  leaving.phase = "turn"
  leaving.phase_time = .7
  for f in leaving.fighters:
   f.speed = 480.0
   f.gait_moving = true
   f.hp = 73.0
   f.acted = true
  var old_x = float(leaving.fighters[0].x)
  var old_phase = float(leaving.fighters[0].gait_phase)
  leaving.step(.25)
  check(leaving.fighters[0].x>old_x+100 and leaving.fighters[0].gait_phase>old_phase,"Turn phase keeps horses riding out instead of freezing mid-stride")
  check(leaving.fighters[0].gait_moving and leaving.drain_events().is_empty(),"Ride-out cannot re-enable combat contacts")
  for tick in range(80):
   leaving.step(1.0/120)
  check(leaving.phase=="ready" and leaving.fighters[0].speed==0 and not leaving.fighters[0].gait_moving,"Rerack resets departure speed and gait for a fresh start")
  check(leaving.fighters[0].hp==73.0,"Riding out and reracking do not heal injuries")
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
    check(absf(leg.proximal.distance_to(leg.knee)-Gait.UPPER)<.01,"Upper visible limb does not stretch")
    var proximal_length = Vector2(-17,31).length() if leg.front else Vector2(32,32).length()
    check(absf(leg.hip.distance_to(leg.proximal)-proximal_length)<.05,"Shoulder/stifle segment does not stretch")
    check(absf(leg.ankle.distance_to(leg.foot)-Gait.PASTERN.length())<.01,"Pastern segment does not stretch")
    for key in ["hip","proximal","knee","ankle","foot"]:
     check(leg[key].is_finite(),"Every horse joint remains finite")
    check(is_finite(leg.toe_angle),"Hoof rotation remains finite")
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
     var shoulder = pivot+Rider.lance_shoulder(direction).rotated(angle)
     var elbow = Rider.arm_elbow(shoulder,hand,Rider.ARM_UPPER,Rider.ARM_LOWER)
     check(absf(elbow.distance_to(hand)-Rider.ARM_LOWER)<.05,"Right lance arm remains reachable")
     var shield_local = ((Model.shield_position(f)-Vector2(f.x,f.lane_y))*Vector2(direction,1)-pivot).rotated(-angle)
     var shield_hand = shield_local+Vector2(-10,4)
     var shield_elbow = Rider.arm_elbow(Rider.shield_shoulder(direction),shield_hand,Rider.ARM_UPPER,Rider.ARM_LOWER)
     check(absf(shield_elbow.distance_to(shield_hand)-Rider.ARM_LOWER)<.05,"Left shield arm remains reachable")
     var torso = Rider.mirrored_transform(pivot,angle,direction)
     check((torso*Rider.lance_shoulder(direction)).x<(torso*Rider.shield_shoulder(direction)).x,"Camera-facing chest preserves anatomical right and left shoulders after turning")
     var drawn = Rider.mirrored_transform(pivot,angle,direction)*Vector2(0,-111)+Vector2(f.x,f.lane_y)
     check(drawn.distance_to(Model.head_position(f))<.01,"Moving rider and real head collision share their anchor")
 var carry = Model.new()
 carry.phase = "charge"
 carry.fighters[0].x = -50000
 carry.fighters[1].x = 50000
 for rider in carry.fighters:
  rider.acted = true
 var carrier = carry.fighters[0]
 carrier.speed = 480
 carrier.gait_moving = true
 var target_height = Model.hand_position(carrier).y-55
 for tick in range(360):
  var aim = asin(clampf((target_height-Model.hand_position(carrier).y)/Model.lance_length(carrier),-.629,.548))
  carry.set_controls(0,aim,0,true,1.0/120)
  carry.step(1.0/120)
 check(carrier.lance_stability>.75,"Compensating for predictable horse motion must not destroy a stable carry")
 var stable_support = float(carrier.lance_stability)
 carrier.mount_velocity_y = 0
 for tick in range(24):
  carry.set_controls(0,.5,0,true,1.0/120)
 check(carrier.lance_stability<stable_support-.2,"A deliberate large redirect still sacrifices support")
 var result = {"passed":failures.is_empty(),"failures":failures,"speed_trace":trace,"gaits":ranges,"stable_carry":stable_support,"scope":"engine injected hold/release, cancelled countdown, UI/focus, real model movement, gait support and anatomical arm anchors; not human play"}
 var report_path = "E:/GALUMU/docs/development/logs/v045/motion-controls-01.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report-path="):
   report_path = arg.trim_prefix("--report-path=")
 DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
 var file = FileAccess.open(report_path,FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"\t"))
 file.close()
 print("MOTION_V045 "+JSON.stringify(result))
 await create_timer(.3,true,false,true).timeout
 quit(0 if failures.is_empty() else 1)

