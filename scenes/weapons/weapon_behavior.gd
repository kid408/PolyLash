extends Node2D
class_name WeaponBehavior

@export var weapon: Weapon

var critical := false

func execute_attack() -> void:
	pass
	
func get_damage() -> float:
	# 获取武器基础伤害和玩家伤害加成
	var weapon_damage: float = weapon.data.stats.damage
	var player_damage: float = Global.player.damage if is_instance_valid(Global.player) else 0.0
	var damage: float = weapon_damage + player_damage
	
	# 应用 Buff 区域的攻击力加成
	if is_instance_valid(Global.player) and Global.player.has_meta("buff_attack_boost"):
		damage *= (1.0 + Global.player.get_meta("buff_attack_boost"))
	
	# 暴击判定
	var crit_chance: float = weapon.data.stats.crit_chance
	if Global.get_chance_sucess(crit_chance):
		critical = true
		damage = ceil(damage * weapon.data.stats.crit_damage)
	return damage
