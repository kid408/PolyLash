extends Node
class_name AutoPlayerController

signal enabled_changed(enabled: bool)
signal status_changed(message: String)

const CONTROLLED_ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"click_left",
	"click_right",
	"skill_e",
	"skill_f",
]
const BEHAVIOR_DECISION_INTERVAL: float = 1.0
const DRAW_RETRY_INTERVAL: float = 2.0
const DRAW_POINT_STEP_INTERVAL: float = 0.08
const DASH_ESCAPE_RADIUS: float = 150.0
const DASH_ESCAPE_ENEMY_COUNT: int = 5
const DEFAULT_OVERDRIVE_SCALE: float = 5.0

var enabled: bool = false
var overdrive_scale: float = 1.0

var _stored_action_events: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _tap_release_timers: Dictionary = {}
var _decision_timer: float = 0.0
var _draw_retry_timer: float = 0.0
var _dash_timer: float = 0.0
var _skill_e_timer: float = 0.0
var _skill_f_timer: float = 0.0
var _draw_step_timer: float = 0.0
var _draw_active: bool = false
var _draw_points: Array[Vector2] = []
var _draw_point_index: int = 0
var _movement_mode: String = "idle"
var _orbit_sign: float = 1.0
var _move_vector: Vector2 = Vector2.ZERO
var _status_message: String = "AI 代打：关闭"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()

func _exit_tree() -> void:
	disable()

func enable(requested_overdrive_scale: float = 1.0) -> void:
	if not enabled:
		enabled = true
		_take_over_input_actions()
		_reset_runtime_state()
	if requested_overdrive_scale > 1.0:
		overdrive_scale = requested_overdrive_scale
	else:
		overdrive_scale = 1.0
	Engine.time_scale = overdrive_scale if overdrive_scale > 1.0 else 1.0
	_update_status()
	enabled_changed.emit(true)

func disable() -> void:
	if not enabled and _stored_action_events.is_empty():
		return
	_release_all_actions()
	_restore_input_actions()
	enabled = false
	overdrive_scale = 1.0
	_draw_active = false
	_draw_points.clear()
	_draw_point_index = 0
	if Engine.time_scale > 1.0:
		Engine.time_scale = 1.0
	_update_status()
	enabled_changed.emit(false)

func _process(delta: float) -> void:
	if not enabled:
		return
	if Global == null or Global.game_paused:
		_release_all_actions()
		return

	_update_tap_releases(delta)

	var player: PlayerBase = _get_front_player()
	if player == null:
		_release_all_actions()
		return

	_decision_timer -= delta
	_draw_retry_timer -= delta
	_dash_timer = max(0.0, _dash_timer - delta)
	_skill_e_timer = max(0.0, _skill_e_timer - delta)
	_skill_f_timer = max(0.0, _skill_f_timer - delta)

	var nearest_enemy: Enemy = _get_nearest_enemy(player.global_position)
	if _decision_timer <= 0.0:
		_choose_behavior(player, nearest_enemy)
		_decision_timer = BEHAVIOR_DECISION_INTERVAL

	if _should_escape(player):
		_trigger_escape_dash(player)
	else:
		_update_movement(player, nearest_enemy)

	_update_draw_behavior(player, nearest_enemy, delta)
	_update_skill_usage(player)
	_update_status(player, nearest_enemy)

func _reset_runtime_state() -> void:
	_pressed_actions.clear()
	_tap_release_timers.clear()
	_decision_timer = 0.0
	_draw_retry_timer = 0.35
	_dash_timer = 0.0
	_skill_e_timer = 0.25
	_skill_f_timer = 1.5
	_draw_step_timer = 0.0
	_draw_active = false
	_draw_points.clear()
	_draw_point_index = 0
	_movement_mode = "idle"
	_orbit_sign = 1.0
	_move_vector = Vector2.ZERO

func _take_over_input_actions() -> void:
	for action_name: String in CONTROLLED_ACTIONS:
		if not InputMap.has_action(action_name):
			continue
		if _stored_action_events.has(action_name):
			continue
		var stored_events: Array[InputEvent] = []
		for event_variant in InputMap.action_get_events(action_name):
			var event: InputEvent = event_variant
			if event != null:
				stored_events.append(event.duplicate())
		_stored_action_events[action_name] = stored_events
		InputMap.action_erase_events(action_name)

