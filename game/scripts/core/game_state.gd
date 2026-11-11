extends Node

signal profile_changed

const Catalogue = preload("res://scripts/core/catalogue.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const SAVE_PATH = "user://profile_v1.json"
const BACKUP_PATH = "user://profile_v1.backup.json"
const MAX_SAVE_BYTES = 2*1024*1024
var save_path = SAVE_PATH
var backup_path = BACKUP_PATH
var items: Array = []
var profile: Dictionary = {}
var session_awarded: Dictionary = {}
var save_error = ""
var profile_save_pending = false
var profile_save_error = ""
var load_notice = ""
var recovery_required = false
var recovery_archives: Array[String] = []
var qa_input_probe = false

func _ready() -> void:
	var arguments = OS.get_cmdline_user_args()
	qa_input_probe = OS.get_executable_path().get_file().to_lower().begins_with("lanceandlaurel-qa")
	if arguments.has("--smoke-test") or arguments.has("--test-profile") or qa_input_probe:
		save_path = "user://qa_profile_v1.json"
		backup_path = "user://qa_profile_v1.backup.json"
	if qa_input_probe:
		save_path = "user://qa_desktop_profile.json"
		backup_path = "user://qa_desktop_profile.backup.json"
	items = Catalogue.load_items()
	profile = default_profile()
	load_profile()

func default_profile() -> Dictionary:
	return {"version": 1, "coins": 520, "renown": 0, "wins": 0, "matches": 0, "region": 0,
		"appearance": Appearance.defaults(),
		# EQUIP-066: "caparison_none" (bare horse) is owned by everyone, so older
		# saves without the slot load with an empty caparison slot unchanged.
		"owned": ["mail_basic", "helm_nasal", "lance_ash", "horse_bay", "crest_bend", "shield_basic", "caparison_none"],
		"equipped": {"armor": "mail_basic", "helmet": "helm_nasal", "lance": "lance_ash", "horse": "horse_bay", "crest": "crest_bend", "shield":"shield_basic", "caparison":"caparison_none"},
		"settings": {"blood": false, "shake": true, "sound": true, "mouse_only": false, "brief_seen":false,"combat_brief_v03":false,"combat_brief_v043":false,"combat_brief_v044":false,"aim_cues":true,"slow_motion":true,"vsync":false, "difficulty": 1}}

func load_profile() -> void:
	save_error = ""
	profile_save_pending = false
	profile_save_error = ""
	load_notice = ""
	recovery_required = false
	var had_file = false
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		had_file = true
		var data = _read_save(path)
		if not data.is_empty():
			profile = sanitize(data)
			if path == backup_path:
				load_notice = "自动存档无法读取，已恢复上一次可用备份。最近一次未写完的进度可能未包含在内。"
			return
	profile = default_profile()
	if had_file:
		recovery_required = true
		load_notice = "自动存档与备份均无法读取。原文件保持不动，请选择手动存档恢复，或保留损坏文件后开始新旅程。"

func start_new_after_recovery() -> bool:
	return _accept_recovery(default_profile()) if recovery_required else false

func _accept_recovery(recovered: Dictionary) -> bool:
	# Only called after an explicit recovery choice. Never erase the bytes that
	# might still allow manual repair, even when both automatic copies are bad.
	recovery_archives.clear()
	for path in [save_path,backup_path]:
		if not FileAccess.file_exists(path): continue
		var source = FileAccess.open(path,FileAccess.READ)
		if source == null:
			save_error = "无法读取原文件，暂未替换："+path.get_file()
			return false
		var source_length = source.get_length()
		source.close()
		if source_length > MAX_SAVE_BYTES:
			# Do not turn recovery into an unbounded disk copy/hash operation.
			save_error = "原存档异常大，暂未替换。请先备份并移走 "+path.get_file()+"，再重新启动游戏。"
			return false
		var archive = path+".damaged-"+str(Time.get_unix_time_from_system()).replace(".","-")+"-"+str(Time.get_ticks_usec())
		if FileAccess.file_exists(archive):
			save_error = "恢复副本名称冲突，请重试。"
			return false
		var error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(archive))
		if error != OK or FileAccess.get_sha256(path) != FileAccess.get_sha256(archive):
			save_error = "无法保留损坏文件，原进度未被替换："+str(error)
			return false
		recovery_archives.append(archive)
	recovery_required = false
	profile = sanitize(recovered)
	if not save_profile():
		recovery_required = true
		return false
	load_notice = "已保留原损坏文件并恢复可用进度。损坏副本位于存档文件夹，文件名含 damaged。"
	profile_changed.emit()
	return true

