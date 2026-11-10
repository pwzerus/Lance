extends Node2D

const UI = preload("res://scripts/ui/ui_factory.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Battle = preload("res://scripts/battle.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const Appearance = preload("res://scripts/core/character_appearance.gd")
const WindowActivity = preload("res://scripts/core/window_activity.gd")
const BACKGROUND = preload("res://assets/art/pixel_v03/tournament_field.png")

class CharacterFaceCanvas extends Node2D:
	const Face = preload("res://scripts/visual/character_face.gd")
	var appearance: Dictionary = {}
	func _draw() -> void:
		Face.draw_portrait(self,appearance,Rect2(0,0,192,240))

class LanceIcon extends Control:
	const Lance = preload("res://scripts/visual/lance_art.gd")
	var equipment: Dictionary = {}
	func _draw() -> void:
		# HORSE-065 readability: a whole lance fitted to the card width was 2-3
		# px thick, so paint, vamplate and head could not be told apart. Keep
		# the true length across the width but thicken the drawing 2.6x.
		# Every lance shares one scale (longest catalogue reach 290) so a long
		# lance visibly outreaches a light one instead of all filling the card;
		# shaft thickness never drops below 1.6x on small armoury cards.
		var length = float(equipment.get("reach",247))
		var factor = size.x/(290.0+78.0)
		var thick = Vector2(factor,minf(maxf(factor*2.6,1.6),size.y/56.0))
		draw_set_transform(Vector2(67*factor,size.y*.30),0,thick)
		Lance.draw(self,equipment,Vector2.ZERO,0,length,false,0,"arena")
		draw_set_transform(Vector2(67*factor,size.y*.74),0,thick)
		Lance.draw(self,equipment,Vector2.ZERO,0,length,false,0,"war")

class ShieldIcon extends Control:
	const ShieldArt = preload("res://scripts/visual/shield_art.gd")
	var equipment: Dictionary = {}
	func _draw() -> void:
		var factor = minf(size.x/84.0,size.y/108.0)
		ShieldArt.draw(self,equipment,size*.5,false,Color.WHITE,0.0,factor)

class CaparisonIcon extends Control:
	## EQUIP-066: the player's own horse coat with the caparison texture on top,
	## in the player's arms: the same two textures the battle mesh uses.
	const HorseSkin = preload("res://scripts/visual/horse_skin.gd")
	var style = "none"
	var design = "bend"
	var coat = "bay"
	func _draw() -> void:
		var coat_texture = HorseSkin.coat_texture(coat)
		if coat_texture==null:
			return
		var aspect = 1024.0/683.0
		var width = minf(size.x,size.y*aspect)
		var area = Rect2((size-Vector2(width,width/aspect))*.5,Vector2(width,width/aspect))
		draw_texture_rect(coat_texture,area,false)
		var cloth = HorseSkin.caparison_texture(style,design)
		if cloth!=null:
			draw_texture_rect(cloth,area,false)

var ui_layer: CanvasLayer
var screen: Control
var preview: RiderView
var battle: BattleScene
var sounds: SoundBank
var page = "home"
var current_mode = "arena"
var session_id = ""
var pending_result: Dictionary = {}
var reward: Dictionary = {}
var selected_slot = "armor"
var selected_era = 0
var selected_region = 0 # 0 all, 1..4 regions, 5 shared
var selected_quality = 0 # 0 all, 1..6 qualities
var selected_item: Dictionary = {}
var info_panel: Control
var message_label: Label
var currency_label: Label
var result_visible = false
var screenshot_dir = ""
var smoke_mode = false
var shutting_down = false
var smoke_started = 0
var smoke_step = 0
var smoke_busy = false
var smoke_screens: Array = []
var smoke_original_profile: Dictionary = {}
var smoke_contacts: Array = []
var smoke_last_report = 0
var practice_match = false
var appearance_draft: Dictionary = {}
var character_options: Dictionary = {}
var character_face_preview: CharacterFaceCanvas
var brief_overlay: Control
var brief_return_focus: Control
var armory_scroll: ScrollContainer
var armory_scroll_offset = 0
var armory_filter_key = ""
var armory_cards: Dictionary = {}
var settings_notice: Label
var save_error_dialog: AcceptDialog

func _ready() -> void:
	# Windows release must enter the OS Job before any gameplay starts.
	# This is a safety interlock, not a security boundary against manual bypass.
	if OS.get_name()=="Windows" and not OS.has_feature("editor") and OS.get_environment("GALUMU_MEMORY_BOUND")!="1024":
		OS.alert("Please launch with Play-Latest.cmd (memory protection required).", "Lance & Laurel")
		get_tree().quit(2)
		return
	get_window().title = "骑枪与桂冠 · Lance & Laurel v0.4.38"
	print("GALUMU_BUILD v0.4.38")
	get_tree().auto_accept_quit = false
	add_child(WindowActivity.new())
	get_window().min_size = Vector2i(960,540)
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	sounds = SoundBank.new()
	sounds.enabled = GameState.profile.settings.sound
	add_child(sounds)
	var arguments = OS.get_cmdline_user_args()
	for i in range(arguments.size()):
		if arguments[i] == "--smoke-test":
			smoke_mode = true
		if arguments[i] == "--screenshots" and i+1 < arguments.size():
			screenshot_dir = arguments[i+1]
	if smoke_mode:
		smoke_original_profile = GameState.profile.duplicate(true)
		smoke_started = Time.get_ticks_msec()
	show_home()
	if GameState.qa_input_probe:
		get_window().title = "Lance & Laurel v0.4.38 QA - Desktop input"
		var audit = preload("res://scripts/core/desktop_input_audit.gd").new()
		audit.main = self
		add_child(audit)

func _clear_screen() -> void:
	if screen:
		# Deferred deletion keeps the old controls alive until frame end.
		# Hide them immediately so a second queued click cannot hit stale UI.
		screen.hide()
		screen.queue_free()
	if preview:
		preview.hide()
		preview.queue_free()
		preview = null
	screen = Control.new()
	screen.theme = UI.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen)
	message_label = null
	currency_label = null
	character_face_preview = null
	character_options.clear()
	brief_overlay = null
	brief_return_focus = null
	armory_cards.clear()

func _header(subtitle: String) -> void:
	UI.label(screen,"LANCE & LAUREL",Vector2(52,28),25,UI.GOLD)
	UI.label(screen,subtitle,Vector2(340,36),16,UI.MUTED)
	currency_label = UI.label(screen,"银币 %s   声望 %s" % [_short_number(int(GameState.profile.coins)),_short_number(int(GameState.profile.renown))],Vector2(1080,35),18,UI.GOLD)
	UI.separator(screen,Vector2(52,76),1336)

func _short_number(value: int) -> String:
	if value>=100000000:
		return "%.1f亿" % (float(value)/100000000)
	if value>=10000:
		return "%.1f万" % (float(value)/10000)
	return str(value)

