extends Node2D
class_name CollapseSingularityTrap

signal removed(trap: CollapseSingularityTrap)

@export var visual_radius: float = 15.0
@export var attract_radius: float = 60.0
@export var lifetime: float = 5.0
@export var event_horizon_radius: float = 300.0
@export var event_horizon_duration: float = 3.0
@export var event_horizon_tick_interval: float = 0.2
@export var event_horizon_damage_ratio: float = 1.50
@export var event_horizon_final_damage_ratio: float = 5.0
@export var elite_true_damage_ratio: float = 10.0
@export var pull_strength: float = 980.0

var owner_player: PlayerBase = null
var source_attack: float = 1.0

var _life_timer: float = 0.0
var _event_horizon_timer: float = 0.0
var _tick_timer: float = 0.0
var _active: bool = true
var _ring: Line2D = null
var _core: Polygon2D = null
var _glow: Line2D = null

func setup(player_node: PlayerBase, base_attack: float) -> void:
	owner_player = player_node
	source_attack = max(1.0, base_attack)
	_life_timer = lifetime

func _ready() -> void:
	add_to_group("player_skill_effects")
	_life_timer = lifetime if _life_timer <= 0.0 else _life_timer
	_rebuild_visuals()

func _process(delta: float) -> void:
	if _event_horizon_timer > 0.0:
		_process_event_horizon(delta)
		return
	_life_timer -= delta
	if _life_timer <= 0.0:
		_remove_self()
		return
	_update_idle_visual(delta)
	if _active:
		_try_consume_target()

func activate_event_horizon() -> void:
	_event_horizon_timer = event_horizon_duration
	_tick_timer = 0.0
	_active = false
	_rebuild_visuals()

func _try_consume_target() -> void:
	var target: Enemy = _select_best_enemy(attract_radius)
	if target == null:
		return
	target.global_position = global_position
	_resolve_annihilation(target)
	_remove_self()

func _select_best_enemy(radius_limit: float) -> Enemy:
	var best_enemy: Enemy = null
	var best_score: float = -INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > radius_limit:
			continue
		var max_hp: float = 0.0
		if enemy.health_component != null:
			max_hp = float(enemy.health_component.max_health)
		var elite_bias: float = 100000.0 if enemy.is_tactical_reject_elite_immune() else 0.0
		var score: float = elite_bias + max_hp
		if score > best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy

func _resolve_annihilation(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
	if enemy.health_component == null:
		return
	if enemy.is_tactical_reject_elite_immune():
		var previous_hp: float = enemy.health_component.current_health
		_apply_true_damage(enemy, source_attack * elite_true_damage_ratio)
		if previous_hp > 0.0 and enemy.is_dead and Global.has_method("spawn_energy_orb"):
			Global.spawn_energy_orb(enemy.global_position, 8.0, Vector2(0, -120))
		Global.spawn_floating_text(enemy.global_position, "ANNIHILATE", Color(1.0, 0.78, 0.3))
		return
	_apply_true_damage(enemy, enemy.health_component.current_health + 999999.0)
	Global.spawn_floating_text(enemy.global_position, "ERASE", Color(1.0, 0.28, 0.2))

func _process_event_horizon(delta: float) -> void:
	_event_horizon_timer = max(0.0, _event_horizon_timer - delta)
	_tick_timer -= delta
	_update_event_horizon_visual(delta)
	_apply_event_pull(delta)
	while _tick_timer <= 0.0 and _event_horizon_timer > 0.0:
		_tick_timer += event_horizon_tick_interval
		_apply_event_tick_damage()
	if _event_horizon_timer <= 0.0:
		_apply_final_explosion()
		_remove_self()

func _apply_event_pull(delta: float) -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_to_center: float = enemy.global_position.distance_to(global_position)
		if distance_to_center > event_horizon_radius:
			continue
		var dir: Vector2 = global_position - enemy.global_position
		if dir.length_squared() <= 0.0:
			continue
		enemy.global_position += dir.normalized() * min(distance_to_center, pull_strength * delta)

func _apply_event_tick_damage() -> void:
	var hit_enemies: Array = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > event_horizon_radius:
			continue
		if enemy.health_component != null:
			enemy.health_component.take_damage(max(1, int(round(source_attack * event_horizon_damage_ratio))))
			hit_enemies.append(enemy)
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("f", hit_enemies, {
			"skill_id": "f_collapse",
			"source": "event_horizon_tick",
		})

func _apply_final_explosion() -> void:
	var hit_enemies: Array = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > event_horizon_radius:
			continue
		if enemy.health_component != null:
			enemy.health_component.take_damage(max(1, int(round(source_attack * event_horizon_final_damage_ratio))))
			hit_enemies.append(enemy)
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("f", hit_enemies, {
			"skill_id": "f_collapse",
			"source": "event_horizon_final",
		})

func _apply_true_damage(enemy: Enemy, damage_amount: float) -> void:
	var hc: HealthComponent = enemy.health_component
	if hc == null or hc.current_health <= 0.0:
		return
	hc.current_health = max(0.0, hc.current_health - damage_amount)
	hc.on_unit_hit.emit()
	if hc.current_health <= 0.0:
		hc.current_health = 0.0
		hc.on_unit_died.emit()
		hc.die()

func _rebuild_visuals() -> void:
	if _core == null:
		_core = Polygon2D.new()
		_core.z_index = 24
		add_child(_core)
	if _ring == null:
		_ring = Line2D.new()
		_ring.closed = true
		_ring.antialiased = true
		_ring.z_index = 25
		add_child(_ring)
	if _glow == null:
		_glow = Line2D.new()
		_glow.closed = true
		_glow.antialiased = true
		_glow.z_index = 23
		add_child(_glow)

	var radius_value: float = event_horizon_radius if _event_horizon_timer > 0.0 else visual_radius
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(Vector2.RIGHT.rotated(angle) * radius_value)
	_core.polygon = points
	_ring.points = points
	_glow.points = points
	if _event_horizon_timer > 0.0:
		_core.color = Color(0.18, 0.2, 0.26, 0.34)
		_ring.width = 10.0
		_ring.default_color = Color(0.88, 0.96, 1.0, 0.72)
		_glow.width = 28.0
		_glow.default_color = Color(0.42, 0.7, 1.0, 0.18)
	else:
		_core.color = Color(0.04, 0.05, 0.08, 0.94)
		_ring.width = 4.0
		_ring.default_color = Color(0.82, 0.9, 1.0, 0.78)
		_glow.width = 16.0
		_glow.default_color = Color(0.48, 0.72, 1.0, 0.16)

func _update_idle_visual(delta: float) -> void:
	if _ring == null or _core == null:
		return
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 5.0 + delta)
	_ring.width = lerp(3.0, 5.0, pulse)
	_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.58, 0.84, pulse))
	_core.scale = Vector2.ONE * lerp(0.92, 1.08, pulse)

func _update_event_horizon_visual(delta: float) -> void:
	if _ring == null or _glow == null:
		return
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 7.0 + delta)
	_ring.width = lerp(8.0, 13.0, pulse)
	_glow.width = lerp(24.0, 34.0, pulse)
	_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.56, 0.84, pulse))
	_glow.modulate = Color(1.0, 1.0, 1.0, lerp(0.08, 0.2, pulse))

func _remove_self() -> void:
	removed.emit(self)
	queue_free()
