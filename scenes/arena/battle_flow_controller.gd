extends RefCounted
class_name BattleFlowController

# ============================================================================
# BattleFlowController - Arena 仅编排的流程控制器
# ============================================================================

var _spawner: Node = null
var _shop_flow_service: ShopFlowService = null
var _reward_flow_service: RewardFlowService = null
var _run_save_service: RunSaveService = null

func setup(spawner: Node, shop_panel: Node, wave_reward_system: Node, wave_reward_panel: Node) -> void:
	_spawner = spawner

	_run_save_service = RunSaveService.new()

	_shop_flow_service = ShopFlowService.new()
	_shop_flow_service.setup(shop_panel, spawner)

	_reward_flow_service = RewardFlowService.new()
	_reward_flow_service.setup(wave_reward_system, wave_reward_panel, _shop_flow_service)

func on_wave_completed(wave_number: int) -> bool:
	SoundManager.play("wave_complete")
	if _spawner and _spawner.has_method("pause_spawning"):
		_spawner.pause_spawning()

	return _reward_flow_service.handle_wave_completed(wave_number)

func on_wave_reward_chosen(reward_data: Dictionary) -> bool:
	return _reward_flow_service.on_reward_chosen(reward_data)

func show_shop_for_wave(wave_number: int) -> bool:
	return _shop_flow_service.show_shop_for_wave(wave_number)

func on_shop_next_wave_requested(slot_index: int, wave_number: int) -> bool:
	SoundManager.play("shop_close")
	SoundManager.play("wave_start")
	return _shop_flow_service.handle_shop_next_wave(_run_save_service, slot_index, wave_number)

func auto_save_progress(slot_index: int, wave_number: int, trigger: String) -> bool:
	return _run_save_service.auto_save_progress(slot_index, wave_number, trigger)

func save_full_battle_state(slot_index: int, wave_number: int) -> bool:
	return _run_save_service.save_full_battle_state(slot_index, wave_number, "return_to_menu")

func clear_battle_state(slot_index: int) -> bool:
	return _run_save_service.clear_battle_state(slot_index)

func save_progress_before_exit(slot_index: int, wave_number: int) -> bool:
	return _run_save_service.auto_save_progress(slot_index, wave_number, "exit_to_menu")

func sync_selection_cache() -> void:
	_run_save_service.sync_selection_cache()

func clear_selection_cache_files() -> void:
	_run_save_service.clear_selection_cache_files()