func _add_preview(point: Vector2, preview_scale: float = 1.0, stats: Dictionary = {}) -> void:
	if preview:
		preview.queue_free()
	preview = Rider.new()
	preview.fighter = Model.new("arena",GameState.player_stats() if stats.is_empty() else stats).fighters[0]
	preview.fighter.x = 0.0
	preview.fighter.aim = -0.16
	preview.red = int(GameState.profile.region) == 1
	preview.position = point
	preview.scale = Vector2.ONE * preview_scale
	preview.preview = true
	add_child(preview)

func show_home() -> void:
	page = "home"
	_apply_display_settings()
	_clear_screen()
	_header("营地 · 准备下一场交锋")
	var era = Catalogue.era_for_renown(int(GameState.profile.renown))
	var region = int(GameState.profile.region)
	var camp = preload("res://scripts/ui/home_camp.gd").new()
	camp.equipment = GameState.player_stats()
	camp.banner_color = Catalogue.REGION_COLORS[region]
	screen.add_child(camp)
	UI.label(screen,"LANCE  /  LAUREL",Vector2(80,117),17,UI.GOLD)
	UI.label(screen,"骑枪与桂冠",Vector2(74,155),57,UI.INK)
	UI.label(screen,"尘土扬起之前，决定这一枪。",Vector2(80,243),23,UI.MUTED)
	var start = UI.button(screen,"开始游戏",Rect2(78,314,552,76),show_match_setup,true)
	start.add_theme_font_size_override("font_size",26)
	UI.label(screen,"选择竞技场或实战，迎向下一位对手。",Vector2(80,407),17,UI.MUTED)
	UI.button(screen,"军械库",Rect2(78,458,266,72),show_armory)
	UI.button(screen,"练习场",Rect2(364,458,266,72),func():_begin_match("arena",true))
	UI.label(screen,"换上你的纹章与装备",Vector2(94,543),16,UI.MUTED)
	UI.label(screen,"熟悉催马、调枪与防盾",Vector2(380,543),16,UI.MUTED)
	UI.button(screen,"存档 / 继续进度",Rect2(78,600,552,52),show_saves)
	UI.button(screen,"历史手记",Rect2(78,672,172,46),show_history)
	UI.button(screen,"设置",Rect2(268,672,172,46),show_settings)
	UI.button(screen,"保存并退出",Rect2(458,672,172,46),_save_and_exit)
	UI.label(screen,"自动保存已启用 · v0.4.38",Vector2(80,750),15,UI.MUTED)
	UI.label(screen,"你的骑士",Vector2(813,122),16,UI.GOLD)
	UI.label(screen,Catalogue.REGIONS[region]+" · "+Catalogue.ERA_NAMES[era],Vector2(813,161),25,UI.INK)
	UI.label(screen,Catalogue.ERAS[era]+"   /   装备、坐骑与纹章随你出战",Vector2(813,205),15,UI.MUTED)
	UI.button(screen,"角色外观",Rect2(1150,116,220,42),show_character)
	_add_preview(Vector2(1072,660),1.30)
	var champion = UI.panel(screen,Rect2(766,690,606,94),Color(.045,.085,.065,.96))
	var next_era = era+1
	var journey = "下一时代 · "+Catalogue.ERA_NAMES[next_era] if next_era<Catalogue.ERAS.size() else "历代工坊已开放 · 继续你的收藏"
	UI.label(champion,journey,Vector2(22,12),18,UI.GOLD)
	var record_label = UI.label(champion,"%s 胜 / %s 场" % [_short_number(int(GameState.profile.wins)),_short_number(int(GameState.profile.matches))],Vector2(452,14),15,UI.MUTED)
	record_label.size=Vector2(132,24)
	record_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var progress = ColorRect.new()
	progress.position=Vector2(22,49)
	progress.size=Vector2(562,6)
	progress.color=Color("27362b")
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	champion.add_child(progress)
	var progress_fill=ColorRect.new()
	var fraction=1.0 if next_era>=Catalogue.ERAS.size() else clampf(float(int(GameState.profile.renown)-Catalogue.ERA_REQUIREMENTS[era])/float(Catalogue.ERA_REQUIREMENTS[next_era]-Catalogue.ERA_REQUIREMENTS[era]),0,1)
	progress_fill.size=Vector2(562*fraction,6)
	progress_fill.color=UI.GOLD
	progress_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	progress.add_child(progress_fill)
	UI.label(champion,"赢得声望，开启新的时代与工坊。" if next_era<Catalogue.ERAS.size() else "每一件收藏，都有它的来处。",Vector2(22,66),14,UI.MUTED)
	if not GameState.save_error.is_empty():
		UI.label(screen,GameState.save_error,Vector2(80,775),13,Color("efb566"),650)
	queue_redraw()

func show_character() -> void:
	page = "character"
	_clear_screen()
	appearance_draft = Appearance.sanitize(GameState.profile.get("appearance",Appearance.defaults()))
	_header("角色外观 · 像素骑士")
	UI.label(screen,"塑造你的骑士",Vector2(60,111),36,UI.INK)
	UI.label(screen,"即时预览；保存后用于营地与骑乘形象。",Vector2(64,170),18,UI.MUTED,850)
	UI.button(screen,"取消并返回",Rect2(1210,106,175,48),_cancel_character)
	var panel = UI.panel(screen,Rect2(60,215,590,435))
	var keys = ["face_shape","skin","brows","beard","eyes","hair"]
	var titles = ["脸型","肤色","眉毛","胡子","瞳色","发色"]
	for row in range(keys.size()):
		var field: String = keys[row]
		UI.label(panel,titles[row],Vector2(24,29+row*58),20,UI.GOLD)
		var option = OptionButton.new()
		option.position = Vector2(190,20+row*58)
		option.size = Vector2(374,46)
		for label in Appearance.OPTIONS[field]:
			option.add_item(str(label))
		option.selected = int(appearance_draft[field])
		option.item_selected.connect(func(index: int):_change_character_option(field,index))
		panel.add_child(option)
		character_options[field] = option
	UI.label(panel,"外观不改变装备属性或比赛判定。",Vector2(24,390),16,UI.MUTED,540)
	var face_panel = UI.panel(screen,Rect2(715,215,236,340),Color(.055,.10,.08,.95))
	UI.label(face_panel,"无盔头像",Vector2(24,14),18,UI.GOLD)
	character_face_preview = CharacterFaceCanvas.new()
	character_face_preview.position = Vector2(737,272)
	character_face_preview.appearance = appearance_draft.duplicate(true)
	screen.add_child(character_face_preview)
	UI.label(face_panel,"眼睛与眉须细节预览",Vector2(24,307),14,UI.MUTED,205)
	UI.label(screen,"当前装备 · 骑乘预览",Vector2(1010,222),18,UI.GOLD)
	var stats = GameState.player_stats().duplicate(true)
	stats["appearance"] = appearance_draft.duplicate(true)
	_add_preview(Vector2(1170,620),.9,stats)
	UI.label(screen,"头盔按当前装备显示；闭盔会遮住部分面容。",Vector2(715,646),15,UI.MUTED,670)
	UI.button(screen,"保存并返回",Rect2(60,686,380,58),_save_character,true)
	UI.button(screen,"取消修改",Rect2(460,686,190,58),_cancel_character)
	message_label = UI.label(screen,"尚未保存 · 修改只影响本页预览",Vector2(715,691),17,UI.MUTED,670)
	queue_redraw()

