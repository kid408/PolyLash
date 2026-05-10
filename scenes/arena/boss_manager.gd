extends Node
class_name BossManager

signal boss_spawned(boss: Enemy, wave_number: int, peak_event: String)

const DEFAULT_BOSS_ID: String = "boss_enemy"
const DEFAULT_BOSS_SCENE_PATH: String = "res://scenes/unit/enemy/enemy_generic.tscn"
const BOSS_SCENE_OVERRIDES := {
	"abyssal_broodmother": "res://scenes/unit/enemy/bosses/boss_abyssal_broodmother.tscn",
	"euclidean_shadow": "res://scenes/unit/enemy/bosses/boss_euclidean_shadow.tscn",
	"fortress_titan": "res://scenes/unit/enemy/bosses/boss_fortress_titan.tscn",
}
const PEAK_EVENT_TO_TIER := {
	"mid_boss": 1,
	"late_boss": 2,
	"final_boss": 3,
}
const BOSS_PRESENTATION := {
	"boss_enemy": {"display_name": "Boss Prototype", "mechanic_hint": "阶段压制 / 区域威胁"},
	"abyssal_broodmother": {"display_name": "深渊巢母", "mechanic_hint": "群聚与吞噬"},
	"euclidean_shadow": {"display_name": "欧几里得阴影", "mechanic_hint": "空间切割与闭合反转"},
	"fortress_titan": {"display_name": "重装要塞", "mechanic_hint": "极限走位与突进压制"},
}

var _boss_pool_configs: Array[Dictionary] = []
var _spawned_boss_ids_by_wave: Dictionary = {}
var _active_boss_ref: WeakRef = null
var _active_peak_event: String = ""

func _ready() -> void:
	reload_configs()

func reload_configs() -> void:
	_boss_pool_configs = ConfigRepository.load_boss_pool_configs()

func reset_runtime() -> void:
	_spawned_boss_ids_by_wave.clear()
	_active_boss_ref = null
	_active_peak_event = ""

func maybe_spawn_boss_for_wave(current_wave: int, peak_event: String, anchor: Vector2 = Vector2.INF) -> Enemy:
	var normalized_event: String = peak_event.strip_edges().to_lower()
	if not PEAK_EVENT_TO_TIER.has(normalized_event):
		return null
	if _spawned_boss_ids_by_wave.has(current_wave):
		return null
	var boss_id: String = pick_boss_id_for_peak_event(current_wave, normalized_event)
	var boss: Enemy = force_spawn_boss(boss_id, current_wave, anchor)
	if boss != null and is_instance_valid(boss):
		_spawned_boss_ids_by_wave[current_wave] = boss.enemy_id
		_active_peak_event = normalized_event
		boss_spawned.emit(boss, current_wave, normalized_event)
	return boss

func pick_boss_id_for_peak_event(current_wave: int, peak_event: String) -> String:
	var normalized_event: String = peak_event.strip_edges().to_lower()
	var tier: int = int(PEAK_EVENT_TO_TIER.get(normalized_event, 0))
	if tier <= 0:
		return DEFAULT_BOSS_ID
	return _pick_boss_id_for_tier(current_wave, tier)

func get_debug_force_spawn_boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry_variant in _boss_pool_configs:
		if not (entry_variant is Dictionary):
			continue
		var boss_id: String = str((entry_variant as Dictionary).get("boss_id", "")).strip_edges()
		if boss_id.is_empty() or ids.has(boss_id):
			continue
		ids.append(boss_id)
	if ids.is_empty():
		ids.append(DEFAULT_BOSS_ID)
	return ids

func force_spawn_boss(boss_id: String = "", current_wave: int = -1, anchor: Vector2 = Vector2.INF) -> Enemy:
	var normalized_id: String = boss_id.strip_edges()
	if normalized_id.is_empty():
		normalized_id = DEFAULT_BOSS_ID
	if ConfigManager.get_enemy_config(normalized_id).is_empty():
		push_warning("[BossManager] Missing boss config for %s, fallback to %s" % [normalized_id, DEFAULT_BOSS_ID])
		normalized_id = DEFAULT_BOSS_ID

	var scene: PackedScene = load(_get_boss_scene_path_for_id(normalized_id)) as PackedScene
	if scene == null:
		push_error("[BossManager] Failed to load boss scene for %s" % normalized_id)
		if normalized_id != DEFAULT_BOSS_ID:
			return force_spawn_boss(DEFAULT_BOSS_ID, current_wave, anchor)
		return null

	var boss: Enemy = scene.instantiate() as Enemy
	if boss == null:
		push_error("[BossManager] Instanced boss is null for %s" % normalized_id)
		return null

	boss.enemy_id = normalized_id
	boss.global_position = _resolve_spawn_position(anchor)
	_apply_boss_config_stats(boss, normalized_id)
	_apply_wave_scaling(boss, current_wave)
	_apply_boss_presentation(boss, normalized_id)

	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	parent_node.add_child(boss)
	_active_boss_ref = weakref(boss)

	var spawner: Spawner = _get_spawner()
	if spawner != null:
		spawner.spawned_enemies.append(boss)

	return boss

