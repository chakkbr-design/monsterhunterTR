extends SceneTree
## Headless: godot --headless --fixed-fps 144 --path . --script res://tests/world/test_world_motion.gd
## (also passes at 60). Render-rate smoothness of the overworld: the player sprite keeps a steady
## offset from the camera while walking (no 60 Hz stepping), a walking wild mon never flickers
## Walk/Idle, a pond swimmer's peace timer runs out, and Z/C don't turn the camera behind a modal UI.

var _fails := 0
var p
var cam
var wm
var rel: Array = []
var anims: Array = []


class Probe:
	extends Node  # runs after every other _process: samples what gets drawn
	var cb: Callable

	func _process(_d: float) -> void:
		cb.call()


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("ok   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _sample() -> void:
	var vis: Node3D = p.sprite if p.sprite else p
	rel.append(vis.global_position.x - (cam.camera as Camera3D).global_position.x)
	if is_instance_valid(wm) and wm.look:
		wm._wander_t = 5.0
		wm._wander_to = wm.global_position + Vector3(5, 0, 0)
		anims.append(wm.look.current_anim())


func _run() -> void:
	var scene: Node3D = load("res://world/overworld.tscn").instantiate()
	root.add_child(scene)
	for i in 30:
		await process_frame
	p = get_first_node_in_group("ow_player")
	cam = get_first_node_in_group("ow_camera")
	wm = get_nodes_in_group("ow_wild")[0]
	wm.peace_timer = 1000.0  # passive wander towards +x, never engages
	p.global_position = Vector3(-15, 0.2, 10)  # 3 s east (12 m) stays clear of the east wall
	for i in 30:
		await process_frame
	check(
		p.visual_position().is_equal_approx(p.global_position),
		"teleport: visual position snaps to the body"
	)
	Input.action_press("move_right")
	var probe := Probe.new()
	probe.process_priority = 10000
	probe.cb = _sample
	root.add_child(probe)
	var t := 0.0
	while t < 3.0:
		await process_frame
		t += root.get_process_delta_time()
	Input.action_release("move_right")
	probe.queue_free()
	var worst := 0.0
	for i in range(rel.size() / 2, rel.size()):
		worst = maxf(worst, absf(rel[i] - rel[i - 1]))
	check(
		worst < 0.005,
		"player sprite steady against the camera while walking (worst %.4f m/frame)" % worst
	)
	var flips := 0
	for i in range(1, anims.size()):
		if anims[i] != anims[i - 1]:
			flips += 1
	check(
		anims.size() > 60 and flips <= 2,
		"walking wild mon keeps its Walk animation (%d flips)" % flips
	)

	# Pond swimmer (roams = false): the peace timer after running away must still run out.
	var sw: Node3D = load("res://world/wild_mon.gd").spawn(
		load("res://core/mon.gd").create("magikarp", 5), {}, scene, Vector3(-5, 0.2, 5)
	)
	sw.roams = false
	sw.peace_timer = 0.5
	for i in 60:
		await physics_frame
	check(sw.peace_timer <= 0.0, "swimmer peace timer runs out (%.2f)" % sw.peace_timer)
	sw.queue_free()

	# No manual camera turn (like the original): Z/C are not camera keys and leave the yaw alone.
	check(
		not InputMap.has_action("cam_left") and not InputMap.has_action("cam_right"),
		"no cam_left/cam_right actions"
	)
	var yaw0: float = cam.yaw()
	for k in [KEY_Z, KEY_C]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = true
		Input.parse_input_event(ev)
		await process_frame
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await process_frame
	for i in 30:
		await process_frame
	check(is_equal_approx(cam.yaw(), yaw0), "Z/C do not turn the camera")
	print("[world motion] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