func _change_character_option(field: String, index: int) -> void:
	if page!="character" or not Appearance.OPTIONS.has(field):
		return
	appearance_draft[field] = index
	appearance_draft = Appearance.sanitize(appearance_draft)
	if is_instance_valid(preview):
		preview.fighter.stats["appearance"] = appearance_draft.duplicate(true)
		preview.queue_redraw()
	if is_instance_valid(character_face_preview):
		character_face_preview.appearance = appearance_draft.duplicate(true)
		character_face_preview.queue_redraw()
	if is_instance_valid(message_label):
		message_label.text = "尚未保存 · 修改只影响本页预览"
		message_label.add_theme_color_override("font_color",UI.MUTED)

func _save_character() -> void:
	if page!="character":
		return
	if GameState.set_appearance(appearance_draft):
		show_home()
		return
	if is_instance_valid(message_label):
		message_label.text = "保存失败 · "+GameState.save_error+"\n修改仍在本页，可重试或取消。"
		message_label.add_theme_color_override("font_color",Color("efb566"))

func _cancel_character() -> void:
	appearance_draft.clear()
	show_home()

func show_match_setup() -> void:
	page = "setup"
	_clear_screen()
	_header("出战 · 选择模式与对手")
	UI.label(screen,"选择你的交锋",Vector2(60,115),38,UI.INK)
	UI.button(screen,"返回营地",Rect2(1208,105,175,48),show_home)
	var descriptions = ["非致死比武 · 每轮领取新枪\n最多三次对冲，落马可提前决胜。","头部有效重击可致命，头盔可抵挡\n断枪跨轮保留，收藏不会丢失。","熟悉催马、枪线和三档盾位\n对手按轮次换盾，不计胜负奖励。"]
	for i in range(3):
		var card = UI.panel(screen,Rect2(60+i*449,200,430,260))
		UI.label(card,["竞技场","实战","练习场"][i],Vector2(24,22),30,UI.GOLD)
		UI.label(card,descriptions[i],Vector2(24,83),19,UI.INK,382)
		var selected = i
		UI.button(card,["进入竞技场","进入实战","开始练习"][i],Rect2(24,182,382,54),func():_begin_match("war" if selected==1 else "arena",selected==2),i==0)
	UI.label(screen,"对手难度",Vector2(64,494),22,UI.GOLD)
	var ai_names = preload("res://scripts/core/opponent_ai.gd").NAMES
	var ai_notes = ["反应较慢，压枪更早，留出观察时间。","会判断来枪与暴露部位，有反应延迟。","更晚收招，会变招与记住上一轮的来枪。"]
	for i in range(3):
		var difficulty = i
		var button = UI.button(screen,ai_names[i],Rect2(60+i*449,539,430,49),func():
			GameState.set_setting("difficulty",difficulty)
			show_match_setup())
		button.toggle_mode = true
		button.button_pressed = int(GameState.profile.settings.difficulty)==i
		button.add_theme_stylebox_override("pressed",UI.box(Color("b69a60"),Color("f0d08c"),5))
		button.add_theme_color_override("font_pressed_color",Color("15221e"))
		UI.label(screen,ai_notes[i],Vector2(64+i*449,604),16,UI.MUTED,421)
	UI.label(screen,"难度改变反应与决策，不增加对手生命或伤害。练习场使用固定教学节奏。",Vector2(64,659),17,UI.MUTED,1200)
	UI.label(screen,"地区线",Vector2(64,722),18,UI.GOLD)
	var region = OptionButton.new()
	region.position = Vector2(165,709)
	region.size = Vector2(250,47)
	for name_value in Catalogue.REGIONS:
		region.add_item(name_value)
	region.selected = int(GameState.profile.region)
	region.item_selected.connect(func(index):
		GameState.profile.region = index
		GameState.save_profile()
		if is_instance_valid(message_label):
			message_label.text = "地区设置已应用，但暂未保存；回营地可重试保存。" if not GameState.save_error.is_empty() else ""
			message_label.tooltip_text = GameState.save_error)
	screen.add_child(region)
	UI.label(screen,"地区选择只影响装饰偏好，已购装备仍可使用。",Vector2(450,722),17,UI.MUTED,820)
	message_label = UI.label(screen,"设置已应用，但暂未保存；回营地可重试保存。" if not GameState.save_error.is_empty() else "",Vector2(64,772),14,Color("efb566"),1300)
	queue_redraw()

func show_saves(notice: String = "") -> void:
	page = "saves"
	_clear_screen()
	_header("存档 · 收藏、装备与养成进度")
	UI.label(screen,"保留你的骑士旅程",Vector2(60,112),38,UI.INK)
	UI.button(screen,"返回营地",Rect2(1208,105,175,48),show_home)
	var auto_card = UI.panel(screen,Rect2(60,191,1320,137))
	UI.label(auto_card,"当前进度 · 自动保存",Vector2(24,18),25,UI.GOLD)
	UI.label(auto_card,"银币 %s  ·  声望 %s  ·  %s 场比赛" % [_short_number(int(GameState.profile.coins)),_short_number(int(GameState.profile.renown)),_short_number(int(GameState.profile.matches))],Vector2(24,65),20,UI.INK)
	UI.button(auto_card,"立即保存",Rect2(896,43,180,50),func():show_saves("已保存当前进度" if GameState.save_profile() else GameState.save_error))
	UI.button(auto_card,"继续游戏",Rect2(1100,43,194,50),show_match_setup,true)
	for i in range(3):
		var slot = i+1
		var data = GameState.read_slot(slot)
		var card = UI.panel(screen,Rect2(60+i*449,360,430,300))
		UI.label(card,"手动存档 %d" % slot,Vector2(24,20),26,UI.GOLD)
		if data.is_empty():
			UI.label(card,"空槽 / 暂无可读取的存档",Vector2(24,76),18,UI.MUTED,382)
		else:
			UI.label(card,data.saved_at+(" · 备份恢复" if data.recovered else ""),Vector2(24,75),16,UI.MUTED,382)
			UI.label(card,"银币 %s  ·  声望 %s\n%s · %s 场比赛" % [_short_number(int(data.profile.coins)),_short_number(int(data.profile.renown)),Catalogue.REGIONS[int(data.profile.region)],_short_number(int(data.profile.matches))],Vector2(24,112),19,UI.INK,382)
		UI.button(card,"保存到此槽" if data.is_empty() else "覆盖此槽",Rect2(24,211,184,53),func():show_saves("已保存到存档 %d" % slot if GameState.save_slot(slot) else GameState.save_error))
		var load_button = UI.button(card,"读取进度",Rect2(223,211,183,53),func():
			if GameState.load_slot(slot):
				sounds.set_enabled(GameState.profile.settings.sound)
				show_saves("已读取存档 %d；原自动存档保留为备份" % slot)
			else:
				show_saves(GameState.save_error))
		load_button.disabled = data.is_empty()
	UI.label(screen,"存档保留收藏、装备与设置；对冲从新比赛开始，不保存战斗中的位置。",Vector2(64,692),18,UI.MUTED,1290)
	UI.label(screen,notice,Vector2(64,739),20,UI.GOLD,1290)
	queue_redraw()

