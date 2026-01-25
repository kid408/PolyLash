# 敌人创建完整指南

**版本**: 2.0 (改进版)  
**更新日期**: 2026-01-25  
**目标**: 让策划能够独立完成90%的敌人创建工作

---

## 📋 目录

1. [快速开始](#快速开始)
2. [创建方法对比](#创建方法对比)
3. [方法1: 使用创建工具（推荐）](#方法1-使用创建工具推荐)
4. [方法2: 手动配置](#方法2-手动配置)
5. [能力系统](#能力系统)
6. [常见问题](#常见问题)
7. [最佳实践](#最佳实践)

---

## 🚀 快速开始

### 30秒创建一个敌人

```gdscript
# 1. 在Godot编辑器中打开 tools/create_enemy_tool.gd
# 2. 修改配置:
var config = {
    "enemy_id": "fire_imp",
    "display_name": "火焰小鬼",
    "health": 120,
    "speed": 200,
    "damage": 15,
    "sprite_path": "res://assets/sprites/Enemies/Enemy_1.png"
}

# 3. 运行脚本 (File -> Run)
# 4. 完成！
```

**创建时间**: 30秒 - 2分钟  
**技术要求**: 无需编程  
**成功率**: 99%

---

## 📊 创建方法对比

| 方法 | 时间 | 难度 | 灵活性 | 推荐度 |
|-----|------|------|--------|--------|
| **创建工具** | 30秒-2分钟 | ⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **手动配置** | 5-10分钟 | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **代码创建** | 1-2小时 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐ |

---

## 方法1: 使用创建工具（推荐）

### 步骤1: 准备资源

在开始之前，准备好：
- ✅ 敌人精灵图片 (PNG格式)
- ✅ 敌人名称和ID
- ✅ 基础属性数值

### 步骤2: 打开创建工具

```
1. 在Godot编辑器中
2. 打开 tools/create_enemy_tool.gd
3. 找到 create_enemy_interactive() 函数
```

### 步骤3: 配置敌人

```gdscript
var config = {
    # 基础信息
    "enemy_id": "ice_golem",           # 唯一ID（英文，下划线分隔）
    "display_name": "冰霜巨人",         # 显示名称
    
    # 基础属性
    "health": 200,                     # 生命值
    "speed": 120,                      # 移动速度
    "damage": 25,                      # 攻击力
    "attack_range": 60,                # 攻击范围
    "attack_cooldown": 1.5,            # 攻击冷却
    
    # 奖励
    "xp_value": 20,                    # 经验值
    "gold_value": 10,                  # 金币
    "energy_drop": 3,                  # 能量掉落
    
    # 视觉
    "sprite_path": "res://assets/sprites/Enemies/IceGolem.png",
    "scale_x": 1.2,                    # X缩放
    "scale_y": 1.2,                    # Y缩放
    "color_r": 0.5,                    # 颜色（可选）
    "color_g": 0.8,
    "color_b": 1.0,
    
    # 能力（可选）
    "abilities": ["charge", "poison_pool"]
}
```

### 步骤4: 运行脚本

```
1. File -> Run (或按 Ctrl+Shift+X)
2. 选择 create_enemy_tool.gd
3. 查看输出日志确认创建成功
```

### 步骤5: 测试敌人

```
1. 打开测试场景
2. 实例化 scenes/unit/enemy/enemy_generic.tscn
3. 在Inspector中设置 enemy_id 为 "ice_golem"
4. 运行场景测试
```

---

## 方法2: 手动配置

### 适用场景

- 需要精确控制所有参数
- 批量修改现有敌人
- 学习系统内部结构

### 配置文件说明

#### 1. enemy_config.csv - 基础属性

```csv
enemy_id,display_name,health,speed,damage,attack_range,attack_cooldown,xp_value,gold_value,knockback_resistance,energy_drop,color_r,color_g,color_b,flock_push,stop_distance,...
ice_golem,冰霜巨人,200,120,25,60,1.5,20,10,0.7,3,0.5,0.8,1.0,20,60,...
```

**字段说明**:
- `enemy_id`: 唯一标识符（必填）
- `display_name`: 显示名称（必填）
- `health`: 生命值（必填）
- `speed`: 移动速度（必填）
- `damage`: 攻击力（必填）
- 其他字段可使用默认值

#### 2. enemy_visual.csv - 视觉配置

```csv
enemy_id,sprite_path,scale_x,scale_y,color_r,color_g,color_b,color_a,z_index,offset_x,offset_y,collision_radius,hitbox_width,hitbox_height,...
ice_golem,res://assets/sprites/Enemies/IceGolem.png,1.2,1.2,0.5,0.8,1.0,1.0,0,0,0,25,50,50,...
```

**字段说明**:
- `sprite_path`: 精灵图片路径（必填）
- `scale_x/y`: 缩放比例
- `color_r/g/b/a`: 颜色调制
- `collision_radius`: 碰撞半径
- `hitbox_width/height`: 受击框大小

#### 3. enemy_abilities.csv - 能力配置

```csv
enemy_id,ability_id,cooldown,min_distance,max_distance,health_threshold,auto_activate,param1,param2,param3,param4,param5,param6
ice_golem,charge,3.0,100,300,0,1,0.8,0.6,3.5,30,,
ice_golem,poison_pool,0,0,999999,0,1,60,5,0.5,8,,
```

**字段说明**:
- `ability_id`: 能力类型（见能力系统章节）
- `cooldown`: 冷却时间
- `min/max_distance`: 激活距离范围
- `health_threshold`: 生命值阈值（0-1）
- `param1-6`: 能力特定参数

### 手动配置步骤

1. **复制模板行**
   ```
   从现有敌人复制一行作为模板
   ```

2. **修改ID和名称**
   ```
   将 enemy_id 改为新的唯一ID
   将 display_name 改为显示名称
   ```

3. **调整属性**
   ```
   根据设计需求修改数值
   ```

4. **保存文件**
   ```
   确保使用UTF-8编码保存
   ```

5. **重启游戏**
   ```
   重新加载配置
   ```

---

## 🎯 能力系统

### 可用能力列表

#### 1. poison_pool - 毒池

**描述**: 死亡时在地面留下持续伤害区域

**参数**:
```csv
enemy_id,ability_id,cooldown,min_distance,max_distance,health_threshold,auto_activate,pool_radius,pool_damage,pool_damage_interval,pool_lifetime
mine_layer,poison_pool,0,0,999999,0,1,60,5,0.5,8
```

**参数说明**:
- `pool_radius`: 毒池半径（默认60）
- `pool_damage`: 每次伤害（默认5）
- `pool_damage_interval`: 伤害间隔（默认0.5秒）
- `pool_lifetime`: 持续时间（默认8秒）

**适用场景**:
- 地雷怪
- 毒系敌人
- 区域控制型敌人

#### 2. shooting - 射击

**描述**: 向玩家发射投射物

**参数**:
```csv
enemy_id,ability_id,cooldown,min_distance,max_distance,health_threshold,auto_activate,projectile_count,arc_angle,projectile_speed,projectile_damage_mult
archer,shooting,3.0,0,300,0,1,3,45,1800,0.5
```

**参数说明**:
- `projectile_count`: 投射物数量（默认3）
- `arc_angle`: 扇形角度（默认45度）
- `projectile_speed`: 投射物速度（默认1800）
- `projectile_damage_mult`: 伤害倍率（默认0.5）

**适用场景**:
- 远程敌人
- 法师型敌人
- Boss技能

#### 3. charge - 冲锋

**描述**: 向玩家冲刺攻击

**参数**:
```csv
enemy_id,ability_id,cooldown,min_distance,max_distance,health_threshold,auto_activate,prep_time,charge_duration,speed_multiplier,warning_line_width
bull,charge,3.0,100,300,0,1,0.8,0.6,3.5,30
```

**参数说明**:
- `prep_time`: 预警时间（默认0.8秒）
- `charge_duration`: 冲锋持续时间（默认0.6秒）
- `speed_multiplier`: 速度倍率（默认3.5）
- `warning_line_width`: 预警线宽度（默认30）

**适用场景**:
- 冲锋型敌人
- 野兽型敌人
- 突进技能

### 能力组合示例

#### 示例1: 毒刺豪猪
```csv
# 冲锋 + 毒池
poison_hedgehog,charge,3.0,100,300,0,1,0.8,0.6,3.5,30,,
poison_hedgehog,poison_pool,0,0,999999,0,1,60,5,0.5,8,,
```

#### 示例2: 远程炮台
```csv
# 射击（多次）
turret,shooting,2.0,0,400,0,1,5,90,2000,0.6,,
```

#### 示例3: 狂暴Boss
```csv
# 生命值低于50%时开始冲锋
boss,charge,5.0,100,400,0.5,1,1.0,0.8,4.0,40,,
```

### 添加自定义能力

如果需要新的能力类型，请联系程序员，或参考以下步骤：

1. **创建能力脚本**
   ```gdscript
   # scenes/components/abilities/my_ability.gd
   extends AbilityBase
   class_name MyAbility
   
   func activate() -> void:
       # 实现能力逻辑
       pass
   ```

2. **注册能力**
   ```gdscript
   # 在 autoloads/ability_manager.gd 中添加
   ability_registry["my_ability"] = {
       "script": "res://scenes/components/abilities/my_ability.gd",
       "name": "我的能力",
       "description": "能力描述"
   }
   ```

3. **配置能力**
   ```csv
   # 在 enemy_abilities.csv 中使用
   my_enemy,my_ability,3.0,0,999999,0,1,param1,param2,...
   ```

---

## ❓ 常见问题

### Q1: 敌人不显示？

**检查清单**:
- ✅ `enemy_id` 在所有配置文件中一致
- ✅ 精灵路径正确且文件存在
- ✅ 场景中正确设置了 `enemy_id`
- ✅ 重启了游戏以重新加载配置

### Q2: 能力不生效？

**检查清单**:
- ✅ `enemy_abilities.csv` 中有对应配置
- ✅ `ability_id` 拼写正确
- ✅ 激活条件满足（距离、生命值等）
- ✅ `auto_activate` 设置为 1

### Q3: 敌人属性不对？

**解决方案**:
1. 检查CSV文件编码（必须是UTF-8）
2. 检查数值格式（不要有多余空格）
3. 使用 `config/convert_csv_utf8.bat` 转换编码
4. 重启游戏重新加载

### Q4: 如何批量创建敌人？

**方法1: 使用工具**
```gdscript
var configs = [
    {"enemy_id": "enemy1", "display_name": "敌人1", ...},
    {"enemy_id": "enemy2", "display_name": "敌人2", ...},
]
tool.create_enemy_batch(configs)
```

**方法2: 复制粘贴**
```
1. 在CSV中复制现有敌人行
2. 批量修改ID和属性
3. 保存文件
```

### Q5: 如何创建精英/Boss？

**简单方法**:
```gdscript
var config = {
    "enemy_id": "fire_boss",
    "display_name": "火焰领主",
    "health": 1000,        # 高生命值
    "damage": 50,          # 高伤害
    "speed": 150,
    "abilities": ["shooting", "charge", "poison_pool"]  # 多个能力
}
```

**高级方法**:
参考 `scenes/unit/enemy/elites/enemy_glutton.gd` 创建自定义精英类

---

## 💡 最佳实践

### 命名规范

```
✅ 好的命名:
- fire_imp
- ice_golem
- poison_spider
- boss_dragon

❌ 不好的命名:
- enemy1
- test
- 火焰小鬼 (不要用中文)
- Fire Imp (不要用空格)
```

### 属性平衡

```
基础小怪:
- 生命值: 50-150
- 速度: 150-250
- 伤害: 5-15

精英怪:
- 生命值: 200-500
- 速度: 100-200
- 伤害: 20-40

Boss:
- 生命值: 800-2000
- 速度: 80-150
- 伤害: 50-100
```

### 能力搭配

```
近战型:
- charge (冲锋)

远程型:
- shooting (射击)

坦克型:
- 无特殊能力，高生命值

控制型:
- poison_pool (毒池)
- shooting (射击)

Boss:
- 多个能力组合
- 根据生命值阶段激活不同能力
```

### 测试流程

1. **单独测试**
   ```
   创建测试场景 -> 添加单个敌人 -> 测试所有行为
   ```

2. **群体测试**
   ```
   添加多个敌人 -> 测试AI和碰撞
   ```

3. **平衡性测试**
   ```
   实际游戏中测试 -> 调整数值 -> 重复测试
   ```

### 性能优化

```
✅ 推荐:
- 每波敌人数量 < 50
- 投射物数量 < 100
- 毒池数量 < 20

⚠️ 注意:
- 避免过多粒子效果
- 避免过于复杂的AI逻辑
- 合理设置能力冷却时间
```

---

## 📚 参考资料

### 相关文档
- `ENEMY_CREATION_QUICK_REFERENCE.md` - 快速参考
- `ENEMY_CREATION_ANALYSIS.md` - 系统分析
- `CHARACTER_CREATION_GUIDE.md` - 角色创建指南（类似流程）

### 配置文件
- `config/enemy/enemy_config.csv` - 基础属性
- `config/enemy/enemy_visual.csv` - 视觉配置
- `config/enemy/enemy_abilities.csv` - 能力配置

### 代码文件
- `scenes/unit/enemy/enemy.gd` - 敌人基类
- `scenes/components/abilities/` - 能力组件
- `autoloads/ability_manager.gd` - 能力管理器
- `tools/create_enemy_tool.gd` - 创建工具

---

## 🎓 进阶主题

### 自定义AI行为

如需更复杂的AI，请参考 `enemy.gd` 中的状态机实现。

### 多阶段Boss

参考 `enemy_glutton.gd` 实现多阶段Boss逻辑。

### 动态难度调整

通过修改配置中的数值，可以实现动态难度。

---

**最后更新**: 2026-01-25  
**维护者**: 开发团队  
**反馈**: 如有问题或建议，请联系项目负责人
