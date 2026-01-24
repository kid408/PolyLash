# 仓库系统实现总结

## 📋 实现概述

成功实现了一个基于 CSV 配置的动态仓库系统，包含完整的 UI、数据管理和持久化功能。

## 🎯 实现的功能

### ✅ 核心功能
- [x] CSV 配置驱动的道具系统
- [x] 动态生成仓库格子（8列 × 6行，共48个格子）
- [x] 道具图标显示（居中，保持宽高比）
- [x] 鼠标悬浮提示（Tooltip）
- [x] 数据持久化（保存到本地文件）
- [x] 默认道具初始化（1-9号道具）
- [x] 添加道具接口（预留游戏内掉落）
- [x] 仓库按钮集成到角色选择界面

### ✅ UI 特性
- [x] 窗口大小自适应（根据容量和列数计算）
- [x] 格子悬浮高亮效果（金色边框）
- [x] Tooltip 跟随鼠标
- [x] 关闭按钮
- [x] 滚动容器（支持大容量仓库）

### ✅ 扩展性
- [x] 预留道具点击接口
- [x] 支持配置修改（容量、列数）
- [x] 易于添加新道具（仅需修改 CSV）

## 📁 新增文件

### 1. 配置文件
```
config/item/item_config.csv
```
- 道具配置表（itemType, description, resourcePath）
- 默认包含 1-9 号道具

### 2. 核心脚本
```
autoloads/warehouse_manager.gd
autoloads/warehouse_manager.gd.uid
```
- 仓库管理器 Autoload
- 负责数据管理、配置加载、持久化

### 3. UI 文件
```
scenes/ui/warehouse_ui.gd
scenes/ui/warehouse_ui.gd.uid
scenes/ui/warehouse_ui.tscn
```
- 仓库界面脚本和场景
- 动态生成格子、显示道具、处理交互

### 4. 文档
```
docs/WAREHOUSE_SYSTEM.md
docs/WAREHOUSE_USAGE_EXAMPLES.md
docs/WAREHOUSE_QUICK_REFERENCE.md
WAREHOUSE_IMPLEMENTATION_SUMMARY.md
```
- 完整的系统文档
- 使用示例和快速参考

## 🔧 修改的文件

### 1. config/system/game_config.csv
**新增配置项**:
```csv
WarehouseCapacity,48,仓库容量（格子数量）
WarehouseColumns,8,仓库列数
```

### 2. scenes/ui/selection_panel/selection_panel.tscn
**新增节点**:
```
[node name="WarehouseButton" type="Button"]
- 位置: 在"强化角色"按钮下方
- 文本: "仓库"
- 样式: 与"强化角色"按钮一致
```

### 3. scenes/ui/selection_panel/selection_panel.gd
**新增代码**:
```gdscript
# 节点引用
@onready var warehouse_button: Button = $MarginContainer/HBoxContainer/RightPanel/WarehouseButton

# 初始化连接
warehouse_button.pressed.connect(_on_warehouse_pressed)

# 按钮回调
func _on_warehouse_pressed() -> void:
    var warehouse_scene = load("res://scenes/ui/warehouse_ui.tscn")
    var warehouse_ui = warehouse_scene.instantiate()
    add_child(warehouse_ui)
```

### 4. project.godot
**新增 Autoload**:
```ini
WarehouseManager="*res://autoloads/warehouse_manager.gd"
```

## 🎨 UI 节点层级结构

```
WarehouseUI (Panel) - 主容器
├── MarginContainer (20px 边距)
│   └── VBoxContainer (16px 间距)
│       ├── TopBar (HBoxContainer, 40px 高度)
│       │   ├── TitleLabel (Label) - "仓库"
│       │   └── CloseButton (Button) - "关闭"
│       └── ScrollContainer (支持滚动)
│           └── GridContainer (8列, 8px 间距)
│               ├── Slot_0 (Button, 64x64)
│               ├── Slot_1 (Button, 64x64)
│               └── ... (共 48 个)
└── TooltipPanel (Panel, 跟随鼠标)
    └── MarginContainer (10px 边距)
        └── TooltipLabel (Label) - 道具描述
```

