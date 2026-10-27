extends Node2D

const UI = preload("res://scripts/ui/ui_factory.gd")
const Catalogue = preload("res://scripts/core/catalogue.gd")
const Rider = preload("res://scripts/visual/rider_view.gd")
const Model = preload("res://scripts/core/joust_match.gd")
const Battle = preload("res://scripts/battle.gd")
const Art = preload("res://scripts/visual/equipment_art.gd")
const BACKGROUND = preload("res://assets/art/pixel_v03/tournament_field.png")

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
var selected_item: Dictionary = {}
var info_panel: Control
var message_label: Label
var currency_label: Label
var result_visible = false
var screenshot_dir = ""
var smoke_mode = false
var smoke_started = 0
var smoke_step = 0
var smoke_busy = false
var smoke_screens: Array = []
var smoke_original_profile: Dictionary = {}
var smoke_contacts: Array = []
var smoke_last_report = 0
var practice_match = false

func _ready() -> void:
	get_window().title = "骑枪与桂冠 · Lance & Laurel v0.4.1"
	print("GALUMU_BUILD v0.4.1")
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
		get_window().title = "Lance & Laurel v0.4.1 QA - Desktop input"
		var audit = preload("res://scripts/core/desktop_input_audit.gd").new()
		audit.main = self
		add_child(audit)

func _clear_screen() -> void:
	if screen:
		screen.queue_free()
	if preview:
		preview.queue_free()
		preview = null
	screen = Control.new()
	screen.theme = UI.theme()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(screen)
	message_label = null
	currency_label = null

func _header(subtitle: String) -> void:
	UI.label(screen,"LANCE & LAUREL",Vector2(52,28),25,UI.GOLD)
	UI.label(screen,subtitle,Vector2(340,36),16,UI.MUTED)
	currency_label = UI.label(screen,"银币  %s     声望  %s" % [GameState.profile.coins,GameState.profile.renown],Vector2(1080,35),18,UI.GOLD)
	UI.separator(screen,Vector2(52,76),1336)

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
	_clear_screen()
	_header("一杆长枪，一次交锋。")
	UI.label(screen,"骑枪与桂冠",Vector2(58,116),52,UI.INK)
	UI.label(screen,"THE LISTS AWAIT",Vector2(62,190),19,UI.GOLD)
	UI.label(screen,"以身体读懂来枪，以速度决定交锋。\n从锁甲与纹章的年代，走向你的骑士收藏。",Vector2(62,236),22,UI.INK,690)
	var mode_a = UI.panel(screen,Rect2(62,337,340,180))
	UI.label(mode_a,"竞技场",Vector2(20,15),27,UI.GOLD)
	UI.label(mode_a,"非致死比武 · 每轮新枪\n三次对冲，或一次落马定胜负。",Vector2(20,60),16,UI.MUTED,300)
	UI.button(mode_a,"披挂上场",Rect2(20,119,300,43),func():_begin_match("arena"),true)
	var mode_b = UI.panel(screen,Rect2(420,337,340,180))
	UI.label(mode_b,"实战",Vector2(20,15),27,Color("cd8f77"))
	UI.label(mode_b,"允许死亡 · 断枪跨轮保留\n更危险的枪尖，更沉重的后果。",Vector2(20,60),16,UI.MUTED,300)
	UI.button(mode_b,"接受挑战",Rect2(20,119,300,43),func():_begin_match("war"))
	UI.button(screen,"军械库 / 购买与装备",Rect2(62,541,340,54),show_armory)
	UI.button(screen,"历史手记",Rect2(420,541,164,54),show_history)
	UI.button(screen,"设置",Rect2(596,541,164,54),show_settings)
	UI.button(screen,"练习场 · 熟悉枪盾（不计输赢）",Rect2(62,650,698,42),func():_begin_match("arena",true))
	UI.label(screen,"地区线",Vector2(65,611),17,UI.MUTED)
	var region = OptionButton.new()
	region.position = Vector2(155,603)
	region.size = Vector2(245,40)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var compact_style = region.get_theme_stylebox(state_name).duplicate()
		compact_style.content_margin_top = 4
		compact_style.content_margin_bottom = 4
		region.add_theme_stylebox_override(state_name,compact_style)
	for name_value in Catalogue.REGIONS:
		region.add_item(name_value)
	region.selected = int(GameState.profile.region)
	region.item_selected.connect(func(index):
		GameState.profile.region = index
		GameState.save_profile()
		show_home())
	screen.add_child(region)
	UI.label(screen,"当前年代  " + Catalogue.ERAS[Catalogue.era_for_renown(int(GameState.profile.renown))],Vector2(420,611),17,UI.GOLD)
	UI.separator(screen,Vector2(62,696),698)
	UI.label(screen,"鼠标瞄准   左键加速   W/S 倾身   Esc 暂停",Vector2(62,718),17,UI.MUTED)
	UI.label(screen,"单机试玩版  ·  Windows  ·  v0.4.1 · 骑手与马匹",Vector2(62,751),14,UI.MUTED)
	UI.button(screen,"退出游戏",Rect2(608,739,150,38),func():
		GameState.save_profile()
		get_tree().quit())
	UI.label(screen,"YOUR CHAMPION",Vector2(941,154),18,UI.GOLD)
	UI.label(screen,"胸肩朝镜头，枪尖朝对手。",Vector2(910,190),17,UI.INK)
	_add_preview(Vector2(1070,663),1.42)
	var champion = UI.panel(screen,Rect2(883,682,489,90),Color(.07,.12,.095,.91))
	UI.label(champion,"%s  ·  %d 胜 / %d 场" % [Catalogue.REGIONS[int(GameState.profile.region)],GameState.profile.wins,GameState.profile.matches],Vector2(20,14),21,UI.GOLD)
	UI.label(champion,"装备与进度自动保存；实战死亡不会删除收藏。",Vector2(20,49),15,UI.MUTED)
	if not GameState.save_error.is_empty():
		UI.label(screen,GameState.save_error,Vector2(62,779),13,Color("df927b"))
	queue_redraw()

