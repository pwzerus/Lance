extends RefCounted
## Original game devices using the project's S26 heraldic vocabulary. These
## are collectible shield designs, not attributed historical family arms.
## Separate from Heraldry.ARMS: cloth baking must retain the 12 owned families.
const Family = preload("res://scripts/visual/heraldry.gd")
const DESIGNS = {
	"shield_basic":{"field":"314e65","charge":"dfc276","motif":"bend","name":"金斜带"},
	"eng_shield_0":{"field":"8e3933","charge":"e8dfbd","motif":"billets","name":"三银方"},
	"eng_shield_1":{"field":"e8dfbd","charge":"8e3933","motif":"crosslet","name":"红阔十字"},
	"eng_shield_2":{"field":"294e72","charge":"dfbd66","motif":"chevron_stars","name":"双星山形"},
	"eng_shield_3":{"field":"8e3933","charge":"dfbd66","motif":"tower","name":"金塔"},
	"eng_shield_4":{"field":"294e72","charge":"e8dfbd","motif":"stag","name":"银鹿角"},
	"eng_shield_5":{"field":"263d35","charge":"dfbd66","motif":"rose","name":"金蔷薇"},
	"fr_shield_0":{"field":"294e72","charge":"e8dfbd","motif":"bars","name":"银双横带"},
	"fr_shield_1":{"field":"294e72","charge":"dfbd66","motif":"fleur","name":"金百合"},
	"fr_shield_2":{"field":"e8dfbd","charge":"8e3933","motif":"lozenges","name":"三红菱"},
	"fr_shield_3":{"field":"294e72","charge":"dfbd66","motif":"lilies","name":"三金百合"},
	"fr_shield_4":{"field":"713d59","charge":"e8dfbd","motif":"star_crescent","name":"银星新月"},
	"fr_shield_5":{"field":"8e3933","charge":"dfbd66","motif":"cross_roundels","name":"十字四圆"},
	"de_shield_0":{"field":"dfbd66","charge":"343c39","motif":"bend_billets","name":"斜带双方"},
	"de_shield_1":{"field":"dfbd66","charge":"343c39","motif":"eagle","name":"展翅黑鹰"},
	"de_shield_2":{"field":"e8dfbd","charge":"8e3933","motif":"paly","name":"红三竖带"},
	"de_shield_3":{"field":"294e72","charge":"e8dfbd","motif":"annulets","name":"三银环"},
	"de_shield_4":{"field":"8e3933","charge":"e8dfbd","motif":"saltire_star","name":"斜十字星"},
	"de_shield_5":{"field":"dfbd66","charge":"343c39","motif":"double_eagle","name":"双首展鹰"},
	"it_shield_0":{"field":"e8dfbd","charge":"34654a","motif":"chequy","name":"绿银方格"},
	"it_shield_1":{"field":"8e3933","charge":"e8dfbd","motif":"keys","name":"银双钥"},
	"it_shield_2":{"field":"294e72","charge":"dfbd66","motif":"sun","name":"金日轮"},
	"it_shield_3":{"field":"e8dfbd","charge":"8e3933","motif":"castle_stars","name":"双塔星"},
	"it_shield_4":{"field":"34654a","charge":"e8dfbd","motif":"fess_lozenges","name":"横带三菱"},
	"it_shield_5":{"field":"713d59","charge":"dfbd66","motif":"wheel","name":"金辐轮"}}

static func record(key: String) -> Dictionary:
	return DESIGNS.get(key,DESIGNS.shield_basic)

