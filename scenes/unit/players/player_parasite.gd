extends PlayerBase
class_name PlayerParasite

const PARASITE_Q_SCRIPT := preload("res://scenes/skills/players/skill_parasite_q.gd")
const PARASITE_E_SCRIPT := preload("res://scenes/skills/players/skill_parasite_e.gd")
const PARASITE_BLOOD_PIT_SCENE := preload("res://scenes/effects/parasite_blood_pit.tscn")

@export var base_health: float = 220.0
@export var base_damage: float = 40.0
@export var base_move_speed: float = 360.0
@export var base_max_energy: float = 120.0
@export var base_energy_regen: float = 10.0
@export var base_pickup_range: float = 170.0
@export var parasite_e_cost: float = 40.0
@export var parasite_e_cooldown: float = 8.0
@export var parasite_dash_cost: float = 5.0
@export var parasite_dash_distance: float = 400.0
@export var parasite_dash_speed: float = 2000.0
@export var parasite_dash_invuln_duration: float = 0.35
@export var parasite_dash_host_trigger_radius: float = 44.0
@export var parasite_blood_pit_radius: float = 60.0
@export var parasite_blood_pit_duration: float = 3.0
@export var parasite_blood_pit_damage_bonus: float = 0.15
@export var parasite_blood_pit_slow_ratio: float = 0.15
@export var parasite_f_energy_percent: float = 40.0
@export var parasite_f_delay: float = 0.5

@onready var dash_timer: Timer = $DashTimer

var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_remaining_distance: float = 0.0
var _dash_total_distance: float = 0.0
var _dash_spawned_enemy_ids: Dictionary = {}

func _ready() -> void:
	if player_id.strip_edges().is_empty():
		player_id = "parasite"
	super._ready()

	health = base_health
	damage = base_damage
	speed = base_move_speed
	base_speed = base_move_speed
	max_energy = base_max_energy
	energy_regen = base_energy_regen
	pickup_range = base_pickup_range
	energy = max_energy
	skill_q_cost = 0.0
	skill_e_cost = parasite_e_cost

	if health_component:
		health_component.setup_with_health(base_health)

	update_ui_signals()
	if is_instance_valid(dash_timer):
		dash_timer.one_shot = true
		dash_timer.wait_time = parasite_dash_invuln_duration
	call_deferred("_install_skill_manager")

func _install_skill_manager() -> void:
	var skill_manager := get_node_or_null("SkillManager") as SkillManager
	if skill_manager == null:
		skill_manager = SkillManager.new(self)
		skill_manager.name = "SkillManager"
		add_child(skill_manager)
	else:
		skill_manager.skill_owner = self

	for slot_name: String in ["q", "e", "lmb", "rmb"]:
		var existing_skill: Variant = skill_manager.skill_slots.get(slot_name, null)
		if existing_skill != null and is_instance_valid(existing_skill):
			(existing_skill as Node).queue_free()
		skill_manager.skill_slots[slot_name] = null

	var q_skill := PARASITE_Q_SCRIPT.new() as SkillBase
	q_skill.skill_owner = self
	q_skill.skill_id = "skill_parasite_q"
	q_skill.name = "Q_Skill"
	q_skill.energy_cost = 0.0
	q_skill.cooldown_time = 0.0
	q_skill.set_skill_tags_from_value("q,active,drawing,parasite")
	skill_manager.add_child(q_skill)
	skill_manager.skill_slots["q"] = q_skill

	var e_skill := PARASITE_E_SCRIPT.new() as SkillBase
	e_skill.skill_owner = self
	e_skill.skill_id = "skill_parasite_e"
	e_skill.name = "E_Skill"
	e_skill.energy_cost = parasite_e_cost
	e_skill.cooldown_time = parasite_e_cooldown
	e_skill.set_skill_tags_from_value("e,active,burst,parasite")
	skill_manager.add_child(e_skill)
	skill_manager.skill_slots["e"] = e_skill

