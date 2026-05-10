extends Enemy
class_name EnemyResonanceGuardian

enum Stance {
	PHYSICAL_IMMUNE,
	SKILL_IMMUNE,
}

const STANCE_INTERVAL: float = 6.0

var _stance: int = Stance.PHYSICAL_IMMUNE
var _stance_timer: float = 3.0
var _feedback_cooldown: float = 0.0
var _base_modulate: Color = Color.WHITE

func _ready() -> void:
	super._ready()
	_base_modulate = visuals.modulate
	_refresh_stance_visual()

func _process(delta: float) -> void:
	if Global.game_paused or is_dead:
		return
	super._process(delta)
	_feedback_cooldown = max(0.0, _feedback_cooldown - delta)
	_stance_timer = max(0.0, _stance_timer - delta)
	if _stance_timer <= 0.0:
		_switch_stance()

func preprocess_incoming_damage(raw_damage: float, payload: Dictionary = {}) -> Dictionary:
	var result: Dictionary = super.preprocess_incoming_damage(raw_damage, payload)
	var damage_value: float = float(result.get("damage", raw_damage))
	var processed_payload: Dictionary = result.get("payload", payload.duplicate(true))
	var blocked: bool = false
	if _stance == Stance.PHYSICAL_IMMUNE:
		blocked = _is_open_line_damage_payload(processed_payload)
	else:
		blocked = _is_skill_slot_damage(processed_payload, "e") or _is_skill_slot_damage(processed_payload, "f")
	if not blocked:
		return {"damage": damage_value, "payload": processed_payload}
	if _feedback_cooldown <= 0.0:
		_feedback_cooldown = 0.18
		var text: String = "PHYSICAL NULL" if _stance == Stance.PHYSICAL_IMMUNE else "SKILL NULL"
		Global.spawn_floating_text(global_position + Vector2(0, -18), text, Color(0.76, 0.94, 1.0))
	return {"damage": 0.0, "payload": processed_payload}

func _switch_stance() -> void:
	_stance = Stance.SKILL_IMMUNE if _stance == Stance.PHYSICAL_IMMUNE else Stance.PHYSICAL_IMMUNE
	_stance_timer = STANCE_INTERVAL
	_refresh_stance_visual()
	Global.spawn_floating_text(global_position, "STANCE", Color(0.76, 0.92, 1.0))

func _refresh_stance_visual() -> void:
	if visuals == null or not is_instance_valid(visuals):
		return
	if _stance == Stance.PHYSICAL_IMMUNE:
		visuals.modulate = _base_modulate.lerp(Color(0.44, 0.82, 1.0, 1.0), 0.42)
	else:
		visuals.modulate = _base_modulate.lerp(Color(1.0, 0.60, 0.32, 1.0), 0.42)
