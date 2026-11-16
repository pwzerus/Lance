extends RefCounted
## Explicit opt-in diagnostic only. No disk writes in a measured frame.
static var enabled = "--trace099" in OS.get_cmdline_user_args() and "--test-profile" in OS.get_cmdline_user_args()
static var rows: Array = []
static var hot_frame = -1
static var hot: Dictionary = {}
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
	hot[label]=float(hot.get(label,0))+(Time.get_ticks_usec()-started)/1000.0
