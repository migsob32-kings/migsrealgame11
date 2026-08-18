extends CanvasLayer

@onready var health_bar = $TextureProgressBar
@onready var mushroom_label = $Label
@onready var jump_bar = $JumpBar 

# --- Variables for the shake effect ---
var original_bar_pos: Vector2
var original_jump_bar_pos: Vector2
var active_hud_tween: Tween

func _ready():
	# Save the starting positions when the game loads
	if health_bar:
		original_bar_pos = health_bar.position
	if jump_bar:
		original_jump_bar_pos = jump_bar.position
		
	# Wait exactly one frame to guarantee the Player is loaded and in the group
	call_deferred("connect_player_signals")

func connect_player_signals():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("SUCCESS: HUD found the Player!")
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
			
		if not player.mushrooms_changed.is_connected(_on_player_mushrooms_changed):
			player.mushrooms_changed.connect(_on_player_mushrooms_changed)
			
		# Connect the new jump signal
		if not player.jumps_changed.is_connected(_on_player_jumps_changed):
			player.jumps_changed.connect(_on_player_jumps_changed)
			
		# Force an initial update so the bar matches the player right away
		_on_player_jumps_changed(player.current_jumps, player.max_jumps)
	else:
		print("ERROR: HUD could not find the Player!")

func _on_player_health_changed(new_health: int, max_health: int):
	if health_bar:
		# Check if the player actually lost health before updating the bar
		var took_damage = new_health < health_bar.value
		
		health_bar.max_value = max_health
		health_bar.value = new_health
		
		# Only play the effect if we took damage
		if took_damage:
			play_hurt_effect()

func _on_player_mushrooms_changed(count: int):
	if mushroom_label:
		mushroom_label.text = "Mushrooms: " + str(count) + " / 3"
		
		if count >= 3:
			mushroom_label.modulate = Color(0.2, 0.8, 0.2)
		else:
			mushroom_label.modulate = Color.WHITE

func _on_player_jumps_changed(current: int, max_jumps: int):
	print("Jump Signal Received! Jumps left: ", current, " / ", max_jumps)
	if jump_bar:
		jump_bar.max_value = max_jumps
		jump_bar.value = current

# --- The Shake and Blink Function ---
func play_hurt_effect():
	if not health_bar or not jump_bar:
		return
		
	# 1. Stop any currently running shake animation
	if active_hud_tween and active_hud_tween.is_valid():
		active_hud_tween.kill()
		health_bar.position = original_bar_pos
		jump_bar.position = original_jump_bar_pos 
		
	# 2. Start the new animation
	active_hud_tween = create_tween()
	
	# Blink Red
	health_bar.modulate = Color(1, 0, 0)
	jump_bar.modulate = Color(1, 0, 0)
	active_hud_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.2)
	active_hud_tween.parallel().tween_property(jump_bar, "modulate", Color.WHITE, 0.2)
	
	# Shake side to side synchronously 
	var shake_amount = 8.0
	
	# Move Right
	active_hud_tween.parallel().tween_property(health_bar, "position", original_bar_pos + Vector2(shake_amount, 0), 0.05)
	active_hud_tween.parallel().tween_property(jump_bar, "position", original_jump_bar_pos + Vector2(shake_amount, 0), 0.05)
	
	# Move Left
	active_hud_tween.chain().tween_property(health_bar, "position", original_bar_pos - Vector2(shake_amount, 0), 0.05)
	active_hud_tween.parallel().tween_property(jump_bar, "position", original_jump_bar_pos - Vector2(shake_amount, 0), 0.05)
	
	# Return to Center
	active_hud_tween.chain().tween_property(health_bar, "position", original_bar_pos, 0.05)
	active_hud_tween.parallel().tween_property(jump_bar, "position", original_jump_bar_pos, 0.05)
