extends Control

# --- Configuration ---
@export_group("Daily Parameters")
@export var quota_min: int = 5
@export var quota_max: int = 10
@export var time_limit_seconds: int = 300 
@export var info_request_penalty_min: int = 40
@export var info_request_penalty_max: int = 90

@export_group("Financials")
@export var payment_per_app: int = 50
@export var fine_per_error: int = 30
@export var failure_to_meet_quota_fine: int = 100

@export_group("Spawning Setup")
@export var document_scene: PackedScene
## Path to the JSON file containing applicant data
@export_file("*.json") var json_data_path: String = "res://data/applicants.json"
@export var default_applicant: ApplicantResource

@export_group("Zones")
@export var approve_zone: Control
@export var deny_zone: Control

@export_group("Splash Screen")
@export var splash_overlay: Control
@export var splash_label: Label
@export var splash_duration: float = 3.0

@export_group("Transitions")
## Path to the summary scene file
@export_file("*.tscn") var summary_scene_path: String = "res://scenes/summary_screen.tscn"

# --- Hidden Metrics & State ---
var ethical_score: int = 0 
var total_fines: int = 0
var pending_paycheck: int = 0 # Payment accumulated for correct processing
var quota_goal: int = 5
var triggered_headlines: Array = []

var current_document: PanelContainer = null
var current_processed: int = 0
var time_left: int = 0
var spawned_count: int = 0
var highlight_tween: Tween
var is_game_active: bool = false
var applicants_data: Array = []

@onready var quota_label = $VBoxContainer/InfoPanel/HBoxContainer/QuotaLabel
@onready var time_label = $VBoxContainer/InfoPanel/HBoxContainer/TimeLabel
@onready var money_label = $VBoxContainer/InfoPanel/HBoxContainer/MoneyLabel
@onready var request_button = $VBoxContainer/InfoPanel/HBoxContainer/RequestButton
@onready var receive_button = $VBoxContainer/InfoPanel/HBoxContainer/ReceiveButton
@onready var game_timer = $GameTimer 

func _ready():
	# Randomize the day's difficulty
	quota_goal = randi_range(quota_min, quota_max)
	time_left = time_limit_seconds
	is_game_active = false
	
	load_applicants_from_json()
	update_ui()
	
	# UI Cleanup
	request_button.focus_mode = Control.FOCUS_NONE
	receive_button.focus_mode = Control.FOCUS_NONE
	request_button.disabled = true
	receive_button.disabled = true
	
	if splash_overlay and splash_label:
		run_splash_sequence()
	else:
		start_game()

# --- Visual Feedback Logic ---

func _process(_delta):
	# Handle transparency feedback based on document center
	if is_game_active and current_document != null:
		if current_document.dragging:
			var center_pos = current_document.global_position + (current_document.size / 2)
			
			if is_over_any_zone(center_pos):
				current_document.modulate.a = 0.5 
			else:
				current_document.modulate.a = 1.0 
		else:
			current_document.modulate.a = 1.0

func is_over_any_zone(pos: Vector2) -> bool:
	if approve_zone and approve_zone.get_global_rect().has_point(pos):
		return true
	if deny_zone and deny_zone.get_global_rect().has_point(pos):
		return true
	return false

# --- Spawning & Data Logic ---