## 📊 数据流程

```
游戏启动
    ↓
WarehouseManager._ready()
    ↓
加载 item_config.csv → item_configs{}
    ↓
加载 warehouse_data.json → warehouse_items{}
    ↓
如果首次运行 → 初始化默认道具 (1-9)
    ↓
用户点击"仓库"按钮
    ↓
实例化 WarehouseUI
    ↓
读取配置 (WarehouseCapacity, WarehouseColumns)
    ↓
生成 48 个格子 (GridContainer)
    ↓
刷新道具显示 (_refresh_items)
    ↓
用户交互 (悬浮/点击)
    ↓
显示 Tooltip / 执行操作
    ↓
添加/移除道具
    ↓
保存到 warehouse_data.json
```

## 🔑 核心 API

### WarehouseManager
```gdscript
# 添加道具（自动寻找空槽位）
WarehouseManager.add_item(item_type: int) -> bool

# 移除道具
WarehouseManager.remove_item(slot_index: int) -> bool

# 获取槽位道具
WarehouseManager.get_item_at_slot(slot_index: int) -> int

# 获取道具配置
WarehouseManager.get_item_config(item_type: int) -> Dictionary

# 获取所有道具
WarehouseManager.get_all_items() -> Dictionary

# 清空仓库
WarehouseManager.clear_warehouse() -> void

# 保存数据
WarehouseManager.save_warehouse_data() -> void
```

### WarehouseUI
```gdscript
# 添加道具并刷新UI
warehouse_ui.add_item_to_warehouse(item_type: int) -> bool

# 刷新显示
warehouse_ui._refresh_items() -> void
```

## 📐 UI 参数配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| warehouse_capacity | 48 | 仓库容量（格子总数） |
| warehouse_columns | 8 | 仓库列数 |
| slot_size | 64 | 格子大小（像素） |
| slot_spacing | 8 | 格子间距（像素） |
| margin | 20 | 外边距（像素） |
| top_bar_height | 60 | 标题栏高度（像素） |

### 窗口大小计算
```gdscript
rows = ceil(capacity / columns)  # 6 行
grid_width = columns * slot_size + (columns - 1) * slot_spacing  # 568px
grid_height = rows * slot_size + (rows - 1) * slot_spacing  # 424px
total_width = grid_width + margin * 2  # 608px
total_height = grid_height + margin * 2 + top_bar_height  # 524px
```

## 🎨 视觉样式

### 格子样式
- **背景色**: `#2a2a2a` (深灰色)
- **边框**: 1px, `#4d4d4d` (灰色)
- **悬浮边框**: 2px, `#ffd700` (金色)
- **圆角**: 4px

### Tooltip 样式
- **背景色**: `#262626` (95% 不透明度)
- **边框**: 2px, `#cdb34d` (金色)
- **圆角**: 6px
- **字体大小**: 16px
- **偏移**: (15, 15) 像素

### 主窗口样式
- **背景色**: `#1a1a1a` (95% 不透明度)
- **圆角**: 10px
- **阴影**: 10px, 黑色 50% 不透明度

## 🔄 数据持久化

### 保存位置
```
user://warehouse_data.json
```

### 数据格式
```json
{
  "0": 1,
  "1": 2,
  "2": 3,
  "3": 4,
  "4": 5,
  "5": 6,
  "6": 7,
  "7": 8,
  "8": 9
}
```

### 保存时机
- 添加道具时自动保存
- 移除道具时自动保存
- 清空仓库时自动保存

## 🚀 使用示例

### 1. 打开仓库
```gdscript
# 在角色选择界面点击"仓库"按钮
# 或在代码中：
var warehouse_scene = load("res://scenes/ui/warehouse_ui.tscn")
var warehouse_ui = warehouse_scene.instantiate()
add_child(warehouse_ui)
```

