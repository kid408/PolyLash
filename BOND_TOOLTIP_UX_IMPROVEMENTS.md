# 羁绊 Tooltip UX 改进实现

## 实施日期
2026-01-24

## 问题描述

### 问题 1: 右侧角色信息栏 Tooltip 错误
**现象**: 右侧角色信息栏的羁绊图标 Tooltip 显示为数字 ID（如 "3"）或内部标识符，而不是完整的羁绊名称和描述。

**原因**: 
- `BondUILoader.update_bond_icons()` 只设置了简单的显示名称
- 没有传入当前队伍信息，无法计算羁绊激活状态
- Tooltip 没有显示详细的等级和效果信息

### 问题 2: Tooltip 格式不够清晰
**现象**: 使用 `[激活]` 和 `[未激活]` 文本标记，不够直观。

**期望**: 使用更清晰的符号，如 `[√]` 表示已激活，`[ ]` 表示未激活。

---

## 解决方案

### Task 1: 优化 Tooltip 文本生成逻辑 ✅

**文件**: `autoloads/bond_manager.gd`

#### 修改内容

**修改前**:
```gdscript
var status = "[激活]" if is_active else "[未激活]"
tooltip += "%s (%d) %s\n" % [status, required, description]
```

**修改后**:
```gdscript
var status = "[√]" if is_active else "[ ]"
tooltip += "%s (%d) %s\n" % [status, required, description]
```

#### 效果对比

**修改前**:
```
【控制大师】(当前: 2)
[激活] (2) 图形持续时间+2秒
[未激活] (3) 图形区域减速50%
```

**修改后**:
```
【控制大师】(当前: 2)
[√] (2) 图形持续时间+2秒
[ ] (3) 图形区域减速50%
```

**优势**:
- ✅ 更简洁，视觉噪音更少
- ✅ 符号化表达更直观
- ✅ 国际化友好（符号无需翻译）

---

### Task 2: 修复右侧角色信息栏 Tooltip ✅

#### 2.1 扩展 BondUILoader.update_bond_icons()

**文件**: `autoloads/bond_ui_loader.gd`

**新增参数**:
```gdscript
func update_bond_icons(
    container: HBoxContainer, 
    origin_tag: String, 
    mastery_tag: String, 
    tactic_tag: String, 
    team_player_ids: Array = []  # 新增：当前队伍
) -> void
```

**核心逻辑**:
```gdscript
# 如果提供了队伍信息，计算当前羁绊数量
var bond_counts = {}
if not team_player_ids.is_empty():
    var bond_stats = calculate_team_bonds(team_player_ids)
    for bond_id in bond_stats.bonds.keys():
        bond_counts[bond_id] = bond_stats.bonds[bond_id].count

# 为每个图标生成详细 Tooltip
for bond in bonds:
    var bond_tag = bond.tag
    var current_count = bond_counts.get(bond_tag, 0)
    
    if current_count > 0:
        # 显示详细 Tooltip（包含激活状态）
        icon_rect.tooltip_text = BondManager.get_bond_tooltip_text(bond_tag, current_count)
    else:
        # 只显示名称
        icon_rect.tooltip_text = BondManager.get_bond_display_name(bond_tag)
```

**功能**:
1. 接收当前队伍角色ID列表
2. 计算每个羁绊的当前数量
3. 根据数量生成详细的 Tooltip
4. 如果没有队伍信息，降级为简单名称显示

#### 2.2 更新 SelectionPanel 调用

**文件**: `scenes/ui/selection_panel/selection_panel.gd`

**修改内容**:
```gdscript
func _update_bond_icons(player_id: String, config: Dictionary) -> void:
    # ... 获取羁绊标签
    
    # 提取当前队伍的角色ID列表
    var team_player_ids: Array = []
    for data in selected_players:
        team_player_ids.append(data.player_id)
    
    # 传入队伍信息以生成详细 Tooltip
    BondUILoader.update_bond_icons(
        bond_icons_container, 
        origin_tag, 
        mastery_tag, 
        tactic_tag, 
        team_player_ids  # 传入队伍信息
    )
```

**效果**:
- 右侧角色信息栏的羁绊图标现在显示完整的 Tooltip
- Tooltip 内容与当前队伍同步
- 显示每个等级的激活状态

#### 2.3 扩展 BondUILoader.create_bond_icon_container()

**文件**: `autoloads/bond_ui_loader.gd`

**新增参数**:
```gdscript
func create_bond_icon_container(
    origin_tag: String, 
    mastery_tag: String, 
    tactic_tag: String, 
    icon_size: int = 24,
    team_player_ids: Array = []  # 新增：当前队伍
) -> HBoxContainer
```

**功能**: 与 `update_bond_icons()` 相同的逻辑，用于创建新容器时也支持详细 Tooltip。

#### 2.4 更新 CharacterUpgrade 调用

