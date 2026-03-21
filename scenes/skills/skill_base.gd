extends Node
class_name SkillBase

const QEFRuntimeService = preload("res://scripts/qef/core/qef_runtime_service.gd")
const RoleSpecRegistry = preload("res://scripts/qef/roles/role_spec_registry.gd")

## ==============================================================================
## 技能基类 - 所有技能的抽象基类
## ==============================================================================
## 
## 功能说明:
## - 提供技能的通用接口和功能
## - 管理技能状态（就绪/冷却/执行中）
## - 处理能量消耗和冷却时间
## - 子类必须实现execute(), charge(), release()方法
## 
## 使用方法:
##   1. 继承SkillBase
##   2. 实现execute(), charge(), release()方法
##   3. 在owner中调用技能方法
## 
## ==============================================================================

# ==============================================================================
# 技能所有者和配置
# ==============================================================================

## 技能所有者（玩家或敌人）
var skill_owner: Node2D

## 技能唯一标识符
var skill_id: String = ""

## 能量消耗
var energy_cost: float = 0.0

## 冷却时间（秒）
var cooldown_time: float = 0.0

## 技能标签（用于羁绊/构筑联动）
var skill_tags: Array[String] = []

# ==============================================================================
# 运行时状态
# ==============================================================================

## 是否处于冷却中
var is_on_cooldown: bool = false

## 冷却计时器
var cooldown_timer: float = 0.0

## 是否正在蓄力
var is_charging: bool = false

## 是否正在执行
var is_executing: bool = false

# ==============================================================================
# 虚函数接口（子类必须实现）
# ==============================================================================

## 执行技能（瞬发技能）
## 用于E键、左键等瞬发技能
func execute() -> void:
	push_warning("[SkillBase] execute() 未实现: %s" % skill_id)

## 蓄力技能（持续按住）
## 用于Q键等需要蓄力的技能
## @param delta: 帧时间增量
func charge(delta: float) -> void:
	pass  # 默认实现为空，子类可选择性实现

## 释放技能（松开按键）
## 用于Q键等需要释放的技能
func release() -> void:
	pass  # 默认实现为空，子类可选择性实现

# ==============================================================================
# 通用功能
# ==============================================================================

## 检查技能是否可以执行
## @return: 如果可以执行返回true，否则返回false
func can_execute() -> bool:
	# 检查冷却状态
	if is_on_cooldown:
		return false
	
	# 检查能量
	if skill_owner and skill_owner.has_method("consume_energy"):
		return skill_owner.energy >= energy_cost
	
	return true

## 消耗能量
## @return: 如果成功消耗返回true，否则返回false
func consume_energy() -> bool:
	if skill_owner and skill_owner.has_method("consume_energy"):
		var final_cost: float = energy_cost
		if _is_e_skill() and QEFRuntimeService.try_consume_free_cost_target(skill_owner, "e"):
			final_cost = 0.0
		if _is_e_skill():
			var profile: Dictionary = get_f_runtime_profile()
			if not profile.is_empty():
				final_cost *= (1.0 - _get_f_e_energy_discount(profile))
		return skill_owner.consume_energy(max(0.0, final_cost))
	return true

## 开始冷却
func start_cooldown() -> void:
	if cooldown_time > 0:
		if _is_e_skill() and _is_global_e_no_cooldown_enabled():
			reset_cooldown()
			return
		is_on_cooldown = true
		var cd: float = cooldown_time
		if _is_e_skill():
			var profile: Dictionary = get_f_runtime_profile()
			if not profile.is_empty():
				cd *= _get_f_e_cooldown_scale(profile)
		# 应用冷却缩减 buff
		if skill_owner and is_instance_valid(skill_owner) and skill_owner.has_meta("buff_cooldown_reduction"):
			cd *= (1.0 - skill_owner.get_meta("buff_cooldown_reduction"))
		cooldown_timer = cd

## 重置冷却
func reset_cooldown() -> void:
	is_on_cooldown = false
	cooldown_timer = 0.0

