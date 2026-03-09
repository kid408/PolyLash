extends RefCounted
class_name RunSaveService

# ============================================================================
# RunSaveService - 负责局内存档事务
# ============================================================================

func auto_save_progress(slot_index: int, wave_number: int, trigger: String) -> bool:
	if slot_index < 0:
		return false
	return SaveFacade.save_progress(slot_index, {
		"trigger": trigger,
		"current_wave": wave_number
	})

func save_full_battle_state(slot_index: int, wave_number: int, trigger: String = "return_to_menu") -> bool:
	if slot_index < 0:
		return false
	return SaveFacade.save_battle_snapshot(slot_index, {
		"trigger": trigger,
		"current_wave": wave_number
	})

func clear_battle_state(slot_index: int) -> bool:
	if slot_index < 0:
		return false
	return SaveFacade.clear_battle_state(slot_index)

func sync_selection_cache() -> void:
	SaveFacade.sync_selection_cache_from_runtime()

func clear_selection_cache_files() -> void:
	SaveFacade.clear_selection_cache_files()