func _save_and_exit() -> void:
	if shutting_down:
		return
	if GameState.save_profile():
		_shutdown_and_quit()
		return
	if is_instance_valid(save_error_dialog) and not save_error_dialog.is_queued_for_deletion():
		save_error_dialog.dialog_text = GameState.save_error+"\n游戏尚未退出，请检查磁盘空间或写入权限后重试。"
		return
	var dialog = AcceptDialog.new()
	save_error_dialog = dialog
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = "保存未成功"
	dialog.dialog_text = GameState.save_error+"\n游戏尚未退出，请检查磁盘空间或写入权限后重试。"
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(610,180))

func _shutdown_and_quit() -> void:
	if shutting_down:
		return
	shutting_down = true
	set_process(false)
	set_process_unhandled_input(false)
	get_viewport().gui_disable_input = true
	# stop() queues mixer cleanup. Keep the tree alive briefly so looped WAV
	# playbacks are released before AudioServer teardown (also after battle).
	if sounds:
		sounds.set_enabled(false)
		sounds.stop_all()
	_close_battle()
	await get_tree().create_timer(.12,true,false,true).timeout
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		_save_and_exit()

func _begin_match(mode: String, practice: bool = false) -> void:
	if GameState.profile.settings.get("combat_brief_v044",false):
		_start_match(mode,practice)
		return
	if is_instance_valid(brief_overlay):
		return
	brief_return_focus = get_viewport().gui_get_focus_owner()
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.70)
	shade.size = Vector2(1440,810)
	brief_overlay = shade
	screen.add_child(shade)
	var panel = UI.panel(shade,Rect2(270,95,900,620),Color(.045,.085,.065,.99))
	UI.label(panel,"上场前 · 四个动作",Vector2(30,24),32,UI.GOLD)
	UI.label(panel,"你在左侧。马匹自动前进，枪和盾都需要时间移动。",Vector2(30,78),20,UI.INK,840)
	var controls = [
		["催马 · 左键 / 空格","按住加速，松手收速；留意马匹体力。"],
		["瞄准 · 上下移动鼠标","抬枪、压枪有过程；停手稳枪。"],
		["防盾 · 1 / 2 / 3","护头 / 护胸 / 护腹；右键或Q循环。"],
		["姿态 · W / S","前倾支撑；后仰避头，同时暴露腰腹。"]]
	for i in range(controls.size()):
		var card=UI.panel(panel,Rect2(30+(i%2)*430,124+(i/2)*96,410,82),Color(.10,.16,.12,.95))
		UI.label(card,controls[i][0],Vector2(15,10),20,UI.GOLD,380)
		UI.label(card,controls[i][1],Vector2(15,43),16,UI.INK,380)
	UI.separator(panel,Vector2(30,329),840)
	var rules = "竞技场 · 最多三轮，落马提前决胜，每轮换新枪；不会死亡。\n盾1 · 胸腹2 · 头盔3；护甲化解1分，擦偏0分，非擦偏断枪+1。"
	if mode=="war":
		rules = "实战 · 有效头部重击可致命，头盔、盾牌和入射角仍有作用。\n擦过可存活；断枪跨轮保留。骑手死亡不会丢失收藏。"
	elif practice:
		rules = "练习场 · 对手按轮次换盾，最多三次对冲。\n没有金币或声望奖惩，先熟悉加减速、瞄准和防盾。"
	UI.label(panel,rules,Vector2(30,347),19,UI.INK,840)
	UI.label(panel,"枪尖颜色与部位框提示当前枪线，并不保证最终命中。",Vector2(30,423),17,UI.GOLD,840)
	UI.label(panel,"Esc 暂停　R 重开　H 判定范围　F11 全屏",Vector2(30,465),16,UI.MUTED,840)
	var begin = UI.button(panel,"明白了，出战",Rect2(30,522,540,58),func():
		for key in ["brief_seen","combat_brief_v043","combat_brief_v044"]:
			GameState.profile.settings[key]=true
		GameState.save_profile()
		_start_match(mode,practice),true)
	var cancel = UI.button(panel,"返回选择",Rect2(590,522,280,58),_dismiss_brief)
	UI.focus_actions([begin,cancel])

func _dismiss_brief() -> void:
	if is_instance_valid(brief_overlay):
		brief_overlay.hide()
		brief_overlay.queue_free()
	brief_overlay=null
	if is_instance_valid(brief_return_focus) and brief_return_focus.is_visible_in_tree():
		brief_return_focus.grab_focus()
	brief_return_focus=null

func _start_match(mode: String, practice: bool = false) -> void:
	_close_battle()
	practice_match = practice
	current_mode = mode
	page = "battle"
	_clear_screen()
	if sounds:
		sounds.music.stop()
	session_id = str(Time.get_ticks_usec())
	pending_result = {}
	reward = {}
	result_visible = false
	battle = Battle.new()
	battle.mode = mode
	battle.practice = practice
	battle.autoplay = smoke_mode
	battle.demo_seed = 271828 if smoke_mode else 0
	battle.finished.connect(_on_match_finished)
	battle.exit_requested.connect(func():
		_close_battle()
		show_home())
	battle.replay_requested.connect(func():_start_match(current_mode,practice_match))
	add_child(battle)
	queue_redraw()

func _close_battle() -> void:
	if battle:
		remove_child(battle)
		battle.queue_free()
		battle = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sounds and sounds.enabled and sounds.music and not sounds.music.playing:
		sounds.music.play()

func _on_match_finished(result: Dictionary) -> void:
	pending_result = result
	var outcome = 0 if int(result.winner) == -1 else (1 if int(result.winner)==0 else -1)
	reward = {"coins":0,"renown":0} if practice_match else GameState.award_match(session_id,outcome,current_mode)

func _process(_delta: float) -> void:
	if battle and battle.is_finished and not result_visible:
		show_result()
	if smoke_mode:
		_run_smoke()

