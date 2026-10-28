extends SceneTree
const Gait = preload("res://scripts/visual/horse_gait.gd")
func _initialize() -> void:
 var rows=[]
 for speed in [0.0,110.0,210.0,340.0,480.0]:
  var nominal=[0,0,0,0]
  var supported=[0,0,0,0]
  var max_gap=[0.0,0.0,0.0,0.0]
  for tick in range(480):
   for i in range(4):
    var pose=Gait.leg(i,TAU*tick/480.0,speed,speed>0)
    if pose.nominal_contact:
     nominal[i]+=1
     if pose.contact:
      supported[i]+=1
     max_gap[i]=maxf(max_gap[i],Gait.GROUND-pose.foot.y)
  rows.append({"speed":speed,"nominal":nominal,"supported":supported,"max_gap":max_gap})
 print("SUPPORT_DIAGNOSTIC ",JSON.stringify(rows))
 quit()