func sanitize(raw: Dictionary) -> Dictionary:
	var clean = default_profile()
	for key in ["coins", "renown", "wins", "matches"]:
		clean[key] = _safe_integer(raw.get(key), int(clean[key]),0,999999999)
	clean.region = _safe_integer(raw.get("region"),0,0,3)
	clean.appearance = Appearance.sanitize(raw.get("appearance",{}))
	if raw.get("owned") is Array:
		for item_id in raw.owned:
			if item_id is String and not Catalogue.find(items, item_id).is_empty() and item_id not in clean.owned:
				clean.owned.append(item_id)
	if raw.get("equipped") is Dictionary:
		for slot in clean.equipped:
			var item_id = str(raw.equipped.get(slot, ""))
			var item = Catalogue.find(items, item_id)
			if item_id in clean.owned and item.get("slot", "") == slot:
				clean.equipped[slot] = item_id
	if raw.get("settings") is Dictionary:
		for key in ["blood", "shake", "sound", "mouse_only", "brief_seen","combat_brief_v03","combat_brief_v043","combat_brief_v044","aim_cues","slow_motion","vsync"]:
			if raw.settings.get(key) is bool:
				clean.settings[key] = raw.settings[key]
		clean.settings.difficulty = _safe_integer(raw.settings.get("difficulty"),1,0,2)
	return clean

func _safe_integer(value: Variant, fallback: int, low: int, high: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value),low,high))
	return fallback

func save_profile() -> bool:
	var saved = _write_save(save_path,backup_path,profile)
	profile_save_pending = not saved
	profile_save_error = "" if saved else save_error
	return saved

func _write_save(path: String, backup: String, data: Dictionary) -> bool:
	if recovery_required:
		save_error = "请先选择存档恢复方式；原损坏文件尚未替换。"
		return false
	var encoded = JSON.stringify(data,"\t").to_utf8_buffer()
	if encoded.size() > MAX_SAVE_BYTES:
		save_error = "存档内容异常过大，原进度未被替换。"
		return false
	var temp_path = path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_error = "无法写入存档：" + str(FileAccess.get_open_error())
		return false
	file.store_buffer(encoded)
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		save_error = "存档写入未完成：" + str(write_error)
		return false
	# The active profile may be an isolated absolute QA path. Do not open
	# user:// just to rename an unrelated file: that directory may be
	# unavailable while the selected save directory is writable.
	var absolute_path = ProjectSettings.globalize_path(path)
	var absolute_backup = ProjectSettings.globalize_path(backup)
	var absolute_temp = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(path):
		# A corrupt primary must never overwrite the only usable backup.
		if not _read_save(path,data.has("format")).is_empty():
			var backup_error = DirAccess.copy_absolute(absolute_path, absolute_backup)
			if backup_error!=OK:
				save_error = "无法备份原进度："+str(backup_error)
				return false
	var error = DirAccess.rename_absolute(absolute_temp, absolute_path)
	if error != OK:
		save_error = "无法保存进度：" + str(error)
		return false
	save_error = ""
	return true

func _read_save(path: String, manual: bool = false) -> Dictionary:
	# A normal full collection is far smaller than this. Bound parsing before
	# allocation so a damaged or replaced JSON cannot consume the game's Job.
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var length = file.get_length()
	if length == 0 or length > MAX_SAVE_BYTES:
		file.close()
		return {}
	var content = file.get_buffer(length)
	file.close()
	var parser = JSON.new()
	if parser.parse(content.get_string_from_utf8()) != OK or not _valid_save(parser.data,manual):
		return {}
	return parser.data

func _valid_save(data: Variant, manual: bool = false) -> bool:
	if not data is Dictionary or data.get("version",0)!=1:
		return false
	if manual:
		return data.get("format","")=="lance-manual-1" and data.get("profile") is Dictionary and _valid_save(data.profile)
	return data.get("owned") is Array and data.get("equipped") is Dictionary and data.get("settings") is Dictionary

func slot_path(slot: int) -> String:
	# Derived from the active profile: QA can never touch the player's slots.
	return save_path.get_basename()+"_slot_%d.json" % slot

