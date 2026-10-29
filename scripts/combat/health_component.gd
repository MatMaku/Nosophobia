extends Node
## Per-owner health. Death is emitted once; presentation and removal belong to the owner.

signal damaged(amount: float)
signal died
signal changed(current: float, maximum: float)

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0:
	set(value):
		if is_equal_approx(max_health, maxf(1.0, value)):
			return
		max_health = maxf(1.0, value)
		_current_health = minf(_current_health, max_health)
		changed.emit(_current_health, max_health)

var current_health: float:
	get:
		return _current_health

var _current_health: float = 0.0


func _ready() -> void:
	reset(max_health)


func reset(new_max_health: float) -> void:
	max_health = maxf(1.0, new_max_health)
	_current_health = max_health
	changed.emit(_current_health, max_health)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or _current_health <= 0.0:
		return
	var previous := _current_health
	_current_health = clampf(_current_health - amount, 0.0, max_health)
	damaged.emit(previous - _current_health)
	changed.emit(_current_health, max_health)
	if _current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	# Healing is not resurrection. Explicit reset is reserved for initialization.
	if amount <= 0.0 or _current_health <= 0.0:
		return
	var previous := _current_health
	_current_health = minf(_current_health + amount, max_health)
	if previous != _current_health:
		changed.emit(_current_health, max_health)
