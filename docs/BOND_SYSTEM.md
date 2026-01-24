# 羁绊系统文档

## 📋 概述

羁绊系统为每个角色定义了三个维度的标签：**身世（Origin）**、**职能（Mastery）** 和 **战术（Tactic）**，并在UI中通过图标展示。

**当前阶段**: 仅实现底层数据结构和UI图标展示，不包含战斗属性加成或羁绊计算逻辑。

---

## 🎯 核心功能

### ✅ 已实现功能
- [x] 羁绊数据配置（CSV）
- [x] 羁绊图标加载器（BondUILoader）
- [x] 选择界面羁绊图标显示
- [x] 角色升级界面羁绊图标显示
- [x] 战斗HUD羁绊图标显示
- [x] 图标容错处理

---

## 📁 文件结构

### 新增文件
```
config/player/bond_config.csv          # 羁绊配置表
autoloads/bond_ui_loader.gd            # 羁绊UI加载器
autoloads/bond_ui_loader.gd.uid        # UID文件
```

### 修改文件
```
config/player/player_config.csv        # 添加羁绊标签列
scenes/ui/selection_panel/selection_panel.tscn    # 添加羁绊图标容器
scenes/ui/selection_panel/selection_panel.gd      # 羁绊图标更新逻辑
scenes/ui/selection_panel/character_upgrade.gd    # 角色卡片羁绊图标
scenes/ui/squad_hud/character_slot.tscn           # HUD羁绊图标容器
scenes/ui/squad_hud/character_slot.gd             # HUD羁绊图标加载
project.godot                                     # 注册BondUILoader
```

---

## 💾 数据结构

### player_config.csv（新增列）
```csv
player_id,origin_tag,mastery_tag,tactic_tag
butcher,martial,destruction,assault
pyro,arcane,destruction,assault
sapper,survivor,control,assist
weaver,arcane,control,assist
wind,martial,velocity,captain
herder,survivor,control,assist
```

### bond_config.csv
```csv
bond_id,bond_type,icon_path_index,display_name,description
martial,origin,1,武道世家,来自武道世家的战士
arcane,origin,2,秘术行者,掌握神秘力量的法师
survivor,origin,3,幸存者,在废土中生存下来的强者
destruction,mastery,1,毁灭打击,擅长造成大量伤害
velocity,mastery,2,极速,拥有超快的移动速度
control,mastery,3,控制大师,擅长控制敌人
assault,tactic,1,突击战术,快速突入敌阵
assist,tactic,2,支援战术,提供强大的支援
captain,tactic,3,指挥官,领导团队作战
```

### 字段说明
| 字段 | 类型 | 说明 |
|------|------|------|
| bond_id | String | 羁绊唯一标识 |
| bond_type | String | 羁绊类型（origin/mastery/tactic） |
| icon_path_index | int | 图标文件索引（1-7） |
| display_name | String | 显示名称 |
| description | String | 羁绊描述 |

---

## 🎨 图标资源

### 图标路径规则
```
身世: res://assets/sprites/Icons/origins/origin{index}.png
职能: res://assets/sprites/Icons/masterys/mastery{index}.png
战术: res://assets/sprites/Icons/tactics/tactic{index}.png
```

### 图标映射示例
```
martial (武道世家) → origin1.png
arcane (秘术行者) → origin2.png
survivor (幸存者) → origin3.png
destruction (毁灭打击) → mastery1.png
velocity (极速) → mastery2.png
control (控制大师) → mastery3.png
assault (突击战术) → tactic1.png
assist (支援战术) → tactic2.png
captain (指挥官) → tactic3.png
```

---

## 🔑 核心 API

