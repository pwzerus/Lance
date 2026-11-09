extends RefCounted
## HORSE-065: horse fatigue from load, build and effort. Pure functions so the
## match model, AI, HUD and tests share one source of truth.
##
## Game abstraction, not veterinary data: a mounted knight and kit are a large
## fraction of what a horse carries comfortably; heavier armour and a lighter
## (faster) horse both cost endurance. A tired horse cannot hold the gallop: the
## reachable speed falls smoothly instead of the old hard cut at 1% stamina.

const RIDER_KG = 72.0
const TACK_KG = 14.0
# Stamina per second. Drain applies while urged; recovery depends on how hard
# the horse is still working (cruising recovers slowly, standing quickly).
# Tuned (horse065-condition01): 13 tired a horse within 3-4.5 s of urging,
# before a single charge was over. 9 keeps one charge mostly at full gallop;
# a long sprint or several passes without rest wear it down.
const DRAIN = 9.0
const RECOVERY = 17.0
const REST_RECOVERY = 11.0
# Below this stamina the gallop ceiling starts to fall toward FLOOR.
const TIRED = 35.0
const FLOOR = .70

## EQUIP-066: real per-item weights (catalogue writes stats.<slot>_kg from
## data/equipment_weights_v066.json). The old tier formulas remain only as a
## fallback for stats built without the catalogue (tests, legacy dictionaries).
static func worn_kg(stats: Dictionary) -> float:
	# What the rider wears: body armour, helmet and shield.
	var armor = float(stats.get("armor_kg",7.0+3.6*float(stats.get("armor_tier",0))))
	var helmet = float(stats.get("helmet_kg",1.5+.8*float(stats.get("helmet_tier",0))))
	var shield = float(stats.get("shield_kg",3.0*float(stats.get("shield_capacity",78.0))/78.0))
	return armor+helmet+shield

static func load_kg(stats: Dictionary) -> float:
	var lance = float(stats.get("lance_kg",8.0*float(stats.get("reach",247.0))/247.0))
	return RIDER_KG+TACK_KG+worn_kg(stats)+lance+float(stats.get("caparison_kg",0.0))

# Rider encumbrance, EQUIP-066. Real field armour hardly slowed a mounted
# man-at-arms; these are deliberate game costs so that light armour is a
# skill choice rather than a strictly worse item (EQUIP066_RESEARCH.md D1).
const AGILITY_REFERENCE_KG = 21.0
const AGILITY_PER_KG = .015

static func agility(stats: Dictionary) -> float:
	# Lance redirection, shield (guard) moves and recovery of lance support.
	return clampf(1.0+AGILITY_PER_KG*(AGILITY_REFERENCE_KG-worn_kg(stats)),.82,1.15)

static func seat(stats: Dictionary) -> float:
	# A heavier armoured rider has more inertia in the saddle: harder to unhorse.
	return clampf(sqrt((RIDER_KG+worn_kg(stats))/96.0),.90,1.12)

static func capacity_kg(stats: Dictionary) -> float:
	# Steadier (heavier-boned) horses carry more; faster, lighter ones less.
	return 128.0*pow(maxf(.5,float(stats.get("stability",1.0))),.9)/sqrt(maxf(.5,float(stats.get("speed",1.0))))

static func burden(stats: Dictionary) -> float:
	return load_kg(stats)/capacity_kg(stats)

static func drain_rate(stats: Dictionary) -> float:
	# EQUIP-066: soft load threshold. Powell et al. 2008 saw little change at
	# 15-20% of body weight and real stress at 25-30%; "comfortable capacity"
	# (burden 1.0) sits near that band, so drain climbs steeply above .88.
	var over = maxf(0.0,burden(stats)-.88)
	return DRAIN*(.55+.60*burden(stats)+2.4*over)*pow(maxf(.5,float(stats.get("speed",1.0))),1.3)

static func recovery_rate(stats: Dictionary, speed: float, gallop: float, trot: float) -> float:
	# Recovers fully while walking/trotting, only a third while still running fast.
	var effort = clampf((speed-trot)/maxf(1.0,gallop-trot),0.0,1.0)
	return RECOVERY*clampf(1.25-.35*burden(stats),.55,1.15)*lerpf(1.0,.33,effort)

static func rest_rate(stats: Dictionary) -> float:
	# Between passes (re-rack and countdown): partial recovery only, so a long
	# match still wears the horse down.
	return REST_RECOVERY*clampf(1.25-.35*burden(stats),.55,1.15)

static func load_speed_factor(stats: Dictionary) -> float:
	# EQUIP-066: steeper than HORSE-065 (.08): Bannerlord's lesson was that a
	# weight penalty too small to feel makes heavy kit a strict upgrade.
	# (balance066-tune01: .40 shifted AI commit timing more than it rewarded
	# the light rider; .20 keeps a felt but moderate gap.)
	return clampf(1.0+.20*(1.0-burden(stats)),.90,1.05)

## EQUIP-066 drive: the rider's OWN horse speed puts weight behind a couched
## lance. Closing speed already scales both riders' hits equally; this makes
## a fresher, faster horse pay off for its owner (1.0 at full gallop).
static func drive(own_speed: float, gallop: float) -> float:
	return clampf(.55+.45*own_speed/maxf(1.0,gallop),.6,1.06)

static func gallop_ceiling(stamina: float) -> float:
	# Fraction of the full gallop the horse can still reach.
	# EQUIP-068 (user): a clear step. The smooth curve still read ~100% at
	# stamina 33 while the HUD already said "tired"; now the gallop drops to
	# 90% the moment the horse is tired and on to 70% when spent. The speed
	# itself still eases toward the new ceiling (no jump).
	if stamina>=TIRED:
		return 1.0
	return lerpf(FLOOR,TIRED_CEILING,clampf(stamina/TIRED,0.0,1.0))

const TIRED_CEILING = .90

# ---- EQUIP-068 rider arm fatigue (臂力) --------------------------------------
# Waving the lance and swinging the shield tire the arms; tired arms move the
# lance and shield more slowly until they rest. Game abstraction, tuned so that
# ~3 s of continuous large redirection takes a fresh arm to ~45%.
const ARM_REST = 18.0        # per second between passes
const ARM_RECOVERY = 12.0    # per second while holding the lance still
const ARM_AIM_COST = 9.0     # per (rad/s above the free band) per lance-weight unit
const ARM_GUARD_COST = 7.0   # per (guard units/s) per shield-weight unit

static func arm_rate(stats: Dictionary, aim_speed: float, guard_speed: float) -> float:
	var lance = float(stats.get("lance_kg",5.0))/5.0
	var shield = float(stats.get("shield_kg",3.5))/3.5
	var work = maxf(0.0,aim_speed-.25)*lance*ARM_AIM_COST+maxf(0.0,guard_speed-.10)*shield*ARM_GUARD_COST
	if work>.01:
		return -work
	return ARM_RECOVERY*clampf(agility(stats),.8,1.15)

static func arm_factor(arm: float) -> float:
	# 1.0 above 60%, about .72 at 30%, .55 when exhausted.
	return lerpf(.55,1.0,smoothstep(8.0,60.0,arm))

static func acceleration_factor(stats: Dictionary, stamina: float) -> float:
	return lerpf(.6,1.0,smoothstep(0.0,TIRED,stamina))*clampf(1.40-.45*burden(stats),.84,1.10)

static func fatigue(stamina: float) -> float:
	# 0 fresh .. 1 spent, for presentation (head carriage, breathing).
	return 1.0-smoothstep(5.0,60.0,stamina)