func load_applicants_from_json():
	if not FileAccess.file_exists(json_data_path):
		print("JSON Error: File not found at ", json_data_path)
		return

	var file = FileAccess.open(json_data_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data_received = json.data
		if data_received is Dictionary and data_received.has("applicants"):
			applicants_data = data_received["applicants"]
			applicants_data.shuffle()
	else:
		print("JSON Error: ", json.get_error_message())

func spawn_next_applicant():
	var new_doc = document_scene.instantiate()
	var runtime_data = ApplicantResource.new()
	
	if spawned_count < applicants_data.size():
		var entry = applicants_data[spawned_count]
		runtime_data.applicant_name = entry["name"]
		runtime_data.summary_text = entry["summary"]
		runtime_data.is_unethical = entry["is_unethical"]
		runtime_data.hidden_evidence_text = entry["evidence"]
		# Store the headline as metadata so we can retrieve it if approved
		runtime_data.set_meta("headline", entry.get("headline", ""))
		new_doc.data = runtime_data
	elif default_applicant != null:
		new_doc.data = default_applicant
	
	$VBoxContainer/DeskArea.add_child(new_doc)
	# Center the document on spawn
	new_doc.global_position = $VBoxContainer/DeskArea.global_position + ($VBoxContainer/DeskArea.size / 2) - (new_doc.size / 2)
	new_doc.dropped.connect(_on_document_processed)
	current_document = new_doc
	spawned_count += 1
	receive_button.disabled = true

# --- Core Mechanics ---

func _on_receive_button_pressed():
	if not is_game_active: return
	if current_document == null and spawned_count < quota_goal:
		spawn_next_applicant()
		stop_button_highlight()
		request_button.disabled = false
		start_button_highlight(request_button)

func _on_request_button_pressed():
	if not is_game_active: return
	if current_document != null:
		if not current_document.evidence_revealed:
			current_document.reveal_evidence()
			
			# Apply variable time penalty (Stress Factor)
			var penalty = randi_range(info_request_penalty_min, info_request_penalty_max)
			time_left = max(0, time_left - penalty)
			
			update_ui()
			request_button.disabled = true
			stop_button_highlight()

func _on_document_processed(drop_pos: Vector2, data: ApplicantResource, document_node: PanelContainer):
	document_node.modulate.a = 1.0
	
	if approve_zone and approve_zone.get_global_rect().has_point(drop_pos):
		process_decision(true, data)
		document_node.queue_free()
		finish_processing()
	elif deny_zone and deny_zone.get_global_rect().has_point(drop_pos):
		process_decision(false, data)
		document_node.queue_free()
		finish_processing()
	update_ui()

func process_decision(approved: bool, data: ApplicantResource):
	current_processed += 1
	
	if approved:
		# Approval path: The "Optimal" path rewards the player with money immediately
		pending_paycheck += payment_per_app
		if data and data.is_unethical:
			ethical_score -= 10
			# Capture the specific headline for the consequence screen
			var h = data.get_meta("headline")
			if h != "":
				triggered_headlines.append(h)
		else:
			ethical_score += 2
	else:
		# Denial path: Requires evidence to be valid
		if current_document and current_document.evidence_revealed:
			if data and data.is_unethical:
				# Valid denial
				pending_paycheck += payment_per_app
				ethical_score += 5
			else:
				# Wrongful denial (eligible person)
				total_fines += fine_per_error
				ethical_score -= 5
		else:
			# Denied without evidence (clerical error)
			total_fines += fine_per_error
			ethical_score -= 5

func finish_processing():
	current_document = null
	request_button.disabled = true
	stop_button_highlight()
	if current_processed < quota_goal:
		receive_button.disabled = false
		start_button_highlight(receive_button)
	else:
		receive_button.disabled = true
		end_workday("QUOTA MET")

func end_workday(reason: String):
	is_game_active = false
	game_timer.stop()
	
	# Penalize for missed quota if day ended via timer
	if reason == "OUT OF TIME" and current_processed < quota_goal:
		total_fines += failure_to_meet_quota_fine
	
	var results = {
		"quota_reached": current_processed,
		"quota_total": quota_goal,
		"ethics": ethical_score,
		"money": pending_paycheck - total_fines,
		"fines": total_fines,
		"paycheck": pending_paycheck,
		"reason": reason,
		"headlines": triggered_headlines
	}
	
	await get_tree().create_timer(1.0).timeout
	var next_scene = load(summary_scene_path).instantiate()
	get_tree().root.add_child(next_scene)
	next_scene.display_results(results)
	queue_free()

# --- Helpers & UI ---

func _on_game_timer_timeout():
	if not is_game_active: return
	if time_left > 0:
		time_left -= 1
		update_ui()
	else:
		end_workday("OUT OF TIME")

func update_ui():
	if quota_label: quota_label.text = "Quota: %d / %d" % [current_processed, quota_goal]
	# Only show fines (debt) during the day. Paycheck comes at summary.
	if money_label: money_label.text = "Credits: %d" % (-total_fines)
	if time_label:
		var minutes = time_left / 60
		var seconds = time_left % 60
		time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func run_splash_sequence():
	splash_overlay.visible = true
	await get_tree().create_timer(splash_duration).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(splash_overlay, "modulate:a", 0.0, 0.3)
	fade_tween.finished.connect(start_game)

func start_game():
	if splash_overlay: splash_overlay.visible = false
	is_game_active = true
	receive_button.disabled = false
	if game_timer.is_stopped(): game_timer.start()
	if current_processed < quota_goal: start_button_highlight(receive_button)

func start_button_highlight(target_button: Button):
	stop_button_highlight() 
	highlight_tween = create_tween().set_loops()
	highlight_tween.tween_property(target_button, "self_modulate", Color(1, 0.4, 0.4), 0.6)
	highlight_tween.tween_property(target_button, "self_modulate", Color.WHITE, 0.6)

func stop_button_highlight():
	if highlight_tween: highlight_tween.kill()
	request_button.self_modulate = Color.WHITE
	receive_button.self_modulate = Color.WHITE