func _restore_input_actions() -> void:
	for action_key: Variant in _stored_action_events.keys():
		var action_name: String = str(action_key)
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		var stored_events_variant: Variant = _stored_action_events.get(action_name, [])
		var stored_events: Array = stored_events_variant if stored_events_variant is Array else []
		for event_variant in stored_events:
			var event: InputEvent = event_variant
			if event != null:
				InputMap.action_add_event(action_name, event)
	_stored_action_events.clear()

func _emit_action(action_name: String, pressed: bool) -> void:
	if not InputMap.has_action(action_name):
		return
	if bool(_pressed_actions.get(action_name, false)) == pressed:
		return
	var event: InputEventAction = InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	_pressed_actions[action_name] = pressed

func _tap_action(action_name: String, hold_duration: float = 0.04) -> void:
	_emit_action(action_name, true)
	_tap_release_timers[action_name] = max(0.01, hold_duration)

func _update_tap_releases(delta: float) -> void:
	var released_actions: Array[String] = []
	for action_key: Variant in _tap_release_timers.keys():
		var action_name: String = str(action_key)
		var remaining: float = max(0.0, float(_tap_release_timers.get(action_name, 0.0)) - delta)
		if remaining <= 0.0:
			released_actions.append(action_name)
		else:
			_tap_release_timers[action_name] = remaining
	for action_name: String in released_actions:
		_emit_action(action_name, false)
		_tap_release_timers.erase(action_name)

func _release_all_actions() -> void:
	for action_name: String in CONTROLLED_ACTIONS:
		_emit_action(action_name, false)
	_tap_release_timers.clear()
	_move_vector = Vector2.ZERO

func _get_front_player() -> PlayerBase:
	if Global == null:
		return null
	if is_instance_valid(Global.player):
		return Global.player
	return null

