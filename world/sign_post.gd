class_name SignPost
extends WorldNpc
## Readable sign. Built by MapBuilder from a map's "signs" entries with the original's HGSS model
## (map "model", default hgss/common/sign_a at 0.8); a post + board only if the model is missing.

var model := "hgss/common/sign_a"
var model_scale := 0.8
var model_rot := 180.0  ## world yaw of the model (deg), the map's "rot"
var model_billboard := false  ## camera-facing foliage (cut trees)
var model_tint := Color.WHITE
var verb := "E: Read"
var drawn := true  ## false when the zone draws the sign itself (voxel zones): prompt only


func _build_body() -> void:
	if not drawn:
		show_tag = false
		return
	var inst := WorldProps.place(
		self,
		model if model != "" else "hgss/common/sign_a",
		global_position if is_inside_tree() else position,
		{"scale": model_scale, "billboard": model_billboard, "tint": model_tint}
	)
	if inst:
		show_tag = false
		inst.position = Vector3.ZERO
		inst.global_rotation.y = deg_to_rad(model_rot)
		return
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 1.0, 0.12)
	pm.material = MapBuilder.mat(Color(0.42, 0.3, 0.18))
	post.mesh = pm
	post.position.y = 0.5
	add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.55, 0.08)
	bm.material = MapBuilder.mat(color)
	board.mesh = bm
	board.position.y = 1.05
	add_child(board)


func prompt() -> String:
	return verb