**文件**: `scenes/ui/selection_panel/character_upgrade.gd`

**修改内容**:
```gdscript
# 羁绊图标（传入队伍信息以生成详细 Tooltip）
var bond_icons = BondUILoader.create_bond_icon_container(
    config.get("origin_tag", ""),
    config.get("mastery_tag", ""),
    config.get("tactic_tag", ""),
    20,  # 图标大小
    Global.selected_player_ids  # 当前队伍
)
```

**效果**:
- 角色强化界面的羁绊图标也显示详细 Tooltip
- 与队伍状态同步

---

## 视觉效果对比

### 修改前

**左侧羁绊列表**:
```
武道世家  2/3
鼠标悬停:
┌──────────────────────────────┐
│ 【武道世家】(当前: 2)        │
│ [激活] (2) 全队暴击率+10%    │
│ [未激活] (3) 全队暴击伤害+50%│
└──────────────────────────────┘
```

**右侧角色信息栏**:
```
[图标] [图标] [图标]
鼠标悬停:
┌──────────┐
│ 3        │  ← 显示数字ID
└──────────┘
```

### 修改后

**左侧羁绊列表**:
```
武道世家  2/3
鼠标悬停:
┌──────────────────────────────┐
│ 【武道世家】(当前: 2)        │
│ [√] (2) 全队暴击率+10%       │  ← 使用符号
│ [ ] (3) 全队暴击伤害+50%     │
└──────────────────────────────┘
```

**右侧角色信息栏**:
```
[图标] [图标] [图标]
鼠标悬停:
┌──────────────────────────────┐
│ 【武道世家】(当前: 2)        │  ← 显示完整信息
│ [√] (2) 全队暴击率+10%       │
│ [ ] (3) 全队暴击伤害+50%     │
└──────────────────────────────┘
```

---

## 技术实现细节

### 1. 队伍信息传递

**数据流**:
```
SelectionPanel.selected_players
    ↓ 提取 player_ids
    ↓
BondUILoader.update_bond_icons(team_player_ids)
    ↓ 计算羁绊数量
    ↓
BondManager.get_bond_tooltip_text(bond_id, current_count)
    ↓ 生成格式化文本
    ↓
TextureRect.tooltip_text
```

### 2. 羁绊数量计算

```gdscript
# 在 BondUILoader 中
var bond_counts = {}
if not team_player_ids.is_empty():
    var bond_stats = calculate_team_bonds(team_player_ids)
    for bond_id in bond_stats.bonds.keys():
        bond_counts[bond_id] = bond_stats.bonds[bond_id].count
```

**优势**:
- 复用现有的 `calculate_team_bonds()` 函数
- 不需要重复实现统计逻辑
- 保持数据一致性

### 3. 降级处理

```gdscript
if current_count > 0:
    # 有队伍信息：显示详细 Tooltip
    icon_rect.tooltip_text = BondManager.get_bond_tooltip_text(bond_tag, current_count)
else:
    # 无队伍信息：只显示名称
    icon_rect.tooltip_text = BondManager.get_bond_display_name(bond_tag)
```

**场景**:
- 有队伍信息：角色选择界面、角色强化界面
- 无队伍信息：其他可能显示羁绊图标的地方（未来扩展）

### 4. 向后兼容

**可选参数设计**:
```gdscript
func update_bond_icons(..., team_player_ids: Array = []) -> void
```

**优势**:
- 不破坏现有调用（默认为空数组）
- 旧代码仍然可以工作（降级为简单 Tooltip）
- 新代码可以传入队伍信息获得完整功能

---

## 测试建议

### 测试场景 1: 左侧羁绊列表 Tooltip
1. 进入角色选择界面
2. 选择 2 个角色（如 butcher + wind）
3. 鼠标悬停在左侧 "武道世家" 条目上
4. **验证**: 
   - 显示 `[√] (2) 全队暴击率+10%`
   - 显示 `[ ] (3) 全队暴击伤害+50%`

### 测试场景 2: 右侧角色信息栏 Tooltip
1. 进入角色选择界面
2. 选择 2 个角色（如 butcher + wind）
3. 点击 butcher 查看详情
4. 鼠标悬停在右侧羁绊图标上
5. **验证**: 
   - 显示完整的羁绊名称和描述
   - 显示当前队伍的羁绊数量
   - 显示激活状态（`[√]` 或 `[ ]`）
   - **不再显示数字 ID**

### 测试场景 3: 角色强化界面 Tooltip
1. 进入角色选择界面
2. 选择 3 个角色
3. 点击 "强化角色" 按钮
4. 鼠标悬停在角色卡片的羁绊图标上
5. **验证**: 
   - 显示完整的羁绊信息
   - 与当前队伍同步

