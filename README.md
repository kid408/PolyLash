# PolyLash - 2D动作生存游戏

<div align="center">

**一款使用Godot 4.x开发的快节奏2D动作生存游戏**

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-In%20Development-yellow.svg)]()

</div>

---

## 📖 目录

- [游戏简介](#游戏简介)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [游戏操作](#游戏操作)
- [项目结构](#项目结构)
- [系统文档](#系统文档)
- [配置系统](#配置系统)
- [开发指南](#开发指南)
- [技术栈](#技术栈)

---

## 🎮 游戏简介

PolyLash是一款快节奏的2D动作生存游戏。玩家需要在无限生成的地图中对抗波次敌人，通过打开宝箱获得属性升级，生存尽可能多的波次。

游戏提供7个独特的可玩角色，每个角色都有专属的技能机制和玩法风格。从几何控制到火焰法术，从陷阱布置到雷电风暴，每个角色都能带来不同的游戏体验。

---

## ✨ 核心特性

### 🎯 游戏玩法

- **波次生存系统** - 10波敌人，难度递增，每波都是新的挑战
- **无限地图** - 动态生成的无缝平铺地图，自由探索
- **宝箱系统** - 4个品质等级，提供丰富的属性升级选择
- **多角色系统** - 7个可玩角色，每个都有独特的技能和玩法
- **属性升级** - 18种可升级属性，打造专属Build
- **动态生成** - 敌人在玩家附近动态生成，保持战斗紧张感

### 💥 战斗体验

- **打击感系统** - 顿帧、屏幕震动、音效反馈，爽快的战斗体验
- **多样化敌人** - 不同类型的敌人，需要不同的应对策略
- **武器系统** - 近战和远程武器，支持升级和强化
- **技能系统** - 每个角色2个独特技能，策略性使用

### 🛠️ 技术特性

- **CSV配置驱动** - 所有游戏数据通过CSV配置，易于调整和扩展
- **模块化设计** - 清晰的代码结构，组件化开发
- **音效系统** - 可配置的音效管理，支持音量和音调调整
- **性能优化** - 对象池、动态加载，保证流畅运行

---

## 🚀 快速开始

### 环境要求

- **Godot Engine**: 4.x 或更高版本
- **操作系统**: Windows / macOS / Linux
- **内存**: 至少 2GB RAM
- **存储**: 至少 500MB 可用空间

### 运行游戏

1. **下载并安装 Godot 4.x**
   - 访问 [Godot官网](https://godotengine.org/) 下载最新版本

2. **克隆或下载项目**
   ```bash
   git clone [项目地址]
   cd PolyLash_Project
   ```

3. **打开项目**
   - 启动Godot Engine
   - 点击"导入"
   - 选择项目目录中的 `project.godot` 文件

4. **运行游戏**
   - 按 `F5` 键运行游戏
   - 或点击编辑器右上角的"运行"按钮

---

## 🎮 游戏操作

### 基础操作

| 按键 | 功能 | 说明 |
|------|------|------|
| **WASD** | 移动 | 控制角色移动 |
| **鼠标左键** | 冲刺攻击 | 向鼠标方向冲刺并造成伤害 |
| **Q键** | 技能1 | 按住蓄力，松开释放（不同角色效果不同） |
| **E键** | 技能2 | 立即释放技能（不同角色效果不同） |

### 调试功能

| 按键 | 功能 | 说明 |
|------|------|------|
| **L键** | 进入下一波 | 跳过当前波次剩余时间 |
| **Tab键** | 切换角色 | 在7个角色之间循环切换 |
| **1-6键** | 切换武器 | 查看不同武器槽位 |

---

## 📁 项目结构

```
PolyLash_Project/
├── assets/                    # 游戏资源
│   ├── audio/                # 音效文件（WAV/OGG）
│   ├── font/                 # 字体文件
│   └── sprites/              # 图片资源（PNG）
│       ├── Players/          # 玩家精灵
│       ├── Enemies/          # 敌人精灵
│       └── Weapons/          # 武器精灵
│
├── autoloads/                 # 全局单例脚本（自动加载）
│   ├── config_manager.gd     # 配置管理器 - 加载和管理所有CSV配置
│   ├── global.gd             # 全局变量和工具函数
│   ├── player_config_loader.gd # 玩家配置加载器
│   ├── sound_manager.gd      # 音效管理器 - 音效播放和管理
│   └── upgrade_manager.gd    # 升级管理器 - 属性升级逻辑
│
├── config/                    # CSV配置文件（游戏数据）
│   ├── system/               # 系统配置
│   │   ├── game_config.csv   # 游戏全局设置
│   │   ├── map_config.csv    # 地图设置
│   │   ├── camera_config.csv # 摄像机设置
│   │   ├── input_config.csv  # 输入映射
│   │   └── sound_config.csv  # 音效配置
│   ├── player/               # 玩家相关
│   │   ├── player_config.csv # 玩家属性
│   │   ├── player_visual.csv # 玩家视觉
│   │   └── player_weapons.csv # 玩家武器
│   ├── enemy/                # 敌人相关
│   │   ├── enemy_config.csv  # 敌人属性
│   │   ├── enemy_visual.csv  # 敌人视觉
│   │   └── enemy_weapons.csv # 敌人武器
│   ├── weapon/               # 武器相关
│   │   ├── weapon_config.csv # 武器基础配置
│   │   └── weapon_stats_config.csv # 武器详细属性
│   ├── wave/                 # 波次相关
│   │   ├── wave_config.csv   # 波次配置
│   │   ├── wave_units_config.csv # 波次单位
│   │   └── wave_chest_config.csv # 波次宝箱
│   ├── item/                 # 物品相关
│   │   ├── chest_config.csv  # 宝箱配置
│   │   └── upgrade_attributes.csv # 升级属性
│   └── README.md             # 配置文件说明
│
├── effects/                   # 特效场景
│   ├── fire_line.tscn        # 火线特效
│   ├── fire_sea.tscn         # 火海特效
│   └── ...                   # 其他特效
│
├── scenes/                    # 游戏场景
│   ├── arena/                # 竞技场相关
│   │   ├── arena.tscn        # 主竞技场场景
│   │   ├── spawner.gd        # 敌人生成器
│   │   └── background.gd     # 无限背景
│   ├── components/           # 可复用组件
│   │   ├── health_component.gd # 生命值组件
│   │   ├── hitbox_component.gd # 攻击判定组件
│   │   └── hurtbox_component.gd # 受击判定组件
│   ├── items/                # 物品
│   │   └── chest/            # 宝箱系统
│   ├── projectiles/          # 投射物
│   │   ├── projectile_laser.tscn # 激光子弹
│   │   └── projectile_pistol.tscn # 手枪子弹
│   ├── ui/                   # 用户界面
│   │   ├── health_bar.gd     # 生命条
│   │   ├── energy_bar.gd     # 能量条
│   │   ├── wave_ui.gd        # 波次UI
│   │   └── chest_indicator.gd # 宝箱指示器
│   ├── unit/                 # 单位（玩家和敌人）
│   │   ├── unit.gd           # 单位基类
│   │   ├── players/          # 玩家角色
│   │   │   ├── player_base.gd # 玩家基类
│   │   │   ├── player_herder.gd # 牧者
│   │   │   ├── player_butcher.gd # 屠夫
│   │   │   ├── player_weaver.gd # 织网者
│   │   │   ├── player_pyro.gd # 烈焰
│   │   │   ├── player_wind.gd # 御风者
│   │   │   ├── player_sapper.gd # 工兵
│   │   │   └── player_tempest.gd # 风暴使者
│   │   └── enemy/            # 敌人
│   │       ├── enemy.gd      # 敌人基类
│   │       ├── enemy_chaser_slow.tscn # 慢速追击者
│   │       ├── enemy_chaser_mid.tscn # 中速追击者
│   │       ├── enemy_Breaker.tscn # 破坏者
│   │       ├── enemy_Shielded.tscn # 盾兵
│   │       ├── enemy_Spiked.tscn # 刺猬
│   │       └── enemy_mine_layer.tscn # 地雷怪
│   └── weapons/              # 武器
│       ├── melee/            # 近战武器
│       └── range/            # 远程武器
│
├── resouce/                   # 资源定义（GDScript资源类）
│   ├── items/                # 物品资源
│   ├── unit/                 # 单位资源
│   └── waves/                # 波次资源
│
├── docs/                      # 文档目录
│   ├── SYSTEMS.md            # 系统详细文档
│   ├── PLAYERS.md            # 玩家角色文档
│   ├── ENEMIES.md            # 敌人系统文档
│   ├── WEAPONS.md            # 武器系统文档
│   └── WAVES.md              # 波次系统文档
│
├── .editorconfig             # 编辑器配置
├── .gitignore                # Git忽略文件
├── project.godot             # Godot项目配置
├── icon.png                  # 项目图标
└── README.md                 # 本文件

```

---

## 📚 系统文档

详细的系统文档请查看 `docs/` 目录：

- **[SYSTEMS.md](docs/SYSTEMS.md)** - 游戏系统详解（波次、宝箱、升级、音效等）
- **[PLAYERS.md](docs/PLAYERS.md)** - 玩家角色详解（7个角色的技能和玩法）
- **[ENEMIES.md](docs/ENEMIES.md)** - 敌人系统详解（敌人类型和AI行为）
- **[WEAPONS.md](docs/WEAPONS.md)** - 武器系统详解（武器类型和属性）
- **[WAVES.md](docs/WAVES.md)** - 波次系统详解（波次配置和生成规则）

---

## ⚙️ 配置系统

游戏使用CSV文件进行配置，所有游戏数据都可以通过修改CSV文件来调整。

### 配置文件位置

所有配置文件位于 `config/` 目录，按功能分类：

- `system/` - 系统配置（游戏、地图、摄像机、输入、音效）
- `player/` - 玩家配置（属性、视觉、武器）
- `enemy/` - 敌人配置（属性、视觉、武器）
- `weapon/` - 武器配置（基础、详细属性）
- `wave/` - 波次配置（波次、单位、宝箱）
- `item/` - 物品配置（宝箱、升级属性）

### CSV文件格式

所有CSV文件遵循统一格式：

```csv
column1,column2,column3
-1,列1说明,列2说明,列3说明
data1,data2,data3
```

- **第一行**：列名（英文）
- **第二行**：注释行（第一列为 -1，其余列为中文说明）
- **第三行及以后**：数据行

### 修改配置

1. 使用文本编辑器或Excel打开CSV文件
2. 修改数据行（不要修改第一行和第二行）
3. 保存文件（确保使用UTF-8编码）
4. 重启游戏以加载新配置

详细的配置说明请查看 `config/README.md`

---

## 🛠️ 开发指南

### 添加新角色

1. 在 `config/player/player_config.csv` 添加角色配置
2. 创建角色脚本继承 `PlayerBase`
3. 实现三个虚函数：
   - `charge_skill_q(delta: float)` - Q技能蓄力
   - `release_skill_q()` - Q技能释放
   - `use_skill_e()` - E技能使用
4. 创建角色场景（.tscn）并设置 `player_id`

### 添加新敌人

1. 在 `config/enemy/enemy_config.csv` 添加敌人配置
2. 创建敌人脚本继承 `Enemy`
3. 实现敌人AI逻辑（可选）
4. 创建敌人场景（.tscn）

### 添加新武器

1. 在 `config/weapon/weapon_stats_config.csv` 添加武器配置
2. 创建武器场景（继承 `Weapon` 基类）
3. 如果是远程武器，创建对应的投射物场景

### 添加新音效

1. 将音效文件放入 `assets/audio/`
2. 在 `config/system/sound_config.csv` 添加配置
3. 使用 `SoundManager.play_sound("sound_id")` 播放

### 代码规范

- 使用 **Tab缩进**（Godot默认）
- 变量命名使用 **snake_case**
- 类名使用 **PascalCase**
- 常量使用 **UPPER_SNAKE_CASE**
- 为关键变量和函数添加注释
- 使用类型提示（GDScript 4.x）

---

## 🔧 技术栈

- **游戏引擎**: Godot 4.x
- **编程语言**: GDScript
- **配置格式**: CSV
- **音效格式**: WAV / OGG
- **图片格式**: PNG
- **版本控制**: Git

---

## 📊 开发进度

### 已完成功能 ✅

- [x] 基础玩家移动和冲刺系统
- [x] 7个可玩角色及其独特技能
- [x] 波次生存系统（10波）
- [x] 无限地图生成
- [x] 宝箱系统（4个品质等级）
- [x] 属性升级系统（18种属性）
- [x] 敌人生成和AI（6种敌人类型）
- [x] 碰撞和伤害系统
- [x] UI系统（生命条、能量条、波次显示）
- [x] 宝箱指示器（屏幕边缘箭头）
- [x] 音效系统（CSV配置）
- [x] CSV配置系统（所有数据可配置）
- [x] 打击感系统（顿帧、屏幕震动、音效）
- [x] 武器系统（近战和远程）
- [x] 配置目录重组（按功能分类）

### 待优化功能 🔄

- [ ] 更多敌人类型和AI行为
- [ ] 更多武器类型和攻击方式
- [ ] Boss战系统
- [ ] 成就系统
- [ ] 存档系统
- [ ] 更多音效和背景音乐
- [ ] 粒子特效优化
- [ ] 性能优化（大量敌人时）
- [ ] 多语言支持
- [ ] 主菜单和设置界面

---

## 🐛 已知问题

目前无重大已知问题。

如果发现问题，请提交Issue。

---

## 📝 更新日志

### v1.0.0 (2024-12-28)

- ✨ 初始版本发布
- ✨ 实现7个可玩角色
- ✨ 实现波次生存系统
- ✨ 实现宝箱和升级系统
- ✨ 实现CSV配置系统
- ✨ 配置目录重组

---

## 📄 许可证

[待定]

---

## 👥 贡献者

[待定]

---

## 📧 联系方式

[待定]

---

<div align="center">

**感谢游玩 PolyLash！**

Made with ❤️ using Godot Engine

</div>
