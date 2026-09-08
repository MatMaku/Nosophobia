extends Node2D
## Draws the test arena directly from its static collision shapes.


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 720), Color(0.055, 0.07, 0.09))
	for child in get_children():
		if child is not StaticBody2D:
			continue
		var collider := child.get_node("CollisionShape2D") as CollisionShape2D
		var center: Vector2 = child.position + collider.position
		var color := Color(0.3, 0.36, 0.42)
		if collider.shape is RectangleShape2D:
			var size: Vector2 = collider.shape.size
			draw_rect(Rect2(center - size / 2.0, size), color)
		elif collider.shape is CircleShape2D:
			draw_circle(center, collider.shape.radius, color)
