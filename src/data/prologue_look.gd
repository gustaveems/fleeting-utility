class_name PrologueLook
extends RefCounted
## DATA — the prologue's look (Ticket-15 Phase C; the palettes and references in
## docs/references/notes.md). One stage per stretch of the film: its sky, fog, sun, glow
## and grade. The Prologue applies a shot's stage when the shot starts.
##
##   town      decay: rust and orange dust, sodium; a low dawn sun through the haze
##             (2049's dead Vegas outlets)
##   canyon    the city: teal-grey monoliths in haze, a low sun burning through it
##             (Heywood flyover; 2049's brutalist massing); the ads the brightest thing
##   colossus  the same city, warmer: the gold copy catches the last sun
##   descent   dusk going to night in the low blocks: neon in the dirt (BR 1982 street)
##   street    night on the avenue (its own lamps and signs carry it)

const STAGES := {
	"town":
	{
		"sky_top": Color("#5A3E2A"),
		"sky_horizon": Color("#E8A040"),
		"fog": Color("#B9875A"),
		"fog_density": 0.0035,
		"ambient_color": Color("#B9875A"),
		"ambient": 0.75,
		"sun": Color(1.0, 0.66, 0.38),
		"sun_energy": 1.5,
		"sun_angle": Vector3(-9, -70, 0),
		"glow": 0.6,
		"exposure": 1.0,
		"saturation": 1.05,
	},
	"canyon":
	{
		"sky_top": Color("#1C272B"),
		"sky_horizon": Color("#B0683E"),
		"fog": Color("#3E4C50"),
		"fog_density": 0.0055,
		"ambient_color": Color("#5F7478"),
		"ambient": 0.5,
		"sun": Color(1.0, 0.74, 0.55),
		"sun_energy": 0.85,
		"sun_angle": Vector3(-7, -55, 0),
		"glow": 0.7,
		"exposure": 1.0,
		"saturation": 0.95,
	},
	"colossus":
	{
		"sky_top": Color("#22292C"),
		"sky_horizon": Color("#C27A42"),
		"fog": Color("#4A5454"),
		"fog_density": 0.005,
		"ambient_color": Color("#6A7373"),
		"ambient": 0.52,
		"sun": Color(1.0, 0.72, 0.5),
		"sun_energy": 0.95,
		"sun_angle": Vector3(-6, -40, 0),
		"glow": 0.7,
		"exposure": 1.05,
		"saturation": 1.0,
	},
	"descent":
	{
		"sky_top": Color("#0B1216"),
		"sky_horizon": Color("#3A2A30"),
		"fog": Color("#2E3B3F"),
		"fog_density": 0.006,
		"ambient_color": Color("#2E3B3F"),
		"ambient": 0.45,
		"sun": Color(0.95, 0.55, 0.4),
		"sun_energy": 0.35,
		"sun_angle": Vector3(-4, -40, 0),
		"glow": 0.7,
		"exposure": 1.0,
		"saturation": 1.0,
	},
	"street":
	{
		"sky_top": Color(0.04, 0.07, 0.09),
		"sky_horizon": Color(0.42, 0.26, 0.18),
		"fog": Color(0.18, 0.24, 0.26),
		"fog_density": 0.0045,
		"ambient": 0.7,
		"sun": Color(1.0, 0.72, 0.45),
		"sun_energy": 0.6,
		"sun_angle": Vector3(-12, -60, 0),
		"glow": 0.45,
		"exposure": 1.0,
		"saturation": 1.0,
	},
}

## Which stage each shot plays in (by shot name; anything unlisted plays in "street").
const SHOT_STAGE := {
	"town_establishing": "town",
	"town_glide": "town",
	"tunnel": "town",
	"aerial_canyon": "canyon",
	"through_train": "canyon",
	"metro_interior": "canyon",
	"colossus_reveal": "colossus",
	"through_statue": "colossus",
	"descent": "descent",
	"station_exit": "descent",
}

## The ads never switch off: billboard emission (the brightest thing in the sky).
const AD_GLOW := 3.0
## Sodium light at the town's station.
const SODIUM := Color("#E8A040")


static func stage_for(shot_name: String) -> String:
	return SHOT_STAGE.get(shot_name, "street")
