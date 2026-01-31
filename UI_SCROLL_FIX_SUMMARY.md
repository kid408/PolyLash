# 角色选择界面滚动修复说明

## 问题描述
角色选择界面的角色列表在添加更多角色后会向下延伸，与武器选择区域重叠，导致UI布局混乱。

## 解决方案
为角色列表添加 ScrollContainer，限制其在 260px 高度内垂直滚动。

## 修改内容

### 1. 场景文件修改 (selection_panel.tscn)

**修改前的层级结构：**
```
PlayerContainerWrapper (Control)
└── PlayerContainer (HBoxContainer)
    └── 角色按钮...
```

**修改后的层级结构：**
```
PlayerContainerWrapper (Control)
└── PlayerScrollContainer (ScrollContainer)
    └── PlayerContainer (GridContainer)
        └── 角色按钮...
```

**关键配置：**
- `PlayerScrollContainer` 设置为填充整个 `PlayerContainerWrapper` (Full Rect)
- 禁用水平滚动 (`horizontal_scroll_mode = 0`)
- 启用垂直滚动 (`vertical_scroll_mode = 2`)
- `PlayerContainer` 设置 `size_flags_horizontal = SIZE_EXPAND_FILL` 以居中显示

### 2. 脚本文件修改 (selection_panel.gd)

#### 2.1 添加节点引用
```gdscript
@onready var player_scroll_container: ScrollContainer = $MarginContainer/HBoxContainer/MainContent/MiddleSection/PlayerContainerWrapper/PlayerScrollContainer
```

#### 2.2 更新 `_generate_player_buttons()` 函数
- 将 `var wrapper = player_container.get_parent()` 改为 `var scroll_container = player_scroll_container`
- 将新的 GridContainer 添加到 `scroll_container` 而不是 `wrapper`
- 设置 GridContainer 的 `size_flags_horizontal = SIZE_EXPAND_FILL` 以确保内容居中

## 效果
- 角色列表现在限制在 260px 高度内
- 当角色数量超过两行时，会自动出现垂直滚动条
- 不再与武器选择区域重叠
- 保持了原有的 8 列网格布局和居中对齐

## 测试建议
1. 添加超过 16 个角色，验证滚动条是否正常出现
2. 测试鼠标滚轮滚动是否流畅
3. 确认角色按钮点击和拖拽功能正常
4. 检查UI布局在不同分辨率下的表现
