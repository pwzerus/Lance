extends "test_impact_v057.gd"
## Reuses the actual swept contact/live GPU/fall checks, but the fatal head
## fixture starts at FULL health. Pure rules separately cover helmet/glance.
func create_battle(mode_name: String, slow: bool):
	return super.create_battle("war" if "--helmet-block" in OS.get_cmdline_user_args() else mode_name,slow)

func stage_model(model, attacker: int, zone: String, fatal: bool, phase: float, solid: bool=false, broken_fixture: bool=false) -> void:
	super.stage_model(model,attacker,zone,fatal,phase,solid,broken_fixture)
	if "--helmet-block" in OS.get_cmdline_user_args() and zone=="head":
		model.fighters[1-attacker].hp=100.0
		model.fighters[1-attacker].stats.helmet=.41
		model.fighters[attacker].stats.power=1.4
	if fatal and zone=="head":
		model.fighters[1-attacker].hp=100.0
		model.fighters[1-attacker].stats.helmet=.08
		model.fighters[attacker].stats.power=1.4

func run() -> void:
	await super.run()
	# super schedules SceneTree.quit for the end of this frame; add the actual
	# fixture scope and new critical-rule assertions before that exit occurs.
	for item in cases:
		if "--helmet-block" in OS.get_cmdline_user_args() and item.zone=="head":
			item["actual_mode"]="war"
			item["defender_initial_hp"]=100.0
			var blocked=false
			for event in item.actual_events:
				if event.get("head_outcome","")=="helmet_block" and not event.dead: blocked=true
			check(blocked,"Helmet fixture failed to stop a comparable lethal blow",{})
		if item.zone=="head" and item.fatal_fixture:
			item["defender_initial_hp"]=100.0
			var critical=false
			for event in item.actual_events:
				if event.get("head_outcome","")=="fatal": critical=true
			check(critical,"Full-health head fixture did not use committed critical rule",{})
	var file=FileAccess.open(report_path,FileAccess.READ)
	if file==null: return
	var report=JSON.parse_string(file.get_as_text())
	file.close()
	report["scope"]="RULE-076 full-health head fixture, attacker power1.4 and defender helmet.08. Actual finite-control sweeps and live GPU/fall; inherited 1HP scope does not apply to head cases. No OS input or player approval."
	if "--helmet-block" in OS.get_cmdline_user_args():
		report["scope"]="RULE-076 helmet block in WAR mode, full-health, power1.4 and helmet.41 (same weapon as the lethal fixture). Inherited arena_mounted case/file names are historical harness labels; actual mode is war. Finite-control sweep, live GPU/normal nonterminal reaction; no OS input or human approval."
	report["cases"]=cases
	report["passed"]=failures.is_empty()
	report["failures"]=failures
	FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HEAD_VISUAL076 ",failures)
	quit(0 if failures.is_empty() else 1)
