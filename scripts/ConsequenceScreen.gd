extends Control

@onready var family_label = $MarginContainer/VBoxContainer/FamilyFateLabel
@onready var newspaper_title = $MarginContainer/VBoxContainer/NewspaperPanel/VBoxContainer/HeadlineLabel
@onready var newspaper_body = $MarginContainer/VBoxContainer/NewspaperPanel/VBoxContainer/BodyLabel
@onready var restart_button = $RestartButton

func setup_consequences(data: Dictionary):
	# 1. Family Fate Logic
	var fate_text = ""
	if not data.rent:
		fate_text = "The locks were changed by noon. Your family is sleeping in the transit tunnels."
	elif not data.food:
		fate_text = "The apartment is warm, but the silence is heavy. Your children went to bed crying from hunger."
	elif not data.meds:
		fate_text = "You paid the bills, but without the medicine, the coughing in the next room hasn't stopped."
	else:
		fate_text = "You managed to provide. For one more night, the wolf is kept from the door."
	family_label.text = fate_text

	# 2. Specific Newspaper Logic
	var headlines = data.get("headlines", [])
	
	if headlines.size() > 0:
		# Pick the MOST RECENT or a RANDOM catastrophe the player caused
		newspaper_title.text = "CITY IN CRISIS"
		newspaper_body.text = headlines[randi() % headlines.size()]
	else:
		# If the player was perfect (or just didn't approve any bad guys)
		if data.ethics > 5:
			newspaper_title.text = "ORDER MAINTAINED"
			newspaper_body.text = "Efficiency rates at the CAD have stabilized. Crime is down, but bureaucratic processing times remain high due to strict vetting procedures."
		else:
			newspaper_title.text = "BUSINESS AS USUAL"
			newspaper_body.text = "The Quota was met. The city continues to grind forward. No news is good news in the Central Allocation Department."

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
