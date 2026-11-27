class_name Joystick
extends Control
## Schwebender Joystick: Finger irgendwo auf den Bildschirm legen und ziehen.
## Am PC geht das genauso mit gedrückter linker Maustaste.

const RADIUS := 90.0
const KNOB_RADIUS := 38.0

var output := Vector2.ZERO
var touch_index := -1
var center := Vector2.ZERO
var knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch_index == -1:
			touch_index = touch.index
			center = touch.position
			knob = center
			output = Vector2.ZERO
			queue_redraw()
		elif not touch.pressed and touch.index == touch_index:
			touch_index = -1
			output = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != touch_index:
			return
		var offset := drag.position - center
		if offset.length() > RADIUS:
			offset = offset.normalized() * RADIUS
		knob = center + offset
		output = offset / RADIUS
		queue_redraw()


func _draw() -> void:
	if touch_index == -1:
		return
	draw_circle(center, RADIUS, Color(0, 0, 0, 0.15))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 4.0)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.75))
