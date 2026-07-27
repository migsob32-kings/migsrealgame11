extends Area2D

var stored_mushrooms: int = 0
var max_capacity: int = 3

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		
		# 1. Ignore the player if they literally just respawned here!
		if body.get("is_respawning") == true:
			return 
			
		# 2. Check how much space the pot has left
		var space_left = max_capacity - stored_mushrooms
		var dropped_amount = 0
		
		# 3. Only take mushrooms if there is space
		if space_left > 0 and body.has_method("drop_amount"):
			dropped_amount = body.drop_amount("mushroom", space_left)
			stored_mushrooms += dropped_amount
			
		# 4. Logic for saving and popups
		if dropped_amount > 0:
			# Player deposited new mushrooms
			if body.has_method("set_respawn_point"):
				body.set_respawn_point(global_position)
			show_popup_message("Respawn Set!\nPot: " + str(stored_mushrooms) + "/" + str(max_capacity))
			
		elif stored_mushrooms > 0:
			# Pot is already active, so they can update their checkpoint for free!
			if body.has_method("set_respawn_point"):
				body.set_respawn_point(global_position)
				
			if stored_mushrooms >= max_capacity:
				show_popup_message("Checkpoint Saved!\nPot is Full (3/3)")
			else:
				show_popup_message("Checkpoint Saved!\nPot: " + str(stored_mushrooms) + "/" + str(max_capacity))
				
		else:
			# Pot is empty, and player has 0 mushrooms
			show_popup_message("Empty pockets!\nNeed mushrooms to start stew.")

func show_popup_message(message: String):
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color.WHITE
	
	get_tree().root.add_child(label)
	
	label.anchor_left = 1.0
	label.anchor_top = 1.0
	label.offset_left = -250
	label.offset_top = -80
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate", Color.TRANSPARENT, 2.0)
	tween.tween_callback(label.queue_free)
