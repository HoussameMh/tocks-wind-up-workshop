class_name StompRules
extends RefCounted
## Decides whether contact with an enemy is a stomp or a hit.


## A stomp needs Tock to be descending, with feet above enemy_base_y + margin.
static func is_stomp(feet_y: float, velocity_y: float, enemy_base_y: float, margin: float) -> bool:
	return velocity_y < 0.0 and feet_y >= enemy_base_y + margin
