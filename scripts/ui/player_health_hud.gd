extends Label


func bind_health(health: Node) -> void:
	health.changed.connect(_update_health)
	_update_health(health.current_health, health.max_health)


func _update_health(current: float, maximum: float) -> void:
	text = "Vida: %.0f / %.0f" % [current, maximum]
	if current <= 0.0:
		text += " — sin vida"
