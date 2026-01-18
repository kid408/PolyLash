# 快速添加玩家角色参考卡

**快速参考** - 添加新玩家角色的最小步骤

---

## 🚀 3步快速添加

### 步骤1：准备精灵
```
将精灵放到: assets/sprites/Players/Player_YourName.png
```

### 步骤2：创建角色脚本
```
创建文件: scenes/unit/players/player_yourname.gd
```

**最小脚本模板**:
```gdscript
extends PlayerBase
class_name PlayerYourName

func _ready() -> void:
    super._ready()
    
    # 初始化技能管理器
    skill_manager = SkillManager.new(self)
    skill_manager.debug_mode = false
    add_child(skill_manager)
    skill_manager.load_skills_from_config("yourname")

func _handle_input(delta: float) -> void:
    # 1. 移动逻辑
    move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if can_move():
        var current_speed = base_speed 
        if stats != null:
            current_speed = stats.speed
        position += move_dir * current_speed * delta
    
    # 2. 技能按键分发
    if not skill_manager:
        return
    
    if Input.is_action_just_pressed("skill_e"):
        skill_manager.execute_skill("e")
        return
    
    if Input.is_action_pressed("skill_q"):
        skill_manager.charge_skill("q", delta)
        return
    elif Input.is_action_just_released("skill_q"):
        skill_manager.release_skill("q")
        return
    
    if Input.is_action_just_pressed("click_left"):
        skill_manager.execute_skill("lmb")
```

### 步骤3：修改3个表

#### player_config.csv
```csv
yourname,角色名称,显示顺序,1,羁绊,100,0.0,50,30,60,0.5,999,800,3,500,角色描述,50.0,0.3
```

#### player_visual.csv
```csv
yourname,res://assets/sprites/Players/Player_YourName.png,res://scenes/unit/players/player_generic.tscn,1,1,1,1,1,1,1
```

#### player_weapons.csv
```csv
yourname,weapon_id_1,weapon_id_2,weapon_id_3,weapon_id_4,weapon_id_5,weapon_id_6
```

### 步骤4：测试
```
1. 按 F5 刷新项目
2. 按 F5 启动游戏
3. 验证角色是否出现
```

---

## 📋 参数速查表

### player_config.csv 参数
| 参数 | 说明 | 示例 |
|------|------|------|
| player_id | 角色ID | yourname |
| display_name | 显示名 | 角色名称 |
| display_order | 显示顺序 | 1 |
| enabled | 是否启用 | 1 |
| ties | 羁绊 | 战士/法师/工程师 |
| health | 生命值 | 100 |
| health_regen | 血量恢复 | 0.0 |
| skill_q_cost | Q技能消耗 | 50 |
| skill_e_cost | E技能消耗 | 30 |
| close_threshold | 近战阈值 | 60 |
| energy_regen | 能量恢复 | 0.5 |
| max_energy | 最大能量 | 999 |
| initial_energy | 初始能量 | 800 |
| max_armor | 最大护甲 | 3 |
| base_speed | 移动速度 | 500 |
| description | 说明 | 角色描述 |
| external_force_decay | 外力衰减 | 50.0 |
| knockback_scale | 击退缩放 | 0.3 |

### player_visual.csv 参数
| 参数 | 说明 | 示例 |
|------|------|------|
| player_id | 角色ID | yourname |
| sprite_path | 精灵路径 | res://assets/sprites/Players/Player_YourName.png |
| scene_path | 场景路径 | res://scenes/unit/players/player_generic.tscn |
| scale_x | X缩放 | 1 |
| scale_y | Y缩放 | 1 |
| color_r | 红色 | 1 |
| color_g | 绿色 | 1 |
| color_b | 蓝色 | 1 |
| color_a | 透明度 | 1 |
| z_index | Z层级 | 1 |

---

## 🎯 常用配置模板

### 基础角色
```csv
yourname,基础角色,8,1,战士,100,0.0,50,30,60,0.5,999,800,3,500,基础角色,50.0,0.3
```

### 法师角色
```csv
yourname,法师角色,8,1,法师,100,0.0,20,20,60,0.5,999,700,3,500,法师角色,50.0,0.3
```

### 工程师角色
```csv
yourname,工程师角色,8,1,工程师,100,0.0,10,40,60,0.5,999,550,3,500,工程师角色,50.0,0.3
```

### 元素体角色
```csv
yourname,元素体角色,8,1,元素体,100,0.0,30,35,60,0.5,999,750,3,500,元素体角色,50.0,0.3
```

### 控制者角色
```csv
yourname,控制者角色,8,1,控制者,100,0.0,20,30,60,0.5,999,600,3,500,控制者角色,50.0,0.3
```

### 刺客角色
```csv
yourname,刺客角色,8,1,刺客,100,0.0,20,20,60,0.5,999,650,3,500,刺客角色,50.0,0.3
```

### 召唤师角色
```csv
yourname,召唤师角色,8,1,召唤师,100,0.5,20,20,60,0.5,999,500,3,500,召唤师角色,50.0,0.3
```

---

## 🔧 快速调整

### 角色太强？
- 减少 `health`
- 减少技能伤害（在技能脚本中）
- 增加 `skill_q_cost` 或 `skill_e_cost`

### 角色太弱？
- 增加 `health`
- 增加技能伤害（在技能脚本中）
- 减少 `skill_q_cost` 或 `skill_e_cost`

### 角色太快？
- 减少 `base_speed`

### 角色太慢？
- 增加 `base_speed`

### 能量恢复太快？
- 减少 `energy_regen`

### 能量恢复太慢？
- 增加 `energy_regen`

---

## 📝 完整参数列表

### player_config.csv
```
player_id,display_name,display_order,enabled,ties,health,health_regen,skill_q_cost,skill_e_cost,close_threshold,energy_regen,max_energy,initial_energy,max_armor,base_speed,description,external_force_decay,knockback_scale
```

### player_visual.csv
```
player_id,sprite_path,scene_path,scale_x,scale_y,color_r,color_g,color_b,color_a,z_index
```

### player_weapons.csv
```
player_id,weapon_slot_1,weapon_slot_2,weapon_slot_3,weapon_slot_4,weapon_slot_5,weapon_slot_6
```

---

## ✅ 检查清单

- [ ] 精灵放到 `assets/sprites/Players/`
- [ ] 创建脚本 `scenes/unit/players/player_yourname.gd`
- [ ] 在 `player_config.csv` 添加角色
- [ ] 在 `player_visual.csv` 添加角色
- [ ] 在 `player_weapons.csv` 添加角色（可选）
- [ ] 按 F5 刷新项目
- [ ] 按 F5 启动游戏
- [ ] 验证角色出现

---

## 🎮 使用 PlayerFactory 创建角色

如果需要在代码中动态创建角色：

```gdscript
# 创建角色
var player = PlayerFactory.create_player("yourname")
get_tree().root.add_child(player)

# 检查角色是否存在
if PlayerFactory.has_player("yourname"):
    print("角色存在")

# 获取所有可用角色
var available = PlayerFactory.get_available_players()
for player_id in available:
    print("可用角色: ", player_id)
```

---

## 📚 相关文件

- `scenes/unit/players/player_generic.tscn` - 通用模板（所有角色共用）
- `autoloads/player_factory.gd` - 工厂类（创建角色）
- `config/player/player_config.csv` - 角色配置
- `config/player/player_visual.csv` - 角色视觉配置
- `config/player/player_weapons.csv` - 角色武器配置

---

**详细指南**: 查看 `docs/ARCHITECTURE.md` 和 `.kiro/player_refactor_completion.md`
