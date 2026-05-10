extends Enemy
class_name EnemyGoldMite

const COIN_PICK_RADIUS: float = 18.0
const COINS_PER_EVOLUTION: int = 10
const HEALTH_MULT_PER_EVOLUTION: float = 1.5
const SCALE_ADD_PER_EVOLUTION: float = 0.2

var _coins_eaten: int = 0
var _evolution_stacks: int = 0
var _base_visual_scale: Vector2 = Vector2.ONE
var _roam_seed: float = randf() * TAU

func _ready() -> void:
	super._ready()
	_base_visual_scale = visuals.scale
	if contact_hitbox != null and is_instance_valid(contact_hitbox):
		contact_hitbox.monitoring = false
		contact_hitbox.monitorable = false

func _state_chase(delta: float) -> void:
	if not can_move:
		return
	var coin: GoldCoin = _find_nearest_coin()
	if coin != null:
		var to_coin: Vector2 = coin.global_position - global_position
		if to_coin.length() <= COIN_PICK_RADIUS:
			_consume_coin(coin)
			return
		var move_dir_value: Vector2 = to_coin.normalized()
		position += move_dir_value * _current_move_speed() * delta
		update_rotation()
		return
	_roam_seed += delta * 0.8
	var roam_dir: Vector2 = Vector2(cos(_roam_seed), sin(_roam_seed * 1.7)).normalized()
	position += roam_dir * (_current_move_speed() * 0.35) * delta
	update_rotation()

func destroy_enemy() -> void:
	if is_dead:
		return
	if not is_backend_kill() and _evolution_stacks > 0:
		var config: Dictionary = ConfigManager.get_enemy_config(enemy_id)
		var base_gold: int = int(config.get("gold_value", 0))
		var extra_multiplier: int = maxi(0, int(pow(2.0, float(_evolution_stacks))) - 1)
		if base_gold > 0 and extra_multiplier > 0:
			Global.spawn_coin(global_position, base_gold * extra_multiplier)
	super.destroy_enemy()

func _find_nearest_coin() -> GoldCoin:
	var nearest_coin: GoldCoin = null
	var nearest_distance_sq: float = INF
	for coin_node in get_tree().get_nodes_in_group("coins"):
		if not (coin_node is GoldCoin):
			continue
		var coin: GoldCoin = coin_node as GoldCoin
		if coin == null or not is_instance_valid(coin):
			continue
		if bool(coin.get("is_collected")):
			continue
		var distance_sq: float = global_position.distance_squared_to(coin.global_position)
		if distance_sq >= nearest_distance_sq:
			continue
		nearest_distance_sq = distance_sq
		nearest_coin = coin
	return nearest_coin

func _consume_coin(coin: GoldCoin) -> void:
	if coin == null or not is_instance_valid(coin):
		return
	var amount: int = max(1, coin.gold_amount)
	coin.set("is_collected", true)
	coin.queue_free()
	_coins_eaten += amount
	Global.spawn_floating_text(global_position + Vector2(0, -16), "STEAL", Color(1.0, 0.84, 0.26))
	_refresh_evolution_state()

func _refresh_evolution_state() -> void:
	var target_stacks: int = int(_coins_eaten / COINS_PER_EVOLUTION)
	if target_stacks <= _evolution_stacks:
		return
	while _evolution_stacks < target_stacks:
		_evolution_stacks += 1
		_apply_evolution_step()

func _apply_evolution_step() -> void:
	if health_component != null and is_instance_valid(health_component):
		health_component.max_health *= HEALTH_MULT_PER_EVOLUTION
		health_component.current_health = health_component.max_health
		health = health_component.max_health
	visuals.scale = _base_visual_scale * (1.0 + SCALE_ADD_PER_EVOLUTION * float(_evolution_stacks))
	Global.spawn_floating_text(global_position, "GREED %d" % _evolution_stacks, Color(1.0, 0.92, 0.42))
