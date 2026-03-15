extends SkillQBase
class_name SkillExecutionerQ

var damage_amp_value: float = 0.45
var damage_amp_duration: float = 4.5
var guillotine_damage: int = 120
var guillotine_duration: float = 1.2
var line_bleed_damage: int = 16
var line_tick_interval: float = 0.45
var execute_fear_duration: float = 0.8
var return_slash_damage: int = 24
var return_slash_width: float = 38.0
var return_slash_delay: float = 0.32
var execute_threshold: float = 0.3
var execute_bonus_scale: float = 0.55
var blade_step_distance: float = 48.0
var blade_tick_interval: float = 0.05
var blade_hit_radius: float = 52.0
var blade_line_damage: int = 18
var blade_push: float = 18.0
var blade_recall_delay: float = 0.2
var blade_recall_count: int = 5
var blade_recall_damage: int = 22
var blade_recall_pull: float = 24.0
var judgement_reel_count: int = 5
var judgement_reel_interval: float = 0.16
var judgement_reel_damage: int = 24

const EXEC_META_CENTER: String = "executioner_zone_center"
const EXEC_META_RADIUS: String = "executioner_zone_radius"
const EXEC_META_EXPIRE_MSEC: String = "executioner_zone_expire_msec"

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": damage_amp_duration,
		"tick_interval": line_tick_interval,
		"damage": line_bleed_damage,
		"damage_interval": line_tick_interval,
		"color": Color(0.62, 0.08, 0.08, 0.56)
	})

	_launch_guillotine_blade(start, end)
	_spawn_return_slash(start, end)

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": guillotine_damage,
		"damage_interval": 0.3,
		"duration": guillotine_duration,
		"color": Color(0.7, 0.1, 0.1, 0.62)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": guillotine_duration,
		"debuff_type": "fear",
		"debuff_value": 1.0,
		"debuff_duration": execute_fear_duration,
		"tick_interval": 0.65,
		"color": Color(0.55, 0.08, 0.08, 0.28)
	})

	_spawn_judgement_reel(polygon)
	_execute_low_health_targets(polygon)
	_cache_execute_window(polygon, guillotine_duration)

func _launch_guillotine_blade(start: Vector2, finish: Vector2) -> void:
	var seg: Vector2 = finish - start
	var length: float = seg.length()
	if length <= 1.0:
		return
	var move_dir: Vector2 = seg / length
	var host: Node2D = Node2D.new()
	host.name = "ExecutionerBladeHost"
	add_child(host)

	var step_total: int = int(max(2.0, ceil(length / max(12.0, blade_step_distance))))
	var step_index: int = 0
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.03, blade_tick_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if step_index > step_total:
			timer.stop()
			host.queue_free()
			_spawn_blade_recall(finish, start, move_dir)
			return
		_emit_blade_tick(start, finish, step_index, step_total, move_dir)
		step_index += 1
	)
	timer.start()

func _spawn_blade_recall(from_pos: Vector2, to_pos: Vector2, move_dir: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(max(0.05, blade_recall_delay)).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		var host: Node2D = Node2D.new()
		host.name = "ExecutionerBladeRecallHost"
		add_child(host)
		var pulse_total: int = int(max(1, blade_recall_count))
		var pulse_index: int = 0
		var timer: Timer = Timer.new()
		timer.wait_time = max(0.06, blade_tick_interval * 1.6)
		timer.one_shot = false
		host.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if pulse_index >= pulse_total:
				timer.stop()
				host.queue_free()
				return
			_emit_blade_recall_tick(from_pos, to_pos, pulse_index, pulse_total, move_dir)
			pulse_index += 1
		)
		timer.start()
	)

func _emit_blade_tick(start: Vector2, finish: Vector2, index: int, total: int, move_dir: Vector2) -> void:
	var t: float = float(index) / float(max(1, total))
	var prev_t: float = float(max(0, index - 1)) / float(max(1, total))
	var current: Vector2 = start.lerp(finish, t)
	var previous: Vector2 = start.lerp(finish, prev_t)
	SkillEffectManager.create_line_effect({
		"start": previous,
		"end": current,
		"width": 14.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.12,
		"color": Color(0.94, 0.24, 0.24, 0.92)
	})
	_apply_radius_mark_damage(current, blade_hit_radius, blade_line_damage)
	_apply_direction_push(current, blade_hit_radius * 1.15, move_dir, blade_push)

func _emit_blade_recall_tick(
	from_pos: Vector2,
	to_pos: Vector2,
	index: int,
	total: int,
	move_dir: Vector2
) -> void:
	var t: float = 0.0
	if total > 1:
		t = float(index) / float(total - 1)
	var center: Vector2 = from_pos.lerp(to_pos, t)
	var tangent: Vector2 = Vector2(-move_dir.y, move_dir.x)
	if tangent.length_squared() <= 0.001:
		tangent = Vector2.UP
	var start: Vector2 = center - tangent * 72.0
	var end: Vector2 = center + tangent * 72.0
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 13.0,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.16,
		"color": Color(1.0, 0.4, 0.4, 0.95)
	})
	_apply_slash_pass(start, end, blade_recall_damage, true)
	_apply_pull_to_point(center, blade_hit_radius * 1.55, blade_recall_pull)

