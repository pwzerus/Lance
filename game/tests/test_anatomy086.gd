extends "test_horse_anatomy063.gd"
var worst={}
var previous_legs={}
func inspect_pose(fighter: Dictionary,view,dt: float,metrics: Dictionary,label: String)->void:
 if previous_legs.has(label):
  for i in range(4):
   var leg=view.leg_poses[i]
   var old=previous_legs[label][i]
   var rate=absf(float(leg.sink)-float(old.sink))/dt
   if rate>float(worst.get("rate",0)):
    worst={"rate":rate,"label":label,"leg":i,"speed":fighter.speed,"phase":fighter.gait_phase,"drive":fighter.motion_drive,"before":old,"after":leg.duplicate(true)}
 previous_legs[label]=view.leg_poses.duplicate(true)
 super.inspect_pose(fighter,view,dt,metrics,label)
func run()->void:
 var path=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report-path="):path=a.trim_prefix("--report-path=")
 if path.is_empty() or FileAccess.file_exists(path) or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024" or not root.get_node("GameState").save_path.contains("qa_"):quit(2);return
 inspect_rest()
 for hz in [20,24,30,60,120]:
  for facing in [1,-1]:
   for speed in [110.0,210.0,340.0,480.0]:await steady_trial(speed,facing,hz)
   await transition_trial(facing,hz)
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rest":rest_rows,"steady":steady_rows,"transitions":transition_rows,"worst_sink":worst,"scope":"Production six-joint support, fixed bone lengths, joint speed and hoof locking at 20/24/30/60/120Hz; not human motion approval"},"\t"))
 print("ANATOMY086 failures ",failures," worst sink rate ",worst.get("rate",0));quit(0 if failures.is_empty() else 1)
