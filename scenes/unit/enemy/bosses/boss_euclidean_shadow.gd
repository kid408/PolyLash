extends Enemy
class_name BossEuclideanShadow

const SPACE_CUT_INTERVAL: float = 4.2
const SPACE_CUT_WARNING: float = 0.55
const SPACE_CUT_LENGTH: float = 760.0
const SPACE_CUT_WIDTH: float = 34.0
const SPACE_CUT_PLAYER_DAMAGE_RATIO: float = 1.15
const SPACE_CUT_ENEMY_DAMAGE_RATIO: float = 0.70
const INVERSION_INTERVAL: float = 6.6
const INVERSION_MAX_ASSET_AGE_MSEC: int = 5000
const INVERSION_PULL_DISTANCE: float = 84.0
const INVERSION_PLAYER_DAMAGE_RATIO: float = 0.95

var _space_cut_timer: float = 1.6
var _inversion_timer: float = 3.4
var _space_cut_pending: bool = false

func on_boss_phase_changed(phase_no: int, is_initial: bool, event_tag: String) -> void:
	_refresh_phase_visuals(phase_no)
	if is_initial:
		return
	_space_cut_timer = min(_space_cut_timer, 0.35)
	_inversion_timer = min(_inversion_timer, 0.8)
	_spawn_phase_shift_visual(_get_phase_color(phase_no, 0.22))
	Global.spawn_floating_text(global_position + Vector2(0.0, -56.0), event_tag.to_upper(), _get_phase_color(phase_no, 1.0))

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	if _space_cut_pending:
		return
	_space_cut_timer = max(0.0, _space_cut_timer - delta)
	_inversion_timer = max(0.0, _inversion_timer - delta)
	if _space_cut_timer <= 0.0:
		_space_cut_timer = _get_space_cut_interval()
		_begin_space_cut()
	if _inversion_timer <= 0.0:
		_inversion_timer = _get_inversion_interval()
		_trigger_closure_inversion()

func _begin_space_cut() -> void:
	if not is_instance_valid(Global.player):
		return
	_space_cut_pending = true
	var cut_pairs: Array[PackedVector2Array] = _build_cut_pairs()
	for cut_pair: PackedVector2Array in cut_pairs:
		if cut_pair.size() < 2:
			continue
		_spawn_cut_warning_visual(cut_pair[0], cut_pair[1])
	var timer := get_tree().create_timer(SPACE_CUT_WARNING)
	timer.timeout.connect(func():
		if not is_instance_valid(self) or is_dead:
			return
		_space_cut_pending = false
		for cut_pair: PackedVector2Array in cut_pairs:
			if cut_pair.size() < 2:
				continue
			_resolve_space_cut(cut_pair[0], cut_pair[1])
	)

func _resolve_space_cut(from_pos: Vector2, to_pos: Vector2) -> void:
	_spawn_cut_impact_visual(from_pos, to_pos)
	var player_damage: float = max(1.0, damage * SPACE_CUT_PLAYER_DAMAGE_RATIO)
	var enemy_damage: float = max(1.0, damage * SPACE_CUT_ENEMY_DAMAGE_RATIO)
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null and _distance_to_segment(player.global_position, from_pos, to_pos) <= SPACE_CUT_WIDTH:
		player.take_damage(player_damage, {
			"source": self,
			"kind": "euclidean_space_cut",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
			"source_position": global_position,
		})
		player.apply_knockback_self((player.global_position - global_position).normalized() * 360.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if _distance_to_segment(enemy.global_position, from_pos, to_pos) > SPACE_CUT_WIDTH:
			continue
		enemy.apply_modifier_damage(enemy_damage, self, {
			"kind": "euclidean_space_cut",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
			"source_position": global_position,
		})

func _trigger_closure_inversion() -> void:
	var recent_assets: Array[Dictionary] = SkillAssetRegistry.list_scene_assets(self, "", "", INVERSION_MAX_ASSET_AGE_MSEC)
	var remaining: int = _get_inversion_asset_count()
	for asset: Dictionary in recent_assets:
		var payload: Dictionary = asset.get("payload", {})
		if not bool(payload.get("is_closed", false)):
			continue
		var polygon_points: PackedVector2Array = _extract_polygon_points(payload)
		if polygon_points.size() < 3:
			continue
		var centroid_value: Vector2 = payload.get("centroid", _average_polygon_point(polygon_points))
		_spawn_inversion_visual(polygon_points, centroid_value)
		_apply_inversion_to_targets(polygon_points, centroid_value, _get_inversion_pull_distance(), _get_inversion_enemy_damage_ratio())
		Global.spawn_floating_text(centroid_value, "INVERT", Color(0.88, 0.68, 1.0))
		remaining -= 1
		if remaining <= 0:
			return

func _apply_inversion_to_targets(polygon_points: PackedVector2Array, centroid_value: Vector2, pull_distance: float, enemy_damage_ratio: float) -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null and Geometry2D.is_point_in_polygon(player.global_position, polygon_points):
		var player_dir: Vector2 = centroid_value - player.global_position
		if player_dir.length_squared() <= 0.0001:
			player_dir = Vector2.RIGHT
		player.global_position += player_dir.normalized() * min(pull_distance, player_dir.length())
		player.take_damage(max(1.0, damage * INVERSION_PLAYER_DAMAGE_RATIO), {
			"source": self,
			"kind": "euclidean_closure_inversion",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
			"source_position": centroid_value,
		})
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon_points):
			continue
		var enemy_dir: Vector2 = centroid_value - enemy.global_position
		if enemy_dir.length_squared() <= 0.0001:
			enemy_dir = Vector2.RIGHT.rotated(randf() * TAU)
		enemy.global_position += enemy_dir.normalized() * min(pull_distance, enemy_dir.length())
		enemy.apply_status("stun", 0.45 + 0.15 * float(max(0, boss_current_phase - 1)), 0.0, 1, 1.0)
		enemy.apply_modifier_damage(max(1.0, damage * enemy_damage_ratio), self, {
			"kind": "euclidean_closure_inversion",
			"damage_type": COMBAT_EVENT_TYPES.DamageType.AOE,
			"source_position": centroid_value,
		})

