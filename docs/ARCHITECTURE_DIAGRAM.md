# 画线技能系统架构图

## 类继承结构

```
┌─────────────────────────────────────────────────────────────┐
│                        SkillBase                            │
│  (基类 - 所有技能的抽象基类)                                  │
│                                                             │
│  • skill_owner: Node2D                                      │
│  • energy_cost: float                                       │
│  • cooldown_time: float                                     │
│  • execute() - 虚函数                                        │
│  • charge() - 虚函数                                         │
│  • release() - 虚函数                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ extends
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   SkillDrawingBase                          │
│  (画线技能中间基类 - 统一管理能量消耗和划线逻辑)                │
│                                                             │
│  【能量参数】                                                 │
│  • energy_per_10px: float = 1.0                            │
│  • energy_threshold_distance: float = 1800.0               │
│  • energy_scale_multiplier: float = 0.0005                 │
│                                                             │
│  【运行时状态】                                               │
│  • is_planning: bool                                        │
│  • is_drawing: bool                                         │
│  • path_points: Array[Vector2]                             │
│  • path_segments: Array[Dictionary]                        │
│  • has_closure: bool                                        │
│  • total_distance_drawn: float                             │
│                                                             │
│  【核心功能】                                                 │
│  • _calculate_current_energy_cost() -> float               │
│  • _calculate_total_consumed_energy() -> float             │
│  • _start_drawing() -> void                                │
│  • _continue_drawing() -> void                             │
│  • _check_intersection_and_closure() -> void               │
│  • _perform_final_closure_check() -> void                  │
│                                                             │
│  【虚函数接口】                                               │
│  • _spawn_line_effect(start, end) -> void  [必须实现]       │
│  • _spawn_area_effect(polygon) -> void     [必须实现]       │
│  • _get_line_color() -> Color              [可选重写]       │
│  • _get_closure_color() -> Color           [可选重写]       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ extends
                              ▼
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌──────────────────┐                      ┌──────────────────┐
│ SkillFirePath    │                      │ SkillWindPath    │
│ (烈焰者Q技能)     │                      │ (御风者Q技能)     │
│                  │                      │                  │
│ 【专属参数】      │                      │ 【专属参数】      │
│ • fire_line_     │                      │ • wind_wall_     │
│   damage: 20     │                      │   pull_force:    │
│ • fire_sea_      │                      │   350.0          │
│   damage: 40     │                      │ • storm_zone_    │
│                  │                      │   pull_force:    │
│ 【实现】          │                      │   400.0          │
│ • _spawn_line_   │                      │                  │
│   effect()       │                      │ 【实现】          │
│ • _spawn_area_   │                      │ • _spawn_line_   │
│   effect()       │                      │   effect()       │
│                  │                      │ • _spawn_area_   │
│ ~100行代码        │                      │   effect()       │
└──────────────────┘                      │                  │
                                          │ ~100行代码        │
                                          └──────────────────┘
        │                                           │
        ▼                                           ▼
┌──────────────────┐                      ┌──────────────────┐
│ SkillHerderLoop  │                      │ SkillSawPath     │
│ (牧羊人Q技能)     │                      │ (锯条Q技能)       │
│                  │                      │                  │
│ 【专属参数】      │                      │ 【专属参数】      │
│ • dash_speed:    │                      │ • saw_fly_speed: │
│   2000.0         │                      │   1100.0         │
│ • dash_base_     │                      │ • saw_damage:    │
│   damage: 50     │                      │   3              │
│                  │                      │                  │
│ 【实现】          │                      │ 【实现】          │
│ • _spawn_line_   │                      │ • _spawn_line_   │
│   effect()       │                      │   effect()       │
│ • _spawn_area_   │                      │ • _spawn_area_   │
│   effect()       │                      │   effect()       │
│ • _apply_herder_ │                      │                  │
│   rewards()      │                      │ ~100行代码        │
│                  │                      └──────────────────┘
│ ~150行代码        │
└──────────────────┘
        │
        ▼
┌──────────────────┐                      ┌──────────────────┐
│ SkillWebWeave    │                      │ SkillMinePath    │
│ (蛛网Q技能)       │                      │ (地雷Q技能)       │
│                  │                      │                  │
│ 【专属参数】      │                      │ 【专属参数】      │
│ • recall_damage: │                      │ • mine_damage:   │
│   40             │                      │   150            │
│ • recall_execute_│                      │ • mine_density:  │
│   mult: 3        │                      │   60             │
│                  │                      │                  │
│ 【实现】          │                      │ 【实现】          │
│ • _spawn_line_   │                      │ • _spawn_line_   │
│   effect()       │                      │   effect()       │
│ • _spawn_area_   │                      │ • _spawn_area_   │
│   effect()       │                      │   effect()       │
│                  │                      │                  │
│ ~100行代码        │                      │ ~100行代码        │
└──────────────────┘                      └──────────────────┘
```

