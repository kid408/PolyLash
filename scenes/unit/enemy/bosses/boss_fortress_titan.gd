extends Enemy
class_name BossFortressTitan

const DASH_INTERVAL: float = 5.4
const DASH_WARNING: float = 0.70
const DASH_DURATION: float = 0.58
const DASH_SPEED: float = 980.0
const DASH_MAX_DISTANCE: float = 620.0
const DASH_CONTACT_RADIUS: float = 64.0
const DASH_DAMAGE_RATIO: float = 1.35
const PHASE2_SHOCKWAVE_RADIUS: float = 180.0
const PHASE2_SHOCKWAVE_DAMAGE_RATIO: float = 0.8
const PHASE3_FOLLOWUP_DELAY: float = 0.18

var _dash_timer: float = 2.0
var _dash_warning_active: bool = false
var _dash_active: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_distance_remaining: float = 0.0
var _dash_time_remaining: float = 0.0
var _dash_hit_player_ids: Dictionary = {}
var _dash_chain_remaining: int = 0

func on_boss_phase_changed(phase_no: int, is_initial: bool, event_tag: String) -> void:
	_refresh_phase_visuals(phase_no)
	if is_initial:
		return
	_dash_timer = min(_dash_timer, 0.45)
	_emit_shockwave(global_position)
	Global.spawn_floating_text(global_position + Vector2(0.0, -56.0), event_tag.to_upper(), _get_phase_color(phase_no, 1.0))

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	if _dash_active:
		super._process(delta)
		_process_dash(delta)
		return
	super._process(delta)
	if _dash_warning_active:
		return
	_dash_timer = max(0.0, _dash_timer - delta)
	if _dash_timer <= 0.0:
		_dash_timer = _get_dash_interval()
		_dash_chain_remaining = 1 if boss_current_phase >= 3 else 0
		_begin_dash_attack()

func destroy_enemy() -> void:
	_end_dash_state()
	super.destroy_enemy()

func _begin_dash_attack() -> void:
	if not is_instance_valid(Global.player):
		return
	_dash_warning_active = true
	_dash_direction = global_position.direction_to(Global.player.global_position)
	if _dash_direction.length_squared() <= 0.0001:
		_dash_direction = Vector2.RIGHT
	_spawn_dash_warning_visual()
	var timer := get_tree().create_timer(DASH_WARNING)
	timer.timeout.connect(func():
		if not is_instance_valid(self) or is_dead:
			return
		_start_dash_state()
	)

func _start_dash_state() -> void:
	_dash_warning_active = false
	_dash_active = true
	can_move = false
	_dash_time_remaining = DASH_DURATION
	_dash_distance_remaining = DASH_MAX_DISTANCE
	_dash_hit_player_ids.clear()
	current_ai_state = AIState.CHARGING
	set_meta("buff_invincible", true)
	Global.spawn_floating_text(global_position + Vector2(0.0, -28.0), "FORTRESS", Color(0.86, 0.90, 1.0))

func _process_dash(delta: float) -> void:
	if not _dash_active:
		return
	var step_distance: float = min(_dash_distance_remaining, DASH_SPEED * delta)
	global_position += _dash_direction * step_distance
	_dash_distance_remaining -= step_distance
	_dash_time_remaining = max(0.0, _dash_time_remaining - delta)
	update_rotation()
	_resolve_dash_player_hit()
	if _dash_time_remaining <= 0.0 or _dash_distance_remaining <= 0.0:
		_end_dash_state()

func _resolve_dash_player_hit() -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return
	var player_id: int = player.get_instance_id()
	if _dash_hit_player_ids.has(player_id):
		return
	if player.global_position.distance_to(global_position) > DASH_CONTACT_RADIUS:
		return
	_dash_hit_player_ids[player_id] = true
	player.take_damage(max(1.0, damage * DASH_DAMAGE_RATIO), {
		"source": self,
		"kind": "fortress_titan_dash",
		"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
		"source_position": global_position,
	})
	player.apply_knockback_self(_dash_direction * 560.0)

