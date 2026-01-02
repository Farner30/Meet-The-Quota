extends PanelContainer

# We only need the dropped signal to check for the Approve/Deny zones
signal dropped(pos: Vector2, data: ApplicantResource, node: PanelContainer)

@export var data: ApplicantResource

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var evidence_revealed: bool = false

@onready var name_label = $VBoxContainer/NameLabel
@onready var summary_label = $VBoxContainer/SummaryLabel
@onready var evidence_label = $VBoxContainer/EvidenceLabel

func _ready():
	if data:
		name_label.text = data.applicant_name
		summary_label.text = data.summary_text
		evidence_label.text = data.hidden_evidence_text
	
	# Keep evidence hidden until the desk button is pressed
	evidence_label.visible = false 
	
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
				if get_parent():
					get_parent().move_child(self, get_parent().get_child_count() - 1)
			else:
				if dragging:
					dragging = false
					var center_pos = global_position + (size / 2)
					dropped.emit(center_pos, data, self)

	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() + drag_offset

# This will be called by Main.gd when the player pays the time penalty
func reveal_evidence():
	evidence_revealed = true
	evidence_label.visible = true