## 获取冷却剩余时间
## @return: 冷却剩余时间（秒）
func get_cooldown_remaining() -> float:
	return cooldown_timer if is_on_cooldown else 0.0

## 设置冷却剩余时间（用于存档恢复/切人冷却快照）
func set_cooldown_remaining(seconds: float) -> void:
	if seconds <= 0.0:
		reset_cooldown()
		return
	is_on_cooldown = true
	cooldown_timer = seconds

## 获取冷却进度（0-1）
## @return: 冷却进度，0表示冷却完成，1表示刚开始冷却
func get_cooldown_progress() -> float:
	if not is_on_cooldown or cooldown_time <= 0:
		return 0.0
	return cooldown_timer / cooldown_time

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	# 确保skill_owner已设置
	if not skill_owner:
		push_error("[SkillBase] 错误: skill_owner未设置 for skill %s" % skill_id)

func _process(delta: float) -> void:
	# 更新冷却计时器
	if is_on_cooldown:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			is_on_cooldown = false
			cooldown_timer = 0.0
			_on_cooldown_complete()

## 冷却完成回调（子类可重写）
func _on_cooldown_complete() -> void:
	pass

func get_f_runtime_profile() -> Dictionary:
	if not is_instance_valid(skill_owner):
		return {}
	if not skill_owner.has_meta("f_runtime_profile"):
		return {}
	var profile = skill_owner.get_meta("f_runtime_profile")
	if profile is Dictionary and bool(profile.get("active", false)):
		return profile
	return {}

func get_e_damage_amp(line_weight: float = 0.35, closure_weight: float = 0.35) -> float:
	var profile: Dictionary = get_f_runtime_profile()
	var slot_payload: Dictionary = _get_e_slot_payload()
	var slot_bonus: float = float(slot_payload.get("damage_amp_bonus", 0.0))
	if profile.is_empty():
		return 1.0 + slot_bonus
	var line_amp: float = max(1.0, float(profile.get("q_line_amp", 1.0)))
	var closure_amp: float = max(1.0, float(profile.get("q_closure_amp", 1.0)))
	return 1.0 + (line_amp - 1.0) * line_weight + (closure_amp - 1.0) * closure_weight + slot_bonus

func get_e_duration_amp(weight: float = 0.25) -> float:
	var profile: Dictionary = get_f_runtime_profile()
	var slot_payload: Dictionary = _get_e_slot_payload()
	var slot_bonus: float = float(slot_payload.get("duration_amp_bonus", 0.0))
	if profile.is_empty():
		return 1.0 + slot_bonus
	var closure_amp: float = max(1.0, float(profile.get("q_closure_amp", 1.0)))
	return 1.0 + (closure_amp - 1.0) * weight + slot_bonus

func is_f_window_active() -> bool:
	return not get_f_runtime_profile().is_empty()

func _is_e_skill() -> bool:
	if has_skill_tag("e"):
		return true
	return skill_id.ends_with("_e")

func _is_global_e_no_cooldown_enabled() -> bool:
	if Global == null:
		return false
	if not Global.has_meta("debug_e_no_cooldown"):
		return false
	return bool(Global.get_meta("debug_e_no_cooldown"))

func _get_f_e_energy_discount(profile: Dictionary) -> float:
	var role_energy_cfg: Dictionary = _get_role_f_energy_config()
	if role_energy_cfg.has("e_cost_discount"):
		return clamp(float(role_energy_cfg.get("e_cost_discount", 0.0)), 0.0, 0.5)
	var line_amp: float = max(1.0, float(profile.get("q_line_amp", 1.0)))
	var closure_amp: float = max(1.0, float(profile.get("q_closure_amp", 1.0)))
	var bonus: float = (line_amp + closure_amp - 2.0) * 0.14
	var slot_payload: Dictionary = _get_e_slot_payload()
	bonus += float(slot_payload.get("energy_discount_bonus", 0.0))
	return clamp(bonus, 0.0, 0.35)

