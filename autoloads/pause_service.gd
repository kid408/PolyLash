extends RefCounted
class_name PauseService

# ============================================================================
# 暂停服务（P0-ARC-02）
# 通过 source stack 统一管理暂停状态，避免多入口互相覆盖。
# ============================================================================

static var _pause_sources: Array[String] = []

static func request_pause(source: String, tree: SceneTree = null) -> void:
	if source.is_empty():
		return
	if not _pause_sources.has(source):
		_pause_sources.append(source)
	_apply_pause_state(tree)

static func release_pause(source: String, tree: SceneTree = null) -> void:
	if source.is_empty():
		return
	_pause_sources.erase(source)
	_apply_pause_state(tree)

static func clear_all(tree: SceneTree = null) -> void:
	_pause_sources.clear()
	_apply_pause_state(tree)

static func is_paused() -> bool:
	return not _pause_sources.is_empty()

static func get_pause_sources() -> Array[String]:
	return _pause_sources.duplicate()

static func _apply_pause_state(tree: SceneTree = null) -> void:
	var scene_tree: SceneTree = tree
	if scene_tree == null:
		scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		scene_tree.paused = is_paused()
	if Global:
		Global.game_paused = is_paused()