func _begin_match(mode: String, practice: bool = false) -> void:
	if GameState.profile.settings.get("combat_brief_v03",false):
		_start_match(mode,practice)
		return
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.70)
	shade.size = Vector2(1440,810)
	screen.add_child(shade)
	var panel = UI.panel(shade,Rect2(315,135,810,540),Color(.045,.085,.065,.99))
	UI.label(panel,"第一次披挂上场",Vector2(32,24),34,UI.GOLD)
	UI.label(panel,"你在左侧，马匹会自动前进。",Vector2(32,85),21,UI.INK)
	UI.label(panel,"左键 / 空格　按住冲刺；点按催马，倒计时内也会保留。\n上下移动鼠标　调枪尖高度；停手压稳，大幅变招会失稳。\n右键 / Q　高低盾切换：高盾护头，低盾护腹，另一处暴露。\nW 前倾 / S 后仰　后仰避高枪，但削弱攻击并暴露腰腹。\nH 判定范围　Esc 暂停　R 重开　F11 全屏",Vector2(32,139),18,UI.INK,746)
	UI.separator(panel,Vector2(32,295),746)
	UI.label(panel,"最多三次对冲；落马提前结束。三轮后比较骑手状态。\n竞技场每轮领取新枪，不会死亡。实战允许死亡，断枪保留。",Vector2(32,316),18,UI.MUTED,746)
	UI.label(panel,"战斗没有准星，观察手臂与枪尖。先在竞技场熟悉瞄准。",Vector2(32,396),17,UI.GOLD,746)
	UI.button(panel,"明白了，出战",Rect2(32,448,480,58),func():
		GameState.set_setting("brief_seen",true)
		GameState.set_setting("combat_brief_v03",true)
		_start_match(mode,practice),true)
	UI.button(panel,"返回营地",Rect2(530,448,248,58),func():shade.queue_free())

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
	UI.label(panel,"练习结束 · 不计输赢与奖励" if practice_match else "HONOUR IN THE LISTS",Vector2(35,22),16,UI.GOLD)
	UI.label(panel,"平分秋色" if draw else ("桂冠属于你" if won else "此番惜败"),Vector2(35,62),42,UI.INK)
	var explanation = "三次对冲后的骑手状态决胜"
	if result.get("reason") == "terminal":
		explanation = "双方同时失去继续战斗能力" if draw else "落马或失去继续战斗能力"
	if result.get("player_dead",false) or result.get("enemy_dead",false):
		explanation = "实战致命伤 · 本局终止，收藏保留"
	UI.label(panel,explanation,Vector2(35,128),18,UI.MUTED,706)
	UI.separator(panel,Vector2(35,177),706)
	UI.label(panel,"你的骑手状态  %d%%        对手  %d%%" % [roundi(float(result.get("player_hp",0))),roundi(float(result.get("enemy_hp",0)))],Vector2(35,199),20,UI.INK)
	UI.label(panel,preload("res://scripts/ui/combat_report.gd").summarize(battle.exchange_log if battle else []),Vector2(35,244),17,UI.INK,706)
	UI.label(panel,"银币  +%s           声望  +%s" % [reward.get("coins",0),reward.get("renown",0)],Vector2(35,363),23,UI.GOLD)
	var next_era = Catalogue.era_for_renown(int(GameState.profile.renown)) + 1
	var progress = "全部时期已开放；继续收集工坊与纹章。" if next_era >= Catalogue.ERAS.size() else "下一时代：%s · 需要 %d 声望（当前 %d）" % [Catalogue.ERAS[next_era],Catalogue.ERA_REQUIREMENTS[next_era],GameState.profile.renown]
	UI.label(panel,progress,Vector2(35,408),15,UI.MUTED,706)
	UI.button(panel,"再次对冲  R",Rect2(35,470,344,56),func():_start_match(current_mode,practice_match),true)
	UI.button(panel,"返回营地",Rect2(397,470,344,56),func():
		_close_battle()
		show_home())

