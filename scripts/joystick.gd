class_name Joystick
extends Control
## Virtueller Joystick für Touchscreens: irgendwo in der linken Bildschirmhälfte
## den Finger auflegen und ziehen. Am PC geht das auch mit gedrückter Maustaste.

const RADIUS := 80.0
const KNOB_RADIUS := 34.0

var output := Vector2.ZERO
var touch_index := -1
var center := Vector2.ZERO
var knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch_index == -1 and touch.position.x < get_viewport_rect().size.x * 0.5:
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
	var c := center
	var k := knob
	if touch_index == -1:
		c = Vector2(150, get_viewport_rect().size.y - 150)
		k = c
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
	draw_circle(k, KNOB_RADIUS, Color(1, 1, 1, 0.5))
