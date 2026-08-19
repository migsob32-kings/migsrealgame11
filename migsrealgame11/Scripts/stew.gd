extends Area2D

@export var heal_amount: int = 20
var player_in_range = null

func _ready():
	# Connect the Area2D signals to this script via code
	# (You can also do this visually in the Node tab)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	# Your player script already adds itself to the "player" group!
	if body.is_in_group("player"):
		player_in_range = body

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null

func _process(_delta):
	# Check if the player is near AND presses 'F'
	if player_in_range and Input.is_action_just_pressed("interact"):
		player_in_range.heal(heal_amount)
		queue_free() # Deletes the stew from the scene
