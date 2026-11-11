extends "test_head076.gd"
const Catalogue=preload("res://scripts/core/catalogue.gd")
func strike(model, speed: float, height: float, shielded: bool, broken: bool=false, stability: float=1.0)->Dictionary:
 var a=model.fighters[0];var d=model.fighters[1]
 # Isolated consecutive incoming intact lances: repeat actual sweep geometry,
 # preserving the defender's injuries. Not a claim that war re-racks weapons.
 d.x=0.0;d.lane_y=0.0;d.guard=1.0 if shielded else 0.0;d.shield=100.0 if shielded else 0.0
 a.x=0.0;a.lane_y=0.0;a.aim=0.0;a.speed=speed*.5;a.lance_stability=stability;a.broken=broken;a.acted=false
 var center=Model.head_position(d)
 var travel=160.0 if shielded else 40.0
 var start=center+Vector2(-(travel-8),height)
 var end=center+Vector2(8,height)
 a.x+=end.x-Model.tip_position(a).x
 a.lane_y+=end.y-Model.tip_position(a).y
 for f in model.fighters:model._cache_pose(f)
 a.prev_hand=start-Vector2.RIGHT*Model.lance_length(a)
 var event=model._detect_contact(0,travel/speed)
 check(not event.is_empty(),"Consecutive real head sweep missing")
 if not event.is_empty():model._apply_contact(event)
 return event
func run()->void:
 var report=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
 var state=root.get_node("GameState")
 if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not state.save_path.contains("qa_"):quit(2);return
 for region in ["eng","fr","de","it"]:
  for tier in range(6):
   var eq=state.default_profile().equipped.duplicate(true);eq.helmet="%s_helmet_%d"%[region,tier]
   var stats=Catalogue.stats(state.items,eq)
   var model=Model.new("war",stats,stats,8608)
   var hits=[]
   for i in range(3):
    var e=strike(model,650.0,0.0,false)
    hits.append(e)
    if model.fighters[1].dead:break
   check(model.fighters[1].dead,"Three centred supported ordinary-lance strikes failed to end "+str(eq.helmet))
   check(hits.size()>=2,"Moderate first hit bypassed helmet trade-off")
   rows.append({"helmet":eq.helmet,"helmet_value":stats.helmet,"power":stats.power,"hits":hits,"hp":model.fighters[1].hp,"dead":model.fighters[1].dead})
 var full=Model.new("war",{}, {"helmet":.41},8609)
 var first=strike(full,960,0,false)
 check(not full.fighters[1].dead and first.head_outcome=="helmet_block","Heavy helmet did not save first comparable lethal strike")
 var old_load=full.fighters[1].head_load
 full._reset_positions()
 check(is_equal_approx(full.fighters[1].head_load,old_load),"Re-rack erased head trauma")
 var second=strike(full,960,0,false)
 check(full.fighters[1].dead and second.head_outcome=="cumulative_fatal","Repeated heavy strike treated helmet as immunity")
 for config in [[400.0,0.0,false,false,1.0],[960.0,22.0,false,false,1.0],[960.0,0.0,true,false,1.0],[650.0,0.0,false,true,1.0],[650.0,0.0,false,false,.35]]:
  var m=Model.new("war",{},{"helmet":.41},8610)
  var hits=[]
  for i in range(3):hits.append(strike(m,config[0],config[1],config[2],config[3],config[4]))
  check(not m.fighters[1].dead,"Weak/glance/shield/unsupported triple became an automatic three-hit execution")
  rows.append({"control":config,"hits":hits,"dead":m.fighters[1].dead,"load":m.fighters[1].head_load})
 var arena=Model.new("arena",{},{"helmet":.1},8611)
 for i in range(3):strike(arena,960,0,false)
 check(not arena.fighters[1].dead and arena.fighters[1].head_load==0,"Cumulative fatal injury leaked into arena")
 check(Model.new("war").fighters[1].head_load==0,"New match inherited old head injury")
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Real sweep, catalogue helmets and standard lance power1.0; consecutive controlled intact incoming lance contacts preserve defender trauma. Whole matches and broken-lance persistence tested separately."},"\t"))
 print("HEAD086 ",failures);quit(0 if failures.is_empty() else 1)
