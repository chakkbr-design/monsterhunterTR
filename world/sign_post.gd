class_name SignPost
extends WorldNpc
## Readable sign (post + board). Built by MapBuilder from a map's "signs" entries.


func _build_body() -> void:
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
	return "E: Ler"
