extends RefCounted
class_name AnimalData

const TIERS := [
	{"name": "Mouse",    "color": Color("FFB6C1"), "radius": 0.25, "droppable": true},
	{"name": "Frog",     "color": Color("2ECC40"), "radius": 0.36, "droppable": true},
	{"name": "Rabbit",   "color": Color("C8A882"), "radius": 0.48, "droppable": true},
	{"name": "Cat",      "color": Color("7B7B7B"), "radius": 0.62, "droppable": true},
	{"name": "Fox",      "color": Color("D4652F"), "radius": 0.78, "droppable": true},
	{"name": "Penguin",  "color": Color("1C1C2E"), "radius": 0.95, "droppable": false},
	{"name": "Zebra",    "color": Color("F5F5F5"), "radius": 1.12, "droppable": false},
	{"name": "Lion",     "color": Color("DAA520"), "radius": 1.30, "droppable": false},
	{"name": "Bear",     "color": Color("5C3A1E"), "radius": 1.50, "droppable": false},
	{"name": "Elephant", "color": Color("8E99A4"), "radius": 1.75, "droppable": false},
	{"name": "Whale",    "color": Color("0D47A1"), "radius": 2.10, "droppable": false},
]

const MAX_TIER := 10
const MAX_DROPPABLE_TIER := 4

static func get_tier(tier: int) -> Dictionary:
	return TIERS[tier]

static func get_random_droppable_tier() -> int:
	return randi_range(0, MAX_DROPPABLE_TIER)

static func get_radius(tier: int) -> float:
	return TIERS[tier]["radius"]

static func get_color(tier: int) -> Color:
	return TIERS[tier]["color"]

static func get_animal_name(tier: int) -> String:
	return TIERS[tier]["name"]

static func get_mass(tier: int) -> float:
	var r: float = TIERS[tier]["radius"]
	return r * r * r * 10.0

static func get_bounce(tier: int) -> float:
	return lerpf(0.15, 0.05, float(tier) / float(MAX_TIER))

static func get_friction(tier: int) -> float:
	return lerpf(0.3, 0.8, float(tier) / float(MAX_TIER))

static func get_score(tier: int) -> int:
	return (tier + 1) * 10