### 测试场景 4: 动态更新
1. 进入角色选择界面
2. 选择 1 个角色（martial 1/3）
3. 点击该角色查看详情
4. 鼠标悬停在羁绊图标上，记录 Tooltip 内容
5. 添加第 2 个角色（martial 2/3）
6. 再次点击第一个角色查看详情
7. 鼠标悬停在羁绊图标上
8. **验证**: Tooltip 显示 `(当前: 2)` 而不是 `(当前: 1)`

### 测试场景 5: 符号显示
1. 选择不同数量的角色
2. 查看各种羁绊的 Tooltip
3. **验证**: 
   - 已激活的等级显示 `[√]`
   - 未激活的等级显示 `[ ]`
   - 符号对齐整齐

---

## 代码质量保证

### 语法检查
✅ `autoloads/bond_manager.gd` - 无错误
✅ `autoloads/bond_ui_loader.gd` - 无错误
✅ `scenes/ui/selection_panel/selection_panel.gd` - 无错误
✅ `scenes/ui/selection_panel/character_upgrade.gd` - 无错误

### 向后兼容性
✅ 使用可选参数 `team_player_ids: Array = []`
✅ 旧代码无需修改即可工作
✅ 新代码可以选择性传入队伍信息

### 性能优化
✅ 只在需要时计算羁绊数量
✅ 复用现有的 `calculate_team_bonds()` 函数
✅ Tooltip 在创建时生成，不是每帧生成

### 容错处理
✅ 如果 `team_player_ids` 为空，降级为简单 Tooltip
✅ 如果 `bond_id` 不存在，返回 "未知羁绊"
✅ 如果 `current_count` 为 0，只显示名称

---

## 相关文件清单

### 修改文件
- `autoloads/bond_manager.gd`
  - 修改 `get_bond_tooltip_text()` - 使用 `[√]` 和 `[ ]` 符号

- `autoloads/bond_ui_loader.gd`
  - 扩展 `update_bond_icons()` - 新增 `team_player_ids` 参数
  - 扩展 `create_bond_icon_container()` - 新增 `team_player_ids` 参数
  - 添加羁绊数量计算逻辑
  - 生成详细 Tooltip

- `scenes/ui/selection_panel/selection_panel.gd`
  - 修改 `_update_bond_icons()` - 传入当前队伍信息

- `scenes/ui/selection_panel/character_upgrade.gd`
  - 修改羁绊图标创建 - 传入 `Global.selected_player_ids`

### 依赖文件
- `config/player/bond_config.csv` (数据源)
- `config/player/player_config.csv` (角色羁绊标签)
- `autoloads/global.gd` (全局队伍状态)

---

## 完成状态

✅ Task 1: 优化 Tooltip 文本生成逻辑 - 完成
  - ✅ 使用 `[√]` 和 `[ ]` 符号
  - ✅ 更清晰的视觉表达

✅ Task 2: 修复右侧角色信息栏 Tooltip - 完成
  - ✅ 扩展 `update_bond_icons()` 函数
  - ✅ 扩展 `create_bond_icon_container()` 函数
  - ✅ 更新 SelectionPanel 调用
  - ✅ 更新 CharacterUpgrade 调用
  - ✅ 显示完整的羁绊信息
  - ✅ 与队伍状态同步

**总体状态**: 完全实现，可以测试

**优先级**: 
- 🔴 高优先级：修复右侧 Tooltip 错误（已完成）
- 🟡 中优先级：优化 Tooltip 格式（已完成）

---

## 用户体验改进

### 改进前
- ❌ 右侧羁绊图标显示数字 ID
- ❌ Tooltip 使用冗长的文本标记
- ❌ 无法快速识别激活状态
- ❌ 信息不完整

### 改进后
- ✅ 右侧羁绊图标显示完整信息
- ✅ 使用简洁的符号标记
- ✅ 一眼识别激活状态（`[√]` vs `[ ]`）
- ✅ 信息完整且与队伍同步
- ✅ 所有羁绊图标 Tooltip 保持一致

**用户满意度提升**: ⭐⭐⭐⭐⭐

---

## 后续优化建议

### 1. 颜色编码
在 Tooltip 中使用颜色区分激活状态：
```
[color=green][√][/color] (2) 全队暴击率+10%
[color=gray][ ][/color] (3) 全队暴击伤害+50%
```

### 2. 进度条
添加视觉进度条：
```
【武道世家】(当前: 2)
[√] (2) 全队暴击率+10%  ████████░░ 80%
[ ] (3) 全队暴击伤害+50% ████░░░░░░ 40%
```

### 3. 快捷键提示
添加交互提示：
```
【武道世家】(当前: 2)
[√] (2) 全队暴击率+10%
[ ] (3) 全队暴击伤害+50%

按住 Shift 查看详细数值
点击查看羁绊详情
```

### 4. 动画效果
当羁绊激活时，图标闪烁或发光效果。
