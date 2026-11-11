extends "test_head076.gd"
## Fixed near/far lanes, identical physical rider poses and hand translation.
## This is distinct from mirroring the entire drawing, which hides lane bias.
func fixed_sweep(attacker_index: int, lane_span: float, zone: String, helmet: float, speed: float=960.0, rotate_only: bool=false)->Dictionary:
 var m=Model.new("war",{"power":1.2,"helmet":helmet,"stability":3.0},{"power":1.2,"helmet":helmet,"stability":3.0},8614)
 for i in range(2):
  var f=m.fighters[i]
  f.lane_y=lane_span*.5 if i==0 else -lane_span*.5
  f.gait_phase=0.0;f.gait_moving=false;f.lean=0.0;f.speed=480.0;f.guard=.43;f.shield=100.0 if zone=="shield" else 0.0
 var a=m.fighters[attacker_index];var d=m.fighters[1-attacker_index]
 d.x=0.0;a.x=0.0
 var target=Model.head_position(d) if zone=="head" else (Model.shield_position(d) if zone=="shield" else Model.body_position(d))
 var angle=asin((target.y-Model.hand_position(a).y)/Model.lance_length(a))
 a.aim=angle
 a.x+=(target.x+8*a.direction)-Model.tip_position(a).x
 for f in m.fighters:m._cache_pose(f)
 var dt=40.0/speed
 if rotate_only:
  a.prev_aim=angle-.15;a.aim=angle+.15
 else:a.prev_hand-=Vector2(a.direction*40.0,0)
 var hit=m._detect_contact(attacker_index,dt)
 check(not hit.is_empty() and hit.get("zone","")==zone,"Fixed-lane sweep missed "+zone)
 if not hit.is_empty():m._apply_contact(hit)
 return {"attacker":attacker_index,"span":lane_span,"zone":zone,"helmet":helmet,"rotate_only":rotate_only,"event":hit,"dead":d.dead,"hp":d.hp,"visual_angle":a.aim}
func run()->void:
 var report=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
 if report.is_empty() or FileAccess.file_exists(report) or not root.get_node("GameState").save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 for zone in ["head","body","shield"]:
  for helm in [.08,.41]:
   var reference={}
   for span in [0.0,64.0,96.0]:
    for side in [0,1]:
     var row=fixed_sweep(side,span,zone,helm)
     rows.append(row)
     if row.event.is_empty():continue
     if reference.is_empty():reference=row.event
     for key in ["speed","damage","impulse","combat_elevation"]:
      check(absf(float(row.event.get(key,0))-float(reference.get(key,0)))<.02,"Drawing depth changed physical "+zone+" "+key)
     check(row.event.glanced==reference.glanced and row.event.dead==reference.dead,"Drawing depth changed protection outcome")
     if zone=="shield":check(not row.event.glanced and row.event.shield_region=="center","Centered upright shield was mislabeled a glancing/rim blow")
     if zone=="head":check(row.dead==(helm<.2),"Helmet ceased to protect an equal moderate lethal strike")
 for side in [0,1]:
  var row=fixed_sweep(side,64,"head",.08,960,true)
  rows.append(row)
  check(not row.dead and float(row.event.get("speed",999))<=30.01,"Pure weapon rotation manufactured charging thrust")
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Controlled real collision sweeps, constant hand translation and matched physical poses in FIXED near/far lanes. Not a full charge/AI balance or human-input test."},"\t"))
 print("DEPTH086 ",failures);quit(0 if failures.is_empty() else 1)
