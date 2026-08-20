extends CanvasLayer

# --- Node References ---
@onready var health_bar = $TextureProgressBar
@onready var hunger_bar = $HungerBar
@onready var mushroom_label = $MushroomLabel 

var player: CharacterBody2D
var original_bar_pos: Vector2
var original_hunger_pos: Vector2 # --- NEW: Store the Hunger Bar's starting position ---

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		connect_player_signals()
		
	if health_bar:
		original_bar_pos = health_bar.position
		
	if hunger_bar: # --- NEW: Save Hunger Bar position ---
		original_hunger_pos = hunger_bar.position

func connect_player_signals():
	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
		
	if not player.mushrooms_changed.is_connected(_on_player_mushrooms_changed):
		player.mushrooms_changed.connect(_on_player_mushrooms_changed)
		
	if not player.stew_buff_changed.is_connected(_on_stew_buff_changed):
		player.stew_buff_changed.connect(_on_stew_buff_changed)
		
	# Force an initial update
	_on_player_health_changed(player.health, player.max_health)
	_on_player_mushrooms_changed(player.get_inventory_count("mushroom"))
	_on_stew_buff_changed(player.stew_bars, player.max_stew_bars)

# --- Signal Receiver Functions ---

func _on_player_health_changed(new_health: int, max_health: int):
	if health_bar:
		var took_damage = new_health < health_bar.value
		health_bar.max_value = max_health
		health_bar.value = new_health
		if took_damage:
			play_hurt_effect()

func _on_player_mushrooms_changed(count: int):
	if mushroom_label:
		mushroom_label.text = "Mushrooms: " + str(count) + " / 3"
		if count >= 3:
			mushroom_label.modulate = Color(0.2, 0.8, 0.2)
		else:
			mushroom_label.modulate = Color.WHITE

func _on_stew_buff_changed(current_bars: int, max_bars: int):
	if hunger_bar:
		hunger_bar.max_value = max_bars
		hunger_bar.value = current_bars

# --- Visual Effects ---
func play_hurt_effect():
	# Shake Health Bar
	if health_bar:
		var tween = create_tween()
		tween.tween_property(health_bar, "position", original_bar_pos + Vector2(5, 0), 0.05)
		tween.tween_property(health_bar, "position", original_bar_pos - Vector2(5, 0), 0.05)
		tween.tween_property(health_bar, "position", original_bar_pos, 0.05)
		
	# --- NEW: Shake Hunger Bar at the exact same time ---
	if hunger_bar:
		var hunger_tween = create_tween()
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos + Vector2(5, 0), 0.05)
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos - Vector2(5, 0), 0.05)
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos, 0.05)
