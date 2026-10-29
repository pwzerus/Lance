extends RefCounted
## Cosmetic indices only: changing appearance never changes combat stats.
const OPTIONS = {
	"face_shape": ["圆阔", "方颌", "窄长", "棱角"],
	"skin": ["浅肤", "暖肤", "小麦", "橄榄", "棕肤", "深肤"],
	"brows": ["平眉", "浓眉", "弯眉", "淡眉"],
	"beard": ["无胡须", "短髭", "络腮胡", "山羊胡", "长胡须"],
	"eyes": ["褐色", "蓝色", "绿色", "灰色", "琥珀"],
	"hair": ["深棕", "乌黑", "栗红", "亚麻"]
}

static func defaults() -> Dictionary:
	return {"face_shape":0,"skin":0,"brows":0,"beard":0,"eyes":0,"hair":0}

static func sanitize(value: Variant) -> Dictionary:
	var clean = defaults()
	if not value is Dictionary:
		return clean
	for key in OPTIONS:
		var index: Variant = value.get(key,0)
		if (index is int or index is float) and is_finite(float(index)):
			clean[key] = int(clampf(float(index),0,OPTIONS[key].size()-1))
	return clean

static func variant(seed_value: int) -> Dictionary:
	# Local arithmetic only. This must not advance the match's RNG stream.
	var value = posmod(seed_value,65521)
	var result = defaults()
	for key in OPTIONS:
		value = posmod(value*109+89,65521)
		result[key] = value % OPTIONS[key].size()
	return result
