extends "profile_result099.gd"
## Read-only cache accounting during actual Main/Battle/results/replay.
var mesh_counts={}
var skin_totals={"uploads":0,"reuses":0}
func probe()->void:
	super.probe()
	var battle=watched.get_ref() if watched else null
	if not is_instance_valid(battle) or not battle.presentation_ready:return
	for rider in battle.riders:
		for skin in [rider.horse_skin,rider.far_hind_skin,rider.far_fore_skin]:
			if skin==null:continue
			var id=skin.get_instance_id();var previous_counts=mesh_counts.get(id,[0,0])
			skin_totals.uploads+=skin.deformation_uploads-int(previous_counts[0])
			skin_totals.reuses+=skin.deformation_reuses-int(previous_counts[1])
			mesh_counts[id]=[skin.deformation_uploads,skin.deformation_reuses]
func run()->void:
	await super.run()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):
			FileAccess.open(arg.trim_prefix("--folder=")+"/skin.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"metrics":skin_totals,"instances":mesh_counts.size(),"scope":"Exact-input mesh reuse observed in actual protected rendering; performance in adjacent report/trace, no input or animation quantization."},"\t"))
