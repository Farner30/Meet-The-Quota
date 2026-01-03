extends Control

# --- UI References ---
@onready var quota_label = $MarginContainer/VBoxContainer/QuotaLabel
@onready var ethics_label = $MarginContainer/VBoxContainer/EthicsLabel
@onready var salary_label = $MarginContainer/VBoxContainer/SalaryBreakdownLabel
@onready var balance_label = $MarginContainer/VBoxContainer/BalanceLabel

# Interactive Checkboxes (Ensure these names match your scene tree)
@onready var rent_check = $MarginContainer/VBoxContainer/RentCheck
@onready var food_check = $MarginContainer/VBoxContainer/FoodCheck
@onready var meds_check = $MarginContainer/VBoxContainer/MedsCheck
@onready var confirm_button = $MarginContainer/VBoxContainer/ConfirmButton

@export_file("*.tscn") var consequence_scene_path: String = "res://scenes/consequence_screen.tscn"

# --- State ---
var total_net_money: int = 0
var current_balance: int = 0
var summary_data: Dictionary = {}

const RENT_COST = 100
const FOOD_COST = 50
const MEDS_COST = 40

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(_on_confirm_pressed)
	
	# Connect checkbox toggles
	rent_check.toggled.connect(_on_expense_toggled.bind(RENT_COST))
	food_check.toggled.connect(_on_expense_toggled.bind(FOOD_COST))
	meds_check.toggled.connect(_on_expense_toggled.bind(MEDS_COST))

func display_results(data: Dictionary):
	summary_data = data
	total_net_money = data.money
	current_balance = total_net_money
	
	quota_label.text = "PROCESSED: %d / %d" % [data.quota_reached, data.quota_total]
	ethics_label.text = "MORAL ALIGNMENT: %d" % data.ethics
	salary_label.text = "Salary: +$%d | Fines: -$%d" % [data.paycheck, data.fines]
	
	update_balance_ui()

func _on_expense_toggled(_is_on: bool, cost: int):
	# Calculate total cost of currently checked boxes
	var total_selected_cost = 0
	if rent_check.button_pressed: total_selected_cost += RENT_COST
	if food_check.button_pressed: total_selected_cost += FOOD_COST
	if meds_check.button_pressed: total_selected_cost += MEDS_COST
	
	current_balance = total_net_money - total_selected_cost
	update_balance_ui()

func update_balance_ui():
	balance_label.text = "Remaining Balance: $%d" % current_balance
	
	# Disable checkboxes that player can't afford if they aren't already checked
	rent_check.disabled = not rent_check.button_pressed and current_balance < RENT_COST
	food_check.disabled = not food_check.button_pressed and current_balance < FOOD_COST
	meds_check.disabled = not meds_check.button_pressed and current_balance < MEDS_COST
	
	# Visual warning if negative (shouldn't happen with the disable logic, but for safety)
	if current_balance < 0:
		balance_label.modulate = Color.RED
	else:
		balance_label.modulate = Color.WHITE

func _on_confirm_pressed():
	# Pass the final allocation results and the headlines to the narrative screen
	var final_allocation = {
		"rent": rent_check.button_pressed,
		"food": food_check.button_pressed,
		"meds": meds_check.button_pressed,
		"ethics": summary_data.ethics,
		"reason": summary_data.reason,
		"headlines": summary_data.get("headlines", [])
	}
	
	var next_scene = load(consequence_scene_path).instantiate()
	get_tree().root.add_child(next_scene)
	next_scene.setup_consequences(final_allocation)
	queue_free()
