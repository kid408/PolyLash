extends Enemy
class_name EnemyTemporalAnchor

const ANCHOR_SCENE := preload("res://scenes/unit/enemy/elites/enemy_temporal_anchor_node.tscn")
const ANCHOR_COOLDOWN: float = 10.0
const ANCHOR_DURATION: float = 4.0
const RECALL_STUN_DURATION: float = 0.5

var _anchor_cooldown_remaining: float = 4.0
var _anchor_duration_remaining: float = 0.0
var _active_anchor: EnemyTemporalAnchorNode = null

func _ready() -> void:
	super._ready()
	_anchor_cooldown_remaining = randf_range(2.5, 4.5)

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_process_anchor_cycle(delta)

func destroy_enemy() -> void:
	_clear_anchor(true)
	super.destroy_enemy()

func _exit_tree() -> void:
	_clear_anchor(true)

func _process_anchor_cycle(delta: float) -> void:
	if _active_anchor != null and is_instance_valid(_active_anchor):
		_anchor_duration_remaining = max(0.0, _anchor_duration_remaining - delta)
		_active_anchor.set_remaining_time(_anchor_duration_remaining)
		if _anchor_duration_remaining <= 0.0:
			_trigger_recall()
		return
	_anchor_cooldown_remaining = max(0.0, _anchor_cooldown_remaining - delta)
	if _anchor_cooldown_remaining > 0.0:
		return
	_spawn_anchor()

func _spawn_anchor() -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player == null or ANCHOR_SCENE == null:
		_anchor_cooldown_remaining = 1.0
		return
	var anchor_node: EnemyTemporalAnchorNode = ANCHOR_SCENE.instantiate() as EnemyTemporalAnchorNode
	if anchor_node == null:
		_anchor_cooldown_remaining = 1.0
		return
	anchor_node.global_position = player.global_position
	anchor_node.anchor_destroyed.connect(_on_anchor_destroyed)
	anchor_node.set_remaining_time(ANCHOR_DURATION)
	get_tree().current_scene.add_child(anchor_node)
	_active_anchor = anchor_node
	_anchor_duration_remaining = ANCHOR_DURATION
	_anchor_cooldown_remaining = ANCHOR_COOLDOWN
	Global.spawn_floating_text(anchor_node.global_position, "ANCHOR", Color(0.82, 0.94, 1.0))

func _trigger_recall() -> void:
	var player: PlayerBase = Global.player if is_instance_valid(Global.player) else null
	if player != null and _active_anchor != null and is_instance_valid(_active_anchor):
		player.global_position = _active_anchor.global_position
		player.apply_control_lock(RECALL_STUN_DURATION, "RECALL")
		Global.spawn_floating_text(player.global_position, "REWIND", Color(0.82, 0.96, 1.0))
	_clear_anchor(true)

func _on_anchor_destroyed(_anchor: EnemyTemporalAnchorNode) -> void:
	_active_anchor = null
	_anchor_duration_remaining = 0.0

func _clear_anchor(queue_free_anchor: bool) -> void:
	if _active_anchor != null and is_instance_valid(_active_anchor) and queue_free_anchor:
		_active_anchor.destroy_enemy()
	_active_anchor = null
	_anchor_duration_remaining = 0.0