### 2. 添加道具（游戏内掉落）
```gdscript
# 敌人死亡时
func _on_enemy_died():
    var item_type = randi() % 9 + 1  # 随机 1-9
    if WarehouseManager.add_item(item_type):
        print("获得道具: %d" % item_type)
    else:
        print("仓库已满")
```

### 3. 检查仓库状态
```gdscript
# 检查是否已满
var items = WarehouseManager.get_all_items()
if items.size() >= WarehouseManager.warehouse_capacity:
    print("仓库已满")

# 统计特定道具数量
var count = 0
for slot in items.keys():
    if items[slot] == item_type:
        count += 1
```

## 🔧 配置修改

### 修改仓库容量
编辑 `config/system/game_config.csv`:
```csv
WarehouseCapacity,64,仓库容量（格子总数）
WarehouseColumns,8,仓库列数
```

### 添加新道具
编辑 `config/item/item_config.csv`:
```csv
10,雷霆之锤 - 增加暴击率,res://assets/sprites/Item/Icon10.png
11,暗影斗篷 - 提升闪避,res://assets/sprites/Item/Icon11.png
```

## 🎯 预留扩展接口

### 1. 道具点击事件
```gdscript
# warehouse_ui.gd 中的 _on_slot_pressed 方法
func _on_slot_pressed(slot_index: int) -> void:
    var item_type = WarehouseManager.get_item_at_slot(slot_index)
    if item_type > 0:
        # TODO: 添加道具使用/移除逻辑
        pass
```

### 2. 道具效果系统
```gdscript
# 可以创建 ItemEffectManager 来处理道具效果
func apply_item_effect(item_type: int):
    match item_type:
        1: player.health += 50
        2: player.max_energy += 10
        # ...
```

### 3. 道具分类/品质
```gdscript
# 在 item_config.csv 中添加字段
itemType,description,resourcePath,category,quality
1,红色药水,res://...,consumable,common
```

## ✅ 测试清单

- [x] 打开仓库界面
- [x] 显示默认道具（1-9号）
- [x] 鼠标悬浮显示 Tooltip
- [x] Tooltip 跟随鼠标移动
- [x] 关闭仓库界面
- [x] 添加道具到仓库
- [x] 仓库数据持久化
- [x] 重启游戏后数据保留
- [x] 仓库已满时无法添加
- [x] 窗口大小自适应

## 📝 后续优化建议

1. **道具使用系统**: 实现道具点击后的使用/丢弃功能
2. **道具分类**: 添加道具类型（装备、消耗品、材料）
3. **道具品质**: 添加品质系统（普通、稀有、史诗）
4. **道具排序**: 实现按类型/品质排序
5. **道具搜索**: 添加搜索/筛选功能
6. **道具堆叠**: 支持同类道具堆叠
7. **批量操作**: 支持批量使用/丢弃
8. **图标预加载**: 优化性能，预加载常用图标
9. **动画效果**: 添加道具获得/使用动画
10. **音效**: 添加打开仓库、获得道具的音效

## 🐛 已知限制

1. 当前版本不支持道具堆叠（每个格子只能放一个道具）
2. 道具排序功能未实现
3. 道具搜索/筛选功能未实现
4. 道具详情面板未实现
5. 道具交易/出售功能未实现

## 📚 相关文档

- [完整系统文档](docs/WAREHOUSE_SYSTEM.md)
- [使用示例](docs/WAREHOUSE_USAGE_EXAMPLES.md)
- [快速参考](docs/WAREHOUSE_QUICK_REFERENCE.md)

## 🎉 总结

仓库系统已完整实现，包含：
- ✅ 完整的数据管理（WarehouseManager）
- ✅ 美观的 UI 界面（WarehouseUI）
- ✅ CSV 配置驱动（易于扩展）
- ✅ 数据持久化（自动保存）
- ✅ 预留扩展接口（易于二次开发）
- ✅ 详细的文档（快速上手）

系统设计灵活，易于扩展，可以满足大多数道具管理需求。所有代码都有详细注释，方便后续维护和功能扩展。
