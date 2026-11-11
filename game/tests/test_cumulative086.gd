extends "test_impact_v057.gd"
## Two genuine finite-control head sweeps. The first survives its helmet;
## the second retains only its actual HP/injury, then drives live Battle FX.
var preceding=[]
func stage_model(model, attacker: int, zone: String, fatal: bool, phase: float, solid: bool=false, broken_fixture: bool=false)->void:
	super.stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
	if not fatal or zone!="head":return
	var first_model=Model.new("war",model.fighters[0].stats.duplicate(true),model.fighters[1].stats.duplicate(true),57051)
	super.stage_model(first_model,attacker,zone,false,phase)
	first_model.fighters[1-attacker].stats.helmet=.41
	var prior={}
	for tick in range(360):
		for e in step_staged(first_model,attacker,zone):
			if e.type=="hit" and e.attacker==attacker:prior=e.duplicate(true)
		if not prior.is_empty():break
	check(not prior.is_empty() and prior.zone=="head" and not first_model.fighters[1-attacker].ko,"First supported helmet strike must survive before cumulative fall")
	var defender=model.fighters[1-attacker]
	defender.stats.helmet=.41
	defender.hp=first_model.fighters[1-attacker].hp
	defender.head_load=first_model.fighters[1-attacker].head_load
	# No fabricated added load or reset HP. A new approach is staged solely
	# for presentation; whole-match break/turn behavior has separate evidence.
	if preceding.size()<24:preceding.append({"attacker":attacker,"phase":phase,"first_hit":prior,"retained_hp":defender.hp,"retained_head_load":defender.head_load})

func run()->void:
	await super.run()
	for item in cases:
		if item.zone!="head":continue
		var found=false
		for e in item.actual_events:
			if e.get("head_outcome","")=="cumulative_fatal" and e.get("head_load_before",0)>0:found=true
		check(found,"Live second head contact bypassed cumulative injury rule")
	var report=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	report.passed=failures.is_empty();report.failures=failures
	report["preceding_contacts"]=preceding
	report.scope="Two finite-control head sweeps with normal power1 and helmet.41, first HP/injury retained, second actual cumulative fatal event feeds live Battle fall/camera/audio. Approach restaged; not a whole match or OS input. Inherited chest 1HP fixtures remain presentation-only."
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CUMULATIVE086 ",failures);quit(0 if failures.is_empty() else 1)
