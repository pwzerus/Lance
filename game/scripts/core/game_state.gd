extends Node

signal profile_changed

const Catalogue = preload("res://scripts/core/catalogue.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const SAVE_PATH = "user://profile_v1.json"
const BACKUP_PATH = "user://profile_v1.backup.json"
var save_path = SAVE_PATH
var backup_path = BACKUP_PATH
var items: Array = []
var profile: Dictionary = {}
var session_awarded: Dictionary = {}
var save_error = ""
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
		"owned": ["mail_basic", "helm_nasal", "lance_ash", "horse_bay", "crest_bend", "shield_basic"],
		"equipped": {"armor": "mail_basic", "helmet": "helm_nasal", "lance": "lance_ash", "horse": "horse_bay", "crest": "crest_bend", "shield":"shield_basic"},
		"settings": {"blood": false, "shake": true, "sound": true, "mouse_only": false, "brief_seen":false,"combat_brief_v03":false,"combat_brief_v043":false,"combat_brief_v044":false,"aim_cues":true,"slow_motion":true, "difficulty": 1}}

func load_profile() -> void:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		if _valid_save(parser.data):
			profile = sanitize(parser.data)
			return

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
		for key in ["blood", "shake", "sound", "mouse_only", "brief_seen","combat_brief_v03","combat_brief_v043","combat_brief_v044","aim_cues","slow_motion"]:
			if raw.settings.get(key) is bool:
				clean.settings[key] = raw.settings[key]
		clean.settings.difficulty = _safe_integer(raw.settings.get("difficulty"),1,0,2)
	return clean

func _safe_integer(value: Variant, fallback: int, low: int, high: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value),low,high))
	return fallback

func save_profile() -> bool:
	return _write_save(save_path,backup_path,profile)

func _write_save(path: String, backup: String, data: Dictionary) -> bool:
	var temp_path = path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_error = "无法写入存档：" + str(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		save_error = "存档写入未完成：" + str(write_error)
		return false
	var folder = DirAccess.open("user://")
	if FileAccess.file_exists(path):
		# A corrupt primary must never overwrite the only usable backup.
		var prior = JSON.new()
		if prior.parse(FileAccess.get_file_as_string(path)) == OK and _valid_save(prior.data, data.has("format")):
			var backup_error = folder.copy(path, backup)
			if backup_error!=OK:
				save_error = "无法备份原进度："+str(backup_error)
				return false
	var error = folder.rename(temp_path, path)
	if error != OK:
		save_error = "无法保存进度：" + str(error)
		return false
	save_error = ""
	return true

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
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Dictionary:
			continue
		var data: Dictionary = parser.data
		if not _valid_save(data,true):
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
	var previous = profile.duplicate(true)
	profile = data.profile
	if not save_profile():
		profile = previous
		return false
	profile_changed.emit()
	return true

func purchase(item_id: String) -> String:
	var item = Catalogue.find(items, item_id)
	if item.is_empty():
		return "物品不存在"
	if item_id in profile.owned:
		return "已经拥有"
	if int(item.era) > Catalogue.era_for_renown(int(profile.renown)):
		return "尚未解锁这个时代"
	if int(profile.renown)<Catalogue.required_renown(item):
		return "需要 %d 声望" % Catalogue.required_renown(item)
	if int(profile.coins) < int(item.price):
		return "银币不足"
	profile.coins -= int(item.price)
	profile.owned.append(item_id)
	if not save_profile():
		profile.coins += int(item.price)
		profile.owned.erase(item_id)
		return "购买未完成：存档不可写，银币已退回"
	profile_changed.emit()
	return "已收入军械库"

func equip(item_id: String) -> bool:
	var item = Catalogue.find(items, item_id)
	if item.is_empty() or item_id not in profile.owned:
		return false
	var previous = profile.equipped[item.slot]
	profile.equipped[item.slot] = item_id
	if not save_profile():
		profile.equipped[item.slot] = previous
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
	profile.appearance = Appearance.sanitize(data)
	if not save_profile():
		profile.appearance = previous
		return false
	profile_changed.emit()
	return true

func set_setting(key: String, value: Variant) -> void:
	if not profile.settings.has(key):
		return
	profile.settings[key] = value
	save_profile()
	profile_changed.emit()
