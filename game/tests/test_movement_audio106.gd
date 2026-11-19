extends "test_audio086.gd"
## Real WAV import/playback and production saddle-trigger checks. Dummy/muted
## output establishes timing and mix safety, not human listening approval.
const Rider106=preload("res://scripts/visual/rider_view.gd")
const Model106=preload("res://scripts/core/joust_match.gd")
const Gait106=preload("res://scripts/visual/horse_gait.gd")

func selection_checks(bank)->void:
	super.selection_checks(bank)
	var hashes={}
	for family in Bank.MOVEMENT_FAMILIES:
		for variant in range(3):
			var name_value="armor_%s_%d"%[family,variant]
			check(bank.streams.has(name_value),"Movement WAV is imported: "+name_value)
			if not bank.streams.has(name_value):continue
			var stream=bank.streams[name_value]
			var metrics=pcm_metrics(stream)
			check(stream.resource_path.begins_with(Bank.MOVEMENT_ASSET_DIR),"Movement uses the shipped WAV, no generated impact fallback")
			check(bool(metrics.valid_pcm) and metrics.get("peak",0)>.1 and metrics.get("peak",1)<.31 and metrics.get("clipped_samples",1)==0,"Movement sample has non-silent unclipped headroom",{"cue":name_value,"metrics":metrics})
			check(not hashes.has(metrics.get("sha256","")),"Movement material and variants use distinct samples")
			hashes[metrics.get("sha256","")]=name_value
			rows.append({"kind":"movement_pcm","cue":name_value,"metrics":metrics})
		var stats={"armor_material":family,"armor_tier":2}
		var before=stats.duplicate(true);var names=[]
		for index in range(4):names.append(bank.movement_cue(stats,.7).cue)
		check(names[0]==names[3] and names[0]!=names[1] and names[1]!=names[2],"Movement has three bounded variants: "+family)
		var weak=bank.movement_cue(stats,.2);var strong=bank.movement_cue(stats,1);var far=bank.movement_cue(stats,1,true)
		check(strong.db>weak.db and far.db==strong.db-5 and stats==before,"Compression strength and distance affect gain without changing equipment")
	check(bank.movement_cue({"armor_material":"padded"},1).is_empty(),"Soft cloth does not sound like metal plates")
	check(bank.movement_cue({},NAN).is_empty() and bank.movement_cue({},0).is_empty(),"Invalid/no compression does not select clatter")
	var saved=bank.streams.duplicate();bank.streams={}
	check(bank.movement_cue({"armor_material":"plate"},1).is_empty(),"Missing clatter never substitutes an impact")
	bank.streams=saved
	compression_checks()

func compression_checks()->void:
	for speed in [220.0,380.0,520.0]:
		var counts=[]
		for hz in [30,60,120]:
			var model=Model106.new();var fighter=model.fighters[0]
			fighter.gait_moving=true;fighter.speed=speed
			var rider=Rider106.new();rider.fighter=fighter;rider.moving=true
			var context={"time":0.0};var pulses=[]
			rider.armor_motion.connect(func(strength):pulses.append({"time":context.time,"strength":strength}))
			for frame in range(hz*8):
				context.time=(frame+1.0)/hz;fighter.gait_phase+=TAU*Gait106.frequency(speed)/hz
				rider._advance_armor_motion(1.0/hz)
			check(pulses.size()>4 and pulses.size()<40,"Gait produces finite support-linked clatter",{"speed":speed,"hz":hz,"pulses":pulses})
			for index in range(1,pulses.size()):
				check(pulses[index].time-pulses[index-1].time>=.179,"A compression does not chatter repeatedly")
			var before=pulses.size()
			for frame in range(60):rider._advance_armor_motion(0.0)
			check(pulses.size()==before,"Zero game time freezes armor sound")
			for state in ["still","ko","dead"]:
				rider.moving=state!="still";fighter.ko=state=="ko";fighter.dead=state=="dead"
				for frame in range(hz):
					fighter.gait_phase+=TAU*Gait106.frequency(speed)/hz;rider._advance_armor_motion(1.0/hz)
				check(pulses.size()==before,"Standing or detached rider cannot emit saddle clatter: "+state)
			counts.append(pulses.size());rows.append({"kind":"saddle_pulses","speed":speed,"hz":hz,"pulses":pulses})
			rider.free()
		check(int(counts.max())-int(counts.min())<=1,"Compression cadence stays consistent at 30/60/120Hz",{"speed":speed,"counts":counts})

func playback_checks(bank)->void:
	await super.playback_checks(bank)
	bank.enabled=true
	for index in range(Bank.MAX_VOICES):bank.play("contact_plate_solid_0",-12)
	var protected=[]
	for voice in bank.voices:protected.append(voice.get_meta("sfx_cue"))
	bank.play("armor_plate_0",-20);bank.play("hoof",-20)
	var after=[]
	for voice in bank.voices:after.append(voice.get_meta("sfx_cue"))
	check(after==protected,"A full contact pool cannot be stolen by hooves/clothing")
	bank.stop_all()
	for index in range(Bank.MAX_VOICES):bank.play("armor_mail_0",-20)
	bank.play("contact_helmet_solid_0",-6)
	var contacts=0
	for voice in bank.voices:
		if voice.get_meta("sfx_cue")=="contact_helmet_solid_0":contacts+=1
	check(contacts==1 and bank.voices.size()==Bank.MAX_VOICES,"Impact displaces movement without growing the voice pool")
	bank.set_movement_duck(1)
	for voice in bank.voices:
		var expected=-38.0 if Bank.is_movement_cue(voice.get_meta("sfx_cue")) else -6.0
		check(absf(voice.volume_db-expected)<.001,"Movement ducks while impact keeps its gain")
	bank.set_movement_duck(1);bank.set_movement_duck(0)
	for voice in bank.voices:
		check(absf(voice.volume_db-float(voice.get_meta("sfx_base_db")))<.001,"Repeated duck calls do not accumulate gain loss")
	bank.set_paused(true);var cursor=bank.next_voice
	bank.play("armor_plate_0")
	check(bank.next_voice==cursor,"Paused movement cannot allocate/steal playback")
	bank.set_paused(false);bank.set_enabled(false);bank.stop_all()
	await real_wait(.35)
