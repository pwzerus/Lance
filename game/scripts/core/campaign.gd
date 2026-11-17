extends RefCounted
## LEVEL-092: an 80-level jousting campaign (8 chapters x 10 levels).
## Deterministic: every level is built from its number, never from RNG state,
## so saves only store which levels are cleared. Each opponent has a kit
## archetype (armour, helmet, lance, horse, shield combination) and an AI
## profile (skill = decision precision, awareness = reaction/reading,
## aggression = how early and how hard they press). Difficulty never changes
## combat stats: only equipment and decisions differ.
const Catalogue = preload("res://scripts/core/catalogue.gd")
const COUNT = 80
const PER_CHAPTER = 10
const CHAPTERS = ["乡间比武","郡守之杯","勃艮第之路","莱茵骑士会","米兰金枪","王家比武大会","圣乔治骑士团","桂冠之巅"]
const CHAPTER_NOTES = [
	"入门比武：前几关对手出手慢、空当明显。先护胸，再把枪稳稳送向胸腹。",
	"郡守设下奖杯。骑手开始懂得护住要害。",
	"沿商路南下，遇到装备更好的游历骑士。",
	"莱茵河畔的骑士会。重甲与长枪成了常客。",
	"米兰工坊的金枪手。他们反应更快，也会变招。",
	"王家大会，四国好手齐聚。",
	"骑士团的精英，几乎不给你第二次机会。",
	"最后的冠军们。每一枪都可能决定桂冠归属。"]
const REGION_KEYS = ["eng","fr","de","it"]
const GIVEN = {
	"eng":["威廉","托马斯","理查","约翰","亨利","休","罗伯特","杰弗里"],
	"fr":["让","皮埃尔","路易","纪尧姆","贝特朗","雅克","于格","戈德弗鲁瓦"],
	"de":["康拉德","奥托","海因里希","弗里德里希","鲁道夫","乌尔里希","沃尔夫冈","哈特曼"],
	"it":["乔瓦尼","马可","洛伦佐","费德里科","安德烈亚","贾科莫","卢卡","朱利亚诺"]}
## Archetype: name, kit offsets (armor, helmet, shield quality), lance type,
## horse line, AI offsets (skill, awareness), aggression, head bias, feint,
## epithets and a one-line counter hint for the player.
const ARCHETYPES = {
	"balanced":{"name":"均衡骑士","armor":0,"helmet":0,"shield":0,"lance":"mixed","horse":"balanced","skill":0.0,"awareness":0.0,"aggression":.5,"head":.0,"feint":false,
		"epithets":["灰鹰","橡木","银桥","北原","长堤"],"hint":"各方面平均。先稳住盾，再找空当。"},
	"swift":{"name":"轻骑","armor":-1,"helmet":-1,"shield":-1,"lance":"light","horse":"fast","skill":.10,"awareness":-.10,"aggression":.85,"head":.0,"feint":false,
		"epithets":["疾风","飞燕","白驹","雀鹰"],"hint":"轻甲快马，冲得早。护甲薄：瞄胸腹就能见效。"},
	"heavy":{"name":"重甲骑士","armor":1,"helmet":1,"shield":1,"lance":"stout","horse":"stable","skill":0.0,"awareness":-.20,"aggression":.30,"head":.0,"feint":false,
		"epithets":["铁塔","重锤","黑岩","铜墙"],"hint":"护甲厚、视野窄、起步慢。打头或绕开大盾，也可以靠速度压迫。"},
	"reach":{"name":"长枪手","armor":0,"helmet":0,"shield":-1,"lance":"long","horse":"balanced","skill":.05,"awareness":0.0,"aggression":.55,"head":.0,"feint":false,
		"epithets":["长影","远矛","苍杉"],"hint":"长枪先到。提前立盾，别在最后一刻才防。"},
	"bulwark":{"name":"铁壁","armor":0,"helmet":0,"shield":1,"lance":"stout","horse":"stable","skill":-.10,"awareness":.25,"aggression":.35,"head":.0,"feint":false,
		"epithets":["铁壁","坚盾","石门"],"hint":"大盾、读枪准。盾挡住的地方别硬打，换高低线。"},
	"headhunter":{"name":"猎首者","armor":-1,"helmet":0,"shield":0,"lance":"long","horse":"fast","skill":.10,"awareness":0.0,"aggression":.90,"head":.45,"feint":false,
		"epithets":["夺盔","断喉","红喙"],"hint":"专打头盔。护头，或后仰躲开，再还他一枪。"},
	"trickster":{"name":"诡枪","armor":0,"helmet":-1,"shield":0,"lance":"mixed","horse":"balanced","skill":.05,"awareness":.10,"aggression":.60,"head":.15,"feint":true,
		"epithets":["狐影","双面","迷雾"],"hint":"会先亮一条枪线再变招。盯住最后的枪尖。"}}
