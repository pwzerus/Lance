extends "res://tests/test_fall_v057.gd"
func run() -> void:
 var report=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--report="):report=a.trim_prefix("--report=")
 var state=root.get_node("GameState")
 if report.is_empty() or FileAccess.file_exists(report) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":quit(2);return
 var eq=state.default_profile().equipped.duplicate(true)
 eq.helmet="de_helmet_1";eq.armor="de_armor_1";eq.shield="de_shield_0"
 stress_stats=Catalogue.stats(Catalogue.load_items(),eq);pose_config={"lean":1.0,"guard":1.0}
 var stage=Node2D.new();root.add_child(stage)
 var actor=make_actor(stage,"flank",1,false,true)
 var rows=[]
 for i in range(1440):
  actor.advance(1.0/120)
  if i%120==119:
   var pts=actor.body_points();var highest=-INF;var ix=0
   for j in range(pts.size()):
    var y=pts[j].rotated(actor.rotation).y
    if y>highest:highest=y;ix=j
   rows.append({"age":actor.age,"gap":actor.support_gap(),"settled":actor.settled,"highest_index":ix,"rotation":actor.rotation,"joints":actor.joints.duplicate(true),"targets":actor._joint_targets(),"support":support_parts(actor)})
 FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
 remove_stage(stage);quit()
