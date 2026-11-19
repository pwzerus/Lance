extends RefCounted
## Explicit opt-in diagnostic only. No disk writes in a measured frame.
static var enabled = "--trace099" in OS.get_cmdline_user_args() and "--test-profile" in OS.get_cmdline_user_args()
static var rows: Array = []
static var hot_frame = -1
static var hot: Dictionary = {}
static var interval_hot: Dictionary = {}
static func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0
static func end(label: String, started: int) -> void:
	if started == 0 or rows.size() >= 2048: return
	rows.append({"stage":label,"start_us":started,"end_us":Time.get_ticks_usec(),"frame":Engine.get_process_frames()})
static func measure(label: String, started: int) -> void:
	if started == 0: return
	var frame=Engine.get_process_frames()
	if frame!=hot_frame:
		hot_frame=frame
		hot={}
	var elapsed=(Time.get_ticks_usec()-started)/1000.0
	hot[label]=float(hot.get(label,0))+elapsed
	interval_hot[label]=float(interval_hot.get(label,0))+elapsed

static func take_interval() -> Dictionary:
	# Sample at consecutive SceneTree.process_frame boundaries. Physics may
	# advance Engine's frame number before the next probe; resetting on that
	# number alone discarded the preceding process/draw spans from reports.
	var result=interval_hot
	interval_hot={}
	return result
