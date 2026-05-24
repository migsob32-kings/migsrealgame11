extends Area2D

var speed = 600.0
var direction = Vector2.RIGHT  # will be set when spawned

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	# hit something
	print("hit: ", body.name)
	queue_free()  # destroy arrow on impact
