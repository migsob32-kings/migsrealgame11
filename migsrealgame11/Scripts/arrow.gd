extends RigidBody2D

func _ready():
	gravity_scale = 1.0
	scale = Vector2(2.0, 2.0)
	contact_monitor = true
	max_contacts_reported = 1

func _physics_process(delta):
	scale = Vector2(2.0, 2.0)
	
	if linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(body):
	freeze = true
	await get_tree().create_timer(3.0).timeout
	queue_free()