const ORDER = ["balanced","swift","heavy","balanced","reach","bulwark","headhunter","trickster","swift","heavy","reach","balanced"]
const HORSES = {"fast":["horse_grey","horse_e1","horse_e3","horse_courser"],
	"stable":["horse_cob","horse_chestnut","horse_e2","horse_steady"],
	"balanced":["horse_bay","horse_bay","horse_e4","horse_e4"]}
const CRESTS = ["crest_bend","crest_chevron","crest_cross","crest_diamond","crest_saltire","crest_quarterly",
	"crest_pale","crest_fess","crest_chequy","crest_roundels","crest_chief","crest_fleur"]
const CAPARISONS = ["caparison_none","caparison_linen","caparison_wool","caparison_velvet"]

## LEVEL-096 (user approved "ease the final chapter"): above TOP_KNEE the AI
## profile rises more slowly. level096-curve01 had levels 60/65 (skill ~1.6)
## at 9-10/12 but 70/75/80 (skill 1.94-2.0, at the cap) at 5/12: the last
## stretch of the curve was a cliff. Skill tops out at ~1.82 (still a veteran,
## feints at >=1.75); awareness at ~1.78. Below the knee nothing changes.
## The reach archetype's skill bonus is .05 (was .15): its edge is the long
## lance; with the extra skill it was the hardest opponent of chapters 6 and 8
## (levels 55 and 75 lowest in every 12-game sample).
const TOP_KNEE = 1.5
const SKILL_TOP_SLOPE = .65
const AWARENESS_TOP_SLOPE = .55

static var _cache: Array = []

static func top_ease(value: float, slope: float) -> float:
	return value if value<=TOP_KNEE else TOP_KNEE+(value-TOP_KNEE)*slope

static func levels(items: Array) -> Array:
	if _cache.size()==COUNT:
		return _cache
	var result: Array = []
	for n in range(1,COUNT+1):
		result.append(build(items,n))
	_cache = result
	return result

static func level(items: Array, number: int) -> Dictionary:
	if number<1 or number>COUNT:
		return {}
	return levels(items)[number-1]

## Gear quality the level is built around (0..5).
static func base_quality(n: int) -> int:
	if n<=10: return 0
	if n<=22: return 1
	if n<=36: return 2
	if n<=52: return 3
	if n<=66: return 4
	return 5

static func _q(value: int) -> int:
	return clampi(value,0,5)

static func shield_quality(kind: String, quality: int) -> int:
	var line_tier = clampi(quality/2,0,2)
	return line_tier*2+(1 if kind in ["heavy","bulwark"] or (kind=="balanced" and quality%2==1) else 0)

## LEVEL-100: explicit onboarding, fading out before the first war match.
## Changes decisions/gear, never a hidden damage or player-health multiplier.
static func training_strength(n: int) -> float:
	if n<1 or n>=15: return 0.0
	return [1.0,1.0,1.0,.92,.84,.76,.68,.60,.52,.44,.34,.25,.16,.08][n-1]

