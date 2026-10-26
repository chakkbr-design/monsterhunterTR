extends SceneTree
## Headless: godot --headless --fixed-fps 60 --path . --script res://tests/ui_front/test_loading.gd
## The loading screen (autoload Loading): delay, hold keys, fade out, and around a house -> Pallet trip.

var _fails := 0
var _shown := 0
var _hidden := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	var ld = root.get_node("/root/Loading")
	ld.shown.connect(func(): _shown += 1)
	ld.hidden.connect(func(): _hidden += 1)
	await frames(2)
	check(not ld.is_showing() and not ld.is_visible_now(), "hidden at start")

	# Short work (under the delay): never shown.
	ld.delay = 0.2
	ld.begin("a")
	await frames(3)
	ld.end("a")
	await _secs(0.3)
	check(_shown == 0 and not ld.is_visible_now(), "short work does not show the screen")

	# Long work: shown after the delay, then fades out.
	ld.begin("b")
	await _secs(0.35)
	check(ld.is_showing() and ld.is_visible_now() and _shown == 1, "long work shows the screen")
	ld.end("b")
	await _secs(ld.MIN_SHOW + ld.FADE_S + 0.2)
	check(not ld.is_showing() and not ld.is_visible_now() and _hidden == 1, "screen hides after")

	# Keys add up; end_later waits frames.
	ld.begin_now("x")
	ld.begin_now("y")
	check(ld.is_showing(), "begin_now shows at once")
	ld.end("x")
	await _secs(ld.MIN_SHOW + 0.1)
	check(ld.is_showing(), "stays while another key is held")
	ld.end_later("y", 2)
	check(ld.busy(), "end_later holds a couple of frames")
	await _secs(ld.MIN_SHOW + ld.FADE_S + 0.2)
	check(not ld.is_showing() and not ld.busy(), "all keys released")

	# House -> Pallet with a real (short) fade: the screen wraps the trip.
	var game = root.get_node("/root/Game")
	game.spawn_request = {"interior": "player_house", "spawn": "door"}
	game.last_save = {}
	ld.delay = 0.0
	var w = load("res://world/route_world.tscn").instantiate()
	w.fade_time = 0.02
	root.add_child(w)
	await frames(10)
	_shown = 0
	_hidden = 0
	await w.go_to_zone("pallet_town", "player_house_door")
	check(_shown >= 1, "loading screen appeared around the house -> Pallet trip")
	check(
		w.builders.has("pallet_town") and w.builders.pallet_town.is_built,
		"Pallet built after the trip"
	)
	check(not w.traveling, "trip finished")
	await _secs(ld.MIN_SHOW + ld.FADE_S + 0.3)
	check(_hidden >= 1 and not ld.is_visible_now(), "loading screen gone after the trip")
	w.queue_free()
	await frames(2)
	print("FAILS: %d" % _fails)
	quit(1 if _fails > 0 else 0)
