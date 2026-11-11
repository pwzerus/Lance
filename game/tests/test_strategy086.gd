extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
const AI=preload("res://scripts/core/opponent_ai.gd")
const Catalogue=preload("res://scripts/core/catalogue.gd")
func _initialize():call_deferred("run")
func run():
 var path=""
 var seeds=6
 var reactive=false
 var backlean=false
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):path=a.trim_prefix("--report=")
  if a.begins_with("--seeds="):seeds=clampi(int(a.trim_prefix("--seeds=")),1,16)
  if a=="--reactive-defense":reactive=true
  if a=="--backlean":backlean=true
 var state=root.get_node("GameState")
 if path.is_empty() or FileAccess.file_exists(path) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")=="":quit(2);return
 var rows=[]
 for tier in [0,5]:
  var eq=state.default_profile().equipped.duplicate(true)
  eq.helmet="de_helmet_%d"%tier;eq.armor="de_armor_%d"%tier
  var stats=Catalogue.stats(state.items,eq)
  for tactic in ["head","body","open"]:
   for seed_id in range(seeds):
    var model=Model.new("war",stats,stats,8660+seed_id)
    var ai=AI.new();var rng=RandomNumberGenerator.new();rng.seed=8660+seed_id
    var hits=[];var guard_hits=0;var head_hits=0;var swaps=0;var previous_zone=""
    var observations=[];var guard=.43
    for tick in range(120*90):
     var me=model.fighters[0];var foe=model.fighters[1]
     observations.append(Model.tip_position(foe).y)
     if observations.size()>30:
      var incoming=float(observations.pop_front())
      if reactive and tick%24==0:
       var zones=[Model.head_position(me).y,Model.body_position(me).y,Model.flank_position(me).y]
       var nearest=0
       for i in range(1,3):
        if absf(zones[i]-incoming)<absf(zones[nearest]-incoming):nearest=i
       guard=[1.0,.43,0.0][nearest]
     var target=Model.head_position(foe) if tactic=="head" else Model.body_position(foe)
     var chosen=tactic
     if tactic=="open":
      var best=-INF
      for zone in ["head","body","flank"]:
       var point=Model.head_position(foe) if zone=="head" else (Model.body_position(foe) if zone=="body" else Model.flank_position(foe))
       var gap=absf(point.y-Model.shield_position(foe).y)
       if gap>best:best=gap;target=point;chosen=zone
     if chosen!=previous_zone:swaps+=1;previous_zone=chosen
     var hand=Model.hand_position(me)
     var aim=asin(clampf((target.y-hand.y)/Model.lance_length(me),-.629,.548))
     model.set_controls(0,aim,-1.0 if backlean else 0.0,absf(foe.x-me.x)<1700,1.0/120,guard)
     ai.update(model,1,2,1.0/120,rng,false)
     model.step(1.0/120)
     for e in model.drain_events():
      if e.type=="hit":
       hits.append(e)
       if e.attacker==0 and e.zone=="shield":guard_hits+=1
       if e.attacker==0 and e.zone=="head":head_hits+=1
     if model.phase=="ended":break
    rows.append({"tier":tier,"tactic":tactic,"seed":seed_id,"guard_hits":guard_hits,"head_hits":head_hits,"swaps":swaps,"result":model.result,"hits":hits})
    FileAccess.open(path+".partial",FileAccess.WRITE).store_string(JSON.stringify(rows))
    print("STRATEGY086 ",rows.size()," ",tier," ",tactic," winner ",model.result.get("winner",-9))
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"reactive_defense":reactive,"backlean":backlean,"scope":"Perfect continuous attack tracking vs actual veteran delayed-observation AI, equal catalogue equipment. Optional guard sees 250ms-old tip and chooses every 200ms; all commands obey production finite movement. Automated tactical stress, not human win-rate evidence."},"\t"))
 quit()