static func build(items: Array, n: int) -> Dictionary:
	var chapter = (n-1)/PER_CHAPTER
	var position = (n-1)%PER_CHAPTER
	var boss = position==PER_CHAPTER-1
	var kind = "heavy" if boss and chapter%2==1 else ("balanced" if boss else str(ORDER[(n*5+chapter)%ORDER.size()]))
	# The first few levels teach the basics against plain riders.
	if n<=3:
		kind = "balanced"
	var arche: Dictionary = ARCHETYPES[kind]
	var region = str(REGION_KEYS[(chapter+position/3)%4])
	var q = base_quality(n)+(1 if boss and n>10 else 0)
	var lance_type = str(arche.lance)
	if lance_type=="mixed":
		lance_type = ["long","stout","light"][n%3]
	# FEEL-094 follow-up (feel094-leveldiag02): under the FEEL-093 tuning a
	# square body hit from a stout lance at full gallop (impulse ~58) just
	# exceeds a starter-kit seat (~57) unless the rider braces, so levels 1 and
	# 10 fell from 11/12 to 7/12 and 4/12 for the scripted player. Chapter 1 is
	# squires: they carry the long lance; stout lances arrive from chapter 2.
	if chapter==0 and lance_type=="stout":
		lance_type = "long"
	# A fresh save carries a 247px lance, not the 276px reference-kit lance
	# used by the old curve benchmark. Do not give the first opponents free
	# first-strike reach. Regional light lances retain distinct appearances.
	if n<=5: lance_type="light"
	var horse_line: Array = HORSES[str(arche.horse)]
	# LEVEL-096 (level096-curve01): the fast line starts at horse_grey, a
	# quality-1 horse (340 coins, speed 1.06), so in quality-0 levels the swift
	# and headhunter squires out-paced their own kit; with the light lance their
	# body hit (~58) again just beat a starter seat (~57) and level 5 played as
	# hard as level 50. Quality-0 riders ride the starter horse. (The stable
	# line's first horse is slower than the starter one and stays.)
	if q==0 and str(arche.horse)=="fast":
		horse_line = HORSES.balanced
	var equipment = {
		"armor":"%s_armor_%d" % [region,_q(q+int(arche.armor))],
		"helmet":"%s_helmet_%d" % [region,_q(q+int(arche.helmet))],
		# REQ-098: progression improves a line, it must not alternate a
		# bulwark between light and heavy just because quality is even/odd.
		"shield":"%s_shield_%d" % [region,shield_quality(kind,_q(q+int(arche.shield)))],
		"lance":"%s_lance_%s_%d" % [region,lance_type,_q(q)],
		"horse":str(horse_line[clampi(q*horse_line.size()/6,0,horse_line.size()-1)]),
		"crest":str(CRESTS[(n*5+chapter)%CRESTS.size()]),
		"caparison":str(CAPARISONS[clampi((q+1)/2,0,3)])}
	for slot in equipment.keys():
		if Catalogue.find(items,str(equipment[slot])).is_empty():
			equipment.erase(slot)
	# Smooth curve with a small saw-tooth inside each chapter: the first levels
	# of a chapter are a breather after its boss.
	var t = float(n-1)/float(COUNT-1)
	var curve = 1.95*pow(t,1.1)+.12*(float(position)/9.0-.5)
	var skill = top_ease(clampf(curve+float(arche.skill)+(.20 if boss else 0.0),0.0,2.0),SKILL_TOP_SLOPE)
	var awareness = top_ease(clampf(curve+float(arche.awareness)+(.20 if boss else 0.0),0.0,2.0),AWARENESS_TOP_SLOPE)
	var given: Array = GIVEN[region]
	var epithets: Array = arche.epithets
	var opponent = "%s「%s」" % [given[(n*7+chapter*3)%given.size()],epithets[(n+chapter)%epithets.size()]]
	if boss:
		opponent = "冠军 "+opponent
	var war = n>=15 and n%10==5
	var training=training_strength(n)
	var ai={"skill":snappedf(skill,.01),"awareness":snappedf(awareness,.01),"aggression":float(arche.aggression),"head_bias":float(arche.head),"feint":bool(arche.feint) or skill>=1.75}
	var hint=str(arche.hint)
	if training>0:
		ai.training=training
		ai.feint=false
		if n<=5: hint="他出手慢，主要打胸。用护胸接枪，再瞄准他盾下的胸腹；按住左键催马。"
		elif n<=10: hint="对手开始换高低枪线，但会提前出手。先稳住盾，瞄准露出的部位。"
	return {"number":n,"chapter":chapter,"chapter_name":CHAPTERS[chapter],"position":position+1,"boss":boss,
		"opponent":opponent,"region":Catalogue.REGIONS[REGION_KEYS.find(region)],"archetype":kind,"archetype_name":str(arche.name),
		"hint":hint,"mode":"war" if war else "arena","quality":_q(q),"equipment":equipment,
		"ai":ai,
		"reward_coins":reward_coins(n,boss),"reward_renown":3 if boss else 1}

static func reward_coins(n: int, boss: bool) -> int:
	return 120+12*(n-1)+(300 if boss else 0)

## Repeat clears pay a quarter of the coins and no renown.
static func replay_coins(n: int, boss: bool) -> int:
	return reward_coins(n,boss)/4

static func ai_label(ai: Dictionary) -> String:
	var names = ["初学","生疏","正规","熟练","老练"]
	var skill = names[clampi(roundi(float(ai.get("skill",1.0))*2.0),0,4)]
	var awareness = names[clampi(roundi(float(ai.get("awareness",1.0))*2.0),0,4)]
	return "技巧%s，判断%s" % [skill,awareness]

## A kit a player could plausibly own when reaching level n with its rewards.
## Used only by the benchmark to sketch the difficulty curve.
static func reference_kit(items: Array, n: int, shield_line: String="mixed") -> Dictionary:
	var q = clampi((n+2)/16,0,5)
	var shield_q=q
	if shield_line in ["light","heavy"]:
		shield_q=clampi(q/2,0,2)*2+(1 if shield_line=="heavy" else 0)
	return Catalogue.stats(items,{"armor":"eng_armor_%d" % q,"helmet":"eng_helmet_%d" % q,"shield":"eng_shield_%d" % shield_q,
		"lance":"eng_lance_long_%d" % q,"horse":["horse_bay","horse_grey","horse_e1","horse_e2","horse_e4","horse_e4"][q],"crest":"crest_bend"})
