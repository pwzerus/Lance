extends "test_contact_mix_v056.gd"
## Add the new riding layer to the existing actual AudioServer mix capture.
## Hardware-facing Master remains muted; finite authored schedules, not ears.
var movement_active106=false
var movement_start106=-1
var movement_index106=0
var movement_material106="plate"
var movement_events106=[]
const MOVEMENT_TIMES106=[0.0,.055,.19,.22,.285,.44,.62,.8]

func record_case(spec:Dictionary)->void:
	movement_active106=not bool(spec.get("probe",false))
	movement_start106=-1;movement_index106=0;movement_events106=[]
	movement_material106="mail" if str(spec.id).contains("helmet") else ("brigandine" if str(spec.id).contains("wood") else "plate")
	if not process_frame.is_connected(movement_probe106):process_frame.connect(movement_probe106)
	await super.record_case(spec)
	movement_active106=false
	rows.append({"kind":"movement_mix_schedule","case":spec.id,"material":movement_material106,"played":movement_events106})

func movement_probe106()->void:
	if not movement_active106 or not recorder or not recorder.is_recording_active():return
	var now=Time.get_ticks_usec()
	if movement_start106<0:movement_start106=now
	var elapsed=(now-movement_start106)/1000000.0
	while movement_index106<MOVEMENT_TIMES106.size() and elapsed>=MOVEMENT_TIMES106[movement_index106]:
		var cue=battle_bank.movement_cue({"armor_material":movement_material106},1.0,movement_index106%2==1)
		check(not cue.is_empty(),"Running mix can select imported clothing")
		if not cue.is_empty():
			battle_bank.play(cue.cue,cue.db,cue.pitch)
			movement_events106.append({"actual_seconds":elapsed,"cue":cue.cue,"requested_db":cue.db,"duck":battle_bank.movement_duck})
		movement_index106+=1
