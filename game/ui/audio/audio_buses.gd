class_name AudioBuses
extends RefCounted
## The mix buses (roadmap R13; architecture.md 9): beds of the place go to
## Ambience, things that happen to Effects, cues for the player to Interface.
## All three feed Master, whose volume is the player's setting. They are
## declared in res://default_bus_layout.tres, which the engine loads at start.
## Do not add buses at run time: in the web build that silenced all sound
## (found 2026-11-19, R13 first made them in code). ensure() is only a
## fallback for a project without the layout file.

const AMBIENCE := &"Ambience"
const EFFECTS := &"Effects"
const INTERFACE := &"Interface"
const ALL: Array[StringName] = [AMBIENCE, EFFECTS, INTERFACE]


## Adds the buses that are missing (none, with the layout file). Safe to call any number of times.
static func ensure() -> void:
	for bus: StringName in ALL:
		if AudioServer.get_bus_index(bus) < 0:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, &"Master")