## 能量消耗流程图

```
用户按住Q键
    │
    ▼
进入规划模式 (_enter_planning_mode)
    │
    ├─ 设置 is_planning = true
    ├─ 清空路径数据
    ├─ 设置起点为鼠标位置
    └─ 启动子弹时间 (Engine.time_scale = 0.1)
    │
    ▼
用户按住左键
    │
    ▼
开始划线 (_start_drawing)
    │
    ├─ 设置 is_drawing = true
    ├─ 清空之前的路径
    └─ 重置能量计数器
    │
    ▼
鼠标移动 (每帧)
    │
    ▼
继续划线 (_continue_drawing)
    │
    ├─ 计算鼠标移动距离
    ├─ 每10像素添加一个点
    │   │
    │   ├─ 计算当前能量消耗 (_calculate_current_energy_cost)
    │   │   │
    │   │   ├─ 如果 total_distance <= 1800px
    │   │   │   └─ 返回 energy_per_10px (1.0)
    │   │   │
    │   │   └─ 如果 total_distance > 1800px
    │   │       └─ 返回 energy_per_10px * (1 + excess * multiplier)
    │   │
    │   ├─ 检查能量是否足够
    │   │   │
    │   │   ├─ 足够 ✓
    │   │   │   ├─ 消耗能量
    │   │   │   ├─ 添加路径点
    │   │   │   ├─ 创建线段
    │   │   │   └─ 检测闭合 (_check_intersection_and_closure)
    │   │   │
    │   │   └─ 不足 ✗
    │   │       ├─ 停止划线
    │   │       └─ 显示提示 "No Energy!"
    │   │
    │   └─ 更新总距离
    │
    └─ 更新视觉效果 (_update_visuals)
        │
        ├─ 绘制路径点
        ├─ 添加鼠标预览线
        └─ 根据状态设置颜色
            │
            ├─ 闭合 → 红色
            ├─ 能量不足 → 灰色
            ├─ 超过阈值 → 渐变橙色
            └─ 正常 → 白色
```

## 闭合检测流程图

```
实时检测 (_check_intersection_and_closure)
    │
    ├─ 检查线段交叉
    │   │
    │   ├─ 最新线段 vs 之前的线段
    │   │   │
    │   │   ├─ 相交 ✓
    │   │   │   └─ has_closure = true
    │   │   │
    │   │   └─ 不相交 ✗
    │   │       └─ 继续检查
    │   │
    │   └─ 使用 Geometry2D.segment_intersects_segment()
    │
    └─ 检查距离闭合
        │
        ├─ 当前点 vs 起点
        │   │
        │   ├─ 距离 < 60px ✓
        │   │   └─ has_closure = true
        │   │
        │   └─ 距离 >= 60px ✗
        │       └─ 继续检查
        │
        └─ 当前点 vs 路径中的早期点
            │
            ├─ 距离 < 60px ✓
            │   └─ has_closure = true
            │
            └─ 距离 >= 60px ✗
                └─ 未闭合

最终检测 (_perform_final_closure_check)
    │
    ├─ 重新检查所有线段对
    │   │
    │   └─ 任意两条不相邻线段相交 → has_closure = true
    │
    └─ 重新检查所有距离闭合
        │
        └─ 终点接近起点或早期点 → has_closure = true
```

## 技能执行流程图

```
用户松开Q键
    │
    ▼
退出规划模式 (_exit_planning_mode_and_execute)
    │
    ├─ 设置 is_planning = false
    ├─ 恢复时间流速 (Engine.time_scale = 1.0)
    └─ 执行最终闭合检测 (_perform_final_closure_check)
    │
    ▼
根据闭合状态执行
    │
    ├─ 闭合 ✓ (_execute_closed_path)
    │   │
    │   ├─ 查找所有闭合多边形 (PolygonUtils.find_all_closing_polygons)
    │   │   │
    │   │   └─ 支持8字形等多区域
    │   │
    │   ├─ 显示闭合遮罩 (PolygonUtils.show_closure_masks)
    │   │   │
    │   │   └─ 统一的红色闪光动画
    │   │
    │   └─ 为每个多边形生成区域效果
    │       │
    │       └─ 调用子类的 _spawn_area_effect(polygon)
    │           │
    │           ├─ SkillFirePath → 生成火海
    │           ├─ SkillWindPath → 生成暴风区
    │           ├─ SkillHerderLoop → 几何击杀
    │           ├─ SkillSawPath → 锯条闭合
    │           ├─ SkillWebWeave → 蛛网收网
    │           └─ SkillMinePath → 地雷区域
    │
    └─ 未闭合 ✗ (_execute_open_path)
        │
        └─ 沿路径生成线段效果
            │
            └─ 调用子类的 _spawn_line_effect(start, end)
                │
                ├─ SkillFirePath → 生成火线
                ├─ SkillWindPath → 生成风墙
                ├─ SkillHerderLoop → 生成线段伤害
                ├─ SkillSawPath → 生成锯条
                ├─ SkillWebWeave → 生成蛛网线
                └─ SkillMinePath → 生成地雷
```

