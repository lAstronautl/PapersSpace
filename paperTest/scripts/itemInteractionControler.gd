extends Node2D



@onready var mousePin: PinJoint2D = $"../mousePin"
@onready var fakeBody: StaticBody2D = $"../mousePin/fakeBody"
@onready var itemsParent: Node2D = $"../items"
@onready var label: Label = $"../mousePin/Label"
@onready var labelBGRect: ColorRect = $"../mousePin/Label/ColorRect"
@onready var fileEditor: Control = $"../fileEditor"

const angularDampOnDrag = 128
const rotationSpeed = 2

var dragging = false
var hovering = false
var heldItem
var hoveredItem
var allHovered = []

func startDrag(item: RigidBody2D) -> void :
	mousePin.node_b = mousePin.get_path_to(item)
	item.angular_damp = angularDampOnDrag
	heldItem = item
	dragging = true

func endDrag(item: RigidBody2D) -> void :
	mousePin.node_b = NodePath()
	item.angular_damp = ProjectSettings.get_setting("physics/2d/default_angular_damp")
	item.lock_rotation = false
	getItemSprite(item).position = Vector2(0, 0)
	dragging = false

func getItemSprite(item: RigidBody2D) -> Sprite2D:
	return item.get_node("CollisionShape2D").get_node("Sprite2D")


func _ready() -> void :
	mousePin.node_a = mousePin.get_path_to(fakeBody)

	call_deferred("_init_all")

	label.visible = false
	fileEditor.visible = false

func _init_all():
	for child in itemsParent.get_children():
		initItem(child)

func initItem(item: RigidBody2D):
	item.mouse_entered.connect(_on_mouse_entered.bind(item))
	item.mouse_exited.connect(_on_mouse_exited.bind(item))

func _physics_process(delta: float) -> void :
	if dragging:
		getItemSprite(heldItem).global_position = heldItem.global_position - Vector2(0, 2)
		getItemSprite(heldItem).use_parent_material = true


		if Input.is_action_pressed("rotateLeft"):
			heldItem.lock_rotation = true
			heldItem.rotate( - rotationSpeed * delta)
		if Input.is_action_pressed("rotateRight"):
			heldItem.lock_rotation = true
			heldItem.rotate(rotationSpeed * delta)
		if Input.is_action_pressed("orientDocument"):

			heldItem.rotate(deg_to_rad((round(heldItem.rotation_degrees / 45.0) * 45.0) - heldItem.rotation_degrees))

func _hover(item: RigidBody2D):
	getItemSprite(item).use_parent_material = false
	label.text = item.name
	labelBGRect.size.x = label.get_theme_font("font").get_string_size(item.name).x + 3
	label.visible = true
	hoveredItem = item
	hovering = true

func _on_mouse_entered(item: RigidBody2D):
	allHovered.append(item)
	if not hovering:
		_hover(item)

func _on_mouse_exited(item: RigidBody2D):
	allHovered.remove_at(allHovered.find(item))
	if hovering:
		getItemSprite(item).use_parent_material = true
	if allHovered.size() < 1:
		label.visible = false
		hovering = false
	else:
		_hover(allHovered[0])

func _input(event: InputEvent) -> void :
	if dragging:
		if event is InputEventMouseButton and not event.is_pressed():
			endDrag(heldItem)
		if event is InputEventMouseMotion:
			if event.position.x > ProjectSettings.get_setting("display/window/size/viewport_width")\
			or event.position.x < 0\
			or event.position.y > ProjectSettings.get_setting("display/window/size/viewport_height")\
			or event.position.y < 0:

				endDrag(heldItem)
	if hovering and not dragging:
		if event.is_pressed():
			if event.is_action("editDocument"):

				if fileEditor.visible:
					fileEditor.visible = false
				elif hoveredItem.get_meta("type") == "txt":
					label.visible = false
					fileEditor.open(hoveredItem)
				return
			if not dragging and event is InputEventMouseButton and event.button_index == 1 and not fileEditor.visible:
				startDrag(hoveredItem)
