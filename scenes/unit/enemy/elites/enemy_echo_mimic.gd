extends Enemy
class_name EnemyEchoMimic

const SAMPLE_INTERVAL: float = 1.0
const MAX_SAMPLES: int = 3
const PATH_HALF_WIDTH: float = 24.0
const PATH_DAMAGE_ICD: float = 0.55
const PATH_DAMAGE_RATIO: float = 1.0

var _sample_timer: float = 0.35
var _path_damage_cooldown: float = 0.0
var _sampled_path: PackedVector2Array = PackedVector2Array()
var _path_line: Line2D = null
var _path_glow: Line2D = null

func _ready() -> void:
	super._ready()
	_setup_path_visuals()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_sample_timer -= delta
	_path_damage_cooldown = max(0.0, _path_damage_cooldown - delta)
	if _sample_timer <= 0.0:
		_sample_timer += SAMPLE_INTERVAL
		_capture_player_sample()
	_refresh_path_visuals()
	_check_player_path_collision()

func _setup_path_visuals() -> void:
	_path_glow = Line2D.new()
	_path_glow.width = 22.0
	_path_glow.default_color = Color(0.44, 0.18, 0.78, 0.12)
	_path_glow.antialiased = true
	_path_glow.top_level = true
	_path_glow.z_index = 7
	add_child(_path_glow)

	_path_line = Line2D.new()
	_path_line.width = 8.0
	_path_line.default_color = Color(0.62, 0.36, 0.96, 0.82)
	_path_line.antialiased = true
	_path_line.top_level = true
	_path_line.z_index = 8
	add_child(_path_line)

func _capture_player_sample() -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return
	_sampled_path.append(player.global_position)
	while _sampled_path.size() > MAX_SAMPLES:
		_sampled_path.remove_at(0)

func _refresh_path_visuals() -> void:
	if _path_line == null or _path_glow == null:
		return
	_path_line.visible = _sampled_path.size() >= 2
	_path_glow.visible = _sampled_path.size() >= 2
	if _sampled_path.size() < 2:
		return
	_path_line.points = _sampled_path
	_path_glow.points = _sampled_path
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.010)
	_path_line.modulate = Color(1.0, 1.0, 1.0, lerp(0.58, 0.92, pulse))
	_path_glow.width = lerp(18.0, 26.0, pulse)

func _check_player_path_collision() -> void:
	if _sampled_path.size() < 2 or _path_damage_cooldown > 0.0:
		return
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null:
		return
	if _distance_to_polyline(player.global_position, _sampled_path) > PATH_HALF_WIDTH:
		return
	_path_damage_cooldown = PATH_DAMAGE_ICD
	player.take_damage(max(1.0, damage * PATH_DAMAGE_RATIO), {
		"source": self,
		"kind": "echo_mimic_path",
		"damage_type": COMBAT_EVENT_TYPES.DamageType.DIRECT,
		"source_position": global_position,
	})
	Global.spawn_floating_text(player.global_position, "ECHO", Color(0.82, 0.52, 1.0))

func _distance_to_polyline(point: Vector2, points: PackedVector2Array) -> float:
	if points.size() < 2:
		return INF
	var best_distance: float = INF
	for i: int in range(points.size() - 1):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, points[i], points[i + 1])
		best_distance = min(best_distance, point.distance_to(closest))
	return best_distance