func show_result() -> void:
	result_visible = true
	var result = pending_result
	var won = int(result.get("winner",-1)) == 0
	var draw = int(result.get("winner",-1)) == -1
	sounds.play("win" if won else "lose",-9)
	var panel = UI.panel(screen,Rect2(332,116,776,578),Color(.045,.085,.065,.98))
	UI.label(panel,"练习结束 · 不计输赢与奖励" if practice_match else (("竞技场" if current_mode=="arena" else "实战")+" · "+preload("res://scripts/core/opponent_ai.gd").NAMES[int(GameState.profile.settings.difficulty)]),Vector2(35,22),16,UI.GOLD)
	UI.label(panel,"平分秋色" if draw else ("桂冠属于你" if won else "此番惜败"),Vector2(35,62),42,UI.INK)
	var explanation = "三次对冲后的骑手状态决胜"
	if result.get("reason") == "terminal":
		explanation = "双方同时失去继续战斗能力" if draw else "落马或失去继续战斗能力"
	elif result.get("reason") == "score":
		explanation = "按比武计分决胜；护甲化解记擦中，擦偏不计分。"
	elif current_mode=="arena":
		explanation = "比分相同，按骑手状态决胜"
	if result.get("player_dead",false) or result.get("enemy_dead",false):
		explanation = "实战致命伤 · 本局终止，收藏保留"
	UI.label(panel,explanation,Vector2(35,128),18,UI.MUTED,706)
	UI.separator(panel,Vector2(35,177),706)
	var status_line = "你的骑手状态  %d%%        对手  %d%%" % [roundi(float(result.get("player_hp",0))),roundi(float(result.get("enemy_hp",0)))]
	if current_mode=="arena":
		status_line = "比分  %d : %d        骑手状态  %d%% : %d%%" % [int(result.get("player_score",0)),int(result.get("enemy_score",0)),roundi(float(result.get("player_hp",0))),roundi(float(result.get("enemy_hp",0)))]
	UI.label(panel,status_line,Vector2(35,199),20,UI.INK)
	# Long armour/glance explanations must never grow over rewards/buttons.
	var report_scroll = ScrollContainer.new()
	report_scroll.name = "ContactReport"
	report_scroll.position = Vector2(35,242)
	report_scroll.size = Vector2(706,110)
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(report_scroll)
	var report = preload("res://scripts/ui/combat_report.gd")
	var contacts: Array = battle.exchange_log if battle else []
	var report_label = UI.label(report_scroll,report.summarize(contacts,current_mode),Vector2.ZERO,17,UI.INK,684)
	report_label.name = "ContactSummary"
	var details = UI.check(panel,"详细数据",false,Vector2(570,16),func(value):
		report_label.text=report.summarize(contacts,current_mode,value)
		report_scroll.scroll_vertical=0)
	details.name = "ShowContactDetails"
	details.set_deferred("size",Vector2(170,42))
	var reward_label = UI.label(panel,"银币  +%s           声望  +%s" % [reward.get("coins",0),reward.get("renown",0)],Vector2(35,363),23,UI.GOLD)
	reward_label.name = "ResultRewards"
	var next_era = Catalogue.era_for_renown(int(GameState.profile.renown)) + 1
	var progress = "全部时期已开放；继续收集工坊与纹章。" if next_era >= Catalogue.ERAS.size() else "下一时代：%s · 需要 %d 声望（当前 %d）" % [Catalogue.ERAS[next_era],Catalogue.ERA_REQUIREMENTS[next_era],GameState.profile.renown]
	UI.label(panel,progress,Vector2(35,408),15,UI.MUTED,706)
	if not GameState.save_error.is_empty():
		UI.label(panel,"进度暂未写入磁盘，请回营地重试保存。",Vector2(35,441),16,Color("efb566"),706)
	UI.button(panel,"再次对冲  R",Rect2(35,470,344,56),func():_start_match(current_mode,practice_match),true)
	UI.button(panel,"返回营地",Rect2(397,470,344,56),func():
		_close_battle()
		show_home())

func show_armory() -> void:
	var filter_key = "%s/%d/%d/%d" % [selected_slot,selected_era,selected_region,selected_quality]
	if page=="armory" and is_instance_valid(armory_scroll):
		armory_scroll_offset=armory_scroll.scroll_vertical
	if filter_key!=armory_filter_key:
		armory_scroll_offset=0
	armory_filter_key=filter_key
	page = "armory"
	_clear_screen()
	_header("军械库 · 不同年代，不同用途。")
	UI.label(screen,"武备与纹章",Vector2(55,105),37,UI.INK)
	UI.button(screen,"返回营地",Rect2(1210,100,175,48),show_home)
	# EQUIP-066: the cause of horse fatigue is shown where it is decided.
	var load_text = _load_summary(GameState.player_stats())
	UI.label(screen,load_text.text,Vector2(300,108),15,load_text.color,890)
	var index = 0
	for slot in Catalogue.SLOT_NAMES:
		var slot_value = str(slot)
		# Seven slots (EQUIP-066 added 马衣) share the space the six used.
		UI.button(screen,Catalogue.SLOT_NAMES[slot],Rect2(56+index*95,169,88,43),func():
			selected_slot = slot_value
			selected_item = {}
			show_armory(),selected_slot == slot_value)
		index += 1
	var era_select = OptionButton.new()
	era_select.position = Vector2(724,169)
	era_select.size = Vector2(210,43)
	era_select.add_item("全部年代")
	for i in range(Catalogue.ERAS.size()):
		era_select.add_item(Catalogue.ERAS[i])
	era_select.selected = selected_era+1
	era_select.item_selected.connect(func(value):
		selected_era = value-1
		selected_item = {}
		show_armory())
	screen.add_child(era_select)
	var region_select = OptionButton.new()
	region_select.position = Vector2(946,169)
	region_select.size = Vector2(199,43)
	for region_name in ["全部地区"]+Catalogue.REGIONS+["欧洲共通"]:
		region_select.add_item(region_name)
	region_select.selected = selected_region
	region_select.item_selected.connect(func(value):
		selected_region = value
		selected_item = {}
		show_armory())
	screen.add_child(region_select)
	var quality_select = OptionButton.new()
	quality_select.position = Vector2(1157,169)
	quality_select.size = Vector2(228,43)
	for quality_name in ["全部品质","新手","初级","中级","中高级","高级","最高级"]:
		quality_select.add_item(quality_name)
	quality_select.selected = selected_quality
	quality_select.item_selected.connect(func(value):
		selected_quality = value
		selected_item = {}
		show_armory())
	screen.add_child(quality_select)
	var scroll = ScrollContainer.new()
	scroll.name="ArmoryList"
	armory_scroll=scroll
	scroll.position = Vector2(55,236)
	scroll.size = Vector2(830,478)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	scroll.add_child(grid)
	var filtered: Array = []
	for item in GameState.items:
		if bool(item.get("legacy",false)) and item.id not in GameState.profile.owned:
			continue
		var region_match = selected_region==0 or item.region==("欧洲共通" if selected_region==5 else Catalogue.REGIONS[maxi(0,selected_region-1)])
		var quality_match = selected_quality==0 or int(item.get("quality",-1))==selected_quality-1
		if item.slot == selected_slot and (selected_era<0 or int(item.era) == selected_era) and region_match and quality_match:
			filtered.append(item)
	for item in filtered:
		var item_value = item
		var owned = item.id in GameState.profile.owned
		var equipped = GameState.profile.equipped.get(item.slot) == item.id
		var card = Button.new()
		card.custom_minimum_size = Vector2(397,126)
		card.text = ""
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_contents = true
		card.add_theme_font_size_override("font_size",14)
		card.tooltip_text = item.description
		card.toggle_mode = true
		card.add_theme_stylebox_override("pressed",UI.box(Color("34452f"),UI.GOLD,5))
		card.pressed.connect(func():
			selected_item = item_value
			_update_item_panel())
		grid.add_child(card)
		armory_cards[item.id]=card
		# Wider icon well (was 72x88): equipment differences were too small to see.
		var title = UI.label(card,("◆ " if equipped else "")+str(item.name),Vector2(14,10),17,UI.INK,218)
		title.max_lines_visible = 2
		var period=UI.label(card,"%s · %s" % [item.get("historical_window",Catalogue.ERAS[int(item.era)]),item.get("quality_name","旧藏")],Vector2(14,65),14,UI.MUTED,218)
		period.autowrap_mode=TextServer.AUTOWRAP_OFF
		period.clip_text=true
		period.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		period.tooltip_text=period.text
		UI.label(card,"已装备" if equipped else ("已收藏" if owned else ("%d 银币 · 声望 %d" % [item.price,Catalogue.required_renown(item)])),Vector2(14,94),15,UI.GOLD,218)
		_add_item_icon(card,item,Vector2(236,8),Vector2(152,100),true)
	if filtered.is_empty():
		var empty=VBoxContainer.new()
		empty.custom_minimum_size=Vector2(790,160)
		empty.add_theme_constant_override("separation",18)
		grid.add_child(empty)
		UI.label(empty,"没有符合当前筛选的装备",Vector2.ZERO,24,UI.GOLD,750)
		var empty_hint = "马匹与马衣为欧洲共通。" if selected_slot in ["horse","caparison"] else "当前地区、年代或品质下没有匹配项。"
		UI.label(empty,empty_hint+"试试清除筛选。",Vector2.ZERO,18,UI.INK,750)
		UI.button(empty,"清除筛选",Rect2(0,0,260,48),func():
			selected_region=0
			selected_era=-1
			selected_quality=0
			selected_item={}
			show_armory())
	info_panel = UI.panel(screen,Rect2(925,229,460,507),Color(.055,.10,.08,.95))
	info_panel.clip_contents = true
	if selected_item.is_empty() and not filtered.is_empty():
		selected_item = filtered[0]
	_update_item_panel()
	scroll.set_deferred("scroll_vertical",armory_scroll_offset)
	message_label = UI.label(screen,"收藏解锁不等于史实复原。每件装备保留来源与改编说明。",Vector2(57,744),16,UI.MUTED,830)
	queue_redraw()