func _get_f_e_cooldown_scale(profile: Dictionary) -> float:
	var line_amp: float = max(1.0, float(profile.get("q_line_amp", 1.0)))
	var closure_amp: float = max(1.0, float(profile.get("q_closure_amp", 1.0)))
	var reduction: float = (line_amp + closure_amp - 2.0) * 0.18
	var slot_payload: Dictionary = _get_e_slot_payload()
	reduction += float(slot_payload.get("cooldown_reduction_bonus", 0.0))
	return clamp(1.0 - reduction, 0.62, 1.0)

func _get_e_slot_payload() -> Dictionary:
	if not is_instance_valid(skill_owner):
		return {}
	return QEFRuntimeService.get_e_bonus(skill_owner)

func get_role_spec() -> Dictionary:
	var role_id: String = _resolve_runtime_role_id()
	if role_id.is_empty():
		return {}
	return RoleSpecRegistry.get_role_spec(role_id)

func _get_role_f_energy_config() -> Dictionary:
	var spec: Dictionary = get_role_spec()
	if spec.is_empty():
		return {}
	var f_energy: Variant = spec.get("f_energy", {})
	if f_energy is Dictionary:
		return f_energy
	return {}

func _resolve_runtime_role_id() -> String:
	if is_instance_valid(skill_owner) and "player_id" in skill_owner:
		return str(skill_owner.get("player_id")).strip_edges().to_lower()
	var base_id: String = skill_id.trim_prefix("skill_")
	if base_id.ends_with("_q") or base_id.ends_with("_e"):
		base_id = base_id.substr(0, base_id.length() - 2)
	return base_id.strip_edges().to_lower()

func set_skill_tags_from_value(raw_tags) -> void:
	skill_tags.clear()

	if raw_tags is Array:
		for tag in raw_tags:
			_append_skill_tag(str(tag))
		return

	var text := str(raw_tags).strip_edges()
	if text.is_empty():
		return

	var separators := [",", "|", ";"]
	for sep in separators:
		text = text.replace(sep, ",")

	for token in text.split(","):
		_append_skill_tag(token)

func has_skill_tag(tag: String) -> bool:
	var normalized := tag.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	return skill_tags.has(normalized)

func _append_skill_tag(raw_tag: String) -> void:
	var tag := raw_tag.strip_edges().to_lower()
	if tag.is_empty():
		return
	if not skill_tags.has(tag):
		skill_tags.append(tag)

## 当技能从场景树中移除时调用
## 注意：不清理已生成的技能效果，让它们按照自己的生命周期消失
func _exit_tree() -> void:
	# 不调用 cleanup()，让技能效果继续存在
	pass

## 在指定位置生成爆炸VFX（E技能通用视觉反馈）
func spawn_skill_vfx(pos: Vector2, color: Color = Color.WHITE, vfx_scale: float = 0.6) -> void:
	var explosion_scene = load("res://scenes/vfx/explosion_area.tscn")
	if not explosion_scene:
		return
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var vfx = explosion_scene.instantiate()
	vfx.global_position = pos
	vfx.scale = Vector2(vfx_scale, vfx_scale)
	vfx.modulate = color
	vfx.z_index = 100
	tree.current_scene.call_deferred("add_child", vfx)
	# 自动清理 - 使用 weakref 避免 lambda capture freed 错误
	var vfx_ref = weakref(vfx)
	tree.create_timer(1.0).timeout.connect(func():
		var v = vfx_ref.get_ref()
		if v and is_instance_valid(v):
			v.queue_free()
	)

# ==============================================================================
# 调试和日志
# ==============================================================================

## 打印技能信息
func print_info() -> void:
	print("[SkillBase] 技能信息:")
	print("  - skill_id: %s" % skill_id)
	print("  - energy_cost: %.1f" % energy_cost)
	print("  - cooldown_time: %.1f" % cooldown_time)
	print("  - is_on_cooldown: %s" % is_on_cooldown)
	print("  - is_charging: %s" % is_charging)
	print("  - is_executing: %s" % is_executing)
