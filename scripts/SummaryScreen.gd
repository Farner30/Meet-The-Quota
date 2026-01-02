extends Control

@onready var quota_label = $VBoxContainer/QuotaLabel
@onready var ethics_label = $VBoxContainer/EthicsLabel
@onready var narrative_label = $VBoxContainer/NarrativeLabel

func _ready():
	# Allow mouse to click buttons on this screen
	mouse_filter = Control.MOUSE_FILTER_STOP

func display_results(data: Dictionary):
	# This is called by Main.gd right after instantiation
	quota_label.text = "PROCESSED: %d / %d" % [data.quota_reached, data.quota_total]
	ethics_label.text = "MORAL ALIGNMENT: %d" % data.ethics
	
	var reason = data.reason
	var outcome = ""
	
	if data.quota_reached < data.quota_total:
		outcome = "STATUS: TERMINATED.\nReason: %s. Your family has been evicted." % reason
	elif data.ethics < -10:
		outcome = "STATUS: PROMOTED.\nReason: %s. You are a model citizen. The streets are a bit more dangerous tonight, but your table is full." % reason
	else:
		outcome = "STATUS: RETAINED.\nReason: %s. You did your job. Order is maintained." % reason
		
	narrative_label.text = outcome

func _on_restart_button_pressed():
	# Standard Godot way to restart the game
	get_tree().change_scene_to_file("res://scenes/main.tscn")
