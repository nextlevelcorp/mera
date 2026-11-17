class_name Game
extends RefCounted
## The contract between the two views of the game (architecture.md 3): what
## the world hands to the fishing view and what comes back. Plain
## dictionaries, so tests can build them. The world mode is not built yet;
## the title screen starts fishing with a request for the first spot.

enum Mode { TITLE, WORLD, FISHING }


## What starts a fishing session. Empty rig or position: the fishing view
## uses the last ones from the save. conditions empty: from the phone's clock.
static func fishing_request(spot_id: String = "", position_id: String = "", rig: String = "", conditions: Dictionary = {}) -> Dictionary:
	return {"spot_id": spot_id, "position_id": position_id, "rig": rig, "conditions": conditions}


## What a fishing session reports when the player leaves it.
static func empty_result() -> Dictionary:
	return {"catches": [], "lost": [], "casts": 0, "time_s": 0.0, "events": []}
