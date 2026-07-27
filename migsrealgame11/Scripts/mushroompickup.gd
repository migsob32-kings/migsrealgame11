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
			# If they are already at the max, cancel the pickup
			if current_count >= max_collect:
				return
		
		# If they aren't at the max, add it to inventory and delete the pickup
		if body.has_method("add_to_inventory"):
			body.add_to_inventory(pickup_type, pickup_amount)
		
		queue_free()
