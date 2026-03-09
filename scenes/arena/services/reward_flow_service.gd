extends RefCounted
class_name RewardFlowService

# ============================================================================
# RewardFlowService - 负责波次奖励流程
# ============================================================================

var _wave_reward_system: Node = null
var _wave_reward_panel: Node = null
var _shop_flow_service: ShopFlowService = null
var _pending_shop_wave: int = -1

func setup(wave_reward_system: Node, wave_reward_panel: Node, shop_flow_service: ShopFlowService) -> void:
	_wave_reward_system = wave_reward_system
	_wave_reward_panel = wave_reward_panel
	_shop_flow_service = shop_flow_service

func handle_wave_completed(wave_number: int) -> bool:
	if _wave_reward_system and _wave_reward_system.has_method("check_wave_reward"):
		if _wave_reward_system.check_wave_reward(wave_number):
			_pending_shop_wave = wave_number
			var options = _wave_reward_system.generate_reward_options()
			if options is Array and options.is_empty():
				push_warning("[RewardFlowService] 奖励选项为空，回退到商店流程")
				return _shop_flow_service.show_shop_for_wave(wave_number)
			if _wave_reward_panel and _wave_reward_panel.has_method("show_rewards"):
				_wave_reward_panel.show_rewards(options)
				return true
			push_warning("[RewardFlowService] 奖励面板不可用，回退到商店流程")
			return _shop_flow_service.show_shop_for_wave(wave_number)

	return _shop_flow_service.show_shop_for_wave(wave_number)

func on_reward_chosen(_reward_data: Dictionary) -> bool:
	if _pending_shop_wave < 0:
		return false

	var wave_number := _pending_shop_wave
	_pending_shop_wave = -1
	return _shop_flow_service.show_shop_for_wave(wave_number)