func _end_dash_state() -> void:
	var ended_position: Vector2 = global_position
	_dash_warning_active = false
	_dash_active = false
	can_move = true
	current_ai_state = AIState.COOLDOWN
	ai_timer = max(ai_timer, 0.45)
	_dash_time_remaining = 0.0
	_dash_distance_remaining = 0.0
	_dash_hit_player_ids.clear()
	if has_meta("buff_invincible"):
		remove_meta("buff_invincible")
	if boss_current_phase >= 2:
		_emit_shockwave(ended_position)
	if boss_current_phase >= 3 and _dash_chain_remaining > 0 and not is_dead:
		_dash_chain_remaining -= 1
		var timer := get_tree().create_timer(PHASE3_FOLLOWUP_DELAY)
		timer.timeout.connect(func():
			if not is_instance_valid(self) or is_dead or _dash_active or _dash_warning_active:
				return
			_begin_dash_attack()
		)
		return

func _spawn_dash_warning_visual() -> void:
	var line := Line2D.new()
	line.top_level = true
	line.width = 18.0
	line.default_color = Color(0.72, 0.84, 1.0, 0.24)
	line.z_index = 32
	line.add_point(global_position)
	line.add_point(global_position + _dash_direction * DASH_MAX_DISTANCE)
	get_tree().current_scene.add_child(line)
	var tween: Tween = line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "width", 30.0, DASH_WARNING)
	tween.tween_property(line, "default_color", Color(0.88, 0.94, 1.0, 0.86), DASH_WARNING)
	tween.chain().tween_callback(line.queue_free)

func _get_dash_interval() -> float:
	match boss_current_phase:
		2:
			return 4.4
		3:
			return 3.4
		_:
			return DASH_INTERVAL

func _emit_shockwave(origin: Vector2) -> void:
	_spawn_shockwave_visual(origin)
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null:
		var player_distance: float = player.global_position.distance_to(origin)
		if player_distance <= PHASE2_SHOCKWAVE_RADIUS:
			var player_dir: Vector2 = player.global_position - origin
			if player_dir.length_squared() <= 0.0001:
				player_dir = _dash_direction
			player.take_damage(max(1.0, damage * PHASE2_SHOCKWAVE_DAMAGE_RATIO), {
				"source": self,
				"kind": "fortress_titan_shockwave",
				"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
				"source_position": origin,
			})
			player.apply_knockback_self(player_dir.normalized() * 420.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_to_origin: float = enemy.global_position.distance_to(origin)
		if distance_to_origin > PHASE2_SHOCKWAVE_RADIUS:
			continue
		var push_dir: Vector2 = enemy.global_position - origin
		if push_dir.length_squared() <= 0.0001:
			push_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.apply_knockback(push_dir.normalized(), 360.0, self, {
			"kind": "fortress_titan_shockwave",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
			"source_position": origin,
		})

func _spawn_shockwave_visual(origin: Vector2) -> void:
	var root := Node2D.new()
	root.top_level = true
	root.global_position = origin
	root.z_index = 34
	get_tree().current_scene.add_child(root)
	var polygon := Polygon2D.new()
	var ring := Line2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(30):
		var angle: float = TAU * float(index) / 30.0
		points.append(Vector2.RIGHT.rotated(angle) * PHASE2_SHOCKWAVE_RADIUS)
	polygon.polygon = points
	polygon.color = Color(0.76, 0.90, 1.0, 0.12)
	root.add_child(polygon)
	ring.points = points
	ring.closed = true
	ring.width = 8.0
	ring.default_color = Color(0.88, 0.96, 1.0, 0.84)
	root.add_child(ring)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(1.14, 1.14), 0.22)
	tween.tween_property(polygon, "color:a", 0.0, 0.22)
	tween.tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(root.queue_free)

func _refresh_phase_visuals(phase_no: int) -> void:
	if visuals == null or not is_instance_valid(visuals):
		return
	visuals.modulate = _get_phase_color(phase_no, 1.0)
	visuals.scale = Vector2.ONE * (1.06 + 0.06 * float(max(0, phase_no - 1)))

func _get_phase_color(phase_no: int, alpha_value: float) -> Color:
	match phase_no:
		2:
			return Color(0.82, 0.90, 1.0, alpha_value)
		3:
			return Color(1.0, 0.86, 0.66, alpha_value)
		_:
			return Color(0.88, 0.94, 1.0, alpha_value)
