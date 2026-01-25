# 大招能量配置指南

## CSV 配置文件说明

### 配置文件位置
**文件**: `config/player/ult_config.csv`

### 字段说明

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `ult_id` | String | 大招ID（格式：角色ID_ult） | `butcher_ult` |
| `name` | String | 大招名称（显示用） | `血之狂怒` |
| `duration` | Float | **持续时间（秒）** | `10.0` |
| `energy_cost` | Float | **能量消耗（百分比 0-100）** | `80.0` |
| `bonus_bond_tag` | String | 临时羁绊标签 | `Martial` |
| `visual_color_hex` | String | 视觉颜色（十六进制） | `#FF3333` |
| `scale_multiplier` | Float | 缩放倍数 | `1.2` |
| `description` | String | 描述 | `屠夫进入血之狂怒状态...` |

### 重点字段详解

#### 1. duration（持续时间）
**作用**: 大招激活后的持续时间

**说明**:
- 单位：秒
- 在这段时间内，角色会保持变身状态
- 临时羁绊标签会在这段时间内生效
- 视觉效果（放大、变色）会持续这么久

**示例**:
```csv
duration
10.0    # 持续10秒
15.0    # 持续15秒（更持久）
5.0     # 持续5秒（短暂爆发）
```

**推荐值**:
- 短爆发型：5-8秒
- 平衡型：10-12秒 ⭐ 推荐
- 持久型：15-20秒

#### 2. energy_cost（能量消耗）
**作用**: 激活大招需要的能量百分比，同时也是消耗的能量量

**说明**:
- 单位：百分比（0-100）
- 这个值有**双重作用**：
  1. **激活条件**：玩家能量必须 ≥ 这个值才能激活
  2. **消耗量**：激活时会消耗这个百分比的能量

**示例**:
```csv
energy_cost
80.0    # 需要80%能量，激活后消耗80%
50.0    # 需要50%能量，激活后消耗50%（更容易激活）
100.0   # 需要满能量，激活后消耗全部能量（最强但最难）
30.0    # 需要30%能量，激活后消耗30%（频繁使用）
```

**推荐值**:
- 频繁使用型：30-40
- 平衡型：50-60 ⭐ 推荐
- 战略型：70-80
- 终极技型：90-100

### CSV 注释行

CSV 文件现在支持注释行（以 `#` 开头）：

```csv
ult_id,name,duration,energy_cost,bonus_bond_tag,visual_color_hex,scale_multiplier,description
# 这是注释行，会被自动跳过
# 字段说明：
# duration: 持续时间（秒）
# energy_cost: 能量消耗（百分比）
butcher_ult,血之狂怒,10.0,80.0,Martial,#FF3333,1.2,屠夫进入血之狂怒状态
```

## 能量消耗配置位置

### ~~1. 代码中的硬编码（已废弃）~~

~~**文件**: `scenes/skills/skill_ultimate_base.gd`~~
~~**第18行**: `var energy_cost: float = 80.0`~~

**现在改为从 CSV 读取！**

### 2. CSV 配置（推荐） ✅

**文件**: `config/player/ult_config.csv`

**字段**: `energy_cost` 列

**修改方法**:
1. 打开 `config/player/ult_config.csv`
2. 找到对应角色的行（如 `butcher_ult`）
3. 修改第4列的 `energy_cost` 值
4. 保存文件

**示例**:
```csv
# 修改前
butcher_ult,血之狂怒,10.0,80.0,Martial,#FF3333,1.2,描述

# 修改后（更容易激活）
butcher_ult,血之狂怒,10.0,50.0,Martial,#FF3333,1.2,描述
```

## 配置示例

### 示例1: 频繁使用的短爆发大招
```csv
butcher_ult,血之狂怒,5.0,30.0,Martial,#FF3333,1.2,短暂但频繁的爆发
```
- 持续5秒
- 只需30%能量
- 可以频繁使用

### 示例2: 平衡型大招（推荐）
```csv
butcher_ult,血之狂怒,10.0,50.0,Martial,#FF3333,1.2,平衡的持续时间和消耗
```
- 持续10秒
- 需要50%能量
- 使用频率适中

