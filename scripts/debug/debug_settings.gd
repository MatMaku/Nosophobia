class_name DebugSettings
extends RefCounted
## Ephemeral session state. UI edits it; composition applies it to explicit dependencies.

signal changed

var show_debug_visuals: bool = false:
	set(value):
		if show_debug_visuals != value:
			show_debug_visuals = value
			changed.emit()
var noclip: bool = false:
	set(value):
		if noclip != value:
			noclip = value
			changed.emit()
var god_mode: bool = false:
	set(value):
		if god_mode != value:
			god_mode = value
			changed.emit()
var enemy_detection_enabled: bool = true:
	set(value):
		if enemy_detection_enabled != value:
			enemy_detection_enabled = value
			changed.emit()
var fog_enabled: bool = true:
	set(value):
		if fog_enabled != value:
			fog_enabled = value
			changed.emit()
var darkness_enabled: bool = true:
	set(value):
		if darkness_enabled != value:
			darkness_enabled = value
			changed.emit()
