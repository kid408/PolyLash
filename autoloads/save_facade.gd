extends RefCounted
class_name SaveFacade

# ============================================================================
# SaveFacade - 统一存档入口（save/load/migrate）
# ============================================================================

const SAVE_SCHEMA_VERSION := 1

static func create_new_slot_save(slot_index: int, leader_id: String, selected_players: Array) -> bool:
	"""统一新建槽位存档入口。"""
	var normalized_players := _normalize_selected_players(selected_players)
	return SaveManager.create_new_save(slot_index, leader_id, normalized_players)

static func save_progress(slot_index: int, context: Dictionary = {}) -> bool:
	"""统一进度存档入口。"""
	if slot_index < 0:
		return false

	if not _ensure_slot_initialized(slot_index):
		printerr("[SaveFacade] 槽位初始化失败，跳过保存: %d" % slot_index)
		return false

	Global.save_current_player_state()
	var payload := _build_progress_payload(slot_index, context)
	return SaveManager.save_game_progress(slot_index, payload)

static func save_battle_snapshot(slot_index: int, context: Dictionary = {}) -> bool:
	"""保存带 battle_state 的完整战斗快照。"""
	var options := context.duplicate(true)
	options["game_state"] = "in_battle"
	options["include_battle_state"] = true
	if not options.has("battle_state"):
		options["battle_state"] = BattleStateManager.save_battle_state()
	if not options.has("trigger"):
		options["trigger"] = "battle_snapshot"
	return save_progress(slot_index, options)

static func clear_battle_state(slot_index: int) -> bool:
	"""清理槽位中的 battle_state 并回到角色选择状态。"""
	if slot_index < 0:
		return false

	var slot_data := SaveManager.get_slot_data(slot_index).duplicate(true)
	if slot_data.is_empty():
		return false

	slot_data.erase("battle_state")
	slot_data["game_state"] = "character_selection"
	slot_data["last_save_trigger"] = "clear_battle_state"
	slot_data["last_save_timestamp"] = int(Time.get_unix_time_from_system())
	return SaveManager.save_game_progress(slot_index, slot_data)

static func load_slot(slot_index: int) -> Dictionary:
	"""统一槽位读取入口（含迁移）。"""
	var raw := SaveManager.load_game_save(slot_index)
	if raw.is_empty():
		return {}
	return migrate_save_data(raw)

static func load_slot_and_apply(slot_index: int) -> Dictionary:
	"""统一读取并恢复运行时状态。"""
	var data := load_slot(slot_index)
	if data.is_empty():
		return {}

	Global.current_save_slot = slot_index
	apply_save_data_to_runtime(data)
	return data

static func migrate_save_data(data: Dictionary) -> Dictionary:
	"""统一迁移入口：兼容旧货币字段和缺失字段。"""
	var migrated := data.duplicate(true)

	if not migrated.has("version"):
		migrated["version"] = SaveManager.CURRENT_VERSION

	if not migrated.has("save_schema_version"):
		migrated["save_schema_version"] = SAVE_SCHEMA_VERSION

	var game_state := str(migrated.get("game_state", "in_progress"))
	var legacy_gold := int(migrated.get("gold", migrated.get("total_gold", 0)))
	if not migrated.has("run_gold"):
		migrated["run_gold"] = legacy_gold if game_state == "in_battle" else 0

	if not migrated.has("soul_shard"):
		if migrated.has("total_gold"):
			migrated["soul_shard"] = int(migrated.get("total_gold", 0))
		else:
			migrated["soul_shard"] = DataManager.get_soul_shard()

	if not migrated.has("gold"):
		migrated["gold"] = int(migrated.get("run_gold", 0))

	if not migrated.has("upgrades") or not (migrated["upgrades"] is Dictionary):
		migrated["upgrades"] = {}

	if not migrated.has("selected_players"):
		migrated["selected_players"] = []

	if not migrated.has("bond_summary") or not (migrated["bond_summary"] is Array):
		migrated["bond_summary"] = []

	if not migrated.has("slot_index"):
		migrated["slot_index"] = -1

	if not migrated.has("leader_id"):
		migrated["leader_id"] = ""

	return migrated

static func apply_save_data_to_runtime(data: Dictionary) -> void:
	"""统一恢复运行时状态入口。"""
	var migrated := migrate_save_data(data)

	Global.reset_selection()
	_restore_selected_players(migrated)
	Global.current_player_index = int(migrated.get("current_player_index", 0))

	var player_states = migrated.get("player_states", {})
	if player_states is Dictionary and not player_states.is_empty():
		Global.player_states = player_states.duplicate(true)
	else:
		Global.init_player_states()

	DataManager.deserialize_progress_data(migrated, true)
	RunStateService.set_run_xp(int(migrated.get("session_xp", 0)))
	var progression: Node = _get_progression_singleton()
	if progression and progression.has_method("recalculate_from_total_xp"):
		progression.call("recalculate_from_total_xp", RunStateService.get_run_xp(), false)
	Global.session_kills = int(migrated.get("session_kills", 0))
	RunStateService.set_session_gold(int(migrated.get("session_gold", 0)))

	var emblems_data = migrated.get("emblems", {})
	if emblems_data is Dictionary and not emblems_data.is_empty():
		EmblemManager.deserialize(emblems_data)

	var modifiers_data = migrated.get("modifiers", {})
	if modifiers_data is Dictionary and not modifiers_data.is_empty():
		ModifierManager.deserialize(modifiers_data)

	var bond_counts = migrated.get("bond_counts", {})
	if bond_counts is Dictionary and not bond_counts.is_empty():
		BondManager.restore_from_save(bond_counts)

	var equipment_data = migrated.get("equipment", {})
	if equipment_data is Dictionary and not equipment_data.is_empty():
		EquipmentManager.deserialize_from_save(equipment_data)

	var warehouse_data = migrated.get("warehouse", {})
	if warehouse_data is Dictionary and not warehouse_data.is_empty():
		WarehouseManager.restore_from_save(warehouse_data)

	if str(migrated.get("game_state", "")) == "in_battle" and migrated.has("battle_state"):
		Global.pending_battle_state = migrated["battle_state"]
	else:
		Global.pending_battle_state = {}

	sync_selection_cache_from_runtime()

