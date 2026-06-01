extends RigidBody2D

func _ready():
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.0
	scale = Vector2(2, 2)
	contact_monitor = true
	max_contacts_reported = 1

func _physics_process(_delta):
	if linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(_body):
	freeze = true
	await get_tree().create_timer(4.0).timeout
	# Fade out over 0.4 seconds then free
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()
