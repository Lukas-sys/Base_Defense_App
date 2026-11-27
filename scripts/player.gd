class_name Player
extends Carrier
## Die Spielfigur. Bewegung per Joystick (Handy) oder WASD/Pfeiltasten (PC).


func _ready() -> void:
	build_body(Color(0.85, 0.5, 0.45), Color(0.35, 0.65, 0.85))
	speed = 6.0


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	input += game.hud.joystick.output + game.autopilot_input
	if input.length() > 1.0:
		input = input.normalized()
	walk(Vector3(input.x, 0.0, input.y), delta)
