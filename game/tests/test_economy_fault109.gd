extends SceneTree
## A failed first-clear write followed by other real actions is different
## from an isolated successful reward call. Keep this ordered transaction
## regression on private paths, including a rescue manual snapshot.
var folder=""
var failures=[]
var rows=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,why:String)->void:
	rows.append({"name":why,"passed":ok})
	if not ok:failures.append(why);push_error(why)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="):folder=arg.trim_prefix("--folder=")
	var state=root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not state.save_path.contains("qa_") or OS.get_environment("GALUMU_MEMORY_BOUND").is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path=folder+"/qa_profile.json";state.backup_path=folder+"/qa_backup.json"
	state.profile=state.default_profile();state.session_awarded.clear()
	check(state.save_profile() and state.save_slot(1),"New journey and older manual snapshot saved")
	var primary_before=FileAccess.get_sha256(state.save_path)
	var normal_backup=state.backup_path
	state.backup_path=folder+"/blocked_backup"
	DirAccess.make_dir_recursive_absolute(state.backup_path)
	FileAccess.open(state.backup_path+"/keep.txt",FileAccess.WRITE).store_string("intentional nonempty QA directory")
	var first=state.award_level("pending-first-clear109",1,1)
	check(first.coins==120 and first.renown==1 and state.profile.campaign_cleared==[1] and state.profile_save_pending,"First-clear retained in memory when backup cannot be written")
	check(FileAccess.get_sha256(state.save_path)==primary_before,"Failed replacement did not destroy earlier primary")
	var pending=state.profile.duplicate(true)
	var pending_error=state.profile_save_error
	check(state.award_level("pending-first-clear109",1,1).is_empty() and state.profile==pending,"Duplicate finish during pending save does not pay again")
	check("存档不可写" in state.purchase("eng_lance_long_0") and state.profile==pending and state.profile_save_pending and state.profile_save_error==pending_error,"Failed purchase refunds without losing pending first-clear")
	check(state.save_slot(2) and state.profile_save_pending,"Emergency manual snapshot does not hide pending automatic save")
	check(not state.load_slot(1) and state.profile==pending and state.profile_save_pending,"Older slot cannot discard pending reward while writes remain blocked")
	state.backup_path=normal_backup
	check(state.save_profile(),"Retry persists first-clear and its purse")
	state.profile=state.default_profile();state.load_profile()
	check(state.profile==pending and not state.profile_save_pending and state.campaign_unlocked(2),"First-clear and next level survive reload after retry")
	check(state.read_slot(2).profile==pending,"Emergency slot retained all pending progress")
	check(state.purchase("eng_lance_long_0")=="已收入军械库" and state.equip("eng_lance_long_0"),"Purchase/equip works after storage recovers")
	var bought=state.profile.duplicate(true)
	state.award_level("next-pending109",2,1)
	check(state.profile.campaign_cleared==[1,2],"Continue from recovered first-clear")
	check(state.save_slot(3),"Current manual slot saved")
	# Corrupt a manual primary only. The preceding snapshot must remain
	# readable, and an explicit restore cannot change other manual slots.
	check(state.save_slot(3),"Manual slot backup created")
	var slot1hash=FileAccess.get_sha256(state.slot_path(1))
	FileAccess.open(state.slot_path(3),FileAccess.WRITE).store_string("truncated manual slot")
	var manual=state.read_slot(3)
	check(not manual.is_empty() and manual.recovered and manual.profile.campaign_cleared==[1,2],"Damaged manual primary reads its backup")
	check(state.load_slot(3) and FileAccess.get_sha256(state.slot_path(1))==slot1hash,"Manual backup restoration preserves other slots")
	# Old pre-campaign saves: legal historic IDs remain equipped/owned; new
	# slots and settings receive defaults. Invalid data cannot manufacture
	# ownership or silently transform another slot into a helmet.
	var old={"version":1,"coins":1234,"renown":17,"wins":7,"matches":11,"owned":["mail_basic","helm_great","lance_ash","horse_grey","crest_chevron"],"equipped":{"armor":"mail_basic","helmet":"helm_great","horse":"horse_grey","crest":"crest_chevron"},"settings":{"blood":true,"sound":false}}
	var clean=state.sanitize(old)
	check(clean.coins==1234 and clean.renown==17 and clean.matches==11 and clean.equipped.helmet=="helm_great" and clean.equipped.horse=="horse_grey" and clean.equipped.crest=="crest_chevron","Legacy currencies and owned equipment preserved")
	check(clean.campaign_cleared.is_empty() and clean.equipped.caparison=="caparison_none" and clean.settings.blood and not clean.settings.sound,"Missing new fields obtain compatible defaults")
	var noisy=old.duplicate(true)
	noisy.owned.append_array(["missing109",null,42,"helm_great"])
	noisy.equipped.helmet="horse_grey";noisy.equipped.armor="de_armor_5"
	noisy.campaign_cleared=[1,1,-1,0,81,"2",2,INF,NAN]
	noisy.coins="999999";noisy.renown=-10;noisy.matches=INF
	noisy.settings.master_volume=INF;noisy.settings.blood="yes"
	var sanitized=state.sanitize(noisy)
	check(sanitized.campaign_cleared==[1,2] and sanitized.renown==0 and sanitized.coins==520 and sanitized.matches==0,"Malformed counters/clears cannot grant progress")
	check("helm_great" in sanitized.owned and "missing109" not in sanitized.owned and sanitized.equipped.helmet=="helm_nasal" and sanitized.equipped.armor=="mail_basic","Unknown/wrong-slot/unowned equipment ignored without deleting legal old items")
	check(not sanitized.settings.blood and is_finite(float(sanitized.settings.master_volume)),"Invalid settings remain finite and typed")
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"checks":rows,"pending_profile":pending,"purchased_profile":bought,"legacy_restored":clean,"scope":"Real isolated storage failure, campaign reward retry, rescue snapshots and malformed/legacy data. Intentional SAVE_IO warnings expected for blocked_backup; no player file, OS input or battle outcome claim."},"\t"))
	print("ECON109_FAULT ",failures);quit(0 if failures.is_empty() else 1)
