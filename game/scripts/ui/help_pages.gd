extends RefCounted
const UI = preload("res://scripts/ui/ui_factory.gd")

static func build(parent: Control, credits: bool, on_rules: Callable, on_credits: Callable, on_back: Callable, license_path: String) -> void:
	UI.button(parent,"玩法速查",Rect2(70,111,235,48),on_rules,not credits)
	UI.button(parent,"制作与许可",Rect2(322,111,235,48),on_credits,credits)
	UI.button(parent,"返回营地",Rect2(1160,111,215,48),on_back)
	var cards = [
		["催马与收速","按住左键或空格催马，松手后逐步收速。\n持续催马消耗马力；太晚发力又可能来不及提速。观察对手来势，留出调枪与举盾的时间。"],
		["枪、盾与身体","鼠标上下调枪；停手更稳。1 / 2 / 3 或点击盾位防守，右键或 Q 循环。\nW / S 倾身；纯鼠标用滚轮、中键回正。枪盾需移动到位，按下不等于已经防住。"],
		["竞技场 · 比武计分","最多三轮，落马提前结束；每轮换新枪但不治疗。\n盾牌实接 1 分，胸腹实击 2 分，头盔实击 3 分，实接断枪另加 1 分。轻触 1 分，擦偏不计分。"],
		["实战 · 伤势与保护","实战允许死亡。有效头部重击可当场结束；头盔、盾牌和擦偏仍可保命，反复有效头伤会累积。\n断枪后保留残柄。本局死亡不会删除收藏。"],
		["装备有取舍","胸甲和头盔分别提供保护；腿部装饰不增加护甲。\n重装、长枪和厚盾有重量代价。马匹速度与稳定性各有所长；十匹坐骑共用四套毛色，不按国家限制。"],
		["判断结果与继续旅程","命中提示区分盾心、盾面、盾缘及身体；结算可展开细节。\n竞技场先比分，同分再看骑手状态；实战无计分胜负。练习不发奖励，可分步上手或自由对冲。"]
	]
	if credits:
		cards = [
			["骑枪与桂冠","GALUMU 项目的历史启发单机骑枪游戏。\n四地区与年代是收藏路线；跨时代拼装不等同于同期原装复原。游戏数值不是历史伤亡统计。"],
			["引擎与字体","Godot Engine 4.5.1 · MIT\nNoto Sans SC · SIL Open Font License 1.1\n发布包的 licenses 文件夹保留完整版权声明和引擎第三方许可。"],
			["美术与音频","美术包含 AI 辅助图像、程序绘制和分件动画整合，不宣称全部由人工逐像素绘制。\n音效与旋律由项目程序生成；未使用其他商业游戏的音频。"],
			["考据与制作","博物馆与文献用于器物结构和年代参考；历史手记、军械库列明具体出处与改编范围。\nCodex 与 Claude 参与开发、整理和验证；玩家无需安装这些工具。"],
			["当前游玩范围","Windows 单机，鼠标与键盘操作；支持纯鼠标姿态选项。\n没有联机、剧情战役、拔刀近战、付费抽取或云存档。手机触控和手柄尚未验收。"],
			["保存与隐私","进度存于你的 Windows 用户文件夹；自动档、备份及三个手动槽各自保留。\n游戏不要求联网账户。查阅博物馆来源时，才会打开你点击的外部网页。"]
		]
	for i in range(cards.size()):
		var card = UI.panel(parent,Rect2(70+(i%3)*440,187+(i/3)*253,425,235))
		card.name = "help_card_%d" % i
		UI.label(card,cards[i][0],Vector2(22,18),24,UI.GOLD,381)
		UI.label(card,cards[i][1],Vector2(22,65),19,UI.INK,381)
	if credits:
		var button = UI.button(parent,"打开许可文件夹",Rect2(70,720,300,49),func():OS.shell_open(license_path))
		button.disabled = license_path.is_empty() or not DirAccess.dir_exists_absolute(license_path)
		UI.label(parent,"许可随完整发布包提供。" if not button.disabled else "完整版权与许可文件随 Windows 发布包提供。",Vector2(400,731),18,UI.MUTED,960)
	else:
		UI.label(parent,"Esc 暂停　·　R 重开　·　F11 全屏　·　H 显示真实判定范围　·　音量与慢动作可在设置中调整",Vector2(70,731),20,UI.MUTED,1300)
