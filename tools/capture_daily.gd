extends "res://tools/lib/verify_harness.gd"
## Frames of the daily things → tools/out/daily_*.png.
##
## Run: godot --path . -s tools/capture_daily.gd   (windowed)


func _title() -> String:
	return "CAPTURE DAILY"


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var phone := ws.find_child("LeasePhone", true, false) as LeasePhone
	var envelope := ws.find_child("NoticeEnvelope", true, false) as NoticeEnvelope
	var player := ws.find_child("Player", true, false) as PlayerMovement
	await wait(1.5)
	(ws.find_child("DayCycle", true, false) as DayCycle).morning.emit(4)
	player.global_position = envelope.global_position + Vector3(0, 0, 0.3)
	await wait(1.0)
	await capture("daily_envelope.png")
	await wait(2.2)
	await capture("daily_card.png")
	envelope.try_interact()
	await wait(0.3)
	await capture("daily_notice.png")
	(ws.find_child("NoticePanel", true, false) as NoticePanel).close()
	(ws.find_child("HeadCall", true, false) as HeadCall).play(
		[["FRIEND", "You up? Big things, big things.", 0.2]], true
	)
	await wait(0.4)
	phone.toggle()
	await wait(0.2)
	await capture("daily_phone.png")
	phone.toggle()
	for level: float in [15.0, 55.0, 95.0]:
		WallPaper.set_decay(level)
		await wait(0.2)
		await capture("daily_walls_%d.png" % int(level))
	var metro := ws.find_child("MetroRide", true, false) as MetroRide
	metro.start_ride()
	for k in 4:
		await wait(1.6)
		await capture("daily_metro_%d.png" % k)
	metro.end_ride()