func _get_space_cut_interval() -> float:
	match boss_current_phase:
		2:
			return 3.3
		3:
			return 2.6
		_:
			return SPACE_CUT_INTERVAL

func _get_inversion_interval() -> float:
	match boss_current_phase:
		2:
			return 5.1
		3:
			return 4.2
		_:
			return INVERSION_INTERVAL

func _get_inversion_asset_count() -> int:
	return 2 if boss_current_phase >= 3 else 1

func _get_inversion_pull_distance() -> float:
	match boss_current_phase:
		2:
			return 112.0
		3:
			return 136.0
		_:
			return INVERSION_PULL_DISTANCE

func _get_inversion_enemy_damage_ratio() -> float:
	match boss_current_phase:
		2:
			return 0.88
		3:
			return 1.08
		_:
			return 0.72

func _build_cut_pairs() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return result
	var base_direction: Vector2 = global_position.direction_to(player.global_position)
	if base_direction.length_squared() <= 0.0001:
		base_direction = Vector2.RIGHT
	var directions: Array[Vector2] = [base_direction]
	if boss_current_phase >= 2:
		directions.append(base_direction.rotated(0.18))
	if boss_current_phase >= 3:
		directions.append(base_direction.rotated(-0.18))
	for direction_value: Vector2 in directions:
		var pair: PackedVector2Array = PackedVector2Array()
		pair.append(global_position - direction_value * 40.0)
		pair.append(global_position + direction_value * SPACE_CUT_LENGTH)
		result.append(pair)
	return result

func _refresh_phase_visuals(phase_no: int) -> void:
	if visuals == null or not is_instance_valid(visuals):
		return
	visuals.modulate = _get_phase_color(phase_no, 1.0)
	visuals.scale = Vector2.ONE * (1.02 + 0.05 * float(max(0, phase_no - 1)))

func _get_phase_color(phase_no: int, alpha_value: float) -> Color:
	match phase_no:
		2:
			return Color(0.88, 0.70, 1.0, alpha_value)
		3:
			return Color(1.0, 0.82, 1.0, alpha_value)
		_:
			return Color(0.74, 0.62, 1.0, alpha_value)

func _spawn_phase_shift_visual(fill_color: Color) -> void:
	var root := Node2D.new()
	root.top_level = true
	root.global_position = global_position
	root.z_index = 33
	get_tree().current_scene.add_child(root)
	var ring := Line2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0 + PI / 6.0
		points.append(Vector2.RIGHT.rotated(angle) * 120.0)
	ring.points = points
	ring.closed = true
	ring.width = 10.0
	ring.default_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.96)
	root.add_child(ring)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(1.36, 1.36), 0.28)
	tween.tween_property(ring, "modulate:a", 0.0, 0.26)
	tween.chain().tween_callback(root.queue_free)

func _extract_polygon_points(payload: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	var points_variant: Variant = payload.get("points", [])
	if points_variant is PackedVector2Array:
		return (points_variant as PackedVector2Array).duplicate()
	if points_variant is Array:
		for point_variant in points_variant:
			if point_variant is Vector2:
				result.append(point_variant)
	return result

func _average_polygon_point(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return global_position
	var accum: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		accum += point
	return accum / float(points.size())

func _distance_to_segment(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> float:
	var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(point, from_pos, to_pos)
	return point.distance_to(closest_point)

func _spawn_cut_warning_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	var root := Line2D.new()
	root.top_level = true
	root.width = 12.0
	root.default_color = Color(0.90, 0.58, 1.0, 0.18)
	root.z_index = 32
	root.add_point(from_pos)
	root.add_point(to_pos)
	get_tree().current_scene.add_child(root)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "width", 24.0, SPACE_CUT_WARNING)
	tween.tween_property(root, "default_color", Color(1.0, 0.72, 1.0, 0.72), SPACE_CUT_WARNING)
	tween.chain().tween_callback(root.queue_free)

func _spawn_cut_impact_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	var root := Line2D.new()
	root.top_level = true
	root.width = 24.0
	root.default_color = Color(1.0, 0.92, 1.0, 0.92)
	root.z_index = 34
	root.add_point(from_pos)
	root.add_point(to_pos)
	get_tree().current_scene.add_child(root)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "modulate:a", 0.0, 0.18)
	tween.tween_property(root, "width", 8.0, 0.18)
	tween.chain().tween_callback(root.queue_free)

func _spawn_inversion_visual(polygon_points: PackedVector2Array, centroid_value: Vector2) -> void:
	var root := Node2D.new()
	root.top_level = true
	root.global_position = centroid_value
	root.z_index = 32
	get_tree().current_scene.add_child(root)
	var local_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon_points:
		local_points.append(point - centroid_value)
	var fill := Polygon2D.new()
	fill.polygon = local_points
	fill.color = Color(0.64, 0.40, 1.0, 0.18)
	root.add_child(fill)
	var border := Line2D.new()
	border.points = local_points
	border.closed = true
	border.width = 8.0
	border.default_color = Color(0.90, 0.70, 1.0, 0.92)
	root.add_child(border)
	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(0.7, 0.7), 0.16)
	tween.tween_property(fill, "color:a", 0.0, 0.20)
	tween.tween_property(border, "modulate:a", 0.0, 0.20)
	tween.chain().tween_callback(root.queue_free)