func _get_nearest_enemy(center: Vector2, max_radius: float = 2200.0) -> Enemy:
	var nearest_enemy: Enemy = null
	var best_distance_sq: float = max_radius * max_radius
	for enemy_variant in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_sq: float = center.distance_squared_to(enemy.global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest_enemy = enemy
	return nearest_enemy

func _count_nearby_enemies(center: Vector2, radius: float) -> int:
	var radius_sq: float = radius * radius
	var count: int = 0
	for enemy_variant in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_squared_to(center) <= radius_sq:
			count += 1
	return count

func _choose_behavior(player: PlayerBase, nearest_enemy: Enemy) -> void:
	if nearest_enemy == null:
		_movement_mode = "wander"
		_move_vector = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
		return
	var enemy_offset: Vector2 = nearest_enemy.global_position - player.global_position
	if enemy_offset.length_squared() <= 0.001:
		enemy_offset = Vector2.RIGHT
	if _rng.randf() < 0.5:
		_movement_mode = "rush"
		_move_vector = enemy_offset.normalized()
	else:
		_movement_mode = "orbit"
		_orbit_sign = -1.0 if _rng.randf() < 0.5 else 1.0
		_move_vector = enemy_offset.orthogonal() * _orbit_sign

func _should_escape(player: PlayerBase) -> bool:
	if _dash_timer > 0.0:
		return false
	if player.health_component == null or player.health_component.max_health <= 0.0:
		return false
	var health_ratio: float = float(player.health_component.current_health) / float(player.health_component.max_health)
	if health_ratio < 0.30:
		return true
	return _count_nearby_enemies(player.global_position, DASH_ESCAPE_RADIUS) > DASH_ESCAPE_ENEMY_COUNT

func _trigger_escape_dash(player: PlayerBase) -> void:
	if _draw_active:
		_finish_draw()
	var threat_center: Vector2 = player.global_position
	var threat_count: int = 0
	for enemy_variant in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.global_position.distance_to(player.global_position) > DASH_ESCAPE_RADIUS:
			continue
		threat_center += enemy.global_position
		threat_count += 1
	if threat_count > 0:
		threat_center /= float(threat_count + 1)
	var escape_direction: Vector2 = (player.global_position - threat_center).normalized()
	if escape_direction.length_squared() <= 0.001:
		escape_direction = -_move_vector.normalized() if _move_vector.length_squared() > 0.001 else Vector2.UP
	_warp_mouse_to_world(player.global_position + escape_direction * 260.0, player)
	_tap_action("click_left", 0.05)
	_dash_timer = 0.9
	_decision_timer = 0.2

func _update_movement(player: PlayerBase, nearest_enemy: Enemy) -> void:
	var desired_move: Vector2 = _move_vector
	if nearest_enemy != null:
		var to_enemy: Vector2 = nearest_enemy.global_position - player.global_position
		var distance: float = to_enemy.length()
		match _movement_mode:
			"rush":
				desired_move = to_enemy.normalized() if distance > 90.0 else to_enemy.orthogonal().normalized()
			"orbit":
				var tangent: Vector2 = to_enemy.orthogonal().normalized() * _orbit_sign
				var radial_adjust: Vector2 = Vector2.ZERO
				if distance > 220.0:
					radial_adjust = to_enemy.normalized() * 0.65
				elif distance < 120.0:
					radial_adjust = -to_enemy.normalized() * 0.85
				desired_move = (tangent + radial_adjust).normalized()
			_:
				desired_move = to_enemy.normalized()
		if not _draw_active:
			_warp_mouse_to_world(nearest_enemy.global_position, player)
	elif not _draw_active:
		_warp_mouse_to_world(player.global_position + desired_move.normalized() * 180.0, player)
	_apply_move_vector(desired_move)

func _apply_move_vector(direction: Vector2) -> void:
	var move: Vector2 = direction.normalized() if direction.length_squared() > 0.001 else Vector2.ZERO
	_move_vector = move
	_emit_action("move_left", move.x < -0.15)
	_emit_action("move_right", move.x > 0.15)
	_emit_action("move_up", move.y < -0.15)
	_emit_action("move_down", move.y > 0.15)

func _update_draw_behavior(player: PlayerBase, nearest_enemy: Enemy, delta: float) -> void:
	if _draw_active:
		_draw_step_timer -= delta
		if _draw_step_timer <= 0.0:
			_draw_step_timer = DRAW_POINT_STEP_INTERVAL
			if _draw_point_index < _draw_points.size():
				_warp_mouse_to_world(_draw_points[_draw_point_index], player)
				_draw_point_index += 1
			else:
				_finish_draw()
		return

	if _draw_retry_timer > 0.0:
		return
	if not _can_attempt_draw(player):
		_draw_retry_timer = 0.35
		return
	_start_draw(player, nearest_enemy)

func _can_attempt_draw(player: PlayerBase) -> bool:
	if player == null:
		return false
	if player.has_method("_is_drawing_active") and bool(player.call("_is_drawing_active")):
		return false
	var required_energy: float = 16.0
	if "skill_q_cost" in player:
		required_energy = max(12.0, float(player.skill_q_cost) * 0.45)
	return player.energy >= required_energy

func _start_draw(player: PlayerBase, nearest_enemy: Enemy) -> void:
	_draw_points = _build_draw_points(player, nearest_enemy)
	if _draw_points.is_empty():
		_draw_retry_timer = 0.75
		return
	_draw_active = true
	_draw_point_index = 0
	_draw_step_timer = 0.0
	_draw_retry_timer = DRAW_RETRY_INTERVAL
	_warp_mouse_to_world(_draw_points[0], player)
	_emit_action("click_right", true)

func _finish_draw() -> void:
	_draw_active = false
	_draw_points.clear()
	_draw_point_index = 0
	_draw_step_timer = 0.0
	_emit_action("click_right", false)

func _build_draw_points(player: PlayerBase, nearest_enemy: Enemy) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var around_enemy: bool = nearest_enemy != null and _rng.randf() < 0.55
	var center: Vector2 = nearest_enemy.global_position if around_enemy else player.global_position
	var radius: float = _rng.randf_range(55.0, 120.0)
	var point_count: int = _rng.randi_range(5, 8)
	var make_closed_attempt: bool = _rng.randf() < 0.65
	var start_angle: float = _rng.randf_range(0.0, TAU)
	if around_enemy:
		center += Vector2.RIGHT.rotated(start_angle) * _rng.randf_range(10.0, 35.0)
	else:
		center += Vector2.RIGHT.rotated(start_angle) * _rng.randf_range(25.0, 65.0)

	for i: int in range(point_count):
		var t: float = float(i) / float(max(1, point_count - 1))
		var angle: float = start_angle + t * PI * _rng.randf_range(1.1, 1.8)
		if make_closed_attempt:
			angle = start_angle + t * TAU
		var jitter: float = _rng.randf_range(-18.0, 18.0)
		var sample_radius: float = max(28.0, radius + jitter)
		points.append(center + Vector2.RIGHT.rotated(angle) * sample_radius)
	if make_closed_attempt and points.size() >= 2:
		points.append(points[0] + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0)))
	else:
		points.append(points[points.size() - 1] + Vector2.RIGHT.rotated(start_angle + PI * 0.35) * _rng.randf_range(40.0, 90.0))
	return points

