extends Enemy
class_name BossAbyssalBroodmother

const SWARM_PULSE_INTERVAL: float = 2.2
const SWARM_PULL_RADIUS: float = 260.0
const SWARM_PULL_DISTANCE: float = 90.0
const DEVOUR_INTERVAL: float = 4.8
const DEVOUR_RADIUS: float = 56.0
const DEVOUR_HEAL_RATIO: float = 0.08
const DEVOUR_BUFF_DURATION: float = 3.5
const DEVOUR_SPEED_BONUS: float = 0.22
const PHASE2_SPAWN_COUNT: int = 2
const PHASE3_SPAWN_COUNT: int = 3
const PHASE3_PULSE_PLAYER_SLOW_RADIUS: float = 210.0

var _swarm_pulse_timer: float = 1.0
var _devour_timer: float = 2.2
var _devour_buff_timer: float = 0.0

func on_boss_phase_changed(phase_no: int, is_initial: bool, event_tag: String) -> void:
	_refresh_phase_visuals(phase_no)
	if is_initial:
		return
	_swarm_pulse_timer = min(_swarm_pulse_timer, 0.4)
	_devour_timer = min(_devour_timer, 0.9)
	_spawn_pulse_visual(_get_phase_color(phase_no, 0.22), _get_swarm_pull_radius() + 24.0)
	Global.spawn_floating_text(global_position + Vector2(0.0, -56.0), event_tag.to_upper(), _get_phase_color(phase_no, 1.0))
	if phase_no >= 2:
		_spawn_brood_minions(1 if phase_no == 2 else 2)

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_swarm_pulse_timer = max(0.0, _swarm_pulse_timer - delta)
	_devour_timer = max(0.0, _devour_timer - delta)
	_devour_buff_timer = max(0.0, _devour_buff_timer - delta)
	if _swarm_pulse_timer <= 0.0:
		_swarm_pulse_timer = _get_swarm_pulse_interval()
		_emit_swarm_pulse()
	if _devour_timer <= 0.0:
		_devour_timer = _get_devour_interval()
		_try_devour_nearby_enemy()

func _current_move_speed() -> float:
	var base_speed_value: float = super._current_move_speed()
	if _devour_buff_timer > 0.0:
		return base_speed_value * (1.0 + DEVOUR_SPEED_BONUS)
	return base_speed_value

func _emit_swarm_pulse() -> void:
	var pull_radius: float = _get_swarm_pull_radius()
	var pull_distance_value: float = _get_swarm_pull_distance()
	var pulled_count: int = 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy is EnemyElites or enemy.is_boss_enemy():
			continue
		var to_center: Vector2 = global_position - enemy.global_position
		var distance_to_center: float = to_center.length()
		if distance_to_center <= 1.0 or distance_to_center > pull_radius:
			continue
		var pull_distance: float = min(pull_distance_value, distance_to_center - 6.0)
		if pull_distance <= 0.0:
			continue
		enemy.global_position += to_center.normalized() * pull_distance
		if enemy.has_method("update_rotation"):
			enemy.call("update_rotation")
		pulled_count += 1
	_apply_phase_three_player_pulse()
	if pulled_count > 0:
		Global.spawn_floating_text(global_position + Vector2(0.0, -28.0), "BROOD x%d" % pulled_count, Color(0.66, 1.0, 0.72))
		_spawn_pulse_visual(Color(0.48, 1.0, 0.58, 0.22), pull_radius)
	if boss_current_phase >= 3:
		_spawn_brood_minions(1)

func _try_devour_nearby_enemy() -> void:
	var candidate: Enemy = null
	var best_distance_sq: float = DEVOUR_RADIUS * DEVOUR_RADIUS
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy is EnemyElites or enemy.is_boss_enemy():
			continue
		var distance_sq: float = global_position.distance_squared_to(enemy.global_position)
		if distance_sq > best_distance_sq:
			continue
		best_distance_sq = distance_sq
		candidate = enemy
	if candidate == null:
		return
	var heal_amount: float = max(1.0, health_component.max_health * DEVOUR_HEAL_RATIO)
	health_component.heal(heal_amount)
	_devour_buff_timer = DEVOUR_BUFF_DURATION
	Global.spawn_floating_text(global_position + Vector2(0.0, -42.0), "DEVOUR", Color(0.92, 1.0, 0.70))
	_spawn_pulse_visual(Color(0.92, 1.0, 0.70, 0.28), DEVOUR_RADIUS * 1.6)
	candidate.destroy_enemy()
	if boss_current_phase >= 2:
		_spawn_brood_minions(PHASE3_SPAWN_COUNT if boss_current_phase >= 3 else PHASE2_SPAWN_COUNT)

func _get_swarm_pulse_interval() -> float:
	match boss_current_phase:
		2:
			return 1.8
		3:
			return 1.4
		_:
			return SWARM_PULSE_INTERVAL

func _get_swarm_pull_radius() -> float:
	match boss_current_phase:
		2:
			return 300.0
		3:
			return 340.0
		_:
			return SWARM_PULL_RADIUS

func _get_swarm_pull_distance() -> float:
	match boss_current_phase:
		2:
			return 112.0
		3:
			return 132.0
		_:
			return SWARM_PULL_DISTANCE

func _get_devour_interval() -> float:
	match boss_current_phase:
		2:
			return 4.0
		3:
			return 3.2
		_:
			return DEVOUR_INTERVAL

func _apply_phase_three_player_pulse() -> void:
	if boss_current_phase < 3:
		return
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return
	var player_distance: float = player.global_position.distance_to(global_position)
	if player_distance > PHASE3_PULSE_PLAYER_SLOW_RADIUS:
		return
	if player.has_method("apply_slow"):
		player.call("apply_slow", 0.25, 0.7)

func _spawn_brood_minions(count: int) -> void:
	if count <= 0:
		return
	var child_id: String = "fractal_slime"
	if boss_current_phase >= 3 and randf() < 0.4:
		child_id = "volatile_spark"
	_spawn_split_children_for_enemy(child_id, count)

func _refresh_phase_visuals(phase_no: int) -> void:
	if visuals == null or not is_instance_valid(visuals):
		return
	visuals.modulate = _get_phase_color(phase_no, 1.0)
	visuals.scale = Vector2.ONE * (1.08 + 0.06 * float(max(0, phase_no - 1)))

func _get_phase_color(phase_no: int, alpha_value: float) -> Color:
	match phase_no:
		2:
			return Color(0.82, 1.0, 0.56, alpha_value)
		3:
			return Color(1.0, 0.92, 0.48, alpha_value)
		_:
			return Color(0.66, 1.0, 0.72, alpha_value)

func _spawn_pulse_visual(fill_color: Color, radius: float) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var root := Node2D.new()
	root.top_level = true
	root.global_position = global_position
	root.z_index = 30
	current_scene.add_child(root)

	var polygon := Polygon2D.new()
	var line := Line2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(28):
		var angle: float = TAU * float(index) / 28.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	polygon.polygon = points
	polygon.color = fill_color
	root.add_child(polygon)
	line.points = points
	line.closed = true
	line.width = 6.0
	line.default_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.92)
	root.add_child(line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(1.18, 1.18), 0.28)
	tween.tween_property(polygon, "color:a", 0.0, 0.28)
	tween.tween_property(line, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(root.queue_free)
