class_name FountainFx
extends Node3D
## Animated water for a fountain (docs/VOXEL.md, "Water"): jets, falling sheets between tiers,
## splashes, mist and the basin surfaces. The voxel generator builds the stone; this node only adds
## the moving water. setup() is the stable API (the water work fills it in):
##   setup({"jets": [{"pos": Vector3, "height": m, "count": n}],
##          "basins": [{"pos": Vector3 (surface centre), "size": Vector2, "kind": "fountain"}],
##          "sheets": [{"from": Vector3, "to": Vector3, "width": m}],
##          "light": Color (optional underwater glow at night)})

var spec := {}


func setup(s: Dictionary) -> void:
	spec = s
	for b in s.get("basins", []):
		var w := WaterSurface.make(b.get("size", Vector2.ONE), {"kind": "fountain", "depth": 0.4})
		w.position = b.get("pos", Vector3.ZERO)
		add_child(w)
