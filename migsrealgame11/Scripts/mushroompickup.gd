extends Area2D

@export var pickup_type = "mushroom"
@export var pickup_amount = 1

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Collected: ", pickup_type)
	
	# Check if it's the player
	if body.name == "Player" or body.is_in_group("player"):
		# Add to player inventory
		if body.has_method("add_to_inventory"):
			body.add_to_inventory(pickup_type, pickup_amount)
		
		# Delete the pickup
		queue_free()
