class_name Util
extends RefCounted
## Helfer für die Grafik: abgerundete Formen, Materialien, Texturen, Schrift.
## Figuren, Pflanzen und Gegenstände werden im Code erzeugt (Maschinen und Deko: siehe Models).

static var _materials := {}
static var _meshes := {}
static var _font: SystemFont


# ------------------------------------------------------------------ Materialien

## Liefert ein (zwischengespeichertes) einfarbiges Material.
static func mat(color: Color, glowing := false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), glowing]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	_materials[key] = m
	return m


## Material, das die Farben direkt aus dem Modell nimmt (für Farbverläufe).
static func vertex_color_mat() -> StandardMaterial3D:
	if _materials.has("_vc"):
		return _materials["_vc"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	_materials["_vc"] = m
	return m


## Material mit Textur, die sich auf großen Flächen wiederholt.
static func textured_mat(tex: Texture2D, repeat: Vector2, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_scale = Vector3(repeat.x, repeat.y, 1)
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


# ---------------------------------------------------------------- Grundformen

## Abgerundeter Quader (sieht viel weicher aus als ein normaler Würfel).
static func box(size: Vector3, color: Color, pos := Vector3.ZERO, roundness := 0.22) -> MeshInstance3D:
	var r := minf(minf(size.x, size.y), size.z) * 0.5 * roundness * 2.0
	return _instance(rounded_box_mesh(size, r), color, pos)


static func cylinder(top_radius: float, bottom_radius: float, height: float, color: Color, pos := Vector3.ZERO, segments := 18) -> MeshInstance3D:
	var key := "cyl_%.3f_%.3f_%.3f_%d" % [top_radius, bottom_radius, height, segments]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top_radius
		mesh.bottom_radius = bottom_radius
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		_meshes[key] = mesh
	return _instance(_meshes[key], color, pos)


static func sphere(radius: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "sph_%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 18
		mesh.rings = 9
		_meshes[key] = mesh
	return _instance(_meshes[key], color, pos)


static func hemisphere(radius: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "hemi_%.3f" % radius
	if not _meshes.has(key):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius
		mesh.is_hemisphere = true
		mesh.radial_segments = 18
		mesh.rings = 5
		_meshes[key] = mesh
	return _instance(_meshes[key], color, pos)


static func capsule(radius: float, height: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "cap_%.3f_%.3f" % [radius, height]
	if not _meshes.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = height
		mesh.radial_segments = 18
		mesh.rings = 6
		_meshes[key] = mesh
	return _instance(_meshes[key], color, pos)


## Kantige "Low-Poly"-Kugel (für Büsche und Baumkronen).
static func lowpoly_sphere(radius: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "lp_%.3f" % radius
	if not _meshes.has(key):
		var src := SphereMesh.new()
		src.radius = radius
		src.height = radius * 2.0
		src.radial_segments = 8
		src.rings = 5
		var st := SurfaceTool.new()
		st.create_from(src, 0)
		st.deindex()
		st.generate_normals()
		_meshes[key] = st.commit()
	return _instance(_meshes[key], color, pos)


static func _instance(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	return mi


## Fügt ein Dreieck so hinzu, dass seine Vorderseite in Richtung n zeigt.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nc)
		st.add_vertex(c)
		st.set_normal(nb)
		st.add_vertex(b)
	else:
		st.set_normal(na)
		st.add_vertex(a)
		st.set_normal(nb)
		st.add_vertex(b)
		st.set_normal(nc)
		st.add_vertex(c)


## Quader mit abgerundeten Kanten und Ecken.
static func rounded_box_mesh(size: Vector3, r: float) -> Mesh:
	var key := "rbox_%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, size.z, r]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	r = clampf(r, 0.0, minf(minf(h.x, h.y), h.z) * 0.98)
	var inner := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hu := absf(h.dot(u))
		var hv := absf(h.dot(v))
		var hn := absf(h.dot(n))
		var us := [-hu, -hu + r, hu - r, hu]
		var vs := [-hv, -hv + r, hv - r, hv]
		var pts := []
		var nrm := []
		for j in 4:
			for i in 4:
				var raw: Vector3 = n * hn + u * float(us[i]) + v * float(vs[j])
				var cl := raw.clamp(-inner, inner)
				var d := raw - cl
				var dir := n if d.length() < 0.00001 else d.normalized()
				pts.append(cl + dir * r)
				nrm.append(dir)
		for j in 3:
			for i in 3:
				var a := j * 4 + i
				var b := a + 1
				var c := a + 4
				var d2 := a + 5
				_tri(st, pts[a], pts[b], pts[d2], nrm[a], nrm[b], nrm[d2], n)
				_tri(st, pts[a], pts[d2], pts[c], nrm[a], nrm[d2], nrm[c], n)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Flache Platte mit abgerundeten Ecken (für Bodenfelder).
static func rounded_slab(size: Vector2, radius: float, height: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := "slab_%.3f_%.3f_%.3f_%.3f" % [size.x, size.y, radius, height]
	if not _meshes.has(key):
		var outline := PackedVector2Array()
		var hx := size.x * 0.5 - radius
		var hz := size.y * 0.5 - radius
		var centers := [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
		for ci in 4:
			for s in 7:
				var ang := (ci * 90.0 + s * 15.0) * PI / 180.0
				outline.append(centers[ci] + Vector2(cos(ang), sin(ang)) * radius)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := Vector3(0, height, 0)
		for i in outline.size():
			var p0 := outline[i]
			var p1 := outline[(i + 1) % outline.size()]
			var a := Vector3(p0.x, height, p0.y)
			var b := Vector3(p1.x, height, p1.y)
			_tri(st, top, a, b, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP)
			var side_n := Vector3(p0.x + p1.x, 0, p0.y + p1.y).normalized()
			var a0 := Vector3(p0.x, 0, p0.y)
			var b0 := Vector3(p1.x, 0, p1.y)
			_tri(st, a0, b0, b, side_n, side_n, side_n, side_n)
			_tri(st, a0, b, a, side_n, side_n, side_n, side_n)
		_meshes[key] = st.commit()
	return _instance(_meshes[key], color, pos)


## Ein Weizenbüschel (3 Halme mit Ähren) mit Farbverlauf von goldbraun nach hellgelb.
static func wheat_mesh() -> Mesh:
	if _meshes.has("wheat"):
		return _meshes["wheat"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.03
	stalk.bottom_radius = 0.045
	stalk.height = 0.75
	stalk.radial_segments = 5
	stalk.rings = 1
	var ear := SphereMesh.new()
	ear.radius = 0.09
	ear.height = 0.5
	ear.radial_segments = 6
	ear.rings = 4
	var offsets := [Vector3(0, 0, 0), Vector3(0.14, 0, 0.08), Vector3(-0.1, 0, 0.12)]
	var heights := [1.0, 0.85, 0.92]
	var bottom := Color(0.85, 0.55, 0.12)
	var top := Color(1.0, 0.95, 0.65)
	for k in 3:
		var tilt := Basis(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), randf_range(0.03, 0.15))
		var hk: float = heights[k]
		var x_stalk := Transform3D(tilt, offsets[k]) * Transform3D(Basis().scaled(Vector3(1, hk, 1)), Vector3(0, 0.375 * hk, 0))
		var x_ear := Transform3D(tilt, offsets[k]) * Transform3D(Basis(), Vector3(0, 0.75 * hk + 0.2, 0))
		_append(st, stalk, x_stalk, bottom, top, 1.25)
		_append(st, ear, x_ear, bottom, top, 1.25)
	var mesh := st.commit()
	_meshes["wheat"] = mesh
	return mesh


## Pflanze für ein Beet: "wheat", "tomato" oder "carrot".
static func plant_mesh(kind: String) -> Mesh:
	if kind == "wheat":
		return wheat_mesh()
	var key := "plant_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := SphereMesh.new()
	leaf.radius = 0.16
	leaf.height = 0.3
	leaf.radial_segments = 6
	leaf.rings = 3
	var green := Color(0.3, 0.62, 0.26)
	var light := Color(0.45, 0.78, 0.32)
	if kind == "tomato":
		var stem := CylinderMesh.new()
		stem.top_radius = 0.025
		stem.bottom_radius = 0.035
		stem.height = 0.55
		stem.radial_segments = 5
		stem.rings = 1
		_append(st, stem, Transform3D(Basis(), Vector3(0, 0.27, 0)), green, green, 1.0)
		for p in [Vector3(0.1, 0.35, 0.05), Vector3(-0.1, 0.45, -0.04), Vector3(0.02, 0.58, 0.08), Vector3(-0.05, 0.28, 0.1)]:
			_append(st, leaf, Transform3D(Basis(), p), green, light, 0.8)
		var fruit := SphereMesh.new()
		fruit.radius = 0.075
		fruit.height = 0.15
		fruit.radial_segments = 8
		fruit.rings = 4
		var red := Color(0.92, 0.22, 0.18)
		for p in [Vector3(0.16, 0.3, 0.12), Vector3(-0.15, 0.4, 0.1), Vector3(0.08, 0.5, -0.14), Vector3(-0.04, 0.22, -0.16)]:
			_append(st, fruit, Transform3D(Basis(), p), red, red.lightened(0.15), 1.0)
	else:
		var root := CylinderMesh.new()
		root.top_radius = 0.075
		root.bottom_radius = 0.0
		root.height = 0.3
		root.radial_segments = 7
		root.rings = 1
		var orange := Color(0.98, 0.55, 0.15)
		_append(st, root, Transform3D(Basis(), Vector3(0, 0.02, 0)), orange, orange.lightened(0.1), 1.0)
		var blade := CylinderMesh.new()
		blade.top_radius = 0.035
		blade.bottom_radius = 0.015
		blade.height = 0.4
		blade.radial_segments = 4
		blade.rings = 1
		for k in 5:
			var b := Basis(Vector3.UP, k * TAU / 5.0) * Basis(Vector3.RIGHT, 0.35)
			_append(st, blade, Transform3D(b, Vector3(0, 0.17, 0)) * Transform3D(Basis(), Vector3(0, 0.2, 0)), green, light, 0.7)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _append(st: SurfaceTool, src: PrimitiveMesh, xf: Transform3D, bottom: Color, top: Color, total_h: float) -> void:
	var arrays := src.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in idx:
		var p := xf * verts[i]
		st.set_color(bottom.lerp(top, clampf(p.y / total_h, 0.0, 1.0)))
		st.set_normal((xf.basis * norms[i]).normalized())
		st.add_vertex(p)


# -------------------------------------------------------------------- Texturen

## Holzdielen-Textur (wird im Code gemalt).
static func plank_texture() -> Texture2D:
	if _meshes.has("tex_planks"):
		return _meshes["tex_planks"]
	var w := 256
	var img := Image.create(w, w, true, Image.FORMAT_RGB8)
	var plank_h := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in w / plank_h:
		var base := Color(0.87, 0.71, 0.5).lightened(rng.randf_range(-0.04, 0.06))
		var seam := rng.randi_range(40, 200)
		for y in plank_h:
			for x in w:
				var c := base
				c = c.darkened(0.04 * sin((x + row * 37) * 0.07 + y * 0.2) + 0.03 * sin(x * 0.31))
				if y == 0 or y == plank_h - 1:
					c = base.darkened(0.18)
				if x == seam or x == (seam + 128) % w:
					c = base.darkened(0.15)
				img.set_pixel(x, row * plank_h + y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_meshes["tex_planks"] = tex
	return tex


## Weiße abgerundete Fläche (Hintergrund für Sprechblasen).
static func bubble_texture() -> Texture2D:
	if _meshes.has("tex_bubble"):
		return _meshes["tex_bubble"]
	var w := 128
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rad := 22.0
	for y in h:
		for x in w:
			var dx := maxf(maxf(rad - x, x - (w - 1 - rad)), 0.0)
			var dy := maxf(maxf(rad - y, y - (h - 1 - rad)), 0.0)
			var dist := sqrt(dx * dx + dy * dy)
			var a := clampf(rad - dist, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_meshes["tex_bubble"] = tex
	return tex


# ---------------------------------------------------------------------- Schrift

## Runde, fette Schrift (nimmt eine passende Schrift, die auf dem Gerät vorhanden ist).
static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Nunito", "Baloo 2", "Roboto", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		_font.font_weight = 800
	return _font


# ------------------------------------------------------------------- Sonstiges

## Richtet einen Knoten so aus, dass seine Vorderseite (-Z) in Richtung dir zeigt.
static func face(node: Node3D, dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		node.rotation.y = atan2(-dir.x, -dir.z)


## Baut das 3D-Modell eines tragbaren Gegenstands ("wheat", "pizza", "pasta", "money").
static func item(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"wheat":
			root.add_child(box(Vector3(0.6, 0.24, 0.42), Color(0.96, 0.94, 0.88), Vector3(0, 0.12, 0), 0.45))
			root.add_child(box(Vector3(0.09, 0.25, 0.43), Color(0.93, 0.55, 0.18), Vector3(0.12, 0.12, 0), 0.3))
		"pizza":
			root.add_child(cylinder(0.32, 0.31, 0.07, Color(0.96, 0.78, 0.42), Vector3(0, 0.035, 0)))
			root.add_child(cylinder(0.26, 0.26, 0.03, Color(0.9, 0.3, 0.22), Vector3(0, 0.08, 0)))
			root.add_child(sphere(0.055, Color(1.0, 0.97, 0.88), Vector3(0.1, 0.095, 0.06)))
			root.add_child(sphere(0.055, Color(1.0, 0.97, 0.88), Vector3(-0.09, 0.095, -0.06)))
			root.add_child(sphere(0.04, Color(0.3, 0.7, 0.3), Vector3(-0.05, 0.1, 0.12)))
			root.add_child(sphere(0.04, Color(0.3, 0.7, 0.3), Vector3(0.12, 0.1, -0.1)))
		"pasta":
			root.add_child(cylinder(0.28, 0.2, 0.16, Color(0.97, 0.97, 1.0), Vector3(0, 0.08, 0)))
			root.add_child(cylinder(0.24, 0.24, 0.04, Color(1.0, 0.84, 0.38), Vector3(0, 0.15, 0)))
			root.add_child(sphere(0.08, Color(0.86, 0.25, 0.18), Vector3(0, 0.17, 0)))
			root.add_child(sphere(0.03, Color(0.3, 0.7, 0.3), Vector3(0.04, 0.24, 0.02)))
		"tomato", "carrot":
			# Holzkiste mit Gemüse
			root.add_child(box(Vector3(0.56, 0.18, 0.42), Color(0.82, 0.6, 0.36), Vector3(0, 0.09, 0), 0.25))
			root.add_child(box(Vector3(0.58, 0.04, 0.44), Color(0.68, 0.46, 0.26), Vector3(0, 0.15, 0), 0.25))
			if kind == "tomato":
				for p in [Vector3(-0.14, 0.2, -0.07), Vector3(0.0, 0.21, 0.07), Vector3(0.14, 0.2, -0.05)]:
					root.add_child(sphere(0.085, Color(0.92, 0.22, 0.18), p))
			else:
				for i in 3:
					var c := capsule(0.05, 0.3, Color(0.98, 0.55, 0.15), Vector3(-0.12 + i * 0.12, 0.2, 0))
					c.rotation_degrees = Vector3(90, 0, 0)
					root.add_child(c)
		"money":
			root.add_child(box(Vector3(0.52, 0.1, 0.3), Color(0.4, 0.82, 0.32), Vector3(0, 0.05, 0), 0.3))
			root.add_child(box(Vector3(0.11, 0.11, 0.31), Color(0.98, 0.85, 0.35), Vector3(0, 0.05, 0), 0.2))
	return root


## Höhe eines Gegenstands, wenn er gestapelt wird.
static func item_height(kind: String) -> float:
	match kind:
		"wheat":
			return 0.25
		"pizza":
			return 0.1
		"pasta":
			return 0.19
		"money":
			return 0.11
		"tomato", "carrot":
			return 0.27
	return 0.2


## Gestrichelter Rahmen mit runden Ecken auf dem Boden (zeigt, wo man sich hinstellen soll).
static func zone_marker(size: Vector2, color: Color) -> Node3D:
	var root := Node3D.new()
	var thick := 0.14
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var corner := 0.35
	# Ecken als kleine Winkel
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			root.add_child(box(Vector3(corner, 0.03, thick), color, Vector3(sx * (hx - corner * 0.5), 0.03, sz * hz), 1.0))
			root.add_child(box(Vector3(thick, 0.03, corner), color, Vector3(sx * hx, 0.03, sz * (hz - corner * 0.5)), 1.0))
	# Striche dazwischen
	var dash := 0.32
	for side in 4:
		var horizontal := side < 2
		var length := (size.x if horizontal else size.y) - corner * 2.0
		var count := maxi(1, int(length / 0.62))
		for i in count:
			var along := -length * 0.5 + (i + 0.5) * length / count
			if horizontal:
				root.add_child(box(Vector3(dash, 0.03, thick), color, Vector3(along, 0.03, hz * (1.0 if side == 0 else -1.0)), 1.0))
			else:
				root.add_child(box(Vector3(thick, 0.03, dash), color, Vector3(hx * (1.0 if side == 2 else -1.0), 0.03, along), 1.0))
	return root


## Text, der flach auf dem Boden liegt.
static func floor_label(text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = font_size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.double_sided = false
	return l


## Schwebender Text, der immer zur Kamera zeigt.
static func billboard_label(text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font()
	l.font_size = font_size
	l.outline_size = 12
	l.outline_modulate = Color(0.1, 0.1, 0.15, 0.9)
	l.modulate = color
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


## Kurze Zahl für Geldbeträge: 950, 1.2K, 34K, 1.5M
static func money_text(value: float) -> String:
	if value >= 1000000.0:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000.0:
		return "%dK" % int(value / 1000.0)
	if value >= 1000.0:
		return "%.1fK" % (value / 1000.0)
	return str(int(value))
