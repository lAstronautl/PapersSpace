extends Node2D

# Holds the placed inflatable walls and doors and remembers them between sessions.
const StructureSave = preload("res://scripts/structureSave.gd")
const inflatableScene = preload("res://prefabs/inflatableStructure.tscn")
const saveKey = "_inflatables"

func _ready() -> void :
	for entry in StructureSave.read().get(saveKey, []):
		place(entry.get("kind", "wall"), Vector2(entry.get("x", 0), entry.get("y", 0)), entry.get("open", false), false, entry.get("health", -1.0))

func place(kind: String, at: Vector2, open: bool = false, save: bool = true, health: float = -1.0) -> Node:
	var structure = inflatableScene.instantiate()
	structure.position = at
	add_child(structure)
	structure.setup(kind, open)
	if health > 0.0:
		structure.health = health
	if save:
		saveAll()
	return structure

func saveAll() -> void :
	var list = []
	for structure in get_children():
		if structure.is_queued_for_deletion():
			continue
		list.append({"kind": structure.kind, "x": structure.position.x, "y": structure.position.y, "open": structure.open, "health": structure.health})
	var data = StructureSave.read()
	data[saveKey] = list
	StructureSave.write(data)