func _update_skill_usage(player: PlayerBase) -> void:
	if player == null:
		return
	if _skill_e_timer <= 0.0 and player.energy >= float(player.skill_e_cost):
		_tap_action("skill_e", 0.05)
		_skill_e_timer = _rng.randf_range(0.75, 1.25)

	if _skill_f_timer <= 0.0 and player.get_energy_percent() >= 40.0:
		_tap_action("skill_f", 0.06)
		_skill_f_timer = _rng.randf_range(3.2, 4.6)

func _warp_mouse_to_world(world_pos: Vector2, player: PlayerBase = null) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var reference_player: PlayerBase = player if player != null else _get_front_player()
	var screen_pos: Vector2 = world_pos
	if reference_player != null:
		screen_pos = reference_player.get_global_transform_with_canvas() * reference_player.to_local(world_pos)
	var visible_rect: Rect2 = viewport.get_visible_rect()
	screen_pos.x = clamp(screen_pos.x, visible_rect.position.x + 4.0, visible_rect.end.x - 4.0)
	screen_pos.y = clamp(screen_pos.y, visible_rect.position.y + 4.0, visible_rect.end.y - 4.0)
	viewport.warp_mouse(screen_pos)

func _update_status(player: PlayerBase = null, nearest_enemy: Enemy = null) -> void:
	var mode_text: String = "关闭"
	if enabled:
		mode_text = "开启"
		if overdrive_scale > 1.0:
			mode_text = "极速 %.1fx" % overdrive_scale
	var player_text: String = "无角色"
	if player != null:
		player_text = player.player_id
	var enemy_text: String = "无目标"
	if nearest_enemy != null:
		enemy_text = nearest_enemy.enemy_id
	var draw_text: String = "画线中" if _draw_active else "待机"
	var next_message: String = "AI 代打：%s | 前台：%s | 目标：%s | 行为：%s | 画线：%s" % [
		mode_text,
		player_text,
		enemy_text,
		_movement_mode,
		draw_text
	]
	if next_message == _status_message:
		return
	_status_message = next_message
	status_changed.emit(_status_message)

func get_status_text() -> String:
	return _status_message

func get_debug_snapshot() -> Dictionary:
	var player: PlayerBase = _get_front_player()
	var nearest_enemy: Enemy = null
	var nearby_count: int = 0
	var health_ratio: float = 0.0
	var energy_ratio: float = 0.0
	if player != null:
		nearest_enemy = _get_nearest_enemy(player.global_position)
		nearby_count = _count_nearby_enemies(player.global_position, DASH_ESCAPE_RADIUS)
		if player.health_component != null and player.health_component.max_health > 0.0:
			health_ratio = clamp(
				float(player.health_component.current_health) / float(player.health_component.max_health),
				0.0,
				1.0
			)
		if player.max_energy > 0.0:
			energy_ratio = clamp(float(player.energy) / float(player.max_energy), 0.0, 1.0)
	return {
		"enabled": enabled,
		"overdrive_scale": overdrive_scale,
		"movement_mode": _movement_mode,
		"draw_active": _draw_active,
		"player_id": player.player_id if player != null else "",
		"target_id": nearest_enemy.enemy_id if nearest_enemy != null else "",
		"nearby_enemy_count": nearby_count,
		"health_ratio": health_ratio,
		"energy_ratio": energy_ratio,
		"dash_cooldown": _dash_timer,
		"skill_e_timer": _skill_e_timer,
		"skill_f_timer": _skill_f_timer,
		"status_text": _status_message,
	}

func is_overdrive_enabled() -> bool:
	return enabled and overdrive_scale > 1.0

func start_overdrive(scale: float = DEFAULT_OVERDRIVE_SCALE) -> void:
	enable(max(1.0, scale))
