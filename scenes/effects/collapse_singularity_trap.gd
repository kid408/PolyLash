extends Node2D
class_name CollapseSingularityTrap

signal removed(trap: CollapseSingularityTrap)

@export var visual_radius: float = 18.0
@export var attract_radius: float = 140.0
@export var lifetime: float = 3.5
@export var idle_tick_interval: float = 1.0
@export var single_target_damage_ratio: float = 3.0
@export var crowd_floor_damage_ratio: float = 0.5
@export var crowd_falloff_count: int = 5
@export var event_horizon_radius: float = 300.0
@export var event_horizon_duration: float = 3.0
@export var event_horizon_tick_interval: float = 0.2
@export var event_horizon_damage_ratio: float = 1.50
@export var event_horizon_final_damage_ratio: float = 5.0
@export var elite_true_damage_ratio: float = 10.0
@export var pull_strength: float = 620.0

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
	_tick_timer = idle_tick_interval

func _ready() -> void:
	add_to_group("player_skill_effects")
	add_to_group("player_summoned_entity")
	_life_timer = lifetime if _life_timer <= 0.0 else _life_timer
	_tick_timer = idle_tick_interval if _tick_timer <= 0.0 else _tick_timer
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
		_apply_idle_pull(delta)
		_tick_timer -= delta
		while _tick_timer <= 0.0 and _active:
			_tick_timer += max(0.05, idle_tick_interval)
			_apply_idle_tick_damage()

func activate_event_horizon() -> void:
	_event_horizon_timer = event_horizon_duration
	_tick_timer = 0.0
	_active = false
	_rebuild_visuals()

func _collect_enemies_in_radius(radius_limit: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(global_position) > radius_limit:
			continue
		result.append(enemy)
	return result

func _apply_idle_pull(delta: float) -> void:
	for enemy: Enemy in _collect_enemies_in_radius(attract_radius):
		var dir: Vector2 = global_position - enemy.global_position
		if dir.length_squared() <= 0.001:
			continue
		var pull_step: float = min(dir.length(), pull_strength * delta)
		enemy.global_position += dir.normalized() * pull_step

func _apply_idle_tick_damage() -> void:
	var trapped_enemies: Array[Enemy] = _collect_enemies_in_radius(attract_radius)
	if trapped_enemies.is_empty():
		return
	var enemy_count: int = trapped_enemies.size()
	var t: float = clamp(float(enemy_count - 1) / max(1.0, float(crowd_falloff_count - 1)), 0.0, 1.0)
	var damage_ratio: float = lerp(single_target_damage_ratio, crowd_floor_damage_ratio, t)
	var damage_amount: float = max(1.0, source_attack * damage_ratio)
	var hit_enemies: Array = []
	for enemy: Enemy in trapped_enemies:
		if enemy.health_component == null:
			continue
		enemy.apply_modifier_damage(damage_amount, owner_player, {
			"kind": "collapse_singularity_tick",
			"damage_type": "DMG_AOE",
			"skill_id": "collapse_space",
			"skill_slot": "q",
			"space_skill_mode": "closed",
		})
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		hit_enemies.append(enemy)
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("space", hit_enemies, {
			"skill_id": "collapse_space",
			"source": "singularity_tick",
			"enemy_count": enemy_count,
		})

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
	for enemy: Enemy in _collect_enemies_in_radius(event_horizon_radius):
		var dir: Vector2 = global_position - enemy.global_position
		if dir.length_squared() <= 0.0:
			continue
		enemy.global_position += dir.normalized() * min(dir.length(), pull_strength * 1.6 * delta)

func _apply_event_tick_damage() -> void:
	var hit_enemies: Array = []
	for enemy: Enemy in _collect_enemies_in_radius(event_horizon_radius):
		if enemy.health_component == null:
			continue
		enemy.health_component.take_damage(max(1, int(round(source_attack * event_horizon_damage_ratio))), {
			"source": owner_player,
			"kind": "collapse_event_horizon_tick",
			"damage_type": "DMG_TRUE",
			"true_damage": true,
			"skill_slot": "f",
		})
		hit_enemies.append(enemy)
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("f", hit_enemies, {
			"skill_id": "f_collapse",
			"source": "event_horizon_tick",
		})

func _apply_final_explosion() -> void:
	var hit_enemies: Array = []
	for enemy: Enemy in _collect_enemies_in_radius(event_horizon_radius):
		if enemy.health_component == null:
			continue
		enemy.health_component.take_damage(max(1, int(round(source_attack * event_horizon_final_damage_ratio))), {
			"source": owner_player,
			"kind": "collapse_event_horizon_final",
			"damage_type": "DMG_TRUE",
			"true_damage": true,
			"skill_slot": "f",
		})
		hit_enemies.append(enemy)
	if is_instance_valid(owner_player) and not hit_enemies.is_empty():
		owner_player.notify_front_skill_damage("f", hit_enemies, {
			"skill_id": "f_collapse",
			"source": "event_horizon_final",
		})

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
		_core.color = Color(0.06, 0.08, 0.12, 0.92)
		_ring.width = 5.0
		_ring.default_color = Color(0.82, 0.9, 1.0, 0.82)
		_glow.width = 18.0
		_glow.default_color = Color(0.48, 0.72, 1.0, 0.18)

func _update_idle_visual(delta: float) -> void:
	if _ring == null or _core == null:
		return
	var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 1000.0) * 5.0 + delta)
	_ring.width = lerp(4.0, 7.0, pulse)
	_ring.modulate = Color(1.0, 1.0, 1.0, lerp(0.58, 0.84, pulse))
	_core.scale = Vector2.ONE * lerp(0.92, 1.14, pulse)

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
