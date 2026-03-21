extends Node2D
class_name QEFLootPack

const PICKUP_DISTANCE: float = 48.0
const APPEAR_SEC: float = 0.14
const TRAIL_SEC: float = 0.16
const PICKUP_LINGER_SEC: float = 0.05
const PICKUP_EXIT_SEC: float = 0.08
const SHATTER_EXIT_SEC: float = 0.08
const EXPIRE_EXIT_SEC: float = 0.12

var pack_payload: Dictionary = {}
var reward_hint: Dictionary = {}
var lifetime_sec: float = 6.0
var bob_seed: float = 0.0
var _born_msec: int = 0
var _exit_state: String = ""
var _pending_collector: Node = null
var _spawn_tween: Tween = null
var _exit_tween: Tween = null

func setup(payload: Dictionary, hint: Dictionary, duration_sec: float) -> void:
	pack_payload = payload.duplicate(true)
	reward_hint = hint.duplicate(true)
	lifetime_sec = max(0.8, duration_sec)

	var world_pos_var: Variant = payload.get("world_pos", Vector2.ZERO)
	if world_pos_var is Vector2:
		global_position = world_pos_var
	else:
		global_position = Vector2.ZERO

	_born_msec = Time.get_ticks_msec()
	bob_seed = randf() * TAU
	name = "QEFLootPack_%s" % str(pack_payload.get("pack_id", "pack"))

func _ready() -> void:
	z_index = 59
	add_to_group("qef_loot_packs")
	_build_visual()
	modulate.a = 0.0
	scale = Vector2(0.82, 0.82)
	_play_spawn_transition()

func _process(delta: float) -> void:
	if not _exit_state.is_empty():
		return

	if Time.get_ticks_msec() - _born_msec >= int(round(lifetime_sec * 1000.0)):
		request_expire()
		return

	_update_visual_motion(delta)

	var player := Global.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > PICKUP_DISTANCE:
		return
	request_collect(player)

func request_collect(collector: Node) -> void:
	if not _exit_state.is_empty():
		return
	_pending_collector = collector
	_start_exit_transition("collect" if _is_owner_collector(collector) else "shatter")

func request_expire() -> void:
	if not _exit_state.is_empty():
		return
	_start_exit_transition("expire")

func _build_visual() -> void:
	if has_node("Root"):
		get_node("Root").queue_free()

	var root := Node2D.new()
	root.name = "Root"
	add_child(root)

	var trail := Line2D.new()
	trail.name = "SourceTrail"
	trail.width = 4.0
	var trail_color: Color = _resolve_owner_color().lerp(Color.WHITE, 0.18)
	trail_color.a = 0.0
	trail.default_color = trail_color
	trail.points = PackedVector2Array([
		_resolve_source_local_offset(),
		Vector2.ZERO,
	])
	root.add_child(trail)

	var owner_frame := Line2D.new()
	owner_frame.name = "OwnerFrame"
	owner_frame.closed = true
	owner_frame.width = 2.4
	owner_frame.default_color = _resolve_owner_color()
	owner_frame.points = PackedVector2Array([
		Vector2(0.0, -15.0),
		Vector2(15.0, 0.0),
		Vector2(0.0, 15.0),
		Vector2(-15.0, 0.0),
	])
	root.add_child(owner_frame)

	var base_icon := Polygon2D.new()
	base_icon.name = "BaseIcon"
	base_icon.polygon = PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 9.0),
		Vector2(-9.0, 0.0),
	])
	base_icon.color = _resolve_fill_color()
	root.add_child(base_icon)

	var inner_cut := Polygon2D.new()
	inner_cut.name = "InnerCut"
	inner_cut.polygon = PackedVector2Array([
		Vector2(0.0, -4.0),
		Vector2(4.0, 0.0),
		Vector2(0.0, 4.0),
		Vector2(-4.0, 0.0),
	])
	inner_cut.color = Color(0.94, 0.96, 1.0, 0.72)
	root.add_child(inner_cut)

	var rare_ring := Line2D.new()
	rare_ring.name = "RareRing"
	rare_ring.closed = true
	rare_ring.width = 2.0
	rare_ring.default_color = Color(1.0, 0.86, 0.38, 0.0)
	rare_ring.points = _build_circle_points(18.0, 18)
	rare_ring.visible = _is_rare_pack()
	root.add_child(rare_ring)

func _play_spawn_transition() -> void:
	_spawn_tween = create_tween()
	_spawn_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_spawn_tween.tween_property(self, "modulate:a", 1.0, APPEAR_SEC)
	_spawn_tween.parallel().tween_property(self, "scale", Vector2.ONE, APPEAR_SEC)

	var trail: Line2D = get_node_or_null("Root/SourceTrail") as Line2D
	if trail != null:
		var trail_color: Color = trail.default_color
		trail_color.a = 0.95
		trail.default_color = trail_color
		_spawn_tween.parallel().tween_method(_set_trail_alpha.bind(trail), 0.95, 0.0, TRAIL_SEC)

