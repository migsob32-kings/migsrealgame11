extends Control

func _on_play_button_pressed():
	# Swap "res://scenes/game.tscn" with your actual game scene path!
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed():
	# Closes the game
	get_tree().quit()