### BondUILoader 方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `get_bond_icon(bond_tag, bond_type)` | String, String | Texture2D | 获取羁绊图标 |
| `get_bond_display_name(bond_tag)` | String | String | 获取显示名称 |
| `get_bond_description(bond_tag)` | String | String | 获取羁绊描述 |
| `get_bond_config(bond_tag)` | String | Dictionary | 获取完整配置 |
| `create_bond_icon_container(origin, mastery, tactic, size)` | String×3, int | HBoxContainer | 创建图标容器 |
| `update_bond_icons(container, origin, mastery, tactic)` | HBoxContainer, String×3 | void | 更新图标 |

---

## 📝 代码示例

### 1. 获取羁绊图标
```gdscript
# 获取单个图标
var texture = BondUILoader.get_bond_icon("martial", "origin")
if texture:
    icon_rect.texture = texture
```

### 2. 创建羁绊图标容器
```gdscript
# 创建包含3个图标的容器
var bond_icons = BondUILoader.create_bond_icon_container(
    "martial",      # 身世
    "destruction",  # 职能
    "assault",      # 战术
    24              # 图标大小
)
parent_node.add_child(bond_icons)
```

### 3. 更新现有图标
```gdscript
# 更新容器中的图标
BondUILoader.update_bond_icons(
    bond_icons_container,
    "arcane",
    "control",
    "assist"
)
```

### 4. 从角色配置加载
```gdscript
var config = ConfigManager.get_player_config("butcher")
var origin_tag = config.get("origin_tag", "")
var mastery_tag = config.get("mastery_tag", "")
var tactic_tag = config.get("tactic_tag", "")

var bond_icons = BondUILoader.create_bond_icon_container(
    origin_tag,
    mastery_tag,
    tactic_tag,
    20
)
```

---

## 🎨 UI 实现

### 1. 选择界面（selection_panel）
**位置**: 角色名称和羁绊标签下方

**节点结构**:
```
RightContent (VBoxContainer)
├── PlayerName (Label)
├── PlayerTies (Label)
├── BondIconsContainer (HBoxContainer) ← 新增
│   ├── OriginIcon (TextureRect, 24x24)
│   ├── MasteryIcon (TextureRect, 24x24)
│   └── TacticIcon (TextureRect, 24x24)
└── HSeparator
```

**更新逻辑**:
```gdscript
func _update_player_info(player_id: String) -> void:
    # ... 其他代码
    _update_bond_icons(player_id, config)

func _update_bond_icons(player_id: String, config: Dictionary) -> void:
    for child in bond_icons_container.get_children():
        child.queue_free()
    
    var origin_tag = config.get("origin_tag", "")
    var mastery_tag = config.get("mastery_tag", "")
    var tactic_tag = config.get("tactic_tag", "")
    
    BondUILoader.update_bond_icons(
        bond_icons_container,
        origin_tag,
        mastery_tag,
        tactic_tag
    )
```

### 2. 角色升级界面（character_upgrade）
**位置**: 角色卡片头部，羁绊标签下方

**实现**:
```gdscript
func _create_character_card(player_id: String) -> Control:
    # ... 创建名称和羁绊标签
    
    # 添加羁绊图标
    var bond_icons = BondUILoader.create_bond_icon_container(
        config.get("origin_tag", ""),
        config.get("mastery_tag", ""),
        config.get("tactic_tag", ""),
        20  # 图标大小
    )
    name_vbox.add_child(bond_icons)
```

### 3. 战斗HUD（character_slot）
**位置**: 能量条和头像之间

**节点结构**:
```
VBoxContainer
├── HealthBar (ProgressBar)
├── EnergyBar (ProgressBar)
├── BondIconsContainer (HBoxContainer) ← 新增
│   ├── OriginIcon (TextureRect, 18x18)
│   ├── MasteryIcon (TextureRect, 18x18)
│   └── TacticIcon (TextureRect, 18x18)
├── Portrait (TextureRect)
└── KeyLabel (Label)
```