func read_slot(slot: int) -> Dictionary:
	if slot<1 or slot>3:
		return {}
	for path in [slot_path(slot),slot_path(slot)+".backup"]:
		if not FileAccess.file_exists(path):
			continue
		var data = _read_save(path,true)
		if data.is_empty():
			continue
		return {"profile":sanitize(data.profile),"saved_at":str(data.get("saved_at","未知时间")),"recovered":path.ends_with(".backup")}
	return {}

func save_slot(slot: int) -> bool:
	if slot<1 or slot>3:
		save_error = "存档槽不存在"
		return false
	return _write_save(slot_path(slot),slot_path(slot)+".backup",{"version":1,"format":"lance-manual-1","saved_at":Time.get_datetime_string_from_system(false,true),"profile":profile})

func load_slot(slot: int) -> bool:
	var data = read_slot(slot)
	if data.is_empty():
		save_error = "存档为空或已损坏，当前进度未改变"
		return false
	if recovery_required:
		return _accept_recovery(data.profile)
	# A manual load is intentional, but pending match rewards must first be
	# preserved in the automatic backup instead of disappearing from memory.
	if profile_save_pending and not save_profile():
		return false
	var previous = profile.duplicate(true)
	profile = data.profile
	if not save_profile():
		profile = previous
		profile_save_pending = false
		profile_save_error = ""
		return false
	profile_changed.emit()
	return true

func purchase(item_id: String) -> String:
	var item = Catalogue.find(items, item_id)
	if item.is_empty():
		return "物品不存在"
	if item_id in profile.owned:
		return "已经拥有"
	if Catalogue.unlock_era(item) > Catalogue.era_for_renown(int(profile.renown)):
		return "尚未解锁这个时代"
	if int(profile.renown)<Catalogue.required_renown(item):
		return "需要 %d 声望" % Catalogue.required_renown(item)
	if int(profile.coins) < int(item.price):
		return "银币不足"
	var was_pending = profile_save_pending
	var prior_error = profile_save_error
	profile.coins -= int(item.price)
	profile.owned.append(item_id)
	if not save_profile():
		profile.coins += int(item.price)
		profile.owned.erase(item_id)
		profile_save_pending = was_pending
		profile_save_error = prior_error
		return "购买未完成：存档不可写，银币已退回"
	profile_changed.emit()
	return "已收入军械库"

func equip(item_id: String) -> bool:
	var item = Catalogue.find(items, item_id)
	if item.is_empty() or item_id not in profile.owned:
		return false
	var previous = profile.equipped[item.slot]
	var was_pending = profile_save_pending
	var prior_error = profile_save_error
	profile.equipped[item.slot] = item_id
	if not save_profile():
		profile.equipped[item.slot] = previous
		profile_save_pending = was_pending
		profile_save_error = prior_error
		return false
	profile_changed.emit()
	return true

func award_match(session_id: String, outcome: int, mode: String) -> Dictionary:
	if session_awarded.has(session_id):
		return {}
	session_awarded[session_id] = true
	var coins = 55 if outcome < 0 else (110 if outcome == 0 else 180)
	var renown = 1 if outcome <= 0 else 3
	if mode == "war":
		coins += 30
	# EQUIP-067: a caparison is display, not protection; winning under your
	# arms adds a little renown (user approved a non-combat benefit).
	if outcome > 0:
		renown += int(Catalogue.find(items,str(profile.equipped.get("caparison",""))).get("stats",{}).get("caparison_renown",0))
	profile.coins += coins
	profile.renown += renown
	profile.matches += 1
	if outcome > 0:
		profile.wins += 1
	save_profile()
	profile_changed.emit()
	return {"coins": coins, "renown": renown}

func player_stats() -> Dictionary:
	var stats = Catalogue.stats(items, profile.equipped)
	stats.appearance = Appearance.sanitize(profile.get("appearance",{}))
	return stats

func set_appearance(data: Dictionary) -> bool:
	var previous: Dictionary = Appearance.sanitize(profile.get("appearance",{}))
	var was_pending = profile_save_pending
	var prior_error = profile_save_error
	profile.appearance = Appearance.sanitize(data)
	if not save_profile():
		profile.appearance = previous
		profile_save_pending = was_pending
		profile_save_error = prior_error
		return false
	profile_changed.emit()
	return true

func set_setting(key: String, value: Variant) -> void:
	if not profile.settings.has(key):
		return
	profile.settings[key] = value
	save_profile()
	profile_changed.emit()
