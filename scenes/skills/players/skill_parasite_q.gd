extends SkillBase
class_name SkillParasiteQ

@export var sample_spacing: float = 10.0
@export var hit_radius: float = 40.0
@export var parasite_duration: float = 8.0
@export var seed_damage_ratio: float = 0.05
@export var preview_width: float = 10.0
@export var preview_color: Color = Color(0.88, 0.18, 0.22, 0.95)
@export var energy_cost_per_sample: float = 0.5

var path_points: Array[Vector2] = []
var is_drawing: bool = false
var _preview_line: Line2D = null
var _spent_energy: float = 0.0

func _ready() -> void:
	skill_id = "skill_parasite_q"
	set_skill_tags_from_value("q,active,drawing,parasite")

func charge(_delta: float) -> void:
	if is_on_cooldown or not is_instance_valid(skill_owner):
		return

	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	if not is_drawing:
		is_drawing = true
		path_points.clear()
		_spent_energy = 0.0
		path_points.append(mouse_pos)
		_ensure_preview_line()
		_refresh_preview_line()
		return

	_append_path_point(mouse_pos)
	_refresh_preview_line()

func release() -> void:
	if not is_drawing:
		return

	is_drawing = false
	_append_path_point(skill_owner.get_global_mouse_position())
	if path_points.size() < 2:
		_spent_energy = 0.0
		_clear_preview()
		path_points.clear()
		return

	var infected_count: int = _apply_seed_to_enemies()
	if is_instance_valid(skill_owner) and skill_owner.has_method("notify_space_draw_release"):
		skill_owner.notify_space_draw_release({
			"source": "space",
			"skill_id": skill_id,
			"is_closed": false,
			"points": path_points.duplicate(),
			"centroid": _calculate_path_center(),
			"approx_area": 0.0,
			"draw_cost": _spent_energy,
		})
	if infected_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "Infect x%d" % infected_count, Color(0.62, 1.45, 0.62))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "Miss", Color(1.0, 0.45, 0.45))
	start_cooldown()
	_clear_preview()
	path_points.clear()
	_spent_energy = 0.0

func cancel_drawing() -> void:
	if not is_drawing:
		return
	is_drawing = false
	_refund_spent_energy()
	_clear_preview()
	path_points.clear()
	_spent_energy = 0.0
	Global.spawn_floating_text(skill_owner.global_position, "Refund", Color(0.62, 0.95, 1.2))

func _append_path_point(target_point: Vector2) -> void:
	if path_points.is_empty():
		path_points.append(target_point)
		return

	var last_point: Vector2 = path_points[path_points.size() - 1]
	var distance: float = last_point.distance_to(target_point)
	if distance <= 0.001:
		return
	if distance < sample_spacing:
		path_points[path_points.size() - 1] = target_point
		return

	var direction: Vector2 = (target_point - last_point).normalized()
	var travelled: float = sample_spacing
	while travelled < distance:
		_maybe_emit_prism_stun(last_point, last_point + direction * travelled)
		if not _consume_path_energy():
			break
		path_points.append(last_point + direction * travelled)
		travelled += sample_spacing
	if path_points[path_points.size() - 1].distance_to(target_point) > 0.001:
		_maybe_emit_prism_stun(path_points[path_points.size() - 1], target_point)
		path_points.append(target_point)

func _apply_seed_to_enemies() -> int:
	var source_attack: float = float(skill_owner.get("damage")) if "damage" in skill_owner else 0.0
	var seed_damage: int = max(1, int(round(max(1.0, source_attack) * seed_damage_ratio)))
	var infected_count: int = 0

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy := enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if _distance_to_polyline(enemy.global_position) > hit_radius:
			continue
		if enemy.health_component:
			enemy.health_component.take_damage(seed_damage, {
				"source": skill_owner,
				"kind": "parasite_seed",
				"damage_type": "DMG_DOT",
			})
		enemy.apply_parasite_state(parasite_duration, source_attack)
		infected_count += 1

	return infected_count

func _distance_to_polyline(point: Vector2) -> float:
	var min_distance: float = INF
	for i in range(1, path_points.size()):
		var start: Vector2 = path_points[i - 1]
		var end_pos: Vector2 = path_points[i]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, start, end_pos)
		min_distance = min(min_distance, point.distance_to(closest))
	return min_distance

func _calculate_path_center() -> Vector2:
	if path_points.is_empty():
		return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point in path_points:
		center += point
	return center / float(path_points.size())

func _ensure_preview_line() -> void:
	if is_instance_valid(_preview_line):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_preview_line = Line2D.new()
	_preview_line.name = "ParasitePreviewLine"
	_preview_line.top_level = true
	_preview_line.z_index = 40
	_preview_line.width = preview_width
	_preview_line.default_color = preview_color
	_preview_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_preview_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	scene.add_child(_preview_line)

func _refresh_preview_line() -> void:
	if not is_instance_valid(_preview_line):
		return
	_preview_line.points = PackedVector2Array(path_points)

func _clear_preview() -> void:
	if not is_instance_valid(_preview_line):
		return
	_preview_line.queue_free()
	_preview_line = null

func _consume_path_energy() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if energy_cost_per_sample <= 0.0:
		return true
	if not skill_owner.has_method("consume_energy"):
		return false
	var paid: bool = skill_owner.consume_energy(energy_cost_per_sample)
	if paid:
		_spent_energy += energy_cost_per_sample
	return paid

func _refund_spent_energy() -> void:
	if _spent_energy <= 0.0 or not is_instance_valid(skill_owner):
		return
	if "energy" in skill_owner:
		skill_owner.energy = min(skill_owner.max_energy, skill_owner.energy + _spent_energy)
		if skill_owner.has_method("update_ui_signals"):
			skill_owner.update_ui_signals()

func _maybe_emit_prism_stun(start_point: Vector2, end_point: Vector2) -> void:
	if BondManager == null or not BondManager.has_method("on_draw_self_intersection"):
		return
	if path_points.size() < 3:
		return
	for i: int in range(path_points.size() - 2):
		var a_start: Vector2 = path_points[i]
		var a_end: Vector2 = path_points[i + 1]
		var intersection_variant: Variant = Geometry2D.segment_intersects_segment(a_start, a_end, start_point, end_point)
		if intersection_variant == null or not (intersection_variant is Vector2):
			continue
		BondManager.on_draw_self_intersection(skill_owner, intersection_variant)
		return
