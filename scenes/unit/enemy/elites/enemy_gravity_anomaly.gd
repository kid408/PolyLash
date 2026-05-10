extends Enemy
class_name EnemyGravityAnomaly

const FIELD_COOLDOWN: float = 8.0
const FIELD_DURATION: float = 3.0
const FIELD_RADIUS: float = 300.0
const FIELD_PLAYER_PULL: float = 560.0
const FIELD_ENEMY_PULL: float = 420.0
const BODY_ARMOR_RADIUS: float = 80.0
const BODY_ARMOR_PER_TARGET: float = 0.15
const BODY_ARMOR_CAP: float = 0.90

var _field_cooldown_remaining: float = 4.0
var _field_duration_remaining: float = 0.0
var _gravity_ring: Line2D = null
var _gravity_fill: Polygon2D = null
var _armor_feedback_cooldown: float = 0.0

func _ready() -> void:
	super._ready()
	_field_cooldown_remaining = randf_range(3.0, 5.5)
	_setup_gravity_field_visual()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_armor_feedback_cooldown = max(0.0, _armor_feedback_cooldown - delta)
	if _field_duration_remaining > 0.0:
		_field_duration_remaining = max(0.0, _field_duration_remaining - delta)
		_apply_gravity_field(delta)
		_refresh_field_visual(true)
		if _field_duration_remaining <= 0.0:
			_field_cooldown_remaining = FIELD_COOLDOWN
			_refresh_field_visual(false)
		return
	_field_cooldown_remaining = max(0.0, _field_cooldown_remaining - delta)
	_refresh_field_visual(false)
	if _field_cooldown_remaining <= 0.0:
		_activate_gravity_field()

func preprocess_incoming_damage(raw_damage: float, payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.preprocess_incoming_damage(raw_damage, payload)
	var processed_payload: Dictionary = result.get("payload", payload.duplicate(true))
	var damage_value: float = float(result.get("damage", raw_damage))
	var shield_count: int = _count_body_shield_enemies()
	if shield_count <= 0 or damage_value <= 0.0:
		return {
			"damage": damage_value,
			"payload": processed_payload,
		}
	var reduction_ratio: float = min(BODY_ARMOR_CAP, float(shield_count) * BODY_ARMOR_PER_TARGET)
	damage_value *= (1.0 - reduction_ratio)
	processed_payload["gravity_body_armor_ratio"] = reduction_ratio
	if reduction_ratio > 0.0 and _armor_feedback_cooldown <= 0.0:
		_armor_feedback_cooldown = 0.2
		if Global != null and Global.has_method("spawn_floating_text"):
			Global.spawn_floating_text(global_position + Vector2(0.0, -24.0), "ARMOR %.0f%%" % (reduction_ratio * 100.0), Color(0.70, 0.92, 1.0))
	return {
		"damage": damage_value,
		"payload": processed_payload,
	}

func _activate_gravity_field() -> void:
	_field_duration_remaining = FIELD_DURATION
	_refresh_field_visual(true)
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(global_position + Vector2(0.0, -22.0), "GRAVITY", Color(0.62, 0.88, 1.0))

func _apply_gravity_field(delta: float) -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null:
		var to_center_player: Vector2 = global_position - player.global_position
		var player_distance: float = to_center_player.length()
		if player_distance > 2.0 and player_distance <= FIELD_RADIUS:
			player.external_force += to_center_player.normalized() * FIELD_PLAYER_PULL * delta
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var other_enemy: Enemy = enemy_node as Enemy
		if other_enemy == self or not is_instance_valid(other_enemy) or other_enemy.is_dead:
			continue
		if other_enemy is EnemyElites:
			continue
		var to_center: Vector2 = global_position - other_enemy.global_position
		var distance_to_center: float = to_center.length()
		if distance_to_center <= 2.0 or distance_to_center > FIELD_RADIUS:
			continue
		var motion: Vector2 = to_center.normalized() * min(distance_to_center - 2.0, FIELD_ENEMY_PULL * delta)
		other_enemy.global_position += motion
		if other_enemy.has_method("update_rotation"):
			other_enemy.call("update_rotation")

func _count_body_shield_enemies() -> int:
	var count: int = 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var other_enemy: Enemy = enemy_node as Enemy
		if other_enemy == self or not is_instance_valid(other_enemy) or other_enemy.is_dead:
			continue
		if global_position.distance_to(other_enemy.global_position) <= BODY_ARMOR_RADIUS:
			count += 1
	return count

func _setup_gravity_field_visual() -> void:
	_gravity_ring = Line2D.new()
	_gravity_ring.width = 4.0
	_gravity_ring.closed = true
	_gravity_ring.default_color = Color(0.52, 0.86, 1.0, 0.86)
	_gravity_ring.z_index = 5
	add_child(_gravity_ring)

	_gravity_fill = Polygon2D.new()
	_gravity_fill.color = Color(0.28, 0.66, 1.0, 0.10)
	_gravity_fill.z_index = 4
	add_child(_gravity_fill)

	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 36
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * FIELD_RADIUS)
	_gravity_ring.points = points
	_gravity_fill.polygon = points
	_refresh_field_visual(false)

func _refresh_field_visual(active: bool) -> void:
	if _gravity_ring == null or _gravity_fill == null:
		return
	_gravity_ring.visible = active
	_gravity_fill.visible = active
	if not active:
		return
	var pulse: float = 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
	_gravity_ring.scale = Vector2.ONE * pulse
	_gravity_fill.scale = Vector2.ONE * pulse