static func sync_selection_cache_from_runtime() -> void:
	"""将当前 Global 的角色/武器写入 SelectionPanel 缓存。"""
	var selection_cache: Array = []
	for i in range(Global.selected_player_ids.size()):
		var pid: String = Global.selected_player_ids[i]
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		selection_cache.append({
			"player_id": pid,
			"weapon_type": wtype,
			"slot_index": i
		})

	_write_json_file("user://player_selection_cache.json", selection_cache)

	var weapon_cache: Dictionary = {}
	for pid in Global.selected_player_ids:
		var wtype: String = Global.selected_player_weapons.get(pid, "")
		if wtype != "":
			weapon_cache[pid] = wtype

	_write_json_file("user://player_weapon_cache.json", weapon_cache)

static func clear_selection_cache_files() -> void:
	"""清除角色/武器缓存文件。"""
	_remove_file_if_exists("user://player_selection_cache.json")
	_remove_file_if_exists("user://player_weapon_cache.json")

static func _ensure_slot_initialized(slot_index: int) -> bool:
	if not SaveManager.is_slot_empty(slot_index):
		return true

	var selected_players := _serialize_selected_players()
	if selected_players.is_empty():
		return false

	var leader_id := str(selected_players[0].get("player_id", ""))
	return create_new_slot_save(slot_index, leader_id, selected_players)

static func _build_progress_payload(slot_index: int, context: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"version": SaveManager.CURRENT_VERSION,
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"slot_index": slot_index,
		"current_wave": int(context.get("current_wave", 1)),
		"current_floor": int(context.get("current_floor", 1)),
		"play_time_seconds": int(context.get("play_time_seconds", 0)),
		"game_state": str(context.get("game_state", "in_progress")),
		"selected_players": _serialize_selected_players(),
		"leader_id": _get_leader_id(),
		"current_player_index": Global.current_player_index,
		"player_states": Global.player_states.duplicate(true),
		"session_xp": RunStateService.get_run_xp(),
		"session_kills": Global.session_kills,
		"session_gold": RunStateService.get_session_gold(),
		"bond_summary": BondManager.get_bond_summary(),
		"bond_counts": BondManager.current_bond_counts.duplicate(true),
		"equipment": EquipmentManager.serialize_for_players(Global.selected_player_ids),
		"warehouse": WarehouseManager.serialize_for_save(),
		"emblems": EmblemManager.serialize(),
		"modifiers": ModifierManager.serialize(),
		"last_save_trigger": str(context.get("trigger", "manual")),
		"last_save_timestamp": int(Time.get_unix_time_from_system())
	}

	var progress_data: Dictionary = DataManager.serialize_progress_data()
	for key in progress_data:
		payload[key] = progress_data[key]

	if bool(context.get("include_battle_state", false)):
		payload["battle_state"] = context.get("battle_state", {})

	if context.has("battle_state"):
		payload["battle_state"] = context.get("battle_state", {})

	return payload

static func _serialize_selected_players() -> Array:
	var players: Array = []
	for pid in Global.selected_player_ids:
		players.append({
			"player_id": pid,
			"weapon_type": Global.selected_player_weapons.get(pid, "")
		})
	return players

static func _get_leader_id() -> String:
	if Global.selected_player_ids.is_empty():
		return ""
	return str(Global.selected_player_ids[0])

static func _restore_selected_players(data: Dictionary) -> void:
	var players_data = data.get("selected_players", [])
	if players_data is Array:
		for entry in players_data:
			if entry is Dictionary:
				var pid: String = str(entry.get("player_id", ""))
				if pid == "":
					continue
				Global.selected_player_ids.append(pid)
				var wtype: String = str(entry.get("weapon_type", ""))
				if wtype != "":
					Global.selected_player_weapons[pid] = wtype
			elif entry is String and entry != "":
				Global.selected_player_ids.append(entry)

	if Global.selected_player_ids.is_empty():
		var leader: String = str(data.get("leader_id", ""))
		if leader != "":
			Global.selected_player_ids.append(leader)

static func _normalize_selected_players(players: Array) -> Array:
	var normalized: Array = []
	for entry in players:
		if entry is Dictionary:
			normalized.append({
				"player_id": str(entry.get("player_id", "")),
				"weapon_type": str(entry.get("weapon_type", ""))
			})
		elif entry is String and entry != "":
			normalized.append({
				"player_id": str(entry),
				"weapon_type": ""
			})
	return normalized

static func _get_progression_singleton() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop as SceneTree
	if tree.root == null:
		return null
	return tree.root.get_node_or_null("ProgressionManager")

static func _write_json_file(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

static func _remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file_name := path.get_file()
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove(file_name)
