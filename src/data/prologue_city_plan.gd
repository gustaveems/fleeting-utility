class_name PrologueCityPlan
extends RefCounted
## DATA — the prologue's city (Ticket-15 Phase B; the plan Alain approved on 2026-10-28:
## docs/references/city_plan_v1.png). World metres, north (−Z) up the plan. PrologueCity
## builds it; only what the film's cameras see is built.

## ----- A. THE TOWN ---------------------------------------------------------------------
## The main street beside the line: [x0, x1, z0, z1] of the road.
const MAIN_STREET := [-690.0, -350.0, 26.0, 38.0]
## Shop rows either side: [z of the facade, outward z (+1 faces south, −1 north), depth].
const SHOP_ROWS := [[25.0, 1.0, 9.0], [39.0, -1.0, 9.0]]
const SHOP_WIDTH := 12.0
## The car park by the station where the fenced stone stands: no shops here (it is also
## the establishing shot's view of the station).
const STONE_LOT := [-603.0, -567.0, 12.0, 25.0]
const DEAD_MALL := [Vector3(-600, 4, -40), Vector3(90, 8, 30)]
const MALL_PARKING := [-650.0, -560.0, -110.0, -60.0]
const DEPOT := [Vector3(-460, 6, -72), Vector3(80, 12, 45)]
const DEPOT_YARD := [-420.0, -340.0, -82.0, -66.0]
## The agri-corp's leased fields: [x0, z0, width, depth], fenced.
const FIELDS := [
	[-700.0, 70.0, 56.0, 120.0],
	[-636.0, 70.0, 56.0, 120.0],
	[-572.0, 70.0, 56.0, 120.0],
	[-508.0, 70.0, 56.0, 120.0],
	[-444.0, 70.0, 56.0, 120.0],
]
## The same billboards as the city's, older and peeling: [x, z, text].
const TOWN_BOARDS := [
	[-520.0, 46.0, "UPGRADE YOUR FOCUS"],
	[-420.0, 18.0, "THE FUTURE IS LEASED"],
]
const TOWN_SIGNS := ["CLOSED", "FOR LEASE", "", "DEPOT JOBS", "", "CLOSED", "NO CREDIT", ""]

## ----- B. THE RIDGE (the tunnel cuts through it) ------------------------------------------
const RIDGE := [-330.0, -255.0]
const RIDGE_HEIGHT := 26.0
## Half-width of the tunnel's corridor and its ceiling (the tunnel's own walls sit inside).
const TUNNEL_HALF := 8.0
const TUNNEL_CEILING := 18.5

## ----- C. THE CITY'S EDGE ---------------------------------------------------------------
const EDGE := [-255.0, -150.0]
const EDGE_BLOCK := 24.0
const EDGE_STEP := 34.0
## The ring highway on stilts, running north-south under the line: x and deck height.
const RING_X := -206.0
const RING_DECK := 7.5

## ----- D. THE MONOLITH CANYON ---------------------------------------------------------------
const CANYON := [-150.0, 190.0]
## Along the track: the walls of megatowers, from d to d (metres along the line).
const WALLS_D := [400.0, 850.0]
## Lateral offsets of the two walls each side, their footprints and height ranges.
const WALL_LATERAL := [26.0, 44.0]
const WALL_FOOTPRINT := [16.0, 20.0]
const WALL_HEIGHT := [[80.0, 140.0], [110.0, 200.0]]
## A cross street every this many metres of track (the first 20 m of each span).
const CROSS_STREET_EVERY := 90.0
const CROSS_STREET_WIDTH := 20.0
## The old low blocks crammed beneath: a grid of 10 m cells, a street every third row.
const LOW_CELL := 10.0
const LOW_HEIGHT := [8.0, 15.0]

## ----- E. THE COLOSSUS CANAL ---------------------------------------------------------------
const CANAL_HALF := 18.0
const BRIDGES_Z := [-90.0, 120.0]
## Relative to the canal's centre x: [x0, x1, z0, z1].
const PLAZA := [-75.0, -22.0, 35.0, 140.0]
const HERITAGE := [-70.0, -22.0, -200.0, -110.0]
const WAREHOUSES := [22.0, 60.0, -200.0, 0.0]

## ----- F. THE LOW BLOCKS ---------------------------------------------------------------
const LOW_BLOCKS := [292.0, 560.0]
const LOW_BLOCK := 17.0
const LOW_BLOCK_STEP := 22.0
const LOW_BLOCK_HEIGHT := [12.0, 34.0]
const NEON := [Color(0.95, 0.2, 0.65), Color(0.2, 0.85, 0.95), Color(1.0, 0.7, 0.25)]

## The far skyline ring behind it all (the horizon), as in Phase A.
const SKYLINE_LATERAL := [80.0, 200.0]
const SKYLINE_HEIGHT := [60.0, 240.0]

## How far the plan runs north and south of the line.
const Z_RANGE := [-290.0, 290.0]
