extends SkillBase
class_name SkillSapperE

var totem_duration: float = 6.6
var totem_max_health: float = 240.0
var totem_taunt_radius: float = 650.0
var totem_explosion_radius: float = 150.0
var totem_explosion_damage: int = 155

var sync_detonate_scale: float = 0.72
var sync_slow_value: float = 0.45
var sync_slow_duration: float = 1.6
var remote_chain_damage_bonus: float = 0.12
const SAPPER_E_CHAIN_META: String = "sapper_e_chain_until_msec"
const SAPPER_E_REMOTE_COUNT_META: String = "sapper_e_remote_count"

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.4, 0.35)
	var duration_amp: float = get_e_duration_amp(0.4)
	var remote_mine_count: int = _detonate_q_mines()
	if remote_mine_count > 0:
		damage_amp *= 1.0 + min(0.42, remote_chain_damage_bonus * float(remote_mine_count))
	var center: Vector2 = skill_owner.global_position
	var totem: Node2D = _spawn_support_totem(center, damage_amp, duration_amp)
	_retarget_enemies(totem)
	_sync_detonate(center, damage_amp, duration_amp, "SYNC BLAST")
	if remote_mine_count > 0:
		Global.spawn_floating_text(center, "REMOTE MINE x%d" % remote_mine_count, Color(1.25, 0.82, 0.34))
		_sync_detonate(center, damage_amp * 0.72, duration_amp, "CHAIN BLAST")

	if is_f_window_active():
		var totem_ref: WeakRef = weakref(totem)
		get_tree().create_timer(0.6).timeout.connect(
			_on_sync_overload_timeout.bind(totem_ref, damage_amp, duration_amp)
		)
	var chain_window: float = 2.0 + (0.5 if is_f_window_active() else 0.0)
	skill_owner.set_meta(SAPPER_E_CHAIN_META, Time.get_ticks_msec() + int(round(chain_window * 1000.0)))
	skill_owner.set_meta(SAPPER_E_REMOTE_COUNT_META, remote_mine_count)

	start_cooldown()

func _spawn_support_totem(pos: Vector2, damage_amp: float, duration_amp: float) -> Node2D:
	var totem: Node2D = Node2D.new()
	totem.name = "SapperSupportTotem"
	totem.global_position = pos
	totem.set_meta("hp", totem_max_health)

	var icon: Polygon2D = Polygon2D.new()
	icon.polygon = PackedVector2Array([Vector2(0, -26), Vector2(18, 12), Vector2(-18, 12)])
	icon.color = Color(0.92, 0.78, 0.25, 0.95)
	icon.z_index = 58
	totem.add_child(icon)

	var aura: Polygon2D = Polygon2D.new()
	aura.polygon = _build_circle_polygon(totem_explosion_radius * 0.56, 18)
	aura.color = Color(1.0, 0.85, 0.25, 0.22)
	aura.z_index = 57
	totem.add_child(aura)

	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(totem)
	else:
		add_child(totem)

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.8, totem_duration * duration_amp)
	life_timer.one_shot = true
	life_timer.autostart = true
	totem.add_child(life_timer)
	var totem_ref: WeakRef = weakref(totem)
	life_timer.timeout.connect(_on_totem_life_timeout.bind(totem_ref, damage_amp, duration_amp))
	return totem

func _explode_totem(totem: Node2D, damage_amp: float, duration_amp: float) -> void:
	if totem == null or not is_instance_valid(totem):
		return
	var center: Vector2 = totem.global_position
	var damage: int = max(1, int(round(float(totem_explosion_damage) * damage_amp)))
	var hit_count: int = _damage_in_radius(center, totem_explosion_radius, damage, duration_amp, true)
	spawn_skill_vfx(center, Color(1.25, 0.65, 0.2, 0.95), 0.9)
	if hit_count > 0:
		Global.spawn_floating_text(center, "TOTEM BOOM", Color(1.3, 0.72, 0.25))
		Global.on_camera_shake.emit(7.0 + float(hit_count) * 0.3, 0.14)
	totem.queue_free()

func _retarget_enemies(totem: Node2D) -> void:
	if totem == null or not is_instance_valid(totem):
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(totem.global_position) > totem_taunt_radius:
			continue
		if enemy.has_method("set_taunt_target"):
			enemy.call("set_taunt_target", totem)

func _sync_detonate(center: Vector2, damage_amp: float, duration_amp: float, label: String) -> void:
	var radius: float = totem_explosion_radius * 1.35
	var damage: int = max(1, int(round(float(totem_explosion_damage) * sync_detonate_scale * damage_amp)))
	var hit_count: int = _damage_in_radius(center, radius, damage, duration_amp, false)
	spawn_skill_vfx(center, Color(1.2, 0.78, 0.35, 0.8), 0.7)
	if hit_count > 0:
		Global.spawn_floating_text(center, "%s x%d" % [label, hit_count], Color(1.2, 0.82, 0.4))
		Global.on_camera_shake.emit(5.0 + float(hit_count) * 0.25, 0.1)

func _damage_in_radius(center: Vector2, radius: float, damage: int, duration_amp: float, heavy_knockback: bool) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", sync_slow_duration * duration_amp, sync_slow_value)
		_apply_status(enemy, "marked", 1.0, 0.1)
		var dir: Vector2 = (enemy.global_position - center).normalized()
		var force: float = 540.0 if heavy_knockback else 360.0
		_apply_knockback(enemy, dir, force * duration_amp)
		hits += 1
	return hits

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", amount)

func _apply_status(enemy: Node2D, status_type: String, duration: float, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, duration, value)

func _apply_knockback(enemy: Node2D, direction: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", direction, force)

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i: int in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _on_sync_overload_timeout(totem_ref: WeakRef, damage_amp: float, duration_amp: float) -> void:
	var totem: Variant = totem_ref.get_ref() if totem_ref != null else null
	if totem == null or not is_instance_valid(totem):
		return
	if not (totem is Node2D):
		return
	_sync_detonate(totem.global_position, damage_amp * 0.88, duration_amp, "OVERLOAD")

func _on_totem_life_timeout(totem_ref: WeakRef, damage_amp: float, duration_amp: float) -> void:
	var totem: Variant = totem_ref.get_ref() if totem_ref != null else null
	if totem == null or not is_instance_valid(totem):
		return
	if not (totem is Node2D):
		return
	_explode_totem(totem, damage_amp, duration_amp)

func _detonate_q_mines() -> int:
	if not is_instance_valid(skill_owner):
		return 0
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if not is_instance_valid(skill_manager):
		return 0
	if not skill_manager.has_method("get_skill"):
		return 0
	var q_skill_var: Variant = skill_manager.call("get_skill", "q")
	if q_skill_var == null:
		return 0
	if not (q_skill_var is Node):
		return 0
	var q_skill: Node = q_skill_var
	if not q_skill.has_method("remote_detonate_all"):
		return 0
	var result: Variant = q_skill.call("remote_detonate_all")
	return max(0, int(result))
