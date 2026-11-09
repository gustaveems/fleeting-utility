extends "res://tools/lib/verify_harness.gd"
## Playtest 2026-11-05: "the shopfronts are black". The boulevard's far side opens a lit
## shop behind its ground-floor glass (`Storefront`), and the pavements carry real street
## furniture. This gates the shops (they exist, each lit, each in its own stretch of
## street, a window display in every one), the budget (a light each, none casting shadows)
## and the furniture (a hydrant, a bin, a camera, a manhole).
##
## Run: godot --headless --path . -s tools/probe_street.gd

## Most lights the shops may add (every one is paid for on the walk).
const MAX_SHOP_LIGHTS := 16


func _title() -> String:
	return "STREET PROBE"


func _run() -> void:
	var evening := (load("res://scenes/evening.tscn") as PackedScene).instantiate()
	evening.set_process(false)  # the layout only: no film
	root.add_child(evening)
	await wait(0.5)
	var layout := evening.find_child("Layout", true, false) as EveningLayout
	if not layout.has_kit():
		print("  (the Downtown kit isn't installed: nothing to check)")
		return

	section("the shops")
	var shops: Array[Node] = layout.find_children("Storefront_*", "Node3D", true, false)
	check("at least six shops on the boulevard", shops.size() >= 6)
	var kinds := {}
	var lit := 0
	var displays := 0
	var shadowed := 0
	for shop in shops:
		kinds[shop.get_meta("kind", -1)] = true
		var light := shop.find_child("ShopLight", false, false) as OmniLight3D
		if light != null:
			lit += 1
			if light.shadow_enabled:
				shadowed += 1
		if shop.find_child("Display", false, false) != null:
			displays += 1
	check("every shop is lit (%d of %d)" % [lit, shops.size()], lit == shops.size())
	check("no shop light casts shadows", shadowed == 0)
	check("not too many lights (%d)" % lit, lit <= MAX_SHOP_LIGHTS)
	check("every shop has a window display (%d)" % displays, displays == shops.size())
	check("all three kinds of shop (%d)" % kinds.size(), kinds.size() == Storefront.Kind.size())
	var overlaps: Array[String] = []
	for i in shops.size():
		for j in range(i + 1, shops.size()):
			var a := shops[i] as Node3D
			var b := shops[j] as Node3D
			var reach: float = float(a.get_meta("width")) * 0.5 + float(b.get_meta("width")) * 0.5
			if (
				absf(a.position.z - b.position.z) < reach
				and absf(a.position.x - b.position.x) < 1.0
			):
				overlaps.append("%s/%s" % [a.name, b.name])
	check("no two shops share a stretch of street %s" % [overlaps.slice(0, 3)], overlaps.is_empty())

	section("the lamps and the shop lights")
	var lamp_01 := layout.find_children("Lamp_01_*", "Node3D", true, false)
	var lamp_02 := layout.find_children("Lamp_02_*", "Node3D", true, false)
	check(
		"both lamp models along the pavement (%d / %d)" % [lamp_01.size(), lamp_02.size()],
		lamp_01.size() >= 4 and lamp_02.size() >= 4
	)
	var lights := layout.find_children("SecurityLight_*", "Node3D", true, false)
	check(
		"a security light over every shop (%d of %d)" % [lights.size(), shops.size()],
		lights.size() == shops.size()
	)

	section("the street furniture")
	for kind in ["Hydrant", "Bin", "Camera", "Manhole"]:
		var found := layout.find_children(kind + "_*", "Node3D", true, false)
		check("%s: %d placed" % [kind, found.size()], found.size() >= 2)
	check(
		"bags out by the bins", not layout.find_children("Bag_*", "Node3D", true, false).is_empty()
	)

	section("the wet street")
	var world_env := evening.find_child("*", true, false)
	for n: Node in evening.get_children():
		if n is WorldEnvironment:
			world_env = n
	check(
		"the road holds reflections (screen-space on)",
		(world_env as WorldEnvironment).environment.ssr_enabled
	)
	var spills := layout.find_children("LightSpill", "MeshInstance3D", true, false)
	check("every shop's light lies on the pavement", spills.size() == shops.size())
	var rats := layout.find_children("Rat_*", "Node3D", true, false)
	check("rats on the kerb (%d)" % rats.size(), rats.size() >= 2)
	var was := (rats[0] as Node3D).position.z
	await wait(1.0)
	check("and they run", not is_equal_approx((rats[0] as Node3D).position.z, was))
	section("the rain")
	var rain := evening.get("rain") as RainFall
	check("no rain before the walk", not rain.active)
	evening.segment_started.emit("walk")
	check("it rains on the walk", rain.active)
	evening.segment_started.emit("metro")
	check("and stops at the metro", not rain.active)
	evening.queue_free()