func get_active_boss() -> Enemy:
	if _active_boss_ref != null:
		var cached: Variant = _active_boss_ref.get_ref()
		if cached is Enemy and is_instance_valid(cached):
			var cached_enemy: Enemy = cached as Enemy
			if not cached_enemy.is_dead:
				return cached_enemy
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node is Enemy:
			var enemy: Enemy = enemy_node as Enemy
			if is_instance_valid(enemy) and not enemy.is_dead and enemy.is_boss_enemy():
				_active_boss_ref = weakref(enemy)
				return enemy
	_active_boss_ref = null
	return null

func get_active_peak_event() -> String:
	return _active_peak_event

func get_boss_presentation(boss_id: String) -> Dictionary:
	var normalized_id: String = boss_id.strip_edges()
	if BOSS_PRESENTATION.has(normalized_id):
		return (BOSS_PRESENTATION[normalized_id] as Dictionary).duplicate(true)
	return {
		"display_name": normalized_id.capitalize(),
		"mechanic_hint": "未知机制",
	}

func _pick_boss_id_for_tier(current_wave: int, tier: int) -> String:
	var candidates: Array[Dictionary] = []
	var weights: Array[float] = []
	for entry_variant in _boss_pool_configs:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		if int(entry.get("tier", 0)) != tier:
			continue
		if int(entry.get("min_wave", 1)) > current_wave:
			continue
		candidates.append(entry)
		weights.append(max(0.01, float(entry.get("base_weight", 1.0))))

	if candidates.is_empty():
		push_warning("[BossManager] Empty boss pool for tier=%d wave=%d, fallback to %s" % [tier, current_wave, DEFAULT_BOSS_ID])
		return DEFAULT_BOSS_ID
	if candidates.size() == 1:
		return str(candidates[0].get("boss_id", DEFAULT_BOSS_ID))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pick_index: int = rng.rand_weighted(weights)
	if pick_index < 0 or pick_index >= candidates.size():
		return DEFAULT_BOSS_ID
	return str(candidates[pick_index].get("boss_id", DEFAULT_BOSS_ID))

func _resolve_spawn_position(anchor: Vector2) -> Vector2:
	var center: Vector2 = anchor
	if center == Vector2.INF or center == Vector2.ZERO:
		if is_instance_valid(Global.player):
			center = Global.player.global_position
		else:
			center = Vector2.ZERO
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(280.0, 380.0)
	return center + Vector2.RIGHT.rotated(angle) * radius

func _apply_boss_config_stats(boss: Enemy, boss_id: String) -> void:
	var config: Dictionary = ConfigManager.get_enemy_config(boss_id)
	if config.is_empty():
		return
	boss.health = float(config.get("health", boss.health))
	boss.speed = float(config.get("speed", boss.speed))
	boss.damage = float(config.get("damage", boss.damage))

func _apply_wave_scaling(boss: Enemy, current_wave: int) -> void:
	var spawner: Spawner = _get_spawner()
	if spawner == null or current_wave <= 0:
		return
	if spawner.enemy_speed_scale > 0.0:
		boss.speed *= spawner.enemy_speed_scale
	boss.health += max(0, current_wave - 1) * spawner.enemy_health_per_wave
	boss.damage += max(0, current_wave - 1) * spawner.enemy_damage_per_wave

func _apply_boss_presentation(boss: Enemy, boss_id: String) -> void:
	var presentation: Dictionary = get_boss_presentation(boss_id)
	boss.set_meta("boss_display_name", str(presentation.get("display_name", boss_id)))
	boss.set_meta("boss_mechanic_hint", str(presentation.get("mechanic_hint", "")))

func _get_boss_scene_path_for_id(boss_id: String) -> String:
	if BOSS_SCENE_OVERRIDES.has(boss_id):
		return str(BOSS_SCENE_OVERRIDES[boss_id])
	return DEFAULT_BOSS_SCENE_PATH

func _get_spawner() -> Spawner:
	var arena_node: Node = get_parent()
	if arena_node == null:
		return null
	var spawner_node: Node = arena_node.get_node_or_null("Spawner")
	if spawner_node is Spawner:
		return spawner_node as Spawner
	return null
