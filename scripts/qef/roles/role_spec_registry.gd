extends RefCounted
class_name RoleSpecRegistry

const RoleSpecBase = preload("res://scripts/qef/roles/role_spec_base.gd")

const SPEC_SCRIPT_BY_ROLE := {
	"butcher": preload("res://scripts/qef/roles/butcher_spec.gd"),
	"glacier": preload("res://scripts/qef/roles/glacier_spec.gd"),
	"jailer": preload("res://scripts/qef/roles/jailer_spec.gd"),
	"blacksmith": preload("res://scripts/qef/roles/blacksmith_spec.gd"),
	"paladin": preload("res://scripts/qef/roles/paladin_spec.gd"),
	"breachmarshal": preload("res://scripts/qef/roles/breachmarshal_spec.gd"),
	"hexwarden": preload("res://scripts/qef/roles/hexwarden_spec.gd"),
	"executioner": preload("res://scripts/qef/roles/executioner_spec.gd"),
	"pyro": preload("res://scripts/qef/roles/pyro_spec.gd"),
	"weaver": preload("res://scripts/qef/roles/weaver_spec.gd"),
	"runeblazer": preload("res://scripts/qef/roles/runeblazer_spec.gd"),
	"bloodsworn": preload("res://scripts/qef/roles/bloodsworn_spec.gd"),
	"spiritcaller": preload("res://scripts/qef/roles/spiritcaller_spec.gd"),
	"mirebinder": preload("res://scripts/qef/roles/mirebinder_spec.gd"),
	"necro": preload("res://scripts/qef/roles/necro_spec.gd"),
	"gildhand": preload("res://scripts/qef/roles/gildhand_spec.gd"),
	"wind": preload("res://scripts/qef/roles/wind_spec.gd"),
	"arcstriker": preload("res://scripts/qef/roles/arcstriker_spec.gd"),
	"stormseer": preload("res://scripts/qef/roles/stormseer_spec.gd"),
	"banner": preload("res://scripts/qef/roles/banner_spec.gd"),
	"turretwright": preload("res://scripts/qef/roles/turretwright_spec.gd"),
	"illusionist": preload("res://scripts/qef/roles/illusionist_spec.gd"),
	"singularist": preload("res://scripts/qef/roles/singularist_spec.gd"),
	"fatebinder": preload("res://scripts/qef/roles/fatebinder_spec.gd"),
	"sapper": preload("res://scripts/qef/roles/sapper_spec.gd"),
	"lurewarden": preload("res://scripts/qef/roles/lurewarden_spec.gd"),
	"plague": preload("res://scripts/qef/roles/plague_spec.gd"),
	"medic": preload("res://scripts/qef/roles/medic_spec.gd"),
	"quartermaster": preload("res://scripts/qef/roles/quartermaster_spec.gd"),
	"swarm": preload("res://scripts/qef/roles/swarm_spec.gd"),
	"broker": preload("res://scripts/qef/roles/broker_spec.gd"),
	"trapper": preload("res://scripts/qef/roles/trapper_spec.gd"),
}

static var _spec_cache: Dictionary = {}

static func get_role_spec_object(role_id: String) -> RoleSpecBase:
	var normalized: String = role_id.strip_edges().to_lower()
	if normalized.is_empty():
		return null
	if _spec_cache.has(normalized):
		var cached: Variant = _spec_cache.get(normalized)
		if cached is RoleSpecBase:
			return cached as RoleSpecBase
	var script_var: Variant = SPEC_SCRIPT_BY_ROLE.get(normalized, null)
	if script_var == null:
		return null
	var spec_obj: Variant = script_var.new()
	if not (spec_obj is RoleSpecBase):
		return null
	_spec_cache[normalized] = spec_obj
	return spec_obj as RoleSpecBase

static func get_role_spec(role_id: String) -> Dictionary:
	var spec_obj: RoleSpecBase = get_role_spec_object(role_id)
	if spec_obj == null:
		return {}
	return spec_obj.get_spec()

static func get_reward_by_id(role_id: String, reward_id: String) -> Dictionary:
	var spec_obj: RoleSpecBase = get_role_spec_object(role_id)
	if spec_obj == null:
		return {}
	return spec_obj.get_reward_by_id(reward_id)

static func roll_pack_reward(role_id: String, runtime: Dictionary, pack_payload: Dictionary = {}) -> Dictionary:
	var spec_obj: RoleSpecBase = get_role_spec_object(role_id)
	if spec_obj == null:
		return {}
	return spec_obj.roll_pack_reward(runtime, pack_payload)

static func roll_combo_reward(role_id: String, preferred_slot: String = "e") -> Dictionary:
	var spec_obj: RoleSpecBase = get_role_spec_object(role_id)
	if spec_obj == null:
		return {}
	return spec_obj.roll_combo_reward(preferred_slot)
