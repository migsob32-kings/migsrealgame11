extends Area2D

@export var pickup_type = "mushroom"
@export var pickup_amount = 1
@export var max_collect = 3

func _ready():
	# --- BUG FIX: Check if the signal is connected before connecting it ---
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		if body.has_method("get_inventory_count"):
			var current_count = body.get_inventory_count(pickup_type)
			if current_count >= max_collect:
				show_popup_message("Maximum " + pickup_type + " collected!")
				return
		
		if body.has_method("add_to_inventory"):
			body.add_to_inventory(pickup_type, pickup_amount)
			
			# Check if now full after collecting
			var new_count = 0
			if body.has_method("get_inventory_count"):
				new_count = body.get_inventory_count(pickup_type)
			
			if new_count >= max_collect:
				show_popup_message("+1 " + pickup_type + "\nFull!")
			else:
				show_popup_message("+1 " + pickup_type)
		
		queue_free()

func show_popup_message(message: String):
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color.WHITE
	
	# Add to scene root (stays on camera)
	get_tree().root.add_child(label)
	
	# Position at bottom right of screen
	label.anchor_left = 1.0
	label.anchor_top = 1.0
	label.offset_left = -250
	label.offset_top = -80
	
	# Fade out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(label.queue_free)
