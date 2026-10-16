extends Node

# StarHorizon's Anchorable on a structure: a wrench (tool quality "Anchoring")
# unbolts it from the floor or bolts it back (AnchorableComponent.Delay, 1 s,
# with the tool's use sound). An unanchored structure can be dragged, but it is
# heavy: it follows the cursor slowly, never turns, cannot leave the room and
# cannot be pushed through another structure. Only the position and the anchored
# flag are remembered between sessions.
const delaySeconds = 1.0
const dragSpeed = 36.0
const bounds = Rect2(16, 16, 160, 160)
const bodySize = Vector2(30, 32)
const StructureSave = preload("res://scripts/structureSave.gd")

var anchored = true
var _hovering = false
var _grabbing = false
var _grabOffset = Vector2.ZERO
@onready var structure: Area2D = get_parent()
@onready var mousePin: Node2D = $"../../mousePin"

func _ready() -> void :
	add_to_group("anchorables")
	structure.mouse_entered.connect(func(): _hovering = true)
	structure.mouse_exited.connect(func(): _hovering = false)
	_load()

# The structure's footprint, in world coordinates.
func rect() -> Rect2:
	return Rect2(structure.global_position - bodySize / 2.0, bodySize)

# Whether a left click on the structure right now would grab it.
func canGrab() -> bool:
	return _grabbing or (_hovering and not anchored)

# An unbolted machine is cut off from its power connection: it does not work.
func isPowered() -> bool:
	return anchored

func toggle() -> void :
	anchored = not anchored
	_grabbing = false
	_save()

func _input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hovering and not anchored and not _itemControler().hovering and not _itemControler().dragging:
				_grabbing = true
				_grabOffset = structure.global_position - mousePin.global_position
		elif _grabbing:
			_grabbing = false
			_save()

func _physics_process(delta: float) -> void :
	if not _grabbing:
		return
	var target = (mousePin.global_position + _grabOffset).clamp(bounds.position, bounds.end)
	var current = structure.global_position
	var step = current.move_toward(target, dragSpeed * delta)
	# Slide along whichever axis is free when another structure is in the way.
	for candidate in [step, Vector2(step.x, current.y), Vector2(current.x, step.y)]:
		if not _blocked(candidate):
			structure.global_position = candidate
			return

func _blocked(at: Vector2) -> bool:
	var footprint = Rect2(at - bodySize / 2.0, bodySize)
	for other in get_tree().get_nodes_in_group("anchorables"):
		if other != self and footprint.intersects(other.rect()):
			return true
	for inflatable in get_tree().get_nodes_in_group("inflatables"):
		if inflatable.blocksMovement() and footprint.intersects(inflatable.rect()):
			return true
	return false

func _itemControler() -> Node2D:
	return $"../../itemInteractionControler"

func _load() -> void :
	var saved = StructureSave.read().get(structure.name)
	if not saved is Dictionary:
		return
	anchored = saved.get("anchored", true)
	structure.position = Vector2(saved.get("x", structure.position.x), saved.get("y", structure.position.y))

func _save() -> void :
	var data = StructureSave.read()
	data[structure.name] = {"anchored": anchored, "x": structure.position.x, "y": structure.position.y}
	StructureSave.write(data)
