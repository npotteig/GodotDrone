extends Spatial


export (Mesh) var mesh: Mesh = null
export (Color) var cone_color := Color(1.0, 1.0, 1.0, 1.0)
onready var multimesh_instance := $MultiMeshInstance


func _ready():
	var multimesh: MultiMesh = multimesh_instance.multimesh
	var count := 0
	var transforms := []
	for child in multimesh_instance.get_children():
		if child is MeshInstance:
			count += 1
			transforms.append(child.transform)
			multimesh_instance.remove_child(child)
			child.queue_free()
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in multimesh.instance_count:
		multimesh.set_instance_transform(i, transforms[i])
