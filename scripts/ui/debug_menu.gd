extends CanvasLayer
## Only edits settings; knows nothing about physics, enemies or rendering internals.

signal panel_changed
const FLAGS := ["show_debug_visuals", "noclip", "god_mode",
	"enemy_detection_enabled", "fog_enabled", "darkness_enabled"]
var _settings: DebugSettings
@onready var _panel: Control = $Blocker
@onready var _options: VBoxContainer = $Blocker/Panel/Margin/Options


func bind_settings(settings: DebugSettings) -> void:
	_settings = settings
	for flag in FLAGS:
		var checkbox := _options.get_node(flag) as CheckBox
		checkbox.toggled.connect(func(value: bool): _settings.set(flag, value))
	_settings.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for flag in FLAGS:
		_options.get_node(flag).set_pressed_no_signal(_settings.get(flag))


func is_open() -> bool:
	return _panel.visible


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_menu") and not event.is_echo():
		_panel.visible = not _panel.visible
		panel_changed.emit()
		get_viewport().set_input_as_handled()
