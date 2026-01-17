# 开发指南

## 开发环境

### 系统要求

- **操作系统**: Windows 10/11 或 macOS 或 Linux
- **Godot 版本**: 4.0 或更高
- **内存**: 8GB 或更多
- **磁盘空间**: 5GB 或更多

### 开发工具

**推荐工具**:
- **Godot 4** - 游戏引擎
- **VS Code** - 代码编辑器
- **Git** - 版本控制
- **Excel 或 LibreOffice** - CSV 编辑

### 安装步骤

1. 下载并安装 Godot 4
2. 克隆项目仓库
3. 在 Godot 中打开项目
4. 等待项目加载完成

## 项目结构

### 目录说明

```
PolyLash/
├── scenes/              # 游戏场景和脚本
│   ├── arena/          # 竞技场场景
│   ├── unit/           # 单位（玩家、敌人）
│   ├── ui/             # UI 界面
│   ├── skills/         # 技能效果
│   ├── weapons/        # 武器效果
│   ├── projectiles/    # 投射物
│   ├── items/          # 物品
│   ├── particles/      # 粒子效果
│   └── components/     # 可复用组件
│
├── config/             # 配置文件（CSV）
│   ├── enemy/         # 敌人配置
│   ├── player/        # 玩家配置
│   ├── weapon/        # 武器配置
│   ├── wave/          # 波次配置
│   └── system/        # 系统配置
│
├── autoloads/         # 全局管理器
│   ├── global.gd
│   ├── config_manager.gd
│   ├── data_manager.gd
│   ├── upgrade_manager.gd
│   └── elite_config_manager.gd
│
├── assets/            # 游戏资源
│   ├── sprites/       # 精灵图片
│   ├── audio/         # 音频文件
│   └── font/          # 字体文件
│
├── effects/           # 特效
│   ├── flash.gdshader
│   └── flash_material.tres
│
└── docs/              # 文档
```

## 代码规范

### 命名规范

**脚本文件**:
- 使用蛇形命名法: `enemy_glutton.gd`
- 场景文件: `enemy_glutton.tscn`

**类名**:
- 使用帕斯卡命名法: `class_name EnemyGlutton`
- 继承关系清晰

**变量名**:
- 使用蛇形命名法: `var current_stage: int`
- 私有变量前缀 `_`: `var _internal_state`
- 常量全大写: `const MAX_STAGE = 5`

**函数名**:
- 使用蛇形命名法: `func _ready() -> void`
- 私有函数前缀 `_`: `func _update_visual()`
- 事件处理函数: `func _on_signal_name()`

### 代码风格

**缩进**:
- 使用 Tab 缩进（Godot 默认）
- 每个缩进级别一个 Tab

**注释**:
- 使用 `#` 单行注释
- 使用 `"""` 多行注释
- 为复杂逻辑添加注释

**代码组织**:
- 按功能分组代码
- 使用分隔符注释分组
- 相关函数放在一起

**示例**:
```gdscript
extends Enemy
class_name EnemyGlutton

# ==============================================================================
# 1. 属性配置
# ==============================================================================

@export var current_stage: int = 1
@export var mobs_eaten_count: int = 0

# ==============================================================================
# 2. 节点引用
# ==============================================================================

@onready var eating_area: Area2D = $EatingDetectionArea

# ==============================================================================
# 3. 初始化
# ==============================================================================

func _ready() -> void:
    super._ready()
    _setup_eating_detection()

# ==============================================================================
# 4. 主循环
# ==============================================================================

func _process(delta: float) -> void:
    super._process(delta)
    _try_eat_nearby_enemy()
```

## 开发工作流

### 1. 修改敌人属性

**步骤**:
1. 打开 `config/enemy/enemy_config.csv`
2. 找到要修改的敌人
3. 修改相应的属性值
4. 保存文件（UTF-8 No BOM）
5. 重启 Godot 编辑器
6. 测试修改效果

**示例**:
```csv
# 修改前
basic_enemy,100,10,150,...

# 修改后（增加血量）
basic_enemy,150,10,150,...
```

### 2. 添加新敌人

**步骤**:
1. 在 `enemy_config.csv` 中添加新行
2. 在 `enemy_visual.csv` 中添加视觉配置
3. 在波次配置中使用新敌人
4. 重启编辑器
5. 测试新敌人

**示例**:
```csv
# enemy_config.csv
new_enemy,120,12,160,0,15,8,5,...

# enemy_visual.csv
new_enemy,res://assets/sprites/Enemies/Enemy_New.png,1,1,1,1,1,...
```

### 3. 修改精英怪进化

**步骤**:
1. 打开 `config/enemy/elite_evolution_config.csv`
2. 修改相应阶段的属性倍数
3. 保存文件
4. 重启编辑器
5. 测试进化效果

