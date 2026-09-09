extends Camera2D
## Short deterministic shot shake. Camera position is never modified.

var _rest_offset: Vector2
var _strength: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_rest_offset = offset
	set_process(false)


func shake(strength: float, duration: float) -> void:
	_strength = maxf(strength, 0.0)
	_duration = maxf(duration, 0.0)
	_elapsed = 0.0
	offset = _rest_offset
	set_process(_strength > 0.0 and _duration > 0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		_stop_shake()
		return
	var progress := _elapsed / _duration
	var decay := (1.0 - progress) * (1.0 - progress)
	var phase := progress * TAU * 3.0
	var displacement := Vector2(sin(phase), sin(phase * 1.7 + 0.8))
	offset = _rest_offset + displacement * _strength * decay


func _stop_shake() -> void:
	offset = _rest_offset
	set_process(false)
