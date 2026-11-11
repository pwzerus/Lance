extends SceneTree
const Gait=preload("res://scripts/visual/horse_gait.gd")
var failures=[]
var rows=[]
func _initialize():call_deferred("run")
func run():
 var report=""
 var baseline=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
  if a.begins_with("--baseline="):baseline=a.trim_prefix("--baseline=")
 if report.is_empty() or FileAccess.file_exists(report) or baseline.is_empty() or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 var old=load(baseline)
 for speed in [110.0,210.0,340.0,480.0]:
  for version in ["old","new"]:
   var script=old if version=="old" else Gait
   var heights=[];var pitches=[];var head_x=[]
   for tick in range(600):
    var pose=script.body(tick*TAU/600,speed,true,1.0,0)
    heights.append(pose.offset.y);pitches.append(pose.rider_pitch)
    head_x.append(pose.offset.x+pose.rider_offset.x+sin(pose.rider_pitch)*111)
   var peaks=0;var reversals=0;var accel_energy=0.0
   for j in range(600):
    if heights[j]>heights[posmod(j-1,600)] and heights[j]>heights[(j+1)%600]:peaks+=1
    if (pitches[j]-pitches[posmod(j-1,600)])*(pitches[(j+1)%600]-pitches[j])<0:reversals+=1
    var acceleration=(head_x[(j+1)%600]-2*head_x[j]+head_x[posmod(j-1,600)])*pow(script.frequency(speed)*600,2)
    accel_energy+=acceleration*acceleration/600
   rows.append({"speed":speed,"version":version,"back_peaks_per_stride":peaks,"torso_reversals":reversals,"back_range":heights.max()-heights.min(),"pitch_range":pitches.max()-pitches.min(),"head_x_acceleration_rms":sqrt(accel_energy)})
   if version=="new" and speed>=340:
    if peaks!=1:failures.append("Run stride needs one main load/release wave")
    if reversals>2:failures.append("Extra torso oscillation within stride")
    if heights.max()-heights.min()<5:failures.append("Motion hidden instead of smoothed")
    if sqrt(accel_energy)>=float(rows[rows.size()-2].head_x_acceleration_rms):failures.append("Head acceleration did not improve")
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Pure curve metrics; continuous rendering and player judgment are separate"},"\t"))
 print("WAVE086 ",failures);quit(0 if failures.is_empty() else 1)