func _spawn_judgement_reel(polygon: PackedVector2Array) -> void:
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var sweep_total: int = int(max(1, judgement_reel_count))
	var sweep_index: int = 0
	var host: Node2D = Node2D.new()
	host.name = "ExecutionerJudgementReelHost"
	add_child(host)

	var timer: Timer = Timer.new()
	timer.wait_time = max(0.08, judgement_reel_interval)
	timer.one_shot = false
	host.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return
		if sweep_index >= sweep_total:
			timer.stop()
			host.queue_free()
			return
		_emit_judgement_reel(center, radius, sweep_index, sweep_total)
		sweep_index += 1
	)
	timer.start()

func _emit_judgement_reel(center: Vector2, radius: float, index: int, total: int) -> void:
	var angle: float = TAU * float(index) / float(max(1, total))
	var dir: Vector2 = Vector2.RIGHT.rotated(angle)
	var start: Vector2 = center + dir * radius * 1.38
	var end: Vector2 = center - dir * radius * 0.1
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": return_slash_width * 0.36,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": Color(1.0, 0.3, 0.3, 0.9)
	})
	_apply_slash_pass(start, end, judgement_reel_damage, true)
	_apply_pull_to_point(center, radius * 0.98, blade_recall_pull * 0.55)

func _spawn_return_slash(start: Vector2, end: Vector2) -> void:
	_apply_slash_pass(start, end, return_slash_damage, false)
	_spawn_slash_visual(start, end, false)

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(max(0.05, return_slash_delay))
	timer.timeout.connect(func() -> void:
		var back_damage: int = int(max(return_slash_damage + 6, line_bleed_damage + 10))
		_apply_slash_pass(end, start, back_damage, true)
		_spawn_slash_visual(end, start, true)
	)

func _apply_slash_pass(start: Vector2, end: Vector2, base_damage: int, is_return: bool) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > return_slash_width:
			continue
		var damage: int = base_damage
		if is_return:
			damage = max(damage, int(round(float(base_damage) * 1.2)))
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.4, damage_amp_value * 0.55, 1, 0.3)
		if is_return:
			_apply_status(enemy, "slow", 0.8, 0.32, 1, 0.1)
		hit_count += 1

	if hit_count > 0:
		var mid: Vector2 = start.lerp(end, 0.5)
		spawn_skill_vfx(mid, Color(0.92, 0.2, 0.2, 0.75), 0.34)

func _apply_radius_mark_damage(center: Vector2, radius: float, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.2, damage_amp_value * 0.6, 1, 0.3)

func _apply_direction_push(center: Vector2, radius: float, dir: Vector2, force: float) -> void:
	var safe_dir: Vector2 = dir.normalized()
	if safe_dir.length_squared() <= 0.0001:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		enemy.global_position += safe_dir * force

func _apply_pull_to_point(center: Vector2, radius: float, force: float) -> void:
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
		var pull_dir: Vector2 = (center - enemy.global_position).normalized()
		enemy.global_position += pull_dir * force

func _spawn_slash_visual(start: Vector2, end: Vector2, is_return: bool) -> void:
	var slash_width: float = 10.0
	var slash_color: Color = Color(0.82, 0.14, 0.14, 0.8)
	if is_return:
		slash_width = 14.0
		slash_color = Color(1.0, 0.22, 0.22, 0.92)
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": slash_width,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.2,
		"color": slash_color
	})

func _execute_low_health_targets(polygon: PackedVector2Array) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var executed: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		var hc: Node = enemy.get_node("HealthComponent")
		var current_hp: float = 0.0
		var max_hp: float = 0.0
		if "current_health" in hc:
			current_hp = float(hc.get("current_health"))
		if "max_health" in hc:
			max_hp = float(hc.get("max_health"))
		if max_hp <= 0.0 or current_hp <= 0.0:
			continue
		var hp_ratio: float = current_hp / max_hp
		if hp_ratio <= execute_threshold:
			var execute_damage: int = int(max(1, int(round(current_hp + max_hp * execute_bonus_scale))))
			_apply_damage(enemy, execute_damage)
			_apply_status(enemy, "fear", execute_fear_duration + 0.35, 1.0, 1, 0.2)
			executed += 1
		else:
			_apply_status(enemy, "marked", 1.2, 0.2, 1, 0.3)

	if executed > 0:
		var center: Vector2 = _calculate_polygon_center(polygon)
		Global.spawn_floating_text(center, "EXECUTE x%d" % executed, Color(1.0, 0.25, 0.25))
		spawn_skill_vfx(center, Color(0.95, 0.2, 0.2, 0.82), 0.5)

func _cache_execute_window(polygon: PackedVector2Array, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var center: Vector2 = _calculate_polygon_center(polygon)
	var radius: float = _polygon_radius(polygon, center)
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(EXEC_META_CENTER, center)
	skill_owner.set_meta(EXEC_META_RADIUS, radius)
	skill_owner.set_meta(EXEC_META_EXPIRE_MSEC, expire_msec)

func _polygon_radius(polygon: PackedVector2Array, center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in polygon:
		radius = max(radius, center.distance_to(point))
	return max(18.0, radius)

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _get_line_color() -> Color:
	return Color(0.62, 0.08, 0.08, 1.0)

func _get_closure_color() -> Color:
	return Color(0.5, 0.05, 0.05, 1.0)

