extends RigidBody2D

func _ready():
	# Enable gravity for the arrow
	gravity_scale = 1.0
	
	# Optional: Make arrow stick to objects on collision
	contact_monitor = true
	max_contacts_reported = 1

func _physics_process(delta):
	# Rotate arrow to match its velocity direction
	if linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(body):
	# Make arrow stick when it hits something
	freeze = true
	# Optional: queue_free after a few seconds
	await get_tree().create_timer(3.0).timeout
	queue_free()
