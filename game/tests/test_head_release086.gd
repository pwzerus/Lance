extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Rider=preload("res://scripts/visual/rider_view.gd")
const Fallen=preload("res://scripts/visual/fallen_rider.gd")
var failures=[]
func _initialize():call_deferred("run")
func run():
 var report=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
 if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 var maximum=0.0;var rows=[]
 for facing in [1,-1]:
  for lean in [-1.0,0.0,1.0]:
   for speed in [0.0,210.0,480.0]:
    var model=Model.new("war")
    var f=model.fighters[0 if facing==1 else 1]
    f.lean=lean;f.speed=speed;f.gait_moving=speed>0;f.gait_phase=2.1
    var before=Rider.head_transform(Rider.arm_pose(f),f)
    var actor=Fallen.new();root.add_child(actor);actor.setup(f,{"zone":"head","direction":-facing,"impulse":70})
    actor._update_pose() # zero elapsed time, zero joint angles
    var after=actor.transform*Rider.head_transform(actor.visual.detached_pose,actor.fighter)
    var error=0.0
    for point in [Vector2(0,-111),Vector2(-20,-145),Vector2(20,-100)]:error=maxf(error,(before*point).distance_to(after*point))
    maximum=maxf(maximum,error)
    if error>.02:failures.append("Head pose snapped at zero-time mount/fall handover: %s/%s/%s"%[facing,lean,speed])
    rows.append({"facing":facing,"lean":lean,"speed":speed,"error":error})
    actor.queue_free();await process_frame
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"maximum_zero_time_head_error":maximum,"rows":rows},"\t"))
 print("HEAD_RELEASE086 max ",maximum," failures ",failures.size());quit(0 if failures.is_empty() else 1)