func show_armory() -> void:
	page = "armory"
	_clear_screen()
	_header("军械库 · 不同年代，不同用途。")
	UI.label(screen,"武备与纹章",Vector2(55,105),37,UI.INK)
	UI.button(screen,"返回营地",Rect2(1210,100,175,48),show_home)
	var index = 0
	for slot in Catalogue.SLOT_NAMES:
		var slot_value = str(slot)
		UI.button(screen,Catalogue.SLOT_NAMES[slot],Rect2(56+index*147,169,136,43),func():
			selected_slot = slot_value
			selected_item = {}
			show_armory(),selected_slot == slot_value)
		index += 1
	var era_select = OptionButton.new()
	era_select.position = Vector2(820,169)
	era_select.size = Vector2(230,43)
	for i in range(Catalogue.ERAS.size()):
		era_select.add_item(Catalogue.ERAS[i])
	era_select.selected = selected_era
	era_select.item_selected.connect(func(value):
		selected_era = value
		selected_item = {}
		show_armory())
	screen.add_child(era_select)
	var scroll = ScrollContainer.new()
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
		if item.slot == selected_slot and int(item.era) == selected_era:
			filtered.append(item)
	for item in filtered:
		var item_value = item
		var owned = item.id in GameState.profile.owned
		var equipped = GameState.profile.equipped.get(item.slot) == item.id
		var card = Button.new()
		card.custom_minimum_size = Vector2(397,116)
		card.text = "%s%s\n%s · %s\n%s" % ["◆ " if equipped else "",item.name,item.region,Catalogue.ERAS[int(item.era)],"已装备" if equipped else ("已收藏" if owned else "%d 银币" % item.price)]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_contents = true
		card.add_theme_font_size_override("font_size",16)
		card.pressed.connect(func():
			selected_item = item_value
			_update_item_panel())
		grid.add_child(card)
		var icon = TextureRect.new()
		icon.texture = Art.item_icon(item)
		icon.position = Vector2(309,12)
		icon.size = Vector2(72,88)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		icon.set_deferred("size",Vector2(72,88))
	if filtered.is_empty():
		UI.label(grid,"这个时期的该类装备仍在整理中。",Vector2.ZERO,18,UI.MUTED)
	info_panel = UI.panel(screen,Rect2(925,229,460,507),Color(.055,.10,.08,.95))
	info_panel.clip_contents = true
	if selected_item.is_empty() and not filtered.is_empty():
		selected_item = filtered[0]
	_update_item_panel()
	message_label = UI.label(screen,"收藏解锁不等于史实复原。每件装备保留来源与改编说明。",Vector2(57,744),16,UI.MUTED,830)
	queue_redraw()