func _player_heraldry() -> String:
	return str(GameState.player_stats().get("heraldry","bend"))

func _load_summary(stats: Dictionary) -> Dictionary:
	var Condition = Model.Condition
	var carried = Condition.load_kg(stats)
	var capacity = Condition.capacity_kg(stats)
	var ratio = carried/maxf(1.0,capacity)
	var band = "轻快" if ratio<.90 else ("适中" if ratio<1.02 else "沉重")
	var color = Color("9fd08a") if ratio<.90 else (UI.GOLD if ratio<1.02 else Color("e08a6a"))
	return {"text":"整备负重 %d kg（护具 %d kg）/ 马匹舒适承载 %d kg · %s" % [roundi(carried),roundi(Condition.worn_kg(stats)),roundi(capacity),band],"color":color}

func _add_item_icon(parent: Control, item: Dictionary, point: Vector2, dimensions: Vector2, deferred_card: bool = false) -> Control:
	var icon: Control
	if item.slot=="lance":
		var lance_icon = LanceIcon.new()
		lance_icon.equipment = item.stats
		icon = lance_icon
	elif item.slot=="shield" and item.stats.has("shield_shape"):
		# Shields are shown in the player's own arms: quality reads as build.
		var shield_icon = ShieldIcon.new()
		shield_icon.equipment = item.stats.duplicate()
		shield_icon.equipment["heraldry"] = _player_heraldry()
		icon = shield_icon
	elif item.slot=="crest":
		# A crest card shows the arms themselves (was a blank coloured shield).
		var crest_icon = ShieldIcon.new()
		crest_icon.equipment = {"shield_shape":"heater","shield_quality":2,"heraldry":str(item.stats.get("heraldry","bend"))}
		icon = crest_icon
	elif item.slot=="caparison":
		var cloth_icon = CaparisonIcon.new()
		cloth_icon.style = str(item.stats.get("caparison_style","none"))
		cloth_icon.design = _player_heraldry()
		cloth_icon.coat = str(GameState.player_stats().get("horse_coat","bay"))
		icon = cloth_icon
	else:
		var texture: TextureRect
		if deferred_card and item.slot in ["armor","helmet"]:
			texture = preload("res://scripts/ui/equipment_icon.gd").new()
			texture.equipment = item
		else:
			texture = TextureRect.new()
			texture.texture = Art.item_icon(item)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon = texture
	icon.position = point
	icon.size = dimensions
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	icon.set_deferred("size",dimensions)
	if item.slot=="lance" and dimensions.x>=120:
		UI.label(icon,"比武冠头",Vector2(0,3),11,UI.MUTED)
		UI.label(icon,"实战尖头",Vector2(0,dimensions.y*.5),11,UI.MUTED)
	return icon

