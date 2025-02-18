extends ProceduralGate
class_name ProceduralGateTorus


export(float) var inner_radius := 1.5
export(float) var outer_radius := 2.0
export(int) var sides := 32
export(int) var ring_sides := 16
export(int) var collision_shape_count := 16


func _add_geometry() -> void:
	geometry = CSGTorus.new()
	geometry.inner_radius = inner_radius
	geometry.outer_radius = outer_radius
	geometry.sides = sides
	geometry.ring_sides = ring_sides
	add_child(geometry)
	geometry.rotate(Vector3.RIGHT, PI / 2.0)


func _add_collision() -> void:
	if static_body.get_child_count() > 0:
		for child in static_body.get_children():
			remove_child(child)
			child.queue_free()
	# Add capsule collision shapes
	var shape := CapsuleShape.new()
	shape.radius = (outer_radius - inner_radius) / 2.0
	var offset := inner_radius + shape.radius
	var length := 2 * PI * offset / collision_shape_count
	shape.height = length
	for i in range(collision_shape_count):
		var collision_shape := CollisionShape.new()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		collision_shape.rotate_y(2 * PI * i / collision_shape_count)
		collision_shape.translate_object_local(Vector3(offset, 0, 0))
	static_body.rotate(Vector3.RIGHT, PI / 2.0)


func _add_checkpoint() -> void:
	var shape := CylinderShape.new()
	shape.height = 0.05
	shape.radius = inner_radius
	var collision := CollisionShape.new()
	collision.shape = shape
	checkpoint.add_child(collision)
	collision.rotate(Vector3.RIGHT, PI / 2.0)