func _update_visual_motion(delta: float) -> void:
	var root: Node2D = get_node_or_null("Root") as Node2D
	if root != null:
		root.position.y = sin((Time.get_ticks_msec() / 180.0) + bob_seed) * 5.0
		root.rotation = sin((Time.get_ticks_msec() / 420.0) + bob_seed) * 0.05

	var rare_ring: Line2D = get_node_or_null("Root/RareRing") as Line2D
	if rare_ring != null and rare_ring.visible:
		var pulse: float = 0.5 + 0.5 * sin((Time.get_ticks_msec() / 120.0) + bob_seed)
		var ring_color: Color = Color(1.0, 0.86, 0.38, 0.35 + pulse * 0.45)
		rare_ring.default_color = ring_color
		rare_ring.width = 2.0 + pulse * 0.7

	var _unused_delta: float = delta

func _set_trail_alpha(alpha: float, trail: Line2D) -> void:
	if trail == null or not is_instance_valid(trail):
		return
	var color: Color = trail.default_color
	color.a = alpha
	trail.default_color = color

func _start_exit_transition(mode: String) -> void:
	_exit_state = mode
	if _spawn_tween != null:
		_spawn_tween.kill()
	if _exit_tween != null:
		_exit_tween.kill()

	_exit_tween = create_tween()
	_exit_tween.set_trans(Tween.TRANS_SINE)
	_exit_tween.set_ease(Tween.EASE_IN)

	match mode:
		"collect":
			var collector_node := _pending_collector as Node2D
			var target_pos: Vector2 = collector_node.global_position if collector_node != null and is_instance_valid(collector_node) else global_position
			_exit_tween.tween_property(self, "scale", Vector2(1.06, 1.06), PICKUP_LINGER_SEC)
			_exit_tween.parallel().tween_property(self, "modulate:a", 0.96, PICKUP_LINGER_SEC)
			_exit_tween.tween_property(self, "global_position", target_pos, PICKUP_EXIT_SEC)
			_exit_tween.parallel().tween_property(self, "scale", Vector2(0.54, 0.54), PICKUP_EXIT_SEC)
			_exit_tween.parallel().tween_property(self, "modulate:a", 0.0, PICKUP_EXIT_SEC)
		"shatter":
			var root: Node2D = get_node_or_null("Root") as Node2D
			if root != null:
				_exit_tween.tween_property(root, "scale", Vector2(1.08, 1.08), SHATTER_EXIT_SEC * 0.5)
				_exit_tween.parallel().tween_property(root, "rotation", 0.22, SHATTER_EXIT_SEC)
				_exit_tween.parallel().tween_property(root, "modulate", Color(0.7, 0.72, 0.78, 0.1), SHATTER_EXIT_SEC)
			_exit_tween.parallel().tween_property(self, "modulate:a", 0.0, SHATTER_EXIT_SEC)
		_:
			_exit_tween.tween_property(self, "scale", Vector2(0.74, 0.74), EXPIRE_EXIT_SEC)
			_exit_tween.parallel().tween_property(self, "modulate:a", 0.0, EXPIRE_EXIT_SEC)

	_exit_tween.finished.connect(_finalize_exit, CONNECT_ONE_SHOT)

func _finalize_exit() -> void:
	var service := load("res://scripts/qef/services/loot_pack_service.gd")
	if service == null:
		queue_free()
		return

	if _exit_state == "collect" or _exit_state == "shatter":
		var collector: Node = _pending_collector
		if collector == null or not is_instance_valid(collector):
			collector = Global.player
		service.collect_pack(self, collector)
		return

	service.expire_pack(self)

func _resolve_fill_color() -> Color:
	var owner_color: Color = _resolve_owner_color()
	return Color(owner_color.r * 0.84 + 0.12, owner_color.g * 0.84 + 0.12, owner_color.b * 0.84 + 0.12, 0.92)

func _resolve_owner_color() -> Color:
	var vfx_color_var: Variant = reward_hint.get("vfx_color", null)
	if vfx_color_var is Color:
		return vfx_color_var as Color
	return Color(1.0, 0.82, 0.42, 0.96)

func _resolve_source_local_offset() -> Vector2:
	var source_var: Variant = pack_payload.get("source_world_pos", reward_hint.get("source_world_pos", Vector2.ZERO))
	if source_var is Vector2:
		var offset: Vector2 = source_var - global_position
		if offset.length_squared() > 36.0:
			return offset.limit_length(72.0)
	return Vector2(-28.0, -18.0)

func _is_owner_collector(collector: Node) -> bool:
	if collector == null or not is_instance_valid(collector) or not ("player_id" in collector):
		return false
	return str(collector.get("player_id")).strip_edges() == str(pack_payload.get("owner_player_id", "")).strip_edges()

func _is_rare_pack() -> bool:
	var rarity: String = str(pack_payload.get("rarity", reward_hint.get("rarity", ""))).strip_edges().to_lower()
	return rarity in ["rare", "epic", "legendary", "mythic"]

func _build_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments: int = max(8, segments)
	for i in range(safe_segments):
		var angle: float = TAU * float(i) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