func _update_item_panel() -> void:
	for id in armory_cards:
		armory_cards[id].set_pressed_no_signal(id==selected_item.get("id",""))
	for child in info_panel.get_children():
		child.queue_free()
	if selected_item.is_empty():
		info_panel.visible=false
		return
	info_panel.visible=true
	var item = selected_item
	UI.label(info_panel,item.name,Vector2(22,16),22,UI.GOLD,415)
	UI.label(info_panel,"%s · %s · %s" % [item.region,item.get("quality_name","旧藏"),item.get("historical_window",Catalogue.ERAS[int(item.era)])],Vector2(22,76),13,UI.MUTED,415)
	UI.label(info_panel,item.description,Vector2(22,112),15,UI.INK,200)
	_add_item_icon(info_panel,item,Vector2(232,100),Vector2(206,140))
	var detail = ""
	for key in item.stats:
		var value = item.stats[key]
		match str(key):
			"armor": detail += "躯干防护  %d%%   " % roundi(float(value)*100)
			"helmet": detail += "头部防护  %d%%   " % roundi(float(value)*100)
			"power": detail += "冲击修正  ×%.2f   " % value
			"reach": detail += "枪长  %d   " % value
			"durability": detail += "耐久  %d   " % value
			"speed": detail += "速度  ×%.2f   " % value
			"stability": detail += "鞍上稳定  ×%.2f   " % value
			"lance_handling": detail += "调枪速度  ×%.2f   " % value
			"shield_capacity": detail += "盾耐久  %d   " % value
			"shield_handling": detail += "换盾速度  ×%.2f   " % value
			"armor_kg","helmet_kg","shield_kg","lance_kg","caparison_kg":
				detail += "重量  %.1f kg   " % value
			"caparison_renown":
				detail += "获胜额外声望  +%d   " % value
	if item.slot=="caparison":
		detail += "不提供防护"
	elif item.slot=="armor" or item.slot=="helmet":
		detail += "越重越护身，但马更易累、调枪换盾更慢"
	var scroll = ScrollContainer.new()
	scroll.name = "ProvenanceScroll"
	scroll.position = Vector2(22,246)
	scroll.size = Vector2(416,143)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)
	var paragraphs = VBoxContainer.new()
	paragraphs.add_theme_constant_override("separation",8)
	scroll.add_child(paragraphs)
	for text_value in [detail,"腿甲花纹只作装饰，不增加防护值。" if item.slot=="armor" else "","制造地："+str(item.manufacture) if item.has("manufacture") else "",str(item.get("use_context","")),"考据："+str(item.source),str(item.historical_note)]:
		if str(text_value).is_empty():
			continue
		UI.label(paragraphs,str(text_value),Vector2.ZERO,14,UI.GOLD if text_value==detail else UI.MUTED,394)
	if item.has("source_url"):
		var source_url = str(item.source_url)
		UI.button(info_panel,"查看馆藏来源 ↗",Rect2(22,397,202,30),func(): OS.shell_open(source_url))
	UI.label(info_panel,"数值为游戏平衡设定",Vector2(242,404),12,UI.MUTED,190)
	var owned = item.id in GameState.profile.owned
	var era_unlocked = int(GameState.profile.renown)>=Catalogue.required_renown(item)
	var equipped = GameState.profile.equipped.get(item.slot) == item.id
	var can_afford = int(GameState.profile.coins)>=int(item.price)
	var action_text = "购买 · %d 银币" % item.price
	if equipped:
		action_text = "已装备"
	elif owned:
		action_text = "装备"
	elif not era_unlocked:
		action_text = "需要 %d 声望" % Catalogue.required_renown(item)
	elif not can_afford:
		action_text = "还差 %d 银币" % (int(item.price)-int(GameState.profile.coins))
	var action = UI.button(info_panel,action_text,Rect2(22,441,412,44),func():
		if owned:
			if GameState.equip(item.id):
				show_armory()
				message_label.text="已装备 · "+str(item.name)
			else:
				message_label.text="装备未更换 · "+GameState.save_error
		else:
			var notice = GameState.purchase(item.id)
			show_armory()
			message_label.text = notice
			sounds.play("click",-12),true)
	action.disabled = equipped or (not owned and (not era_unlocked or not can_afford))

func show_settings() -> void:
	page = "settings"
	_clear_screen()
	_header("设置 · 让每一次交锋更适合你。")
	var panel = UI.panel(screen,Rect2(70,123,680,656))
	UI.label(panel,"游戏设置",Vector2(28,24),34,UI.GOLD)
	UI.check(panel,"显示血腥表现",GameState.profile.settings.blood,Vector2(28,104),func(value):_change_setting("blood",value))
	UI.label(panel,"关闭只隐藏血迹与伤口；实战依然允许死亡。",Vector2(28,150),16,UI.MUTED)
	UI.check(panel,"镜头震动",GameState.profile.settings.shake,Vector2(28,195),func(value):_change_setting("shake",value))
	UI.check(panel,"音乐与音效",GameState.profile.settings.sound,Vector2(28,250),func(value):
		_change_setting("sound",value)
		sounds.set_enabled(value))
	UI.check(panel,"纯鼠标姿态控制",GameState.profile.settings.mouse_only,Vector2(28,305),func(value):_change_setting("mouse_only",value))
	UI.label(panel,"滚轮前后调倾身，中键回正；鼠标瞄准，左键加速。",Vector2(28,353),16,UI.MUTED,620)
	UI.label(panel,"AI 难度",Vector2(28,406),19,UI.INK)
	var difficulty = OptionButton.new()
	difficulty.position = Vector2(183,398)
	difficulty.size = Vector2(280,45)
	for value in preload("res://scripts/core/opponent_ai.gd").NAMES:
		difficulty.add_item(value)
	difficulty.selected = int(GameState.profile.settings.difficulty)
	difficulty.item_selected.connect(func(value):_change_setting("difficulty",value))
	panel.add_child(difficulty)
	UI.check(panel,"垂直同步 · 撕裂时开启",bool(GameState.profile.settings.get("vsync",false)),Vector2(28,452),func(value):_change_setting("vsync",value))
	UI.label(panel,"关闭可减少显示等待；游戏仍限制为最高 60 帧。",Vector2(28,499),15,UI.MUTED,620)
	settings_notice = UI.label(panel,"修改后自动保存",Vector2(28,538),15,UI.MUTED,620)
	UI.button(panel,"返回营地",Rect2(28,581,620,49),show_home,true)
	UI.panel(screen,Rect2(810,123,565,596),Color(.055,.10,.08,.95))
	UI.label(screen,"操作",Vector2(844,150),32,UI.GOLD)
	UI.label(screen,"移动鼠标　瞄准；大幅改向会失稳\n左键 / 空格　按住催马，松开减速\n1 / 2 / 3　护头 / 护胸 / 护腹（右键循环）\nW / S　　 前倾支撑 / 后仰避头\nH　　　　 显示判定范围\nEsc　　　 暂停与设置\nR 重开　　F11 全屏",Vector2(844,219),22,UI.INK,510)
	UI.label(screen,"触控输入已预留：左侧滑动倾身，右侧瞄准，\n右侧额外触点加速；尚未在手机设备验收。",Vector2(844,510),17,UI.MUTED,510)
	UI.check(screen,"接近时放缓与命中慢动作",GameState.profile.settings.slow_motion,Vector2(844,600),func(value):_change_setting("slow_motion",value))
	UI.check(screen,"显示枪线颜色与部位提示",GameState.profile.settings.aim_cues,Vector2(844,656),func(value):_change_setting("aim_cues",value))
	queue_redraw()

func _change_setting(key: String, value: Variant) -> void:
	GameState.set_setting(key,value)
	if key=="vsync": _apply_display_settings()
	if page=="settings" and is_instance_valid(settings_notice):
		var saved = GameState.save_error.is_empty()
		settings_notice.text = "已保存设置" if saved else "设置已应用，但暂未保存；可回营地重试保存。"
		settings_notice.add_theme_color_override("font_color",UI.MUTED if saved else Color("efb566"))
		settings_notice.tooltip_text = GameState.save_error

func _apply_display_settings() -> void:
	# Keep the independent 60 FPS cap in WindowActivity. On this Windows/GL
	# setup swap synchronization stalled isolated rendering far below budget.
	# Players can restore sync if tearing is visible; no quality or RAM change.
	if DisplayServer.get_name()=="headless": return
	var requested = DisplayServer.VSYNC_ENABLED if bool(GameState.profile.settings.get("vsync",false)) else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode()!=requested:
		DisplayServer.window_set_vsync_mode(requested)

