#!/usr/bin/env python3
"""Generate expanded weapon_config.csv with 120 rows"""

def main():
    # Read existing CSV
    with open('config/weapon/weapon_config.csv', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # New weapon definitions
    new_weapons = []
    
    # Melee weapons (11 variants × 4 levels)
    melee_weapons = [
        ('thrust_charged', '蓄力突刺', 'line', 'weapon_melee_thrust', 'stun', [280,300,320,340], [0.5,0.6,0.7,0.8], [30,35,40,45]),
        ('swing_cleave', '横扫斩击', 'sector', 'weapon_melee_sector', 'none', [200,220,240,260], [120,125,130,135], [0,0,0,0]),
        ('swing_heavy', '重型挥砍', 'sector', 'weapon_melee_sector', 'none', [180,190,200,210], [60,65,70,75], [0,0,0,0]),
        ('circular_vortex', '旋风斩', 'circle', 'weapon_melee_circle', 'none', [360,360,360,360], [300,320,340,360], [0,0,0,0]),
        ('circular_dual', '双刀旋舞', 'circle', 'weapon_melee_circle', 'none', [360,360,360,360], [2,3,4,5], [0,0,0,0]),
        ('hammer_smash', '战锤重击', 'point', 'weapon_melee_point', 'stun', [150,160,170,180], [80,90,100,110], [0,0,0,0]),
        ('whip_lash', '鞭击', 'line', 'weapon_melee_thrust', 'none', [300,320,340,360], [0,0,0,0], [15,18,20,22]),
        ('spear_spin', '长矛旋转', 'circle', 'weapon_melee_circle', 'none', [360,360,360,360], [180,200,220,240], [0,0,0,0]),
        ('dagger_flurry', '匕首连击', 'point', 'weapon_melee_point', 'poison', [160,170,180,190], [3,4,5,6], [0,0,0,0]),
        ('scythe_reap', '镰刀收割', 'sector', 'weapon_melee_sector', 'poison', [220,240,260,280], [180,185,190,195], [0,0,0,0]),
        ('chain_whip', '链鞭', 'line', 'weapon_melee_thrust', 'none', [280,300,320,340], [5,6,7,8], [25,28,30,32]),
    ]
    
    for base_id, base_name, shape, scene_suffix, effect, ranges, param1s, param2s in melee_weapons:
        for lvl in range(1, 5):
            dmg = 1 if lvl <= 2 else 2
            cd = [0.8, 0.7, 0.6, 0.5][lvl-1]
            upgrade = f"{base_id}_{lvl+1}" if lvl < 4 else ""
            sector = param1s[lvl-1] if shape == 'sector' else 0
            
            line = f"{base_id}_{lvl},{base_name}{lvl}级,melee,{lvl},{dmg},1,{cd},0.0{5+lvl-1},1.5,{ranges[lvl-1]},{1.5+0.1*(lvl-1)},0,15,0.08,0.15,0.1,0,res://scenes/weapons/melee/{scene_suffix}.tscn,,res://assets/sprites/Weapons/Melee/{base_id}.png,\"{base_id}1.png,{base_id}2.png,{base_id}3.png,{base_id}4.png\",0|0,30|0,1.{2+lvl-1}|1.0,res://anims/{base_id}_frames.tres,res://scenes/vfx/{base_id}_attack.tscn,res://scenes/vfx/{base_id}_hit.tscn,res://assets/audio/{base_id.title()}.wav,{shape},,{effect},{sector},1,0,0,{param1s[lvl-1]},{param2s[lvl-1]},0,{upgrade},{lvl},res://assets/sprites/Weapons/Icons/{base_id}_icon_{lvl}.png,\"\"\n"
            new_weapons.append(line)
    
    # Range weapons (10 variants × 4 levels)
    range_weapons = [
        ('single_arc', '弧线箭', 'single', 'weapon_range_physical', 'none', [320,340,360,380], [200,220,240,260], [0,0,0,0], [0,0,0,0]),
        ('single_sniper', '狙击枪', 'single', 'weapon_range_physical', 'none', [500,520,540,560], [0,0,0,0], [0,0,0,0], [3000,3200,3400,3600]),
        ('spread_fan', '扇形散射', 'spread', 'weapon_range_physical', 'none', [280,300,320,340], [0,0,0,0], [7,8,9,10], [1600,1700,1800,1900]),
        ('spread_burst', '爆发散射', 'spread', 'weapon_range_physical', 'none', [260,280,300,320], [0,0,0,0], [12,14,16,18], [1400,1500,1600,1700]),
        ('pierce_ricochet', '穿透反弹', 'pierce', 'weapon_range_beam', 'none', [350,370,390,410], [0,2,3,5], [0,0,0,0], [2000,2200,2400,2600]),
        ('pierce_laser', '穿透激光', 'pierce', 'weapon_range_beam', 'none', [400,420,440,460], [0,2,3,-1], [0,0,0,0], [2500,2700,2900,3100]),
        ('magic_chain', '连锁闪电', 'magic', 'weapon_range_magic', 'chain', [300,320,340,360], [2,3,4,5], [0,0,0,0], [1800,1900,2000,2100]),
        ('magic_meteor', '陨石术', 'magic', 'weapon_range_magic', 'fire', [350,370,390,410], [500,520,540,560], [0,0,0,0], [1200,1300,1400,1500]),
        ('magic_heal_aoe', '治疗光环', 'magic', 'weapon_range_magic', 'heal', [320,340,360,380], [0,0,0,0], [0.5,0.55,0.6,0.65], [1500,1600,1700,1800]),
        ('bow_arrow', '弓箭', 'single', 'weapon_range_physical', 'none', [400,420,440,460], [100,110,120,130], [0,0,0,0], [1600,1700,1800,1900]),
    ]
    
    for base_id, base_name, bullet_mode, scene_suffix, effect, ranges, param1s, param2s, speeds in range_weapons:
        for lvl in range(1, 5):
            dmg = 1 if lvl <= 2 else 2
            cd = [0.8, 0.7, 0.6, 0.5][lvl-1]
            upgrade = f"{base_id}_{lvl+1}" if lvl < 4 else ""
            bullet_cnt = param2s[lvl-1] if bullet_mode == 'spread' else 1
            spread = [30,35,40,45][lvl-1] if bullet_mode == 'spread' else 0
            pierce = param1s[lvl-1] if bullet_mode == 'pierce' else 0
            
            line = f"{base_id}_{lvl},{base_name}{lvl}级,range,{lvl},{dmg},0.95,{cd},0.0{5+lvl-1},1.5,{ranges[lvl-1]},{0.5+0.1*(lvl-1)},0,10,0.05,0.1,0.1,{speeds[lvl-1]},res://scenes/weapons/range/{scene_suffix}.tscn,res://scenes/projectiles/projectile_{base_id}.tscn,res://assets/sprites/Weapons/Range/{base_id}.png,\"{base_id}1.png,{base_id}2.png,{base_id}3.png,{base_id}4.png\",20|0,0|0,1.0|1.0,res://anims/{base_id}_frames.tres,res://scenes/vfx/{base_id}_attack.tscn,res://scenes/vfx/{base_id}_hit.tscn,res://assets/audio/{base_id.title()}.wav,straight,{bullet_mode},{effect},0,{bullet_cnt},{spread},{pierce},{param1s[lvl-1]},{param2s[lvl-1]},0,{upgrade},{lvl},res://assets/sprites/Weapons/Icons/{base_id}_icon_{lvl}.png,\"\"\n"
            new_weapons.append(line)
    
    # Write expanded CSV
    with open('config/weapon/weapon_config.csv', 'w', encoding='utf-8') as f:
        f.writelines(lines)
        f.writelines(new_weapons)
    
    print(f"✅ Expanded weapon_config.csv to {len(lines) + len(new_weapons)} rows")
    print(f"   - Original: {len(lines)} rows")
    print(f"   - Added: {len(new_weapons)} new weapon rows")

if __name__ == '__main__':
    main()
