extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
var rows=[]
func _initialize():call_deferred("run")
func run():
 var report=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
 var state=root.get_node("GameState")
 if report.is_empty() or FileAccess.file_exists(report) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 var base=state.default_profile().equipped.duplicate(true)
 var directions=[1] if "--one-facing" in OS.get_cmdline_user_args() else [1,-1]
 for tier in [0,2,5]:
  for strategy in ["always","finish","coast"]:
   for shield in [false,true]:
    for facing in directions:
     var eq=base.duplicate(true)
     eq.helmet="de_helmet_%d"%tier
     var stats=Catalogue.stats(state.items,eq)
     var model=Model.new("war",stats,stats,8600)
     var ai=0 if facing==1 else 1
     var di=1-ai
     if facing==-1:
      model.fighters[ai].lane_y=32.0;model.fighters[ai].gait_phase=0.0
      model.fighters[di].lane_y=-32.0;model.fighters[di].gait_phase=1.1
      for f in model.fighters:model._cache_pose(f)
     if not shield:model.fighters[di].shield=0.0
     var hits=[]
     for tick in range(120*80):
      var target=Model.head_position(model.fighters[di])
      var hand=Model.hand_position(model.fighters[ai])
      var distance=absf(model.fighters[ai].x-model.fighters[di].x)
      var boost=strategy=="always" or (strategy=="finish" and distance<1700)
      model.set_controls(ai,asin(clampf((target.y-hand.y)/Model.lance_length(model.fighters[ai]),-.629,.548)),0,boost,1.0/120,0)
      model.set_controls(di,.5,0,boost,1.0/120,1 if shield else 0)
      if "--passive" in OS.get_cmdline_user_args():model.fighters[di].acted=true
      model.step(1.0/120)
      for e in model.drain_events():
       if e.type=="rerack" and facing==-1:
        # Lane persists between passes; phase resets. Assign mirrored roles,
        # do not swap the already mirrored lanes back on every other pass.
        model.fighters[ai].lane_y=32.0;model.fighters[ai].gait_phase=0.0
        model.fighters[di].lane_y=-32.0;model.fighters[di].gait_phase=1.1
        for f in model.fighters:model._cache_pose(f)
       if e.type=="hit":
        var detail=e.duplicate(true)
        detail["pass"]=model.pass_number
        detail["attacker_speed"]=model.fighters[int(e.attacker)].speed
        detail["lance_stability"]=model.fighters[int(e.attacker)].lance_stability
        detail["stamina"]=model.fighters[int(e.attacker)].stamina
        hits.append(detail)
      if model.phase=="ended":break
     rows.append({"tier":tier,"strategy":strategy,"shielded":shield,"facing":facing,"attacker":ai,"stats":stats,"hp":model.fighters[di].hp,"dead":model.fighters[di].dead,"ko":model.fighters[di].ko,"hits":hits,"result":model.result})
     print("RULES086 case ",rows.size()," tier ",tier," ",strategy," shield ",shield," hp ",model.fighters[di].hp)
     FileAccess.open(report+".partial",FileAccess.WRITE).store_string(JSON.stringify(rows))
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Normal catalogue gear, full model steps/finite aim, stationary guard choices, production pointer/AI asin height mapping with automated perfect height tracking; not human/AI win rates","rows":rows},"\t"))
 print("RULES086 recorded ",rows.size()," normal-geared trials")
 quit()
