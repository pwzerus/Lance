extends "test_visual072.gd"
## Reuse the 24 helmet/armour, two-facing, three-lean fit sheet at gallop.
## The old stationary sheet cannot exercise mounted gaze stabilization.
func new_rider(stats: Dictionary, facing: int)->RiderView:
	var rider=super.new_rider(stats,facing)
	rider.fighter.speed=480.0
	rider.fighter.gait_moving=true
	rider.fighter.gait_phase=.8
	rider.moving=true
	return rider
