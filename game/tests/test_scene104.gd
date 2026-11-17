extends "test_cinema099.gd"
## Level-two presentation fixture: real swept hit with controlled KO health,
## actual enemy equipment, Main result screen and repeated match lifecycle.
## This is not a campaign difficulty or human input test.
func run_battle() -> void:
	var state=root.get_node("GameState")
	state.save_path=report_path.get_base_dir()+"/qa_profile.json"
	state.backup_path=report_path.get_base_dir()+"/qa_backup.json"
	await super.run_battle()

func start_case() -> void:
	main.set_process(false)
	root.get_node("GameState").profile.campaign_cleared=[1]
	root.get_node("GameState").profile.settings.combat_brief_v044=true
	main._start_level(2)

func after_result(c: Dictionary, b: Node) -> void:
	# Restore Main's ordinary result transition after the controlled capture.
	main.set_process(true)
	for i in range(12): await process_frame
	check(main.result_visible,"Level-two result overlay appears: "+str(c.name))
	check(is_equal_approx(Engine.time_scale,1.0),"Result overlay restores normal clock")
	for rider in b.riders:
		check(is_equal_approx(rider.modulate.a,1.0),"Result overlay does not resurrect a faded rider")
	if capture_dir!="none":save_frame(str(c.name)+"_result")
	main.set_process(false)