func _handle_input(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _is_dashing:
		_update_dash(delta)
	else:
		if can_move():
			var current_speed = speed
			if has_meta("buff_speed_boost"):
				current_speed *= (1.0 + get_meta("buff_speed_boost"))
			position += move_dir * current_speed * delta

	if Input.is_action_just_pressed("tactical_reject"):
		_try_activate_tactical_reject()

	var skill_manager := get_node_or_null("SkillManager") as SkillManager
	var draw_held: bool = Input.is_action_pressed("click_right")

	if skill_manager != null:
		if Input.is_action_just_pressed("skill_e"):
			skill_manager.execute_skill("e")
			return
		if Input.is_action_just_pressed("skill_f"):
			_activate_parasite_f()
			return

		var q_skill := skill_manager.get_skill("q")
		var q_is_charging: bool = q_skill != null and is_instance_valid(q_skill) and bool(q_skill.is_charging)

		if draw_held:
			skill_manager.charge_skill("q", delta)
			return

		if q_is_charging and Input.is_action_just_released("click_right"):
			skill_manager.release_skill("q")
			return

	if Input.is_action_just_pressed("click_left"):
		_try_start_dash()
		return

func _load_config_from_csv() -> void:
	max_energy = base_max_energy
	energy_regen = base_energy_regen
	base_speed = base_move_speed
	speed = base_move_speed
	skill_q_cost = 0.0
	skill_e_cost = parasite_e_cost
	close_threshold = 60.0

func _load_weapons_from_config() -> void:
	super._load_weapons_from_config()

func _load_ultimate_skill() -> void:
	ultimate_skill = null

func _cancel_parasite_space() -> void:
	var skill_manager := get_node_or_null("SkillManager") as SkillManager
	if skill_manager == null:
		return
	var q_skill := skill_manager.get_skill("q")
	if q_skill != null and is_instance_valid(q_skill) and q_skill.has_method("cancel_drawing"):
		q_skill.call("cancel_drawing")

func _try_start_dash() -> void:
	if _is_dashing:
		return
	if not consume_energy(parasite_dash_cost):
		return

	var dash_target: Vector2 = get_global_mouse_position()
	var dash_dir: Vector2 = global_position.direction_to(dash_target)
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = move_dir.normalized()
	if dash_dir.length_squared() <= 0.0001:
		dash_dir = Vector2.RIGHT if is_facing_right() else Vector2.LEFT

	_is_dashing = true
	_dash_direction = dash_dir.normalized()
	_dash_remaining_distance = parasite_dash_distance
	_dash_total_distance = parasite_dash_distance
	_dash_spawned_enemy_ids.clear()
	set_meta("buff_invincible", true)
	if is_instance_valid(dash_timer):
		dash_timer.stop()
		dash_timer.wait_time = parasite_dash_invuln_duration
		dash_timer.start()
	dash_started.emit(player_id, global_position, _dash_direction)
	notify_front_dash_used({
		"start": global_position,
		"end": global_position + _dash_direction * parasite_dash_distance,
		"direction": _dash_direction,
		"distance": parasite_dash_distance,
	})
	Global.spawn_floating_text(global_position, "DASH", Color(0.72, 1.0, 0.92))

func _update_dash(delta: float) -> void:
	if not _is_dashing:
		return
	var step: float = min(_dash_remaining_distance, parasite_dash_speed * delta)
	var from_pos: Vector2 = global_position
	global_position += _dash_direction * step
	_dash_remaining_distance = max(0.0, _dash_remaining_distance - step)
	_check_dash_parasite_hosts(from_pos, global_position)
	var normalized_time: float = 1.0 - (_dash_remaining_distance / max(1.0, _dash_total_distance))
	dash_active.emit(player_id, global_position, _dash_direction, normalized_time)
	if _dash_remaining_distance <= 0.0:
		_finish_dash()

func _finish_dash() -> void:
	if not _is_dashing:
		return
	_is_dashing = false
	dash_finished.emit(player_id, global_position, _dash_direction)

func _on_dash_timer_timeout() -> void:
	if has_meta("buff_invincible"):
		remove_meta("buff_invincible")

func _check_dash_parasite_hosts(from_pos: Vector2, to_pos: Vector2) -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_parasitized:
			continue
		var enemy_id: int = enemy.get_instance_id()
		if _dash_spawned_enemy_ids.has(enemy_id):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, from_pos, to_pos)
		if enemy.global_position.distance_to(closest) > parasite_dash_host_trigger_radius:
			continue
		_dash_spawned_enemy_ids[enemy_id] = true
		_spawn_parasite_blood_pit(enemy.global_position)

func _spawn_parasite_blood_pit(position_world: Vector2) -> void:
	if PARASITE_BLOOD_PIT_SCENE == null:
		return
	var pit := PARASITE_BLOOD_PIT_SCENE.instantiate() as ParasiteBloodPit
	if pit == null:
		return
	pit.setup(
		parasite_blood_pit_radius,
		parasite_blood_pit_duration,
		parasite_blood_pit_damage_bonus,
		parasite_blood_pit_slow_ratio
	)
	pit.global_position = position_world
	get_tree().current_scene.add_child(pit)
	Global.spawn_floating_text(position_world, "BLOOD PIT", Color(0.68, 1.0, 0.6))

func _activate_parasite_f() -> void:
	var energy_cost: float = max_energy * (parasite_f_energy_percent / 100.0)
	if not consume_energy(energy_cost):
		return
	var hosts: Array[Enemy] = _get_parasitized_hosts()
	if hosts.is_empty():
		Global.spawn_floating_text(global_position, "MISS", Color(1.0, 0.45, 0.45))
		return

	var source_attack: float = damage
	for enemy in hosts:
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		enemy.trigger_parasite_detonation(source_attack, parasite_f_delay)
	if has_method("notify_front_skill_damage"):
		notify_front_skill_damage("f", hosts, {
			"skill_id": "f_parasite",
			"source": "parasite_festival",
		})
	Global.spawn_floating_text(global_position, "FESTIVAL x%d" % hosts.size(), Color(1.0, 0.38, 0.32))

func _get_parasitized_hosts() -> Array[Enemy]:
	var hosts: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead or not enemy.is_parasitized:
			continue
		hosts.append(enemy)
	return hosts