## 数据流图

```
CSV配置文件 (skill_params.csv)
    │
    ├─ energy_per_10px: 1.0
    ├─ energy_threshold_distance: 1800.0
    ├─ energy_scale_multiplier: 0.0005~0.001
    └─ 其他专属参数
    │
    ▼
加载到技能实例
    │
    ├─ SkillDrawingBase 自动读取能量参数
    └─ 子类读取专属参数
    │
    ▼
运行时计算
    │
    ├─ 每10像素消耗能量
    ├─ 超过阈值后递增
    └─ 右键清除时返还
    │
    ▼
生成效果
    │
    ├─ 未闭合 → 线段效果
    │   │
    │   └─ SkillEffectManager.create_line_effect()
    │       │
    │       ├─ 创建 Area2D
    │       ├─ 添加 Line2D 视觉
    │       ├─ 设置伤害定时器
    │       └─ 自动清理
    │
    └─ 闭合 → 区域效果
        │
        └─ SkillEffectManager.create_area_effect()
            │
            ├─ 创建 Area2D
            ├─ 添加 Polygon2D 视觉
            ├─ 设置伤害定时器
            └─ 自动清理
```

## 模块依赖图

```
┌─────────────────────────────────────────────────────────────┐
│                      游戏场景                                │
│                   (get_tree().current_scene)                │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 包含
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      玩家节点                                │
│                     (Player)                                │
│                                                             │
│  • skill_owner: Node2D                                      │
│  • energy: float                                            │
│  • consume_energy(amount) -> bool                           │
│  • gain_energy(amount) -> void                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 拥有
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   技能实例                                   │
│              (SkillFirePath, etc.)                          │
│                                                             │
│  • 继承 SkillDrawingBase                                     │
│  • 实现 _spawn_line_effect()                                │
│  • 实现 _spawn_area_effect()                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 使用
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  效果管理器                                  │
│              (SkillEffectManager)                           │
│                                                             │
│  • create_line_effect(config) -> int                        │
│  • create_area_effect(config) -> int                        │
│  • 统一管理效果生命周期                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 使用
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  多边形工具                                  │
│                (PolygonUtils)                               │
│                                                             │
│  • find_all_closing_polygons() -> Array                    │
│  • show_closure_masks() -> void                             │
│  • calculate_polygon_center() -> Vector2                    │
│  • calculate_polygon_area() -> float                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 使用
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  全局工具                                    │
│                   (Global)                                  │
│                                                             │
│  • spawn_floating_text(pos, text, color)                   │
│  • on_camera_shake.emit(intensity, duration)               │
│  • play_player_dash()                                       │
└─────────────────────────────────────────────────────────────┘
```

## 文件组织结构

```
PolyLash_Project/
│
├── scenes/
│   └── skills/
│       ├── skill_base.gd                    # 基类
│       ├── skill_drawing_base.gd            # 画线技能中间基类 ✨ 新增
│       │
│       └── players/
│           ├── skill_fire_path.gd           # 烈焰者Q技能 (重构版)
│           ├── skill_wind_path.gd           # 御风者Q技能 (重构版)
│           ├── skill_herder_loop.gd         # 牧羊人Q技能 (重构版)
│           ├── skill_saw_path.gd            # 锯条Q技能 (待迁移)
│           ├── skill_web_weave.gd           # 蛛网Q技能 (待迁移)
│           └── skill_mine_path.gd           # 地雷Q技能 (待迁移)
│
├── autoloads/
│   ├── skill_effect_manager.gd              # 效果管理器
│   ├── polygon_utils.gd                     # 多边形工具
│   └── global.gd                            # 全局工具
│
├── config/
│   └── player/
│       └── skill_params.csv                 # 技能参数配置
│
└── docs/
    ├── DRAWING_SKILL_REFACTORING.md         # 完整重构文档 ✨ 新增
    ├── DRAWING_SKILL_COMPARISON.md          # 前后对比文档 ✨ 新增
    ├── DRAWING_SKILL_MIGRATION_GUIDE.md     # 迁移指南 ✨ 新增
    ├── DRAWING_SKILL_QUICK_REFERENCE.md     # 快速参考 ✨ 新增
    └── ARCHITECTURE_DIAGRAM.md              # 架构图 ✨ 新增
```

---

**文档版本**: 1.0  
**创建日期**: 2026-01-25  
**用途**: 帮助理解画线技能系统的架构和数据流
