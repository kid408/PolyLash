extends SkillBase
class_name SkillTotem

# Sapper E: remote detonation command + decoy totem.
var totem_duration: float = 8.0
var totem_max_health: float = 200.0
var totem_taunt_radius: float = 600.0
var totem_explosion_radius: float = 120.0
var totem_explosion_damage: int = 150

var active_totem: Node2D = null

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

	var detonated_count: int = _trigger_remote_detonation()
	_spawn_or_refresh_totem()

	if detonated_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "REMOTE BOOM x%d" % detonated_count, Color(1.25, 0.72, 0.3))
		Global.on_camera_shake.emit(6.0 + float(detonated_count) * 0.35, 0.14)
	else:
		Global.spawn_floating_text(skill_owner.global_position, "DECOY DEPLOY", Color(0.7, 1.0, 0.7))

	start_cooldown()

func _trigger_remote_detonation() -> int:
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

	var detonated: Variant = q_skill.call("remote_detonate_all")
	return int(detonated)

func _spawn_or_refresh_totem() -> void:
	if is_instance_valid(active_totem):
		active_totem.queue_free()
		active_totem = null
	active_totem = _create_totem()
	active_totem.global_position = skill_owner.global_position
	get_tree().current_scene.add_child(active_totem)

func _create_totem() -> Node2D:
	var totem: Node2D = Node2D.new()
	totem.name = "SapperDecoyTotem"
	totem.add_to_group("player")
	totem.add_to_group("player_skill_effects")
	totem.set_meta("hp", totem_max_health)
	totem.set_meta("exploded", false)

	var marker: Polygon2D = Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -26),
		Vector2(22, 18),
		Vector2(-22, 18)
	])
	marker.color = Color(0.35, 0.92, 0.35, 0.95)
	totem.add_child(marker)

	var taunt_timer: Timer = Timer.new()
	taunt_timer.wait_time = 0.25
	taunt_timer.one_shot = false
	taunt_timer.autostart = true
	totem.add_child(taunt_timer)
	taunt_timer.timeout.connect(_on_taunt_tick.bind(weakref(totem)))

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.5, totem_duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	totem.add_child(life_timer)
	life_timer.timeout.connect(_on_totem_expired.bind(weakref(totem)))

	return totem

func _on_taunt_tick(totem_ref: WeakRef) -> void:
	var totem_obj: Variant = totem_ref.get_ref()
	if totem_obj == null or not is_instance_valid(totem_obj):
		return
	if not (totem_obj is Node2D):
		return
	var totem: Node2D = totem_obj
	if bool(totem.get_meta("exploded", false)):
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

func _on_totem_expired(totem_ref: WeakRef) -> void:
	var totem_obj: Variant = totem_ref.get_ref()
	if totem_obj == null or not is_instance_valid(totem_obj):
		return
	if not (totem_obj is Node2D):
		return
	_explode_totem(totem_obj)

func _explode_totem(totem: Node2D) -> void:
	if not is_instance_valid(totem):
		return
	if bool(totem.get_meta("exploded", false)):
		return
	totem.set_meta("exploded", true)

	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(totem.global_position) > totem_explosion_radius:
			continue
		if enemy.has_node("HealthComponent"):
			enemy.get_node("HealthComponent").take_damage(max(1, totem_explosion_damage))
		if enemy.has_method("apply_knockback"):
			var dir: Vector2 = (enemy.global_position - totem.global_position).normalized()
			enemy.call("apply_knockback", dir, 300.0)
		hit_count += 1

	spawn_skill_vfx(totem.global_position, Color(1.0, 0.55, 0.22, 0.85), 0.7)
	if hit_count > 0:
		Global.spawn_floating_text(totem.global_position, "TOTEM BOOM x%d" % hit_count, Color(1.2, 0.7, 0.3))
		Global.on_camera_shake.emit(4.0 + float(hit_count) * 0.3, 0.1)

	if is_instance_valid(totem):
		totem.queue_free()
	if totem == active_totem:
		active_totem = null

func cleanup() -> void:
	if is_instance_valid(active_totem):
		active_totem.queue_free()
	active_totem = null
