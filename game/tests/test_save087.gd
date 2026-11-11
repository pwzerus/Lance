extends SceneTree
var folder = ""
var state: Node
var results: Array = []
var failures: Array = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, name_value: String, detail: Variant = null) -> void:
	results.append({"name":name_value,"passed":ok,"detail":detail})
	if not ok: failures.append(name_value)
func write(path: String, value: String) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value)
	file.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--folder="): folder=arg.trim_prefix("--folder=")
	state = root.get_node("GameState")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not "qa_" in str(state.save_path):
		quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	state.save_path = folder+"/qa_profile.json"
	state.backup_path = folder+"/qa_backup.json"
	state.profile = state.default_profile()
	state.profile.coins = 1000
	check(state.save_profile(),"initial-save")
	var good_backup = state.backup_path
	state.backup_path = folder+"/directory_not_a_file"
	DirAccess.make_dir_recursive_absolute(state.backup_path)
	write(state.backup_path+"/keep.txt","non-empty directory blocks backup replacement")
	var first = state.award_match("qa-087-reward",1,"arena")
	var earned = state.profile.coins
	check(first.get("coins",0)>0 and not state.save_error.is_empty(),"reward-write-failure-is-visible")
	check(state.award_match("qa-087-reward",1,"arena").is_empty() and state.profile.coins==earned,"duplicate-reward-callback-does-not-double-pay")
	check(state.save_slot(1),"manual-slot-can-still-save")
	check(state.get("profile_save_pending")==true,"manual-slot-success-must-not-hide-unsaved-current-progress",state.save_error)
	state.backup_path = good_backup
	check(state.save_profile(),"retry-current-save")
	state.profile.coins = 0
	state.load_profile()
	check(state.profile.coins==earned,"reward-survives-reload-after-retry")
	# Backup restoration must be explicit and must not destroy the good copy.
	var recovered = state.default_profile()
	recovered.coins = 321
	write(state.save_path,"broken primary")
	write(state.backup_path,JSON.stringify(recovered))
	state.load_profile()
	check(state.profile.coins==321,"backup-restores-progress")
	check(state.get("load_notice")!=null and not str(state.get("load_notice")).is_empty(),"backup-restoration-shown-to-player")
	check(state.save_profile(),"repair-primary-after-backup-restore")
	check(JSON.parse_string(FileAccess.get_file_as_string(state.backup_path)).coins==321,"good-backup-not-overwritten-by-corrupt-primary")
	# Two broken copies must never be silently replaced by starter gear.
	write(state.save_path,"primary damaged bytes 087")
	write(state.backup_path,"backup damaged bytes 087")
	var hash_primary = FileAccess.get_sha256(state.save_path)
	var hash_backup = FileAccess.get_sha256(state.backup_path)
	state.load_profile()
	check(state.get("recovery_required")==true,"two-broken-copies-require-choice")
	check(not state.save_profile(),"automatic-save-refuses-to-replace-broken-pair")
	check(FileAccess.get_sha256(state.save_path)==hash_primary and FileAccess.get_sha256(state.backup_path)==hash_backup,"broken-originals-unchanged-before-consent")
	if state.has_method("start_new_after_recovery"):
		check(state.start_new_after_recovery(),"explicit-new-journey-preserves-broken-files")
		var archive_hashes = []
		for path in state.recovery_archives: archive_hashes.append(FileAccess.get_sha256(path))
		check(hash_primary in archive_hashes and hash_backup in archive_hashes,"preserved-files-match-original-bytes",archive_hashes)
		state.profile.coins = 7
		state.load_profile()
		check(state.profile.coins==520 and not state.recovery_required,"fresh-profile-readable-after-confirmation")
		# A valid manual slot offers recovery without discarding that journey.
		write(state.save_path,"second primary failure")
		write(state.backup_path,"second backup failure")
		state.load_profile()
		check(state.load_slot(1) and state.profile.coins==earned,"manual-slot-recovers-broken-automatic-pair")
		check(state.recovery_archives.size()==2,"manual-recovery-also-preserves-both-broken-copies")
		# A failed transactional purchase/appearance must not claim a new pending
		# profile when its in-memory mutation has already been rolled back.
		state.backup_path = folder+"/directory_not_a_file"
		var owned_before = state.profile.owned.duplicate()
		var coins_before = state.profile.coins
		var buy_id = ""
		for item in state.items:
			if item.id not in state.profile.owned and int(item.price)<=coins_before and int(item.get("era",0))==0 and int(item.get("renown",0))==0:
				buy_id=item.id
				break
		var buy_message = state.purchase(buy_id)
		check(not buy_id.is_empty() and "存档不可写" in buy_message and state.profile.owned==owned_before and state.profile.coins==coins_before and not state.profile_save_pending,"failed-purchase-rolls-back-without-false-pending",buy_message)
		state.backup_path = good_backup
		check(state.save_profile(),"restore-writable-path-after-purchase-fault")
		state.profile.coins = 200
		check(state.save_profile() and state.save_slot(3),"prepare-earlier-manual-progress")
		state.backup_path = folder+"/directory_not_a_file"
		state.award_match("qa-087-before-manual-load",1,"arena")
		var pending_coins = state.profile.coins
		state.backup_path = good_backup
		check(state.load_slot(3) and state.profile.coins==200,"manual-load-replaces-current-only-after-pending-save")
		check(JSON.parse_string(FileAccess.get_file_as_string(state.backup_path)).coins==pending_coins,"pending-reward-retained-in-automatic-backup-after-manual-load")
		var before_large = FileAccess.get_sha256(state.save_path)
		var oversized = state.profile.duplicate(true)
		oversized["unexpected"] = "X".repeat(2*1024*1024)
		check(not state._write_save(state.save_path,state.backup_path,oversized) and FileAccess.get_sha256(state.save_path)==before_large,"oversize-save-does-not-replace-valid-progress")
		write(state.save_path,"X".repeat(2*1024*1024+1))
		state.load_profile()
		check(not state.recovery_required and not state.load_notice.is_empty(),"oversize-primary-falls-back-before-json-allocation")
		write(state.backup_path,"broken oversized-pair backup")
		state.load_profile()
		check(state.recovery_required and not state.start_new_after_recovery(),"oversize-unreadable-pair-never-starts-unbounded-archive-copy")
		check(FileAccess.file_exists(state.save_path) and FileAccess.get_file_as_string(state.backup_path)=="broken oversized-pair backup","oversize-pair-left-untouched")
	else: check(false,"explicit-recovery-operation-missing")
	write(folder+"/report.json",JSON.stringify({"passed":failures.is_empty(),"results":results,"failures":failures,"scope":"Real file failures in a fresh isolated QA folder. No player saves touched."},"\t"))
	print("SAVE087 ",failures)
	quit(0 if failures.is_empty() else 1)
