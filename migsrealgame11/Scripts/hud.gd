extends CanvasLayer

@onready var health_bar = $TextureProgressBar
@onready var mushroom_label = $Label

func _on_player_health_changed(new_health: int, max_health: int):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = new_health

func _on_player_mushrooms_changed(count: int):
	if mushroom_label:
		mushroom_label.text = "Mushrooms: " + str(count) + " / 3"
		
		if count >= 3:
			mushroom_label.modulate = Color(0.2, 0.8, 0.2)
		else:
			mushroom_label.modulate = Color.WHITE
