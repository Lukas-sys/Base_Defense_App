class_name Pile
extends Node3D
## Zeigt einen Stapel gleicher Gegenstände an (z. B. Pizzen auf der Theke).

const PER_COLUMN := 8

var kind := "pizza"
var max_visible := 24
var items: Array[Node3D] = []


func setup(item_kind: String, visible_max := 24, columns_x := 3) -> void:
	kind = item_kind
	max_visible = visible_max
	var h := Util.item_height(kind)
	for i in max_visible:
		var it := Util.item(kind)
		var col := i / PER_COLUMN
		var level := i % PER_COLUMN
		it.position = Vector3((col % columns_x) * 0.65, level * h, (col / columns_x) * 0.6)
		it.visible = false
		add_child(it)
		items.append(it)


func show_count(n: int) -> void:
	for i in items.size():
		items[i].visible = i < n
