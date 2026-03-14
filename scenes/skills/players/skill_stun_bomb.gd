extends SkillBase
class_name SkillStunBomb

# Weaver E: recall command first, stun fallback if no web is active.
var forced_recall_bonus_mult: float = 1.25
var forced_recall_pull: float = 480.0
var fallback_stun_radius: float = 220.0
var fallback_stun_duration: float = 0.8
var fallback_stun_color: Color = Color(0.2, 0.8, 1.0, 0.5)

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return

	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var recalled: bool = _try_trigger_forced_recall()
	if recalled:
		Global.on_camera_shake.emit(6.0, 0.12)
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "RECALL!", Color(1.15, 0.45, 0.25))
	else:
		_perform_fallback_stun()

	start_cooldown()

func _try_trigger_forced_recall() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if not is_instance_valid(skill_manager):
		return false
	if not skill_manager.has_method("get_skill"):
		return false

	var q_skill_var: Variant = skill_manager.call("get_skill", "q")
	if q_skill_var == null:
		return false
	if not (q_skill_var is Node):
		return false
	var q_skill: Node = q_skill_var
	if not q_skill.has_method("trigger_forced_recall"):
		return false

	var result: Variant = q_skill.call("trigger_forced_recall", forced_recall_bonus_mult, forced_recall_pull)
	return bool(result)

func _perform_fallback_stun() -> void:
	if not is_instance_valid(skill_owner):
		return

	Global.on_camera_shake.emit(7.0, 0.18)
	_create_stun_visual(skill_owner.global_position, fallback_stun_radius)

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if skill_owner.global_position.distance_to(enemy.global_position) > fallback_stun_radius:
			continue
		_apply_stun_effect(enemy)
		hit_count += 1

	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "STUN x%d" % hit_count, Color(0.8, 1.0, 1.2))

func _apply_stun_effect(enemy: Node2D) -> void:
	var enemy_ref: WeakRef = weakref(enemy)
	if "can_move" in enemy:
		enemy.set("can_move", false)
	enemy.modulate = Color(0.35, 0.45, 1.0)

	get_tree().create_timer(fallback_stun_duration).timeout.connect(func():
		var enemy_obj: Variant = enemy_ref.get_ref()
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			return
		if not (enemy_obj is Node2D):
			return
		var live_enemy: Node2D = enemy_obj
		if "can_move" in live_enemy:
			live_enemy.set("can_move", true)
		live_enemy.modulate = Color.WHITE
	)

func _create_stun_visual(center: Vector2, radius: float) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return

	var poly: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(32):
		var angle: float = float(i) * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	poly.polygon = points
	poly.color = fallback_stun_color
	poly.z_index = 80
	poly.global_position = center
	scene_tree.current_scene.add_child(poly)

	var tween: Tween = poly.create_tween()
	tween.tween_property(poly, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(poly, "color:a", 0.0, 0.35)
	tween.tween_callback(poly.queue_free)
