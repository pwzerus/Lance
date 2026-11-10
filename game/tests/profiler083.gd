extends RefCounted
## Opt-in, bounded diagnostic only; never imported by production scripts.
static var enabled = false
static var totals: Dictionary = {}
static func record(key: String, start: int) -> void:
	if not enabled: return
	var elapsed = Time.get_ticks_usec()-start
	if not totals.has(key): totals[key] = {"calls":0,"usec":0,"max_usec":0}
	var entry: Dictionary = totals[key]
	entry.calls += 1
	entry.usec += elapsed
	entry.max_usec = maxi(entry.max_usec,elapsed)
