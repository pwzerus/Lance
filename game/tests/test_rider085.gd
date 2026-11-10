extends SceneTree
## Pending runtime regression: shared mounted anchors, finite limbs and unchanged horse.
const Gait=preload("res://scripts/visual/horse_gait.gd")
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
var failures=[]
func check(ok: bool, message: String) -> void:
 if not ok and message not in failures:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var report=""
 var baseline=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
  if a.begins_with("--baseline="):baseline=a.trim_prefix("--baseline=")
 var state=root.get_node("GameState")
 if report.is_empty() or baseline.is_empty() or FileAccess.file_exists(report) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 var old=load(baseline)
 var model=Model.new("arena",state.player_stats(),state.player_stats())
 check(absf(Gait.body(0.6,0,true,1,0).rider_pitch)<.0001,"Starting from rest introduces a pose jump")
 var rows=[]
 var cases=0
 for speed in [0.0,100.0,210.0,320.0,480.0]:
  var hip_min=INF;var hip_max=-INF;var pitch_min=INF;var pitch_max=-INF
  var old_min=INF;var old_max=-INF
  for step in range(48):
   var phase=step*TAU/48
   var pose=Gait.body(phase,speed,speed>0,1,0)
   var former=old.body(phase,speed,speed>0,1,0)
   for key in former:
    if key not in ["rider_offset","rider_pitch"]:check(former[key]==pose[key],"Horse body/neck/feet must not change with rider tuning")
   for leg in range(4):check(Gait.leg(leg,phase,speed,speed>0)==old.leg(leg,phase,speed,speed>0),"Horse limb trajectory changed")
   var hip_y=pose.offset.y+pose.rider_offset.y
   hip_min=minf(hip_min,hip_y);hip_max=maxf(hip_max,hip_y)
   pitch_min=minf(pitch_min,pose.rider_pitch);pitch_max=maxf(pitch_max,pose.rider_pitch)
   old_min=minf(old_min,former.rider_pitch);old_max=maxf(old_max,former.rider_pitch)
   check(absf(pose.rider_offset.y)<3.5,"Pelvis separates too far from saddle")
   for facing in [-1,1]:
    for lean in [-1.0,0.0,1.0]:
     var f=model.fighters[0].duplicate(true)
     f.x=0;f.lane_y=0;f.direction=facing;f.speed=speed;f.gait_phase=phase;f.gait_moving=speed>0;f.lean=lean
     var arms=Rider.arm_pose(f)
     check(arms.right.hand.distance_to(Model.hand_position(f))<.002,"Lance hand detached from rule anchor")
     check(arms.shield_center.distance_to(Model.shield_position(f))<.002,"Shield detached from rule anchor")
     check(arms.torso_transform.origin.distance_to(Model.rider_origin(f))<.002,"Torso detached from shared seat")
     var neck=Rider.neck_geometry(arms,f)
     check(neck.top.is_finite() and neck.base.is_finite(),"Nonfinite neck")
     var legs=Rider.seated_leg_pose(f)
     for side in ["near","far"]:
      var a=legs[side];var thigh=Vector2(23,29) if side=="near" else Vector2(21,24)
      var ankle=Vector2(7,82) if side=="near" else Vector2(10,78)
      check(absf(a.hip.distance_to(a.knee)-thigh.length())<.002 and absf(a.knee.distance_to(a.ankle)-(ankle-thigh).length())<.002,"Mounted leg stretches instead of absorbing through knee")
     cases+=1
  rows.append({"speed":speed,"hip_vertical_range":hip_max-hip_min,"torso_pitch_range":pitch_max-pitch_min,"old_pitch_range":old_max-old_min})
 check(rows[-1].torso_pitch_range>rows[-1].old_pitch_range*1.5,"Fast rider follow-through is still too faint")
 check(rows[-1].hip_vertical_range>rows[1].hip_vertical_range,"Fast riding lacks stronger vertical travel than walking")
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":cases,"motion":rows,"scope":"Math/shared pose regression only, not GPU/player acceptance"},"\t"))
 print("RIDER085 ",failures);quit(0 if failures.is_empty() else 1)
