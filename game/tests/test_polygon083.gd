extends "test_live083.gd"
## Debug-engine logger only: retain the original error and its script callers.
## Never suppress drawing or filter the engine's own report.
class TraceLogger extends Logger:
	var path=""
	var gate=Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var traces=[]
		for trace in script_backtraces: traces.append(trace.format())
		if traces.is_empty():
			for trace in Engine.capture_script_backtraces(): traces.append(trace.format())
		gate.lock()
		var output=FileAccess.open(path,FileAccess.READ_WRITE)
		if output:
			output.seek_end()
			var row={"function":function,"file":file,"line":line,"code":code,"rationale":rationale,"kind":error_type,"traces":traces,"frame":Engine.get_process_frames()}
			if ResourceLoader.exists("res://scripts/visual/probe_dispatch083.gd"):
				row.submission=load("res://scripts/visual/probe_dispatch083.gd").snapshot()
			output.store_line(JSON.stringify(row))
			output.close()
		gate.unlock()
var trace_logger: TraceLogger
func _initialize() -> void:
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--errors="): output=arg.trim_prefix("--errors=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	FileAccess.open(output,FileAccess.WRITE).close()
	trace_logger=TraceLogger.new()
	trace_logger.path=output
	OS.add_logger(trace_logger)
	super._initialize()