static func _rect(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return Family._box(Vector2(x,y),Vector2(x+w,y+h))

static func _line(a: Vector2,b: Vector2,width: float) -> PackedVector2Array:
	var n=(b-a).normalized().orthogonal()*width*.5
	return PackedVector2Array([a+n,b+n,b-n,a-n])

static func _transformed(polygons: Array[PackedVector2Array], center: Vector2, scale: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for polygon in polygons:
		var p=PackedVector2Array()
		for point in polygon: p.append(center+point*scale)
		result.append(p)
	return result

static func _eagle(double_head: bool) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	result.append(PackedVector2Array([Vector2(-7,-25),Vector2(7,-25),Vector2(10,12),Vector2(17,25),Vector2(0,19),Vector2(-17,25),Vector2(-10,12)]))
	for sign_value in [-1,1]:
		var wing=PackedVector2Array([Vector2(5,-13),Vector2(17,-22),Vector2(30,-36),Vector2(29,-16),Vector2(23,-18),Vector2(26,-7),Vector2(20,-10),Vector2(22,2),Vector2(16,-2),Vector2(13,11),Vector2(6,5)])
		for i in range(wing.size()): wing[i].x*=sign_value
		result.append(wing)
	for sign_value in [-1,1] if double_head else [-1]:
		var head=PackedVector2Array([Vector2(0,-21),Vector2(2,-38),Vector2(10,-42),Vector2(15,-39),Vector2(20,-32),Vector2(10,-33),Vector2(6,-22)])
		for i in range(head.size()): head[i].x*=sign_value
		result.append(head)
	return result

static func polygons(key: String, overlay: bool=false, facing: int=1) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	var motif=str(record(key).motif)
	var triples=[Vector2(-16,-25),Vector2(16,-25),Vector2(0,9)]
	if overlay:
		match motif:
			"tower": result.append(_rect(-6,-2,12,22))
			"rose": result.append(Family._circle(Vector2(0,-6),7,12))
			"star_crescent": result.append(Family._circle(Vector2(9,-1),17,20))
			"annulets":
				for point in triples: result.append(Family._circle(point,6,14))
			"saltire_star":
				result.append(Family._circle(Vector2(0,-6),17,16))
			"keys":
				for sign_value in [-1,1]: result.append(Family._circle(Vector2(sign_value*15,-27),4,12))
			"castle_stars":
				for x in [-20,12]: result.append(_rect(x,0,8,18))
			"fess_lozenges":
				for x in [-22,0,22]: result.append(PackedVector2Array([Vector2(x,-18),Vector2(x+7,-7),Vector2(x,4),Vector2(x-7,-7)]))
			"wheel": result.append(Family._circle(Vector2(0,-6),19,24))
	else:
		match motif:
			"bend","fleur","chequy": result=Family.charge_polygons(motif)
			"billets":
				for point in triples: result.append(_rect(point.x-6,point.y-10,12,20))
			"crosslet":
				result.append(PackedVector2Array([Vector2(-15,-42),Vector2(15,-42),Vector2(6,-15),Vector2(29,-24),Vector2(29,8),Vector2(6,-1),Vector2(15,30),Vector2(-15,30),Vector2(-6,-1),Vector2(-29,8),Vector2(-29,-24),Vector2(-6,-15)]))
			"chevron_stars":
				result=Family.charge_polygons("chevron")
				for x in [-18,18]: result.append(Family._star(Vector2(x,-28),9,4))
			"tower":
				result.append(_rect(-21,-26,42,49))
				for x in [-21,-5,11]: result.append(_rect(x,-36,10,10))
			"stag":
				result.append(PackedVector2Array([Vector2(-9,-13),Vector2(9,-13),Vector2(13,0),Vector2(4,25),Vector2(-4,25),Vector2(-13,0)]))
				for sign_value in [-1,1]:
					result.append(_line(Vector2(sign_value*6,-8),Vector2(sign_value*22,-39),5))
					for y in [-21,-31]: result.append(_line(Vector2(sign_value*15,y+4),Vector2(sign_value*29,y-5),4))
			"rose":
				for i in range(5): result.append(Family._circle(Vector2(0,-6)+Vector2.from_angle(-PI/2+TAU*i/5)*15,12,12))
			"bars":
				for y in [-28,0]: result.append(_rect(-70,y,140,13))
			"lozenges":
				for point in triples: result.append(_transformed(Family.charge_polygons("diamond"),point,.40)[0])
			"lilies":
				for point in triples: result.append_array(_transformed(Family.charge_polygons("fleur"),point,.42))
			"star_crescent":
				result.append(Family._circle(Vector2(0,2),23,22))
				result.append(Family._star(Vector2(0,-33),11,4.8))
			"cross_roundels":
				result=_transformed(Family.charge_polygons("cross"),Vector2.ZERO,.55)
				for x in [-20,20]:
					for y in [-27,12]: result.append(Family._circle(Vector2(x,y),7,12))
			"bend_billets":
				result=Family.charge_polygons("bend")
				result.append(_rect(10,-34,13,17))
				result.append(_rect(-23,5,13,17))
			"eagle","double_eagle": result=_eagle(motif=="double_eagle")
			"paly":
				for x in [-25,-5,15]: result.append(_rect(x,-70,10,140))
			"annulets":
				for point in triples: result.append(Family._circle(point,11,14))
			"saltire_star": result=Family.charge_polygons("saltire")
			"keys":
				for sign_value in [-1,1]:
					result.append(_line(Vector2(sign_value*15,-24),Vector2(-sign_value*14,23),6))
					result.append(Family._circle(Vector2(sign_value*15,-27),9,12))
					result.append(_line(Vector2(-sign_value*15,22),Vector2(-sign_value*25,13),7))
			"sun":
				result.append(Family._circle(Vector2(0,-6),13,16))
				for i in range(12):
					var ray=Vector2.from_angle(TAU*i/12)
					result.append(PackedVector2Array([Vector2(0,-6)+ray*29,Vector2(0,-6)+ray.rotated(.18)*16,Vector2(0,-6)+ray.rotated(-.18)*16]))
			"castle_stars":
				for x in [-28,4]:
					result.append(_rect(x,-18,24,41))
					for dx in [0,16]: result.append(_rect(x+dx,-27,8,9))
				result.append(Family._star(Vector2(0,-36),10,4))
			"fess_lozenges": result.append(_rect(-70,-24,140,34))
			"wheel": result.append(Family._circle(Vector2(0,-6),27,24))
	for p in range(result.size()):
		for i in range(result[p].size()): result[p][i].x*=facing
	return result

## Foreground inside cutouts, drawn after the field-coloured overlay.
static func details(key: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	match str(record(key).motif):
		"saltire_star": result.append(Family._star(Vector2(0,-6),12,5))
		"wheel":
			for i in range(8): result.append(_line(Vector2(0,-6),Vector2(0,-6)+Vector2.from_angle(TAU*i/8)*22,4))
			result.append(Family._circle(Vector2(0,-6),7,12))
	return result
