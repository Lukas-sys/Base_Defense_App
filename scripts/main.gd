class_name Main
extends Node3D
## Holzwacht – das Herz des Spiels.
## Baut die Welt auf, steuert Tag und Nacht, schickt Gegnerwellen und verwaltet
## Rohstoffe und Upgrades.
##
## Spielablauf:
##   Tag:   Holz hacken und Stein abbauen (einfach daneben stehen), Arbeiter
##          anheuern, Axt/Waffe/Mauer verbessern, Türme bauen.
##   Nacht: Monster greifen die Basis an. Spieler und Türme kämpfen automatisch.
##          Sind alle Monster besiegt, beginnt der nächste Tag.

const MAP_RADIUS := 28.0
const BASE_RADIUS := 4.5
const HQ_HIT_RADIUS := 4.2
const DAY_DURATION := 50.0
const MAX_WORKERS := 6
const TREE_COUNT := 45
const ROCK_COUNT := 20

const DAY_SKY := Color(0.55, 0.75, 0.95)
const NIGHT_SKY := Color(0.03, 0.04, 0.1)

# Rohstoffe und Fortschritt
var wood := 0
var stone := 0
var day := 1
var is_night := false
var phase_time := DAY_DURATION
var day_duration := DAY_DURATION
var enemies_to_spawn := 0
var spawn_timer := 0.0
var game_over := false
var kills := 0

# Upgrade-Stufen
var axe_level := 1
var weapon_level := 1
var wall_level := 1
var hq_max_hp := 150.0
var hq_hp := 150.0

# Spielobjekte
var player: Player
var hud: Hud
var camera: Camera3D
var sun: DirectionalLight3D
var torch: OmniLight3D
var environment: Environment
var hq: Node3D
var wall_ring: Node3D
var resource_nodes: Array[ResourceNode] = []
var enemies: Array[Enemy] = []
var workers: Array[Worker] = []
var towers: Array[Tower] = []
var tower_slots: Array[Vector3] = []
var night_factor := 0.0

# Automatischer Selbsttest (wird von GitHub Actions benutzt, siehe README)
var smoke_test := false
var smoke_time := 0.0


func _ready() -> void:
	randomize()
	smoke_test = "--smoke" in OS.get_cmdline_user_args()
	if smoke_test:
		day_duration = 3.0
		phase_time = day_duration
		Engine.time_scale = 4.0
		print("Selbsttest gestartet")
	for i in 6:
		var angle := TAU * i / 6.0 + PI / 6.0
		tower_slots.append(Vector3(cos(angle), 0, sin(angle)) * 7.0)
	_build_environment()
	_build_ground()
	_build_base()
	_spawn_resources()
	player = Player.new()
	player.setup(self)
	player.position = Vector3(0, 0, 2.0)
	add_child(player)
	camera = Camera3D.new()
	camera.rotation_degrees = Vector3(-54, 0, 0)
	camera.fov = 55.0
	add_child(camera)
	camera.position = player.position + _camera_offset()
	hud = Hud.new()
	hud.setup(self)
	add_child(hud)
	hud.show_message("Lauf zu Bäumen und Felsen, um zu sammeln!", 4.0)
	if smoke_test:
		_smoke_buy_everything()


func _process(delta: float) -> void:
	camera.position = camera.position.lerp(player.position + _camera_offset(), 1.0 - exp(-6.0 * delta))
	_update_lighting(delta)
	if smoke_test:
		_smoke_step(delta)
	if game_over:
		return
	if not is_night:
		phase_time -= delta
		if phase_time <= 0.0:
			_start_night()
	else:
		if enemies_to_spawn > 0:
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				_spawn_enemy()
				enemies_to_spawn -= 1
				spawn_timer = maxf(0.5, 2.0 - 0.1 * day)
		elif enemies.is_empty():
			_start_day()


func _camera_offset() -> Vector3:
	return Vector3(0, 16, 11.5)


# ---------------------------------------------------------------- Tag & Nacht

func start_night_now() -> void:
	if not is_night and not game_over:
		phase_time = 0.0


func enemies_left() -> int:
	return enemies.size() + enemies_to_spawn


func _start_night() -> void:
	is_night = true
	enemies_to_spawn = 3 + day * 2
	spawn_timer = 0.5
	hud.show_message("Die Nacht bricht herein! Verteidige deine Basis!", 3.0)


func _start_day() -> void:
	is_night = false
	var bonus := 5 + day * 3
	wood += bonus
	stone += bonus
	day += 1
	phase_time = day_duration
	hq_hp = minf(hq_max_hp, hq_hp + hq_max_hp * 0.25)
	player.hp = player.max_hp
	hud.show_message("Nacht überlebt! Belohnung: +%d Holz, +%d Stein" % [bonus, bonus], 3.5)


