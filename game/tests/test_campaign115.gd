extends "test_campaign_probe107.gd"
## Same legal-budget, delayed-input probe, with the real terminal body phase.
## A later support loss can change the first KO result into a draw. Observe it
## before recording outcomes; no rendering/OS input/human win-rate claim.
func observe_terminal115(model) -> void:
	for tick in range(240):model.advance_terminal_pose113(1.0/120.0)

var recent115=[]
var saved115=false
var dump_number115=0
func observe_step115(model,side: int,tick: int) -> void:
	if tick==0:
		recent115.clear();saved115=false
	var f:Dictionary=model.fighters[side]
	if tick%12==0 or f.unseated:
		var row={"tick":tick,"time":model.time_elapsed,"phase":model.phase,"side":side}
		for key in ["direction","speed","aim","guard","lean","arm","hp","stamina","unsteady","seat_strain","seat_offset","seat_exit_reason","unseated","damage_total"]:row[key]=f.get(key)
		var physical=model.bodies115[side]
		if physical:
			row.body={"pelvis":str(physical.body.pelvis_x),"chest":str(physical.body.x),"saddle":str(physical.last_support.get("saddle")),"contacts":physical.body.support_contacts115.keys(),"spine":physical.body.spine_flex(),"unsupported_time":physical.unsupported_time,"last_hit":physical.last_hit}
		recent115.append(row)
		while recent115.size()>40:recent115.pop_front()
	# Full HP can be a legitimate shield-impact fall; preserve the incoming
	# contact and supports so reviewers can distinguish it from calm ejection.
	if f.unseated and f.hp==100 and not saved115:
		saved115=true
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--report="):
				var path=argument.trim_prefix("--report=").get_base_dir()+"/fullhp%02d.json"%dump_number115
				FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(recent115,"\t"))
				dump_number115+=1
