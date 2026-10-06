extends CanvasLayer
## Multi-touch pads. Each child of $Pads is named after the input action it presses,
## so touch drives the same InputMap actions as the keyboard.

var _touches := {}  # finger index -> action name
var _held: Array = []

@onready var pads := $Pads.get_children()


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if event is InputEventScreenDrag or event.pressed:
		_touches[event.index] = _action_at(event.position)
	else:
		_touches.erase(event.index)
	var now := _touches.values()
	for pad in pads:
		var a: String = pad.name
		if now.has(a) and not _held.has(a):
			Input.action_press(a)
		elif _held.has(a) and not now.has(a):
			Input.action_release(a)
		pad.modulate.a = 1.0 if now.has(a) else 0.55
	_held = now


func _action_at(pos: Vector2) -> String:
	for pad in pads:
		if pad.get_global_rect().has_point(pos):
			return pad.name
	return ""


func _exit_tree() -> void:
	for a in _held:
		Input.action_release(a)
