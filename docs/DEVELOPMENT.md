# 开发指南

本文档提供PolyLash项目的开发指南、最佳实践和常见问题解决方案。

---

## 目录

- [开发环境设置](#开发环境设置)
- [项目规范](#项目规范)
- [开发流程](#开发流程)
- [常见任务](#常见任务)
- [调试技巧](#调试技巧)
- [性能优化](#性能优化)
- [常见问题](#常见问题)

---

## 开发环境设置

### 必需工具

#### 1. Godot Engine 4.x
- **下载**: [Godot官网](https://godotengine.org/)
- **版本**: 4.x或更高
- **推荐**: 使用最新稳定版

#### 2. 代码编辑器
推荐使用以下编辑器之一：

**VS Code** (推荐)
- 安装插件：godot-tools
- 配置GDScript语法高亮
- 配置代码格式化

**Godot内置编辑器**
- 集成度高
- 调试方便
- 功能相对简单

#### 3. 版本控制
- **Git**: 必需
- **GitHub Desktop**: 可选，图形化界面

### 项目设置

#### 1. 克隆项目
```bash
git clone [项目地址]
cd PolyLash_Project
```

#### 2. 打开项目
1. 启动Godot Engine
2. 点击"导入"
3. 选择`project.godot`文件
4. 点击"导入并编辑"

#### 3. 验证配置
1. 按F5运行游戏
2. 检查控制台是否有错误
3. 验证配置加载成功

---

## 项目规范

### 代码规范

#### 命名规范

**变量和函数**: snake_case
```gdscript
var player_health: float = 100.0
func calculate_damage(base_damage: float) -> float:
```

**类名**: PascalCase
```gdscript
class_name PlayerBase
class_name SkillManager
```

**常量**: UPPER_SNAKE_CASE
```gdscript
const MAX_HEALTH: float = 1000.0
const ENERGY_REGEN_RATE: float = 0.5
```

**私有变量**: 前缀下划线
```gdscript
var _internal_state: int = 0
func _private_method() -> void:
```

#### 类型提示

**始终使用类型提示**（GDScript 4.x）：
```gdscript
# 变量类型提示
var health: float = 100.0
var player_name: String = "Player"
var enemies: Array[Enemy] = []

# 函数类型提示
func calculate_damage(base: float, multiplier: float) -> float:
    return base * multiplier

# 参数类型提示
func spawn_enemy(enemy_scene: PackedScene, position: Vector2) -> Enemy:
    var enemy: Enemy = enemy_scene.instantiate()
    enemy.global_position = position
    return enemy
```

#### 注释规范

**文件头注释**:
```gdscript
## ==============================================================================
## 类名 - 简短描述
## ==============================================================================
## 
## 详细说明:
## - 功能1
## - 功能2
## 
## 使用方法:
##   var instance = ClassName.new()
##   instance.method()
## 
## ==============================================================================
```

**函数注释**:
```gdscript
## 计算伤害
## 
## 参数:
## - base_damage: 基础伤害
## - multiplier: 伤害倍率
## 
## 返回:
## - 计算后的伤害值
func calculate_damage(base_damage: float, multiplier: float) -> float:
    return base_damage * multiplier
```

**变量注释**:
```gdscript
## 玩家当前生命值
var health: float = 100.0

## 是否处于无敌状态
var is_invincible: bool = false
```

#### 代码格式

**缩进**: 使用Tab（Godot默认）

**空行**:
- 函数之间空一行
- 逻辑块之间空一行
- 类定义后空一行

**行长度**: 建议不超过100字符

**示例**:
```gdscript
extends Node
class_name ExampleClass

# ==============================================================================
# 常量定义
# ==============================================================================

const MAX_VALUE: int = 100

# ==============================================================================
# 变量定义
# ==============================================================================

var current_value: int = 0

# ==============================================================================
# 生命周期函数
# ==============================================================================

func _ready() -> void:
    initialize()

func _process(delta: float) -> void:
    update_value(delta)

# ==============================================================================
# 公共方法
# ==============================================================================

func initialize() -> void:
    current_value = 0

func update_value(delta: float) -> void:
    current_value += int(delta * 10)
    current_value = min(current_value, MAX_VALUE)

# ==============================================================================
# 私有方法
# ==============================================================================

func _internal_method() -> void:
    pass
```

### 文件组织

#### 场景文件 (.tscn)
- 与脚本文件同名
- 放在对应的目录
- 示例：`player_herder.tscn` 和 `player_herder.gd`

#### 脚本文件 (.gd)
- 一个文件一个类
- 文件名与类名一致（snake_case vs PascalCase）
- 示例：`skill_base.gd` → `class_name SkillBase`

#### 资源文件
- 按类型分类存放
- 使用描述性名称
- 示例：`player_herder_sprite.png`

### Git规范

#### Commit Message格式

```
<type>: <subject>

<body>

<footer>
```

**Type类型**:
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例**:
```
feat: 添加新角色Tempest

- 实现风暴使者角色
- 添加台风眼和狂风龙卷技能
- 配置角色属性和技能参数

Closes #123
```

#### 分支管理

**主分支**:
- `main`: 稳定版本
- `develop`: 开发版本

**功能分支**:
- `feature/角色名`: 新角色开发
- `feature/系统名`: 新系统开发

**修复分支**:
- `fix/bug描述`: bug修复

**示例**:
```bash
# 创建功能分支
git checkout -b feature/new-character

# 开发完成后合并
git checkout develop
git merge feature/new-character
```

---

## 开发流程

### 添加新角色

#### 1. 规划阶段
- 确定角色定位和玩法
- 设计技能机制
- 确定属性数值

#### 2. 配置阶段

**player_config.csv**:
```csv
player_id,display_name,health,max_energy,energy_regen,base_speed,max_armor
player_new,新角色,5000,999,0.5,500,3
```

**player_visual.csv**:
```csv
player_id,sprite_path,color_r,color_g,color_b
player_new,res://assets/sprites/Players/player_new.png,1.0,1.0,1.0
```

**player_skill_bindings.csv**:
```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
player_new,skill_new_q,skill_new_e,skill_dash,
```

#### 3. 技能开发

创建技能脚本：
```gdscript
extends SkillBase
class_name SkillNewQ

func execute() -> void:
    if not can_execute():
        return
    
    consume_energy()
    # 技能逻辑
    start_cooldown()
```

配置技能参数：
```csv
skill_id,energy_cost,cooldown,damage
skill_new_q,30,5.0,50
skill_new_e,20,3.0,30
```

#### 4. 场景创建

1. 复制现有角色场景
2. 重命名为`player_new.tscn`
3. 修改精灵和碰撞
4. 设置`player_id = "player_new"`

#### 5. 测试验证

1. 运行游戏
2. 使用Tab键切换到新角色
3. 测试所有技能
4. 检查数值平衡

### 添加新敌人

#### 1. 配置敌人属性

**enemy_config.csv**:
```csv
enemy_id,display_name,health,speed,damage,attack_range,attack_cooldown
enemy_new,新敌人,100,150,10,50,1.0
```

#### 2. 创建敌人脚本

```gdscript
extends Enemy
class_name EnemyNew

func _ready() -> void:
    super._ready()
    # 初始化

func _process(delta: float) -> void:
    super._process(delta)
    # 自定义行为
```

#### 3. 创建敌人场景

1. 复制现有敌人场景
2. 重命名为`enemy_new.tscn`
3. 设置`enemy_id = "enemy_new"`
4. 配置精灵和碰撞

#### 4. 添加到波次

**wave_units_config.csv**:
```csv
wave_id,enemy_scene,weight
wave_1_to_5,res://scenes/unit/enemy/enemy_new.tscn,2.0
```

### 添加新技能

#### 1. 创建技能脚本

**位置**: `scenes/skills/players/skill_new.gd`

```gdscript
extends SkillBase
class_name SkillNew

## 技能特定参数
var special_param: float = 0.0

func execute() -> void:
    if not can_execute():
        return
    
    consume_energy()
    
    # 技能逻辑
    print("[SkillNew] 执行技能")
    
    start_cooldown()
```

#### 2. 配置技能参数

**skill_params.csv**:
```csv
skill_id,energy_cost,cooldown,special_param
skill_new,30,5.0,100.0
```

#### 3. 绑定到角色

**player_skill_bindings.csv**:
```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
player_herder,skill_new,skill_herder_explosion,skill_dash,
```

### 添加新武器

#### 1. 配置武器属性

**weapon_stats_config.csv**:
```csv
weapon_id,display_name,damage,accuracy,cooldown,max_range,projectile_speed
weapon_new_1,新武器1级,25.0,0.9,1.0,250.0,1600.0
```

#### 2. 创建武器场景

1. 复制现有武器场景
2. 重命名为`weapon_new.tscn`
3. 配置精灵和属性

#### 3. 创建投射物（如果是远程武器）

1. 复制现有投射物场景
2. 重命名为`projectile_new.tscn`
3. 配置精灵和碰撞

#### 4. 配置升级路径

```csv
weapon_id,upgrade_to
weapon_new_1,weapon_new_2
weapon_new_2,weapon_new_3
weapon_new_3,weapon_new_4
weapon_new_4,
```

---

## 常见任务

### 调整数值平衡

#### 1. 角色属性
修改`config/player/player_config.csv`：
```csv
player_id,health,base_speed
player_herder,6000,550  # 增加生命值和速度
```

#### 2. 技能参数
修改`config/player/skill_params.csv`：
```csv
skill_id,energy_cost,cooldown,damage
skill_dash,8,0,20  # 降低消耗，增加伤害
```

#### 3. 敌人属性
修改`config/enemy/enemy_config.csv`：
```csv
enemy_id,health,damage
enemy_chaser_slow,80,8  # 降低生命值和伤害
```

#### 4. 波次难度
修改`config/wave/wave_config.csv`：
```csv
wave_id,wave_time,min_spawn_time,max_spawn_time
wave_1_to_5,25.0,1.0,2.0  # 增加时长，降低生成频率
```

### 添加新音效

#### 1. 准备音效文件
- 格式：WAV或OGG
- 位置：`assets/audio/`
- 命名：描述性名称

#### 2. 配置音效
修改`config/system/sound_config.csv`：
```csv
sound_id,sound_path,volume_db,min_pitch,max_pitch,description
new_sound,res://assets/audio/new_sound.wav,0.0,0.9,1.1,新音效
```

#### 3. 播放音效
```gdscript
SoundManager.play_sound("new_sound")
```

### 修改UI

#### 1. 生命条
位置：`scenes/ui/health_bar.gd`

修改颜色：
```gdscript
var health_color: Color = Color(1.0, 0.0, 0.5)  # 粉红色
```

#### 2. 波次UI
位置：`scenes/ui/wave_ui.gd`

修改文字：
```gdscript
func get_wave_text() -> String:
    return "第%s波" % wave_index  # 中文显示
```

---

## 调试技巧

### 控制台日志

#### 基础日志
```gdscript
print("普通信息")
print_debug("调试信息")
push_warning("警告信息")
push_error("错误信息")
```

#### 格式化日志
```gdscript
print("[%s] 玩家生命值: %.1f" % [player_id, health])
print("位置: %v" % global_position)
```

#### 条件日志
```gdscript
if debug_mode:
    print("[DEBUG] 技能执行")
```

### 调试工具

#### 1. 远程调试
- 按F5运行游戏
- 在编辑器中查看场景树
- 实时修改节点属性

#### 2. 断点调试
- 在代码行号左侧点击设置断点
- 按F5运行游戏
- 游戏会在断点处暂停

#### 3. 性能监控
- 按F3显示性能监控
- 查看FPS、内存使用等

### 常用调试代码

#### 显示碰撞形状
```gdscript
# 在project.godot中设置
[debug]
shapes/collision/shape_color = Color(0, 0.6, 0.7, 0.5)
```

#### 打印场景树
```gdscript
func print_tree() -> void:
    print(get_tree().root.get_tree_string())
```

#### 检查节点有效性
```gdscript
if not is_instance_valid(node):
    push_error("节点无效")
    return
```

---

## 性能优化

### 对象池

#### 实现对象池
```gdscript
var projectile_pool: Array[Projectile] = []
var pool_size: int = 50

func _ready() -> void:
    # 预创建对象
    for i in range(pool_size):
        var projectile = projectile_scene.instantiate()
        projectile.visible = false
        projectile_pool.append(projectile)
        add_child(projectile)

func get_projectile() -> Projectile:
    for projectile in projectile_pool:
        if not projectile.visible:
            return projectile
    
    # 池已满，创建新对象
    var projectile = projectile_scene.instantiate()
    projectile_pool.append(projectile)
    add_child(projectile)
    return projectile

func return_projectile(projectile: Projectile) -> void:
    projectile.visible = false
    projectile.global_position = Vector2.ZERO
```

### 减少实例化

#### 缓存场景
```gdscript
var scene_cache: Dictionary = {}

func get_scene(path: String) -> PackedScene:
    if not scene_cache.has(path):
        scene_cache[path] = load(path)
    return scene_cache[path]
```

### 优化碰撞检测

#### 使用Area2D
```gdscript
# 使用Area2D的信号而不是每帧检测
func _on_area_entered(area: Area2D) -> void:
    if area is Hurtbox:
        area.take_damage(damage)
```

#### 减少碰撞层
```gdscript
# 只检测必要的碰撞层
collision_mask = 0b000010  # 只检测第2层
```

### 优化渲染

#### 使用CanvasItem.visible
```gdscript
# 不可见时禁用处理
func _process(delta: float) -> void:
    if not visible:
        return
    # 处理逻辑
```

#### 减少draw调用
```gdscript
# 缓存绘制结果
var cached_texture: Texture2D

func _draw() -> void:
    if cached_texture:
        draw_texture(cached_texture, Vector2.ZERO)
    else:
        # 绘制并缓存
        pass
```

---

## 常见问题

### Q: 配置修改后不生效？
**A**: 需要重启游戏。ConfigManager在启动时加载配置。

### Q: 技能不执行？
**A**: 检查：
1. 技能是否正确加载
2. 能量是否足够
3. 是否在冷却中
4. 启用debug_mode查看日志

### Q: 敌人不生成？
**A**: 检查：
1. 波次配置是否正确
2. 敌人场景路径是否正确
3. wave_units_config.csv是否配置
4. 查看Spawner日志

### Q: 碰撞不工作？
**A**: 检查：
1. CollisionShape2D是否启用
2. 碰撞层和掩码是否正确
3. Area2D信号是否连接
4. 节点是否在场景树中

### Q: 性能问题？
**A**: 优化：
1. 使用对象池
2. 减少实例化
3. 优化碰撞检测
4. 使用性能监控定位瓶颈

### Q: 如何调试崩溃？
**A**: 
1. 查看控制台错误信息
2. 使用断点定位问题
3. 检查节点有效性
4. 避免空引用

---

## 最佳实践

### 1. 代码组织
- 使用清晰的文件结构
- 一个文件一个类
- 相关文件放在同一目录

### 2. 配置管理
- 所有数据通过CSV配置
- 使用描述性的ID和名称
- 保持配置文件整洁

### 3. 错误处理
- 检查节点有效性
- 使用默认值
- 提供有意义的错误信息

### 4. 性能优化
- 使用对象池
- 缓存常用资源
- 避免每帧创建对象

### 5. 测试验证
- 频繁测试
- 使用调试工具
- 记录问题和解决方案

---

## 资源链接

### 官方文档
- [Godot官方文档](https://docs.godotengine.org/)
- [GDScript参考](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/index.html)

### 社区资源
- [Godot社区](https://godotengine.org/community)
- [Godot Discord](https://discord.gg/godotengine)
- [Godot Reddit](https://www.reddit.com/r/godot/)

### 学习资源
- [GDQuest](https://www.gdquest.com/)
- [HeartBeast](https://www.youtube.com/c/uheartbeast)
- [Brackeys](https://www.youtube.com/c/Brackeys)

---

## 总结

遵循本开发指南可以：

1. **提高效率**: 统一的规范和流程
2. **保证质量**: 最佳实践和代码规范
3. **易于维护**: 清晰的代码结构
4. **团队协作**: 统一的开发标准

祝开发顺利！
