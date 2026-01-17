# 项目架构设计

## 整体架构

PolyLash 是一个基于 Godot 4 的 2D 生存射击游戏，采用模块化架构设计。

### 核心模块

```
┌─────────────────────────────────────────────────────────┐
│                    游戏主循环                              │
│                   (Arena Scene)                          │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
    ┌────────┐          ┌────────┐         ┌────────┐
    │ 玩家   │          │ 敌人   │         │ 波次   │
    │ 系统   │          │ 系统   │         │ 系统   │
    └────────┘          └────────┘         └────────┘
        │                   │                   │
        ├─ 角色选择         ├─ 敌人生成        ├─ 波次配置
        ├─ 技能系统         ├─ 敌人 AI         ├─ 敌人分配
        ├─ 武器系统         ├─ 精英怪系统      └─ 难度调整
        └─ 升级系统         └─ 特殊效果
```

## 目录结构

```
PolyLash/
├── scenes/                 # 游戏场景
│   ├── arena/             # 竞技场场景
│   ├── unit/              # 单位（玩家、敌人）
│   │   ├── player/        # 玩家角色
│   │   └── enemy/         # 敌人
│   │       └── elites/    # 精英怪
│   ├── ui/                # UI 界面
│   ├── skills/            # 技能效果
│   ├── weapons/           # 武器效果
│   ├── projectiles/       # 投射物
│   ├── items/             # 物品（宝箱等）
│   ├── particles/         # 粒子效果
│   └── components/        # 可复用组件
│
├── config/                # 配置文件（CSV）
│   ├── enemy/            # 敌人配置
│   ├── player/           # 玩家配置
│   ├── weapon/           # 武器配置
│   ├── wave/             # 波次配置
│   └── system/           # 系统配置
│
├── autoloads/            # 全局管理器
│   ├── global.gd         # 全局变量和信号
│   ├── config_manager.gd # 配置管理
│   ├── data_manager.gd   # 数据管理
│   ├── upgrade_manager.gd# 升级管理
│   └── elite_config_manager.gd # 精英怪配置
│
├── assets/               # 游戏资源
│   ├── sprites/          # 精灵图片
│   ├── audio/            # 音频文件
│   └── font/             # 字体文件
│
├── effects/              # 特效
│   ├── flash.gdshader    # 闪烁着色器
│   └── flash_material.tres # 闪烁材质
│
└── docs/                 # 文档
```

## 核心类关系

### 单位系统

```
Unit (基类)
├── Player (玩家)
│   ├── PlayerButcher
│   ├── PlayerHerder
│   ├── PlayerPyro
│   ├── PlayerSapper
│   ├── PlayerTempest
│   ├── PlayerWeaver
│   └── PlayerWind
│
└── Enemy (敌人)
    ├── EnemyGlutton (精英怪)
    └── 其他敌人类型
```

### 配置系统

```
ConfigManager (敌人配置)
├── 敌人基础属性
├── 敌人视觉配置
└── 敌人行为配置

EliteConfigManager (精英怪配置)
├── 精英怪基础配置
├── 进化阶段配置
└── 生成配置
```

## 数据流

### 游戏初始化流程

```
1. 启动游戏
   ↓
2. 加载配置文件
   ├── ConfigManager 加载敌人配置
   ├── EliteConfigManager 加载精英怪配置
   └── 其他管理器加载各自配置
   ↓
3. 初始化场景
   ├── 创建竞技场
   ├── 初始化玩家
   └── 初始化敌人生成器
   ↓
4. 开始游戏循环
```

### 敌人生成流程

```
Spawner (生成器)
├── 普通敌人生成
│   ├── 从 wave_config 读取配置
│   ├── 创建敌人实例
│   └── 应用配置属性
│
└── 精英怪生成
    ├── 从 elite_spawn_config 读取配置
    ├── 创建 EnemyGlutton 实例
    └── 初始化进化系统
```

### 精英怪进化流程

```
EnemyGlutton
├── 初始化（Stage 1）
│   ├── 设置基础属性
│   ├── 初始化吞噬检测
│   └── 启动 AI
│
├── 吞噬敌人
│   ├── 检测附近敌人
│   ├── 吞噬敌人
│   ├── 增加计数
│   └── 检查进化条件
│
└── 进化到下一阶段
    ├── 更新视觉（精灵、缩放）
    ├── 应用属性倍数
    ├── 启用新能力
    └── 更新奖励值
```

## 关键系统

### 1. 配置系统

**特点**:
- 所有游戏数据存储在 CSV 文件中
- 运行时动态加载
- 无需重新编译即可修改参数

**配置管理器**:
- `ConfigManager`: 管理敌人配置
- `EliteConfigManager`: 管理精英怪配置
- `UpgradeManager`: 管理升级配置

### 2. 敌人系统

**敌人类型**:
- 普通敌人: 基础敌人，可配置属性
- 精英怪: 可进化的特殊敌人
- 特殊敌人: 具有特殊能力的敌人

**敌人 AI**:
- 追逐状态: 追踪玩家
- 冲锋状态: 直线冲锋
- 预警状态: 显示红线警告
- 冷却状态: 恢复后继续追逐

### 3. 精英怪系统

**进化机制**:
- 通过吞噬其他敌人进化
- 5 个进化阶段
- 每个阶段有不同的属性和能力

**进化阶段**:
- Stage 1: 初始形态
- Stage 2: 酸液射手（可射击投射物）
- Stage 3: 巨型怪物（免疫击退，AoE 攻击）
- Stage 4: 过度进食（继续进化）
- Stage 5: 终极形态（最强形态）

### 4. 玩家系统

**玩家属性**:
- 生命值
- 伤害
- 速度
- 防御

**技能系统**:
- 每个角色有独特的技能
- 技能可升级
- 技能有冷却时间

### 5. 波次系统

**波次配置**:
- 定义每波敌人的类型和数量
- 支持难度调整
- 支持精英怪生成

## 通信机制

### 信号系统

使用 Godot 的信号系统进行事件通信：

```gdscript
# 全局信号（在 Global 中定义）
signal on_enemy_killed(enemy)
signal on_player_damaged(damage)
signal on_camera_shake(intensity, duration)
signal on_create_block_text(unit)
```

### 配置访问

```gdscript
# 访问敌人配置
var config = ConfigManager.get_enemy_config("basic_enemy")

# 访问精英怪配置
var elite_config = EliteConfigManager.get_elite_config("enemy_glutton")

# 访问进化配置
var evolution = EliteConfigManager.get_evolution_stage("enemy_glutton", 2)
```

## 性能考虑

### 优化策略

1. **对象池**: 重用敌人和投射物对象
2. **LOD**: 根据距离调整敌人 AI 更新频率
3. **批处理**: 批量更新敌人状态
4. **缓存**: 缓存配置数据避免重复加载

### 内存管理

- 及时释放已死亡的敌人
- 清理不可见的效果
- 限制同时存在的敌人数量

## 扩展性

### 添加新敌人

1. 在 `enemy_config.csv` 中添加配置
2. 在 `enemy_visual.csv` 中添加视觉配置
3. 创建敌人脚本（可选）
4. 在波次配置中使用

### 添加新技能

1. 在 `player_skills.csv` 中添加配置
2. 创建技能脚本
3. 在玩家配置中绑定
4. 实现技能效果

### 添加新玩家角色

1. 创建玩家脚本（继承自 Player）
2. 在 `player_config.csv` 中添加配置
3. 添加角色精灵和动画
4. 在选择界面中添加角色

---

**最后更新**: 2026年1月17日
