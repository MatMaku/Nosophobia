extends RefCounted
## One resolved hitscan ray/pellet. Presentation reads these exact world-space values.

var start: Vector2
var end: Vector2
var hit: bool
var collision_normal: Vector2
var collider: Object


func _init(origin: Vector2, endpoint: Vector2, collision: Dictionary) -> void:
	start = origin
	end = endpoint
	hit = not collision.is_empty()
	collision_normal = collision.get("normal", Vector2.ZERO)
	collider = collision.get("collider")
