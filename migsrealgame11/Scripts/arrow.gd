extends RigidBody2D

@export var min_damage_velocity := 50.0 
@export var damage := 10

var has_hit := false

func _ready():
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.0
	scale = Vector2(0.5, 0.5)
	contact_monitor = true
	max_contacts_reported = 1

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# Optimization: Only calculate rotation if it hasn't hit anything yet
	if not has_hit and linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(body):
	if has_hit:
		return

	has_hit = true

	# 1. Did we hit the enemy? 
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
		# Destroy the arrow instantly on hitting the enemy
		queue_free()
		return

	# 2. If we hit the environment (walls, floors)
	# Freeze the arrow in place safely
	set_deferred("freeze", true)
	
	# --- THE FIX: Disable the collision shape so it doesn't become a ramp ---
	# Note: If your collision node is named differently, change "CollisionShape2D" to match!
	$CollisionShape2D.set_deferred("disabled", true)

	# Start the cleanup timer
	await get_tree().create_timer(4.0).timeout

	# Fade out over 0.4 seconds then free
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()