**示例**:
```csv
# 修改前
enemy_glutton,2,2.0,1.2,2.067,...

# 修改后（增加血量倍数）
enemy_glutton,2,2.5,1.2,2.067,...
```

### 4. 添加新技能

**步骤**:
1. 创建技能脚本 `scenes/skills/players/skill_new.gd`
2. 继承自 `Skill` 基类
3. 实现 `_ready()` 和 `_process()` 方法
4. 在 `player_skills.csv` 中添加配置
5. 在玩家脚本中绑定技能
6. 测试技能效果

**示例**:
```gdscript
extends Skill
class_name SkillNew

func _ready() -> void:
    super._ready()
    # 初始化技能

func _process(delta: float) -> void:
    super._process(delta)
    # 更新技能
```

## 调试技巧

### 1. 打印调试信息

```gdscript
# 打印敌人信息
print(\"[Enemy] Health: \", stats.health)
print(\"[Enemy] Position: \", global_position)

# 打印配置信息
print(\"[Config] Enemy config: \", ConfigManager.get_enemy_config(\"basic_enemy\"))

# 打印精英怪信息
print(\"[EnemyGlutton] Stage: \", current_stage)
print(\"[EnemyGlutton] Mobs eaten: \", mobs_eaten_count)
```

### 2. 使用 Godot 调试器

- 在代码中设置断点
- 使用 F5 启动调试
- 逐步执行代码
- 查看变量值

### 3. 查看输出日志

- 打开 Godot 输出面板
- 查看 print 输出
- 查看错误信息
- 查看警告信息

### 4. 配置调试

```gdscript
# 打印所有配置
EliteConfigManager.print_all_configs()
ConfigManager.print_all_configs()

# 打印特定配置
var config = ConfigManager.get_enemy_config(\"basic_enemy\")
print(config)
```

## 常见任务

### 调整游戏难度

**增加敌人难度**:
1. 增加敌人血量
2. 增加敌人伤害
3. 增加敌人速度
4. 增加敌人数量

**减少敌人难度**:
1. 减少敌人血量
2. 减少敌人伤害
3. 减少敌人速度
4. 减少敌人数量

### 平衡游戏

**玩家太强**:
- 增加敌人属性
- 增加敌人数量
- 增加精英怪生成

**玩家太弱**:
- 减少敌人属性
- 减少敌人数量
- 增加玩家奖励

### 添加新内容

**添加新敌人**:
1. 创建敌人配置
2. 创建敌人脚本（可选）
3. 在波次中使用

**添加新技能**:
1. 创建技能脚本
2. 创建技能配置
3. 在玩家中绑定

**添加新玩家角色**:
1. 创建玩家脚本
2. 创建玩家配置
3. 在选择界面中添加

## 性能优化

### 1. 减少敌人数量

```gdscript
# 在 wave_config.csv 中减少 max_spawn
max_spawn,50  # 从 100 改为 50
```

### 2. 优化敌人 AI

```gdscript
# 减少 AI 更新频率
if Engine.get_frames_drawn() % 10 == 0:
    # 每 10 帧更新一次
```

### 3. 使用对象池

```gdscript
# 重用敌人对象而不是创建新对象
var enemy = enemy_pool.get_enemy()
enemy.reset()
```

## 版本控制

### Git 工作流

**创建分支**:
```bash
git checkout -b feature/new-enemy
```

**提交更改**:
```bash
git add .
git commit -m \"Add new enemy type\"
```

**推送分支**:
```bash
git push origin feature/new-enemy
```

**合并分支**:
```bash
git checkout main
git merge feature/new-enemy
```

### 提交信息规范

```
[类型] 简短描述

详细描述（可选）

- 修改项 1
- 修改项 2
```

**类型**:
- `feat` - 新功能
- `fix` - 修复 bug
- `docs` - 文档更新
- `style` - 代码风格
- `refactor` - 代码重构
- `perf` - 性能优化
- `test` - 测试

**示例**:
```
feat: Add new enemy type

- Added basic_enemy_v2 configuration
- Implemented new AI behavior
- Added visual effects

Closes #123
```

## 常见问题

### Q: 配置修改后没有生效？
A: 重启 Godot 编辑器，Godot 会缓存配置文件。

### Q: 如何调试敌人 AI？
A: 使用 print 输出敌人状态，或使用 Godot 调试器设置断点。

### Q: 如何优化游戏性能？
A: 减少敌人数量、优化 AI 更新频率、使用对象池。

### Q: 如何添加新功能？
A: 创建新脚本、添加配置、在相应系统中集成。

### Q: 如何测试修改？
A: 运行游戏、观察效果、查看输出日志。

## 相关资源

- [Godot 官方文档](https://docs.godotengine.org/)
- [GDScript 文档](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)
- [项目架构](ARCHITECTURE.md)
- [配置指南](CONFIGURATION.md)

---

**最后更新**: 2026年1月17日
