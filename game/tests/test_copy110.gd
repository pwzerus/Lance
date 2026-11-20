extends SceneTree
## Presentation contract: mixed actual archived matches and explicit edge fixtures.
const Report=preload("res://scripts/ui/combat_report.gd")
const Status=preload("res://scripts/ui/combat_status098.gd")
const Campaign=preload("res://scripts/core/campaign.gd")
const Comparison=preload("res://scripts/ui/equipment_comparison.gd")
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,note:String)->void:
	if not value:failures.append(note)
func run()->void:
	var folder=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty() or not root.get_node("GameState").save_path.contains("qa_"):quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	for row in [
		[[{"defender":0,"ko":true},{"defender":1,"ko":true}],"双方落马。"],
		[[{"defender":0,"dead":true},{"defender":1,"dead":true}],"双方阵亡。"],
		[[{"defender":0,"dead":true},{"defender":1,"ko":true}],"双方落马，你阵亡了。"],
		[[{"defender":0,"ko":true},{"defender":1,"dead":true}],"双方落马，对手阵亡。"]]:
		check(Report.summarize(row[0],"war")==row[1],"Simultaneous casualties keep both riders")
		row[0].reverse();check(Report.summarize(row[0],"war")==row[1],"Simultaneous casualties independent of ordering")
	check(Report.summarize([]).contains("未接触"),"No fabricated shield contact in empty exchange")
	var shield={"attacker":1,"defender":0,"zone":"shield","ko":true,"ko_reason":"impact","damage":1,"impulse":80,"unsteady":.4}
	check(Report.summarize([shield]).contains("虽用盾挡住"),"Shield stop explains transmitted impulse")
	check(Report.next_action([shield]).contains("W"),"Keyboard advice shows current control")
	check(Report.next_action([shield],true).contains("滚轮") and not Report.next_action([shield],true).contains("W"),"Mouse-only advice adapts controls")
	shield.ko_reason="health"
	check(Report.summarize([shield]).contains("累积伤势") and not Report.summarize([shield]).contains("掀下"),"Health exhaustion is not direct impact knockdown")
	for path in ["econ109-earned11","econ109-earned13","econ109-earned15"]:
		var source="E:/GALUMU/docs/development/logs/"+path+"/screens/report.json"
		var data=JSON.parse_string(FileAccess.get_file_as_string(source))
		check(data is Dictionary and data.get("passed",false),"Archived earned match evidence exists "+path)
		if not data is Dictionary:continue
		for row in data.rows:
			if int(row.level) not in [55,64,75]:continue
			var advice=Report.next_action(row.hits)
			var cause=Report.summarize(row.hits,str(row.result.get("mode","arena")))
			rows.append({"source":source,"level":row.level,"attempt":row.attempt,"cause":cause,"advice":advice})
			if int(row.level)==64 and int(row.attempt)==1:
				check(cause.contains("累积伤势"),"Actual level64 ended through accumulated injury")
				check(advice.contains("头部受创最多"),"Actual level64 earlier head wounds outweigh final body hit")
	check(rows.size()>=5,"Actual archived win/loss cases included")
	var source7="E:/GALUMU/docs/development/logs/ux110-journey02/screens/report.json"
	var record7=JSON.parse_string(FileAccess.get_file_as_string(source7))
	var checked7=false
	for row in record7.rows:
		if int(row.level)!=7 or int(row.attempt)!=1:continue
		checked7=true
		var own=0;var enemy=0;var receipts=[]
		for hit in row.hits:
			var line=Status.score_text(hit);receipts.append(line)
			if int(hit.attacker)==0:own+=int(hit.points)
			else:enemy+=int(hit.points)
			if hit.glanced:check(line=="未计分","Glancing broken lance has no tournament bonus")
		check(own==3 and enemy==4,"Actual level7 score breakdown sums to displayed result")
		check("2分 · 盾击＋断枪" in receipts and "1分 · 轻触" in receipts,"Blocked bonus and armor touch are explained")
		check(Report.next_action(row.hits,false,row.result).contains("擦过不计分"),"Score loss recommends improving scoring rather than needless defense")
		rows.append({"source":source7,"level":7,"cause":"Actual score loss","advice":Report.next_action(row.hits,false,row.result),"receipts":receipts})
	check(checked7,"Actual newly observed score-loss case covered")
	check(Status.score_text({}).is_empty(),"No invented score on unplayed contact")
	var font=load("res://scripts/ui/ui_factory.gd").theme().default_font
	for receipt in ["4分 · 实击＋断枪","2分 · 盾击＋断枪","1分 · 轻触","未计分"]:
		check(font.get_string_size(receipt,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=151,"Readable score receipt stays within its card: "+receipt)
	var head_bonus=[{"attacker":1,"defender":0,"zone":"head","damage":35,"broke":true,"glanced":false,"attaint":true,"points":4},{"attacker":0,"defender":1,"zone":"body","damage":20,"broke":false,"glanced":false,"attaint":true,"points":2}]
	var head_advice=Report.next_action(head_bonus,false,{"winner":1,"reason":"score"})
	check(head_advice.contains("头部受创最多") and not head_advice.contains("盾击"),"Head strike bonus cannot be mislabeled shield-block feedback")
	var shield_bonus=head_bonus.duplicate(true);shield_bonus[0].zone="shield";shield_bonus[0].damage=2;shield_bonus[0].impulse=40
	check(Report.next_action(shield_bonus,false,{"winner":1,"reason":"score"}).contains("盾击"),"Actual shield-bonus branch explains that event")
	check(not Campaign.all_complete({"campaign_cleared":[80]}),"Final chapter alone is not all chapters")
	check(not Campaign.all_complete({"campaign_cleared":range(1,80)}),"Missing final chapter remains incomplete")
	check(Campaign.all_complete({"campaign_cleared":range(1,81)}),"All eighty unique clears complete campaign")
	var dup=range(1,80);dup.append(79)
	check(not Campaign.all_complete({"campaign_cleared":dup}),"Duplicate clear does not substitute missing eighty")
	var state=root.get_node("GameState")
	var profile=state.default_profile()
	for level in Campaign.levels(state.items):
		var heading="第 %d 关 · %s · %s · %s"%[int(level.number),"竞技场" if level.mode=="arena" else "实战",str(level.opponent),str(level.archetype_name)]
		check(font.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=520,"Mode and opponent fit result header "+str(level.number))
	var lengths={}
	for item in state.items:
		var comparison=Comparison.summarize(state.items,profile.equipped,item)
		check(comparison.lines.size()<=5,"Comparison stays concise "+str(item.id))
		lengths[item.id]=comparison.lines.size()
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"archived_rows":rows,"comparison_line_counts":lengths,"scope":"Pure presentation tests: archived natural matches plus clearly supplied edge states, no new battle/human-input evidence."},"\t"))
	quit(0 if failures.is_empty() else 1)
