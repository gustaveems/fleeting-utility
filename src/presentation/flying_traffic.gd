class_name FlyingTraffic
extends Node3D
## PRESENTATION — flying cars streaming along straight sky lanes (Fab: Cyberpunk Flying
## Car, Floating Cyber Car, Sentinel police car). Each lane runs `from` → `to` at a speed;
## cars wrap at the end, evenly spread. Missing models leave the lane empty.
##
##   traffic.add_lane(from, to, speed, count, [model paths])

const MODELS: Array[String] = [
	"res://assets/third_party/fab/flying_car/car.glb",
	"res://assets/third_party/fab/cyber_car/floating_futuristic_cyber_car_jfg.glb",
	"res://assets/third_party/fab/police_car/sentinel_pursuer.glb",
]
## Each model's own forward axis (they were authored facing different ways).
const FORWARD: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.BACK]

var _lanes: Array[Dictionary] = []


func add_lane(from: Vector3, to: Vector3, speed: float, count: int, seed: int = 0) -> void:
	var dir := (to - from).normalized()
	var length := from.distance_to(to)
	var cars: Array[Node3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in count:
		var i := rng.randi() % MODELS.size()
		if not ResourceLoader.exists(MODELS[i]):
			continue
		var car := (load(MODELS[i]) as PackedScene).instantiate() as Node3D
		add_child(car)
		# Turn the model so its own forward axis points along the lane.
		var yaw := atan2(dir.x, dir.z) - atan2(FORWARD[i].x, FORWARD[i].z)
		car.rotation.y = yaw
		car.set_meta("along", length * (k + rng.randf_range(0.0, 0.6)) / count)
		cars.append(car)
		_place(car, from, dir, length)
	_lanes.append({"from": from, "dir": dir, "length": length, "speed": speed, "cars": cars})


func _process(delta: float) -> void:
	for lane in _lanes:
		for car: Node3D in lane["cars"]:
			var along := fposmod(
				float(car.get_meta("along")) + float(lane["speed"]) * delta, lane["length"]
			)
			car.set_meta("along", along)
			_place(car, lane["from"], lane["dir"], lane["length"])


func _place(car: Node3D, from: Vector3, dir: Vector3, length: float) -> void:
	car.position = from + dir * fposmod(float(car.get_meta("along")), length)
