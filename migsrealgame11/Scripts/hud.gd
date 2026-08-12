extends CanvasLayer

# Make sure these names match the nodes in your HUD scene exactly!
@onready var health_bar = $TextureProgressBar
@onready var mushroom_label = $Label

# We connect the Player's 'health_changed' signal to this function
func _on_player_health_changed(new_health, max_health):
	health_bar.max_value = max_health
	health_bar.value = new_health

# We connect the Player's 'mushrooms_changed' signal to this function
func _on_player_mushrooms_changed(count):
	mushroom_label.text = "Mushrooms: " + str(count) + " / 3"
	
	if count >= 3:
		mushroom_label.modulate = Color(0.2, 0.8, 0.2)
	else:
		mushroom_label.modulate = Color.WHITE



func _on_character_body_2d_mushrooms_changed(count: Variant) -> void:
	pass # Replace with function body.
