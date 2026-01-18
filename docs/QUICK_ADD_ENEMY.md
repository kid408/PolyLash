# 快速添加敌人参考卡

**快速参考** - 添加新敌人的最小步骤

---

## 🚀 3步快速添加

### 步骤1：准备精灵
```
将精灵放到: assets/sprites/Enemies/Enemy_YourName.png
```

### 步骤2：修改3个表

#### enemy_config.csv
```csv
your_enemy,敌人名称,100,150,10,50,1,10,5,0.5,5,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

#### enemy_visual.csv
```csv
your_enemy,res://assets/sprites/Enemies/Enemy_YourName.png,1,1,1,1,1,1,0,0,0,20,40,40,1,1,1,1
```

#### wave_units_config.csv
```csv
wave_1_to_5,res://scenes/unit/enemy/enemy_generic.tscn,your_enemy,3
```

### 步骤3：测试
```
1. 按 F5 刷新项目
2. 按 F5 启动游戏
3. 验证敌人是否出现
```

---

## 📋 参数速查表

### 基础参数
| 参数 | 说明 | 示例 |
|------|------|------|
| enemy_id | 敌人ID | your_enemy |
| display_name | 显示名 | 敌人名称 |
| health | 生命值 | 100 |
| speed | 速度 | 150 |
| damage | 攻击力 | 10 |
| xp_value | 经验值 | 10 |
| gold_value | 金币值 | 5 |

### 视觉参数
| 参数 | 说明 | 示例 |
|------|------|------|
| sprite_path | 精灵路径 | res://assets/sprites/Enemies/Enemy_YourName.png |
| scale_x | X缩放 | 1 |
| scale_y | Y缩放 | 1 |
| color_r | 红色 | 1 |
| color_g | 绿色 | 1 |
| color_b | 蓝色 | 1 |

### 特殊能力参数
| 参数 | 说明 | 示例 |
|------|------|------|
| can_charge | 冲锋 | 0(否) 或 1(是) |
| shoot_cooldown | 射击冷却 | 2.5 |
| pool_radius | 毒池半径 | 60.0 |

---

## 🎯 常用配置模板

### 基础敌人
```csv
basic_enemy,基础敌人,100,150,10,50,1,10,5,0.5,5,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

### 快速敌人
```csv
fast_enemy,快速敌人,50,300,5,40,0.5,15,8,0.3,3,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

### 坦克敌人
```csv
tank_enemy,坦克敌人,300,100,20,60,2,30,15,0.9,15,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

### 冲锋敌人
```csv
charger_enemy,冲锋者,100,150,15,50,1,25,15,0.6,8,1,0.2,0.2,20.0,60.0,0.8,0.6,3.5,3.0,40.0,1,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

### 射击敌人
```csv
shooter_enemy,射手,150,100,6,50,1.5,20,12,0.8,6,0.5,0.8,1,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,2.5,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

### 毒液敌人
```csv
poison_enemy,毒液怪,80,120,8,45,1.2,12,6,0.4,4,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,80.0,8.0,0.5,10.0
```

---

## 🔧 快速调整

### 敌人太强？
- 减少 `health`
- 减少 `damage`
- 增加 `attack_cooldown`

### 敌人太弱？
- 增加 `health`
- 增加 `damage`
- 减少 `attack_cooldown`

### 敌人太快？
- 减少 `speed`

### 敌人太慢？
- 增加 `speed`

---

## 📝 完整参数列表

```
enemy_id,display_name,health,speed,damage,attack_range,attack_cooldown,xp_value,gold_value,knockback_resistance,energy_drop,color_r,color_g,color_b,flock_push,stop_distance,charge_prep_time,charge_duration,charge_speed_mult,charge_cooldown,break_radius,can_charge,shoot_cooldown,projectile_count,projectile_arc_angle,projectile_speed,pool_radius,pool_damage,pool_damage_interval,pool_lifetime
```

```
enemy_id,sprite_path,scale_x,scale_y,color_r,color_g,color_b,color_a,z_index,offset_x,offset_y,collision_radius,hitbox_width,hitbox_height,animation_speed,flash_color_r,flash_color_g,flash_color_b
```

---

## ✅ 检查清单

- [ ] 精灵放到 `assets/sprites/Enemies/`
- [ ] 在 `enemy_config.csv` 添加敌人
- [ ] 在 `enemy_visual.csv` 添加敌人
- [ ] 在 `wave_units_config.csv` 添加敌人
- [ ] 按 F5 刷新项目
- [ ] 按 F5 启动游戏
- [ ] 验证敌人出现

---

**详细指南**: 查看 `docs/ADD_NEW_ENEMY_GUIDE.md`