**加载逻辑**:
```gdscript
func setup(p_player_id: String, key_number: int) -> void:
    # ... 其他初始化
    _load_bond_icons(p_player_id)

func _load_bond_icons(p_player_id: String) -> void:
    var config = ConfigManager.get_player_config(p_player_id)
    var bonds = [
        {"tag": config.get("origin_tag", ""), "type": "origin"},
        {"tag": config.get("mastery_tag", ""), "type": "mastery"},
        {"tag": config.get("tactic_tag", ""), "type": "tactic"}
    ]
    
    for bond in bonds:
        var icon_rect = TextureRect.new()
        icon_rect.custom_minimum_size = Vector2(18, 18)
        icon_rect.texture = BondUILoader.get_bond_icon(bond.tag, bond.type)
        bond_icons_container.add_child(icon_rect)
```

---

## 🎯 图标尺寸规范

| 界面 | 图标大小 | 间距 | 说明 |
|------|---------|------|------|
| 选择界面 | 24×24 | 4px | 标准尺寸 |
| 角色升级 | 20×20 | 4px | 略小，适配卡片 |
| 战斗HUD | 18×18 | 2px | 最小，节省空间 |

---

## ⚠️ 容错处理

### 1. 图标文件不存在
```gdscript
var texture = BondUILoader.get_bond_icon(bond_tag, bond_type)
if texture:
    icon_rect.texture = texture
else:
    # 显示占位符
    icon_rect.modulate = Color(0.3, 0.3, 0.3, 0.5)
```

### 2. 配置缺失
```gdscript
var origin_tag = config.get("origin_tag", "")
if origin_tag == "":
    print("[Warning] 角色缺少羁绊标签")
    return
```

### 3. 类型不匹配
```gdscript
# BondUILoader 会自动验证类型
if config.bond_type != bond_type:
    printerr("羁绊类型不匹配")
    return null
```

---

## 🔧 调试方法

### 打印羁绊配置
```gdscript
print(BondUILoader.bond_configs)
```

### 测试图标加载
```gdscript
var texture = BondUILoader.get_bond_icon("martial", "origin")
if texture:
    print("图标加载成功")
else:
    print("图标加载失败")
```

### 验证角色配置
```gdscript
var config = ConfigManager.get_player_config("butcher")
print("Origin: %s" % config.get("origin_tag", ""))
print("Mastery: %s" % config.get("mastery_tag", ""))
print("Tactic: %s" % config.get("tactic_tag", ""))
```

---

## 🚀 未来扩展

### 1. 羁绊计算系统
```gdscript
# 计算队伍羁绊加成
func calculate_team_bonds(player_ids: Array[String]) -> Dictionary:
    var bond_counts = {}
    for player_id in player_ids:
        var config = ConfigManager.get_player_config(player_id)
        # 统计羁绊数量
    return bond_counts
```

### 2. 羁绊效果系统
```gdscript
# 应用羁绊效果
func apply_bond_effects(player: Player, active_bonds: Dictionary):
    for bond_id in active_bonds:
        match bond_id:
            "martial":
                player.attack_damage *= 1.1
            "destruction":
                player.skill_damage *= 1.15
```

### 3. 羁绊UI提示
```gdscript
# 显示羁绊激活状态
func show_bond_status(bond_id: String, count: int, required: int):
    var status_label = Label.new()
    if count >= required:
        status_label.text = "✓ %s (%d/%d)" % [bond_id, count, required]
        status_label.modulate = Color.GREEN
    else:
        status_label.text = "○ %s (%d/%d)" % [bond_id, count, required]
```

---

## 📚 相关文档

- [角色配置文档](PLAYERS.md)
- [UI系统文档](../README.md)

---

## 🎉 总结

羁绊系统的底层数据和UI展示已完整实现：

- ✅ **数据层**: CSV配置，支持扩展
- ✅ **加载器**: BondUILoader，统一管理
- ✅ **UI展示**: 三个界面完整集成
- ✅ **容错处理**: 图标缺失不崩溃
- ✅ **代码规范**: 清晰注释，易维护

系统设计灵活，为后续的羁绊计算和效果系统预留了扩展空间！
