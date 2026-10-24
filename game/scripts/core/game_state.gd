extends Node

signal profile_changed

const Catalogue = preload("res://scripts/core/catalogue.gd")
const SAVE_PATH = "user://profile_v1.json"
const BACKUP_PATH = "user://profile_v1.backup.json"
var save_path = SAVE_PATH
var backup_path = BACKUP_PATH
var items: Array = []
var profile: Dictionary = {}
var session_awarded: Dictionary = {}
var save_error = ""

func _ready() -> void:
	var arguments = OS.get_cmdline_user_args()
	if arguments.has("--smoke-test") or arguments.has("--test-profile"):
		save_path = "user://qa_profile_v1.json"
		backup_path = "user://qa_profile_v1.backup.json"
	items = Catalogue.load_items()
	profile = default_profile()
	load_profile()

func default_profile() -> Dictionary:
	return {"version": 1, "coins": 520, "renown": 0, "wins": 0, "matches": 0, "region": 0,
		"owned": ["mail_basic", "helm_nasal", "lance_ash", "horse_bay", "crest_bend"],
		"equipped": {"armor": "mail_basic", "helmet": "helm_nasal", "lance": "lance_ash", "horse": "horse_bay", "crest": "crest_bend"},
		"settings": {"blood": false, "shake": true, "sound": true, "mouse_only": false, "brief_seen":false, "difficulty": 1}}

func load_profile() -> void:
	for path in [save_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		if parser.data is Dictionary and parser.data.get("version", 0) == 1:
			profile = sanitize(parser.data)
			return

func sanitize(raw: Dictionary) -> Dictionary:
	var clean = default_profile()
	for key in ["coins", "renown", "wins", "matches"]:
		clean[key] = _safe_integer(raw.get(key), int(clean[key]),0,999999999)
	clean.region = _safe_integer(raw.get("region"),0,0,3)
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
		for key in ["blood", "shake", "sound", "mouse_only", "brief_seen"]:
			if raw.settings.get(key) is bool:
				clean.settings[key] = raw.settings[key]
		clean.settings.difficulty = _safe_integer(raw.settings.get("difficulty"),1,0,2)
	return clean

func _safe_integer(value: Variant, fallback: int, low: int, high: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value),low,high))
	return fallback

func save_profile() -> bool:
	var temp_path = save_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_error = "无法写入存档：" + str(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		save_error = "存档写入未完成：" + str(write_error)
		return false
	var folder = DirAccess.open("user://")
	if FileAccess.file_exists(save_path):
		# A corrupt primary must never overwrite the only usable backup.
		var prior = JSON.new()
		if prior.parse(FileAccess.get_file_as_string(save_path)) == OK and prior.data is Dictionary and prior.data.get("version",0)==1:
			folder.copy(save_path, backup_path)
	var error = folder.rename(temp_path, save_path)
	if error != OK:
		save_error = "无法保存进度：" + str(error)
		return false
	save_error = ""
	return true

func purchase(item_id: String) -> String:
	var item = Catalogue.find(items, item_id)
	if item.is_empty():
		return "物品不存在"
	if item_id in profile.owned:
		return "已经拥有"
	if int(item.era) > Catalogue.era_for_renown(int(profile.renown)):
		return "尚未解锁这个时代"
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
	return Catalogue.stats(items, profile.equipped)

func set_setting(key: String, value: Variant) -> void:
	if not profile.settings.has(key):
		return
	profile.settings[key] = value
	save_profile()
	profile_changed.emit()