### 示例3: 战略性强力大招
```csv
butcher_ult,血之狂怒,15.0,80.0,Martial,#FF3333,1.2,持久且强大的变身
```
- 持续15秒
- 需要80%能量
- 需要积累但效果持久

### 示例4: 终极爆发大招
```csv
butcher_ult,血之狂怒,20.0,100.0,Martial,#FF3333,1.3,最强大的终极形态
```
- 持续20秒
- 需要满能量
- 最强大但最难积累

## 能量不足提示

### 已添加的飘字提示

**文件**: `scenes/skills/skill_ultimate_base.gd`

**位置**: `try_activate()` 方法

```gdscript
# 能量不足时显示
Global.spawn_floating_text(
    player_ref.global_position, 
    "能量不足 (45%/80%)",  # 显示当前能量/需求能量
    Color.ORANGE_RED
)
```

**效果**:
- 当能量不足时，会显示飘字：`能量不足 (45%/80%)`
- 颜色为橙红色，醒目提示

## 其他相关配置

### 能量恢复速度
**文件**: `config/player/player_config.csv`

**字段**: `energy_regen`

```csv
player_id,energy_regen
butcher,0.5  # 每秒恢复0.5点能量
pyro,2.0     # 每秒恢复2.0点能量（恢复更快）
```

### 最大能量值
**文件**: `config/player/player_config.csv`

**字段**: `max_energy`

```csv
player_id,max_energy
butcher,999   # 最大能量999
pyro,1500     # 最大能量1500（能量池更大）
```

## 推荐配置方案

### 方案1: 低门槛高频率
```csv
ult_id,name,duration,energy_cost,...
butcher_ult,血之狂怒,8.0,30.0,...
```
**特点**: 容易激活，频繁使用，战术灵活

### 方案2: 平衡型（推荐）⭐
```csv
ult_id,name,duration,energy_cost,...
butcher_ult,血之狂怒,10.0,50.0,...
```
**特点**: 适中频率，平衡的持续时间

### 方案3: 战略型
```csv
ult_id,name,duration,energy_cost,...
butcher_ult,血之狂怒,12.0,70.0,...
```
**特点**: 需要积累，但效果持久

### 方案4: 终极爆发
```csv
ult_id,name,duration,energy_cost,...
butcher_ult,血之狂怒,15.0,100.0,...
```
**特点**: 最强大，但使用频率最低

## 快速修改指南

### 想让大招更容易激活？

**修改**: `config/player/ult_config.csv`

```csv
# 找到对应角色的行，修改 energy_cost 列（第4列）
butcher_ult,血之狂怒,10.0,30.0,Martial,#FF3333,1.2,描述
#                        ^^^^
#                    改为30（从80改为30）
```

### 想让大招持续更久？

**修改**: `config/player/ult_config.csv`

```csv
# 找到对应角色的行，修改 duration 列（第3列）
butcher_ult,血之狂怒,15.0,80.0,Martial,#FF3333,1.2,描述
#                    ^^^^
#                改为15秒（从10改为15）
```

### 想让能量恢复更快？

**修改**: `config/player/player_config.csv`

```csv
player_id,energy_regen
butcher,2.0  # 从0.5改为2.0，恢复速度提升4倍
```

## 测试建议

1. **测试不同能量消耗**
   - 尝试 30、50、80、100 不同的值
   - 观察使用频率的变化

2. **测试不同持续时间**
   - 尝试 5、10、15、20 秒
   - 找到最舒适的持续时间

3. **平衡调整**
   - 低消耗 + 短持续 = 频繁小爆发
   - 高消耗 + 长持续 = 战略大招

## 总结

- **duration**: 大招持续时间（秒）- 控制变身持续多久
- **energy_cost**: 能量消耗（百分比）- 控制激活难度和使用频率
- **配置位置**: `config/player/ult_config.csv` ✅ 推荐
- **注释支持**: CSV 支持 `#` 开头的注释行
- **飘字提示**: 能量不足时自动显示

**推荐配置**: `duration=10.0, energy_cost=50.0` - 平衡且易用！
