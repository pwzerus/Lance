extends SceneTree
const Model=preload("res://scripts/core/joust_match.gd")
var rows=[]
var failures=[]
func _initialize(): call_deferred("run")
func urge(style: String, gap: float) -> bool:
	if style=="brake": return gap<3600 and gap>1250
	return gap<(3600 if style=="early" else 1700)
func trial(style: String, opponent: String) -> Dictionary:
	var m=Model.new("arena",{}, {},8001)
	m.phase="charge"
	for f in m.fighters: f.acted=true
	var changed_at=-1.0
	for tick in range(60*22):
		var gap=absf(m.fighters[0].x-m.fighters[1].x)
		var target=-.5 if gap<850 else 0.0
		if changed_at<0 and gap<850: changed_at=tick/60.0
		m.set_controls(0,target,0,urge(style,gap),1.0/60)
		m.set_controls(1,0,0,urge(opponent,gap),1.0/60)
		m.step(1.0/60)
		if gap<400:
			return {"style":style,"opponent":opponent,"time":tick/60.0,"adjustment_time":tick/60.0-changed_at,"speed":m.fighters[0].speed,"stamina":m.fighters[0].stamina,"aim_error":absf(m.fighters[0].aim-target)}
	return {}
func run():
	var report=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report) or OS.get_environment("GALUMU_MEMORY_BOUND")=="" or not root.get_node("GameState").save_path.contains("qa_"):
		quit(2);return
	for opponent in ["early","late"]:
		for style in ["early","late","brake"]:
			rows.append(trial(style,opponent))
	for offset in [0,3]:
		if rows[offset+2].aim_error>=rows[offset+1].aim_error: failures.append("Braking failed to buy correction accuracy")
		if rows[offset+2].speed>=rows[offset+1].speed: failures.append("Braking did not sacrifice drive")
	if rows[1].time>=rows[4].time: failures.append("Opponent pressure did not shorten total preparation time")
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Finite controls and actual movement; contacts disabled to measure timing, drive and late target correction, not win rates."},"\t"))
	quit(0 if failures.is_empty() else 1)
