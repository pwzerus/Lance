extends "test_play087.gd"
const Trace = preload("res://scripts/core/frame_trace099.gd")
var watched: WeakRef
var previous: Dictionary = {}
var spikes: Array = []
var frame_begin = 0
var drawn_at = 0
var draw_duration = 0
func prepare(battle, seed_value: int) -> void:
	super.prepare(battle,seed_value)
	watched=weakref(battle)
	if not process_frame.is_connected(probe):
		process_frame.connect(probe)
		RenderingServer.frame_post_draw.connect(post_draw)
func post_draw() -> void:
	drawn_at=Time.get_ticks_usec()
	draw_duration=drawn_at-frame_begin
func probe() -> void:
	var b=watched.get_ref() if watched else null
	if not is_instance_valid(b): return
	var now=Time.get_ticks_usec()
	var row={"us":now,"phase":b.match_model.phase,"finished":b.is_finished,"result":b.get_parent().result_visible,"phase_time":b.match_model.phase_time,"exchange":b.exchange_state.state,"scale":Engine.time_scale,"frame":Engine.get_process_frames(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"frame_to_post_ms":draw_duration/1000.0,"post_to_next_ms":(now-drawn_at)/1000.0}
	row.hot=Trace.take_interval()
	row.hot_scope="Accumulated since previous process-frame probe; nested spans overlap."
	if not previous.is_empty() and now-int(previous.us)>30000 and spikes.size()<512:
		spikes.append({"gap_ms":(now-int(previous.us))/1000.0,"before":previous,"after":row})
	previous=row
	frame_begin=now
func run() -> void:
	await super.run()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--folder="):
			FileAccess.open(a.trim_prefix("--folder=")+"/trace.json",FileAccess.WRITE).store_string(JSON.stringify({"stages":Trace.rows,"spikes":spikes},"\t"))