func _update_lighting(delta: float) -> void:
	var goal := 1.0 if is_night else 0.0
	night_factor = lerpf(night_factor, goal, 1.0 - exp(-1.5 * delta))
	sun.light_energy = lerpf(1.2, 0.12, night_factor)
	environment.background_color = DAY_SKY.lerp(NIGHT_SKY, night_factor)
	environment.ambient_light_energy = lerpf(0.7, 0.2, night_factor)
	torch.light_energy = lerpf(0.0, 3.0, night_factor)


# --------------------------------------------------------------- Rohstoffe

func add_resource(kind: String, amount: int, where: Vector3) -> void:
	if kind == "wood":
		wood += amount
		popup_text(where, "+%d Holz" % amount, Color(0.95, 0.75, 0.45))
	else:
		stone += amount
		popup_text(where, "+%d Stein" % amount, Color(0.85, 0.88, 0.95))


func find_nearest_resource(from: Vector3, max_dist: float, kind := "") -> ResourceNode:
	var best: ResourceNode = null
	var best_dist := max_dist
	for node in resource_nodes:
		if not node.is_available():
			continue
		if kind != "" and node.kind != kind:
			continue
		var d := from.distance_to(node.position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


func gather_interval() -> float:
	return 0.9 / (1.0 + 0.4 * (axe_level - 1))


func gather_yield() -> int:
	return 1 + int((axe_level - 1) / 3.0)


# ------------------------------------------------------------------- Kampf

func find_nearest_enemy(from: Vector3, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_dist := max_dist
	for enemy in enemies:
		if enemy.dead:
			continue
		var d := from.distance_to(enemy.position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func weapon_damage() -> float:
	return 12.0 + 7.0 * (weapon_level - 1)


func weapon_range() -> float:
	return 4.5 + 0.25 * (weapon_level - 1)


func weapon_cooldown() -> float:
	return maxf(0.35, 0.7 - 0.03 * (weapon_level - 1))


func tower_damage() -> float:
	return 10.0 + 5.0 * (weapon_level - 1)


func spawn_projectile(from: Vector3, target: Enemy, damage: float, color: Color) -> void:
	var p := Projectile.new()
	p.setup(target, damage, color)
	p.position = from
	add_child(p)


func damage_hq(amount: float) -> void:
	if game_over:
		return
	hq_hp -= amount
	if hq_hp <= 0.0:
		hq_hp = 0.0
		game_over = true
		hud.show_game_over(day)


func on_enemy_killed(enemy: Enemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	enemies.erase(enemy)
	kills += 1
	add_resource("stone", 1 + int(day / 3.0), enemy.position)
	enemy.queue_free()


func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	enemy.setup(self, day)
	var angle := randf() * TAU
	enemy.position = Vector3(cos(angle), 0, sin(angle)) * MAP_RADIUS
	add_child(enemy)
	enemies.append(enemy)


# ---------------------------------------------------------------- Upgrades
# IDs: "worker", "axe", "weapon", "wall", "tower"

## Kosten als Vector2i: x = Holz, y = Stein
func get_cost(id: String) -> Vector2i:
	match id:
		"worker":
			return Vector2i(12 + 10 * workers.size(), 4 * workers.size())
		"axe":
			return Vector2i(8 * axe_level, 4 * axe_level)
		"weapon":
			return Vector2i(6 * weapon_level, 8 * weapon_level)
		"wall":
			return Vector2i(12 * wall_level, 10 * wall_level)
		"tower":
			return Vector2i(20 + 15 * towers.size(), 15 + 12 * towers.size())
	return Vector2i.ZERO


func is_maxed(id: String) -> bool:
	match id:
		"worker":
			return workers.size() >= MAX_WORKERS
		"axe":
			return axe_level >= 8
		"weapon":
			return weapon_level >= 10
		"wall":
			return wall_level >= 10
		"tower":
			return towers.size() >= tower_slots.size()
	return true


func can_buy(id: String) -> bool:
	if game_over or is_maxed(id):
		return false
	var cost := get_cost(id)
	return wood >= cost.x and stone >= cost.y


func upgrade_text(id: String) -> String:
	var title := ""
	match id:
		"worker":
			title = "Arbeiter anheuern (%d/%d)" % [workers.size(), MAX_WORKERS]
		"axe":
			title = "Axt verbessern (Stufe %d)" % axe_level
		"weapon":
			title = "Waffe verbessern (Stufe %d)" % weapon_level
		"wall":
			title = "Mauer verstärken (Stufe %d)" % wall_level
		"tower":
			title = "Turm bauen (%d/%d)" % [towers.size(), tower_slots.size()]
	if is_maxed(id):
		return title + "\nMaximum erreicht"
	var cost := get_cost(id)
	return "%s\n%d Holz   %d Stein" % [title, cost.x, cost.y]


func buy(id: String) -> void:
	if not can_buy(id):
		return
	var cost := get_cost(id)
	wood -= cost.x
	stone -= cost.y
	match id:
		"worker":
			var w := Worker.new()
			w.setup(self, "wood" if workers.size() % 2 == 0 else "stone")
			w.position = Vector3(randf_range(-1.5, 1.5), 0, 2.5)
			add_child(w)
			workers.append(w)
			hud.show_message("Ein neuer Arbeiter hilft dir!")
		"axe":
			axe_level += 1
			hud.show_message("Axt verbessert: du sammelst schneller!")
		"weapon":
			weapon_level += 1
			hud.show_message("Waffe verbessert: mehr Schaden für dich und die Türme!")
		"wall":
			wall_level += 1
			hq_max_hp += 60.0
			hq_hp = hq_max_hp
			_build_wall()
			hud.show_message("Mauer verstärkt und repariert!")
		"tower":
			var t := Tower.new()
			t.setup(self)
			t.position = tower_slots[towers.size()]
			add_child(t)
			towers.append(t)
			hud.show_message("Turm gebaut!")


# ------------------------------------------------------------- Welt-Aufbau

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = DAY_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)
	torch = OmniLight3D.new()
	torch.position = Vector3(0, 4.0, 0)
	torch.light_color = Color(1.0, 0.65, 0.3)
	torch.omni_range = 14.0
	torch.light_energy = 0.0
	add_child(torch)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_RADIUS * 2.0 + 30.0, MAP_RADIUS * 2.0 + 30.0)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = Util.mat(Color(0.33, 0.55, 0.27))
	add_child(ground)
	# Lichtung um die Basis
	var clearing := Util.cylinder(BASE_RADIUS + 4.0, BASE_RADIUS + 4.0, 0.02, Color(0.55, 0.47, 0.32), Vector3(0, 0.01, 0))
	add_child(clearing)


func _build_base() -> void:
	hq = Node3D.new()
	add_child(hq)
	hq.add_child(Util.box(Vector3(3.0, 2.0, 3.0), Color(0.6, 0.42, 0.25), Vector3(0, 1.0, 0)))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(3.6, 1.4, 3.6)
	roof.mesh = prism
	roof.material_override = Util.mat(Color(0.65, 0.2, 0.15))
	roof.position = Vector3(0, 2.7, 0)
	hq.add_child(roof)
	hq.add_child(Util.box(Vector3(0.8, 1.2, 0.1), Color(0.3, 0.2, 0.1), Vector3(0, 0.6, 1.52)))
	hq.add_child(Util.cylinder(0.05, 0.05, 1.6, Color(0.3, 0.2, 0.1), Vector3(1.2, 4.0, 1.2)))
	var flag := Util.box(Vector3(0.8, 0.5, 0.05), Color(0.95, 0.8, 0.2), Vector3(1.6, 4.55, 1.2))
	hq.add_child(flag)
	_build_wall()


func _build_wall() -> void:
	if wall_ring != null:
		wall_ring.queue_free()
	wall_ring = Node3D.new()
	add_child(wall_ring)
	var height := 0.7 + 0.25 * wall_level
	var color := Color(0.5, 0.34, 0.2) if wall_level < 4 else Color(0.55, 0.55, 0.6)
	var segments := 28
	var radius := 3.7
	for i in segments:
		# Lücke als Tor (zur Kamera hin)
		if i == 6 or i == 7:
			continue
		var angle := TAU * i / segments
		var post := Util.box(Vector3(0.5, height, 0.5), color, Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius))
		post.rotation.y = -angle
		wall_ring.add_child(post)


func _spawn_resources() -> void:
	for i in TREE_COUNT + ROCK_COUNT:
		var node := ResourceNode.new()
		node.setup("wood" if i < TREE_COUNT else "stone")
		node.position = _free_spot()
		add_child(node)
		resource_nodes.append(node)


## Sucht einen zufälligen Platz, der nicht zu nah an der Basis oder anderen Objekten ist.
func _free_spot() -> Vector3:
	var pos := Vector3.ZERO
	for attempt in 30:
		var angle := randf() * TAU
		var dist := randf_range(BASE_RADIUS + 5.0, MAP_RADIUS - 2.0)
		pos = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		var ok := true
		for other in resource_nodes:
			if other.position.distance_to(pos) < 2.2:
				ok = false
				break
		if ok:
			return pos
	return pos


func popup_text(where: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 10
	label.pixel_size = 0.01
	label.position = where + Vector3(0, 2.4, 0)
	add_child(label)
	var t := label.create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y + 1.5, 1.0)
	t.tween_property(label, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------- Selbsttest (CI)

func _smoke_buy_everything() -> void:
	wood = 5000
	stone = 5000
	for id in ["worker", "worker", "axe", "weapon", "wall", "tower", "tower"]:
		buy(id)
	print("Selbsttest: Arbeiter=%d Türme=%d Axt=%d Waffe=%d Mauer=%d" % [workers.size(), towers.size(), axe_level, weapon_level, wall_level])


func _smoke_step(delta: float) -> void:
	smoke_time += delta
	if smoke_time > 60.0:
		print("SMOKE_TEST_OK Tag=%d Besiegt=%d Holz=%d Stein=%d Basis=%d" % [day, kills, wood, stone, int(hq_hp)])
		Engine.time_scale = 1.0
		get_tree().quit()
