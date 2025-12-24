extends PanelContainer

@export var data: ApplicantResource

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

@onready var name_label = $VBoxContainer/NameLabel
@onready var summary_label = $VBoxContainer/SummaryLabel

func _ready():
	# Update text if data exists
	if data:
		name_label.text = data.applicant_name
		summary_label.text = data.summary_text
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	for child in get_children():
		set_mouse_filter_recursive(child)

func set_mouse_filter_recursive(node: Node):
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		set_mouse_filter_recursive(child)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = global_position - get_global_mouse_position()
				# Pop to the top of the desk
				if get_parent():
					get_parent().move_child(self, get_parent().get_child_count() - 1)
			else:
				dragging = false

	# We check dragging here in _gui_input
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() + drag_offset
