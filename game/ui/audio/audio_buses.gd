class_name AudioBuses
extends RefCounted
## The mix buses (roadmap R13; architecture.md 9): beds of the place go to
## Ambience, things that happen to Effects, cues for the player to Interface.
## All three feed Master, whose volume is the player's setting. Created in
## code once, so no bus layout file is needed.

const AMBIENCE := &"Ambience"
const EFFECTS := &"Effects"
const INTERFACE := &"Interface"
const ALL: Array[StringName] = [AMBIENCE, EFFECTS, INTERFACE]


## Adds the buses that are missing. Safe to call any number of times.
static func ensure() -> void:
	for bus: StringName in ALL:
		if AudioServer.get_bus_index(bus) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
