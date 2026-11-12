extends "test_play087.gd"
var probe_battle: WeakRef
var previous_probe={}
var spikes=[]
func prepare(battle, seed_value:int)->void:
	super.prepare(battle,seed_value)
	probe_battle=weakref(battle)
	if not process_frame.is_connected(probe):process_frame.connect(probe)
func probe()->void:
	var b=probe_battle.get_ref() if probe_battle else null
	if not is_instance_valid(b):return
	var row={"usec":Time.get_ticks_usec(),"phase":b.match_model.phase,"phase_time":b.match_model.phase_time,"pass":b.match_model.pass_number,"exchange":b.exchange_state.state,"time_scale":Engine.time_scale,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"ready":b.presentation_ready}
	if not previous_probe.is_empty() and row.usec-previous_probe.usec>30000:
		spikes.append({"gap_ms":(row.usec-previous_probe.usec)/1000.0,"before":previous_probe,"after":row})
	previous_probe=row
func run()->void:
	await super.run()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):
			FileAccess.open(a.trim_prefix("--folder=")+"/spikes.json",FileAccess.WRITE).store_string(JSON.stringify(spikes,"\t"))
