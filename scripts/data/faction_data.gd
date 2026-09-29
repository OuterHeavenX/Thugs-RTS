class_name FactionData
extends RefCounted

## Playable countries. Slice ships with america vs asia.
## Future factions to add later: africa, europe, australia, south_america.

const FACTIONS := {
	"america": {
		"name": "America",
		"color": Color(0.16, 0.38, 0.95),
		"dark": Color(0.10, 0.24, 0.65),
		"light": Color(0.45, 0.62, 1.00),
	},
	"asia": {
		"name": "Asia",
		"color": Color(0.92, 0.16, 0.14),
		"dark": Color(0.62, 0.10, 0.10),
		"light": Color(1.00, 0.45, 0.40),
	},
}


static func display_name(faction: String) -> String:
	return String(FACTIONS[faction]["name"])


static func color_of(faction: String) -> Color:
	var c: Color = FACTIONS[faction]["color"]
	return c
