extends Enemy
class_name EnemySiegeBehemoth

const GRAB_RADIUS: float = 100.0
const GRAB_COOLDOWN: float = 6.0
const GRAB_WINDUP: float = 1.0
const HOLD_OFFSET: Vector2 = Vector2(0.0, -58.0)
const THROW_SPEED: float = 1100.0
const THROW_MAX_DISTANCE: float = 720.0
const THROW_EXTRA_DAMAGE_RATIO: float = 1.25
const THROW_PLAYER_HIT_RADIUS: float = 36.0
const THROW_PLAYER_KNOCKBACK: float = 420.0

var _grab_cooldown_remaining: float = 2.5
var _hold_timer_remaining: float = 0.0
var _held_enemy: Enemy = null
var _launched_enemy: Enemy = null
var _launch_velocity: Vector2 = Vector2.ZERO
var _launch_distance_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	_grab_cooldown_remaining = randf_range(2.0, 4.0)

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_update_held_enemy_anchor()
	_process_grab_cycle(delta)
	_process_launched_enemy(delta)

func destroy_enemy() -> void:
	_cleanup_held_enemy(true)
	_cleanup_launched_enemy(true)
	super.destroy_enemy()

func _exit_tree() -> void:
	_cleanup_held_enemy(true)
	_cleanup_launched_enemy(true)

func _process_grab_cycle(delta: float) -> void:
	if _launched_enemy != null and is_instance_valid(_launched_enemy):
		return
	if _held_enemy != null and is_instance_valid(_held_enemy):
		_hold_timer_remaining = max(0.0, _hold_timer_remaining - delta)
		if _hold_timer_remaining <= 0.0:
			_throw_held_enemy()
		return
	_grab_cooldown_remaining = max(0.0, _grab_cooldown_remaining - delta)
	if _grab_cooldown_remaining > 0.0:
		return
	var candidate: Enemy = _find_grab_candidate()
	if candidate == null:
		_grab_cooldown_remaining = 1.0
		return
	_grab_enemy(candidate)

func _process_launched_enemy(delta: float) -> void:
	if _launched_enemy == null or not is_instance_valid(_launched_enemy):
		_launched_enemy = null
		return
	var step: Vector2 = _launch_velocity * delta
	_launched_enemy.global_position += step
	_launch_distance_remaining -= step.length()
	if _launched_enemy.has_method("update_rotation"):
		_launched_enemy.call("update_rotation")
	if _check_launched_enemy_hit_player():
		_cleanup_launched_enemy(true)
		return
	if _launch_distance_remaining <= 0.0:
		_cleanup_launched_enemy(true)

func _update_held_enemy_anchor() -> void:
	if _held_enemy == null or not is_instance_valid(_held_enemy):
		_held_enemy = null
		return
	_held_enemy.global_position = global_position + HOLD_OFFSET

func _find_grab_candidate() -> Enemy:
	var best_candidate: Enemy = null
	var best_distance_sq: float = GRAB_RADIUS * GRAB_RADIUS
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var candidate: Enemy = enemy_node as Enemy
		if candidate == self or not is_instance_valid(candidate) or candidate.is_dead:
			continue
		if candidate is EnemyElites:
			continue
		if bool(candidate.get_meta("behemoth_carried", false)):
			continue
		var distance_sq: float = global_position.distance_squared_to(candidate.global_position)
		if distance_sq > best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_candidate = candidate
	return best_candidate

func _grab_enemy(candidate: Enemy) -> void:
	_held_enemy = candidate
	_hold_timer_remaining = GRAB_WINDUP
	_grab_cooldown_remaining = GRAB_COOLDOWN
	_set_carried_enemy_state(candidate, false)
	candidate.set_meta("behemoth_carried", true)
	candidate.global_position = global_position + HOLD_OFFSET
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(global_position + Vector2(0.0, -72.0), "GRAB!", Color(1.0, 0.84, 0.52))

func _throw_held_enemy() -> void:
	if _held_enemy == null or not is_instance_valid(_held_enemy):
		_held_enemy = null
		return
	var target_pos: Vector2 = global_position + Vector2.RIGHT.rotated(randf() * TAU) * 220.0
	if is_instance_valid(Global.player):
		target_pos = Global.player.global_position
	var throw_dir: Vector2 = target_pos - _held_enemy.global_position
	if throw_dir.length_squared() <= 0.0001:
		throw_dir = Vector2.RIGHT
	_launch_velocity = throw_dir.normalized() * THROW_SPEED
	_launch_distance_remaining = THROW_MAX_DISTANCE
	_launched_enemy = _held_enemy
	_held_enemy.remove_meta("behemoth_carried")
	_held_enemy = null
	if Global != null and Global.has_method("spawn_floating_text"):
		Global.spawn_floating_text(global_position + Vector2(0.0, -84.0), "THROW!", Color(1.0, 0.62, 0.32))

func _check_launched_enemy_hit_player() -> bool:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return false
	if player.global_position.distance_to(_launched_enemy.global_position) > THROW_PLAYER_HIT_RADIUS:
		return false
	var hit_dir: Vector2 = player.global_position - global_position
	if hit_dir.length_squared() <= 0.0001:
		hit_dir = _launch_velocity.normalized()
	var damage_amount: float = max(1.0, damage * THROW_EXTRA_DAMAGE_RATIO)
	player.take_damage(damage_amount, {
		"source": self,
		"kind": "siege_behemoth_throw",
		"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
		"source_position": global_position,
	})
	player.apply_knockback_self(hit_dir.normalized() * THROW_PLAYER_KNOCKBACK)
	return true

func _set_carried_enemy_state(target_enemy: Enemy, enabled: bool) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
	target_enemy.can_move = enabled
	var disabled: bool = not enabled
	if target_enemy.collision_shape != null and is_instance_valid(target_enemy.collision_shape):
		target_enemy.collision_shape.set_deferred("disabled", disabled)
	var hurtbox: Area2D = target_enemy.get_node_or_null("HurtboxComponent")
	if hurtbox != null and is_instance_valid(hurtbox):
		hurtbox.monitoring = enabled
		hurtbox.monitorable = enabled
	var hitbox: Area2D = target_enemy.get_node_or_null("HitboxComponent")
	if hitbox != null and is_instance_valid(hitbox):
		hitbox.monitoring = enabled
		hitbox.monitorable = enabled

func _cleanup_held_enemy(force_destroy: bool) -> void:
	if _held_enemy == null or not is_instance_valid(_held_enemy):
		_held_enemy = null
		return
	_held_enemy.remove_meta("behemoth_carried")
	if force_destroy and not _held_enemy.is_dead:
		_held_enemy.destroy_enemy()
	else:
		_set_carried_enemy_state(_held_enemy, true)
	_held_enemy = null
	_hold_timer_remaining = 0.0

func _cleanup_launched_enemy(force_destroy: bool) -> void:
	if _launched_enemy == null or not is_instance_valid(_launched_enemy):
		_launched_enemy = null
		_launch_velocity = Vector2.ZERO
		_launch_distance_remaining = 0.0
		return
	_launched_enemy.remove_meta("behemoth_carried")
	if force_destroy and not _launched_enemy.is_dead:
		_launched_enemy.destroy_enemy()
	else:
		_set_carried_enemy_state(_launched_enemy, true)
	_launched_enemy = null
	_launch_velocity = Vector2.ZERO
	_launch_distance_remaining = 0.0