func _update_item_panel() -> void:
	for child in info_panel.get_children():
		child.queue_free()
	if selected_item.is_empty():
		return
	var item = selected_item
	UI.label(info_panel,item.name,Vector2(22,18),25,UI.GOLD,415)
	UI.label(info_panel,"%s · %s" % [item.region,item.get("historical_window",Catalogue.ERAS[int(item.era)])],Vector2(22,61),15,UI.MUTED,415)
	UI.label(info_panel,item.description,Vector2(22,101),16,UI.INK,312)
	var icon = TextureRect.new()
	icon.texture = Art.item_icon(item)
	icon.position = Vector2(344,101)
	icon.size = Vector2(90,126)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(icon)
	icon.set_deferred("size",Vector2(90,126))
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
	UI.label(info_panel,detail,Vector2(22,248),17,UI.GOLD,412)
	UI.separator(info_panel,Vector2(22,310),412)
	UI.label(info_panel,"考据  " + str(item.source),Vector2(22,326),14,UI.MUTED,412)
	UI.label(info_panel,item.historical_note,Vector2(22,358),14,UI.MUTED,412)
	var owned = item.id in GameState.profile.owned
	var era_unlocked = int(item.era) <= Catalogue.era_for_renown(int(GameState.profile.renown))
	var equipped = GameState.profile.equipped.get(item.slot) == item.id
	var action_text = "已装备" if equipped else ("装备" if owned else ("购买 · %d 银币" % item.price if era_unlocked else "需要 %d 声望" % Catalogue.ERA_REQUIREMENTS[int(item.era)]))
	var action = UI.button(info_panel,action_text,Rect2(22,421,412,55),func():
		if owned:
			GameState.equip(item.id)
			show_armory()
		else:
			var notice = GameState.purchase(item.id)
			show_armory()
			message_label.text = notice
			sounds.play("click",-12),true)
	action.disabled = equipped or not era_unlocked

func show_settings() -> void:
	page = "settings"
	_clear_screen()
	_header("设置 · 让每一次交锋更适合你。")
	var panel = UI.panel(screen,Rect2(70,123,680,596))
	UI.label(panel,"游戏设置",Vector2(28,24),34,UI.GOLD)
	UI.check(panel,"显示血腥表现",GameState.profile.settings.blood,Vector2(28,104),func(value):GameState.set_setting("blood",value))
	UI.label(panel,"关闭只隐藏血迹与伤口；实战依然允许死亡。",Vector2(28,150),16,UI.MUTED)
	UI.check(panel,"镜头震动",GameState.profile.settings.shake,Vector2(28,195),func(value):GameState.set_setting("shake",value))
	UI.check(panel,"音乐与音效",GameState.profile.settings.sound,Vector2(28,250),func(value):
		GameState.set_setting("sound",value)
		sounds.set_enabled(value))
	UI.check(panel,"纯鼠标姿态控制",GameState.profile.settings.mouse_only,Vector2(28,305),func(value):GameState.set_setting("mouse_only",value))
	UI.label(panel,"滚轮前后调倾身，中键回正；鼠标瞄准，左键加速。",Vector2(28,353),16,UI.MUTED,620)
	UI.label(panel,"AI 难度",Vector2(28,406),19,UI.INK)
	var difficulty = OptionButton.new()
	difficulty.position = Vector2(183,398)
	difficulty.size = Vector2(280,45)
	for value in ["初学 · 较慢反应","标准 · 读招与速度","老练 · 更精准的来枪"]:
		difficulty.add_item(value)
	difficulty.selected = int(GameState.profile.settings.difficulty)
	difficulty.item_selected.connect(func(value):GameState.set_setting("difficulty",value))
	panel.add_child(difficulty)
	UI.button(panel,"返回营地",Rect2(28,493,620,59),show_home,true)
	UI.label(screen,"操作",Vector2(844,150),32,UI.GOLD)
	UI.label(screen,"移动鼠标　瞄准；大幅改向会失稳\n左键 / 空格　按住冲刺；点按催马\n右键 / Q　高低盾切换\nW / S　　 前倾支撑 / 后仰避头\nH　　　　 显示判定范围\nEsc　　　 暂停与设置\nR 重开　　F11 全屏",Vector2(844,219),22,UI.INK,510)
	UI.label(screen,"触控输入已预留：左侧滑动倾身，右侧瞄准，\n右侧额外触点加速；尚未在手机设备验收。",Vector2(844,510),17,UI.MUTED,510)
	UI.check(screen,"接近时放缓与命中慢动作",GameState.profile.settings.slow_motion,Vector2(844,600),func(value):GameState.set_setting("slow_motion",value))
	queue_redraw()

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
		if event.physical_keycode == KEY_F11:
			var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.physical_keycode == KEY_ESCAPE and page != "battle":
			show_home()
		elif event.physical_keycode == KEY_R and page == "battle" and result_visible:
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
		get_tree().create_timer(1.0).timeout.connect(func():get_tree().quit())
	if elapsed > 180000:
		GameState.profile = smoke_original_profile
		GameState.save_profile()
		push_error("Smoke test timed out at step " + str(smoke_step))
		get_tree().quit(1)
	smoke_busy = false

func _capture(name_value: String) -> void:
	if screenshot_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var path = screenshot_dir.path_join(name_value + ".png")
	var error = image.save_png(path)
	print("SCREENSHOT: " + path + " " + str(error))
	smoke_screens.append(name_value)