func show_history() -> void:
	page = "history"
	_clear_screen()
	_header("历史手记 · 器物有来处，改编有说明。")
	UI.label(screen,"枪尖之外的历史",Vector2(56,107),37,UI.INK)
	UI.button(screen,"返回营地",Rect2(1210,101,175,48),show_home)
	var entries = [
		["四地区，早期共通", "12 世纪至 13 世纪早期，英、法、德、意骑手装备并不截然不同。本作先保留结构共性，再扩充地区与个人装饰。", "Met · Fashion 1000–1300", "https://www.metmuseum.org/essays/fashion-in-european-armor-1000-1300"],
		["比武也可能用尖头枪", "冠状多齿头与尖头枪头有各自赛事语境。名字中含“war”的比武并不自动等于真实战场杀敌。", "Met · Four Lance Heads", "https://www.metmuseum.org/art/collection/search/35791"],
		["钢铁并不等于僵硬", "合身战场甲与专用比武甲需要分别理解。后者可能集中保护来枪方向，前者还要兼顾多方向威胁与活动。", "Wallace · Armour A23", "https://wallacelive.wallacecollection.org/eMP/eMuseumPlus?module=collection&objectId=60514&service=ExternalInterface"],
		["马匹不只比巨大", "英格兰考古研究提醒：中世纪马匹的体格、性情、训练与用途要结合看待，不能把现代巨型挽马作为唯一模板。", "University of Exeter", "https://news-archive.exeter.ac.uk/2022/january/articles/medievalwarhorsesweresurp.html"],
		["装饰有结构和年代", "盾徽、头饰、绘画、蚀刻和镀金丰富了骑士形象。收藏可以跨时代，拼装却不应被宣传成同代原装复原。", "Met · Decoration of Armor", "https://www.metmuseum.org/essays/the-decoration-of-european-armor"],
		["我们的规则与历史边界", "竞技场绝不死亡、实战低断枪倾向、固定隔栏分道、三轮与 HP 决胜，均属于本作游戏规则。史实不提供可照抄的统一断枪率。", "项目考据档案 · 38 项来源", ""]]
	for i in range(entries.size()):
		var entry = entries[i]
		var card = UI.panel(screen,Rect2(56+(i%3)*449,180+(i/3)*271,430,250))
		UI.label(card,entry[0],Vector2(20,17),23,UI.GOLD)
		UI.label(card,entry[1],Vector2(20,66),17,UI.INK,389)
		UI.label(card,entry[2],Vector2(20,190),13,UI.MUTED,389)
		if not str(entry[3]).is_empty():
			var url = str(entry[3])
			UI.button(card,"查阅来源 ↗",Rect2(255,207,150,31),func():OS.shell_open(url))
	UI.label(screen,"这里是历史启发的游戏，装备数值与奖励属于设计；更多注释在项目 docs 中。",Vector2(56,750),16,UI.MUTED)
	queue_redraw()

func _draw() -> void:
	if page == "battle":
		return
	draw_texture_rect(BACKGROUND,Rect2(0,0,1440,810),false,Color(.57,.62,.55))
	for i in range(18):
		var alpha = .62 * (1.0-float(i)/18)
		draw_rect(Rect2(i*80,0,80,810),Color(.025,.055,.041,alpha))
	draw_rect(Rect2(0,0,1440,86),Color(.035,.07,.05,.92))
	draw_rect(Rect2(0,786,1440,24),Color(.03,.055,.04,.7))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keys = [event.keycode,event.physical_keycode]
		if KEY_F11 in keys:
			var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif KEY_ESCAPE in keys and page != "battle":
			if is_instance_valid(brief_overlay):
				_dismiss_brief()
			else:
				show_home()
		elif KEY_R in keys and page == "battle" and result_visible:
			_start_match(current_mode,practice_match)

func _run_smoke() -> void:
	if Time.get_ticks_msec()-smoke_last_report>5000:
		smoke_last_report = Time.get_ticks_msec()
		print("SMOKE_PROGRESS elapsed=",Time.get_ticks_msec()-smoke_started," step=",smoke_step," busy=",smoke_busy," phase=",battle.match_model.phase if battle else page," pass=",battle.match_model.pass_number if battle else 0," scale=",Engine.time_scale," fps=",Engine.get_frames_per_second())
	if smoke_busy:
		return
	smoke_busy = true
	var elapsed = Time.get_ticks_msec() - smoke_started
	if battle and not battle.effects.bursts.is_empty() and current_mode not in smoke_contacts:
		smoke_contacts.append(current_mode)
		await _capture("08_arena_impact" if current_mode=="arena" else "09_war_impact")
	if smoke_step == 0 and elapsed > 1000:
		await _capture("01_home")
		smoke_step = 1
	elif smoke_step == 1 and elapsed > 2100:
		show_armory()
		smoke_step = 2
	elif smoke_step == 2 and elapsed > 3100:
		await _capture("02_armory")
		show_history()
		smoke_step = 3
	elif smoke_step == 3 and elapsed > 4200:
		await _capture("03_history")
		_start_match("arena")
		smoke_step = 4
	elif smoke_step == 4 and battle and battle.match_model.phase == "charge" and battle.match_model.fighters[0].x > -330:
		await _capture("04_arena")
		smoke_step = 5
	elif smoke_step == 5 and result_visible:
		await _capture("05_result")
		smoke_step = 6
		get_tree().create_timer(1.0).timeout.connect(func():_start_match("war"))
	elif smoke_step == 6 and current_mode == "war" and battle and battle.match_model.phase == "charge" and absf(float(battle.match_model.fighters[0].x)-float(battle.match_model.fighters[1].x))<750:
		await _capture("06_war")
		smoke_step = 7
	elif smoke_step == 7 and current_mode == "war" and result_visible:
		await _capture("07_war_result")
		smoke_step = 8
		GameState.profile = smoke_original_profile
		GameState.save_profile()
		print("SMOKE_TEST_COMPLETE: " + str(smoke_screens))
		get_tree().create_timer(1.0).timeout.connect(_shutdown_and_quit)
	if elapsed > 180000:
		GameState.profile = smoke_original_profile
		GameState.save_profile()
		push_error("Smoke test timed out at step " + str(smoke_step))
		get_tree().quit(1)
	smoke_busy = false

func _capture(name_value: String) -> void:
	if screenshot_dir.is_empty():
		return
	var directory_error = DirAccess.make_dir_recursive_absolute(screenshot_dir)
	if directory_error != OK:
		push_error("Cannot create smoke capture directory: " + screenshot_dir)
		get_tree().quit(2)
		return
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = screenshot_dir.path_join(name_value + ".png")
	var error = image.save_png(path)
	print("SCREENSHOT: " + path + " " + str(error))
	if error != OK:
		push_error("Smoke capture failed: " + path)
		get_tree().quit(2)
		return
	smoke_screens.append(name_value)
