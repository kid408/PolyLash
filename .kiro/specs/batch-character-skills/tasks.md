# 实现计划：批量角色技能系统

## 概述

按照基础设施→技能实现→配置绑定的顺序，分阶段实现 30 套新角色技能系统。每个阶段完成后进行检查点验证。

## 任务

- [x] 1. 重构 skill_params.csv 为长表格式
  - [x] 1.1 在 ConfigManager 中实现 load_skill_params_long_format() 方法
    - 读取 skill_id, param_name, param_value, description 四列
    - 将数据转换为 {skill_id: {param_name: param_value}} 字典
    - 自动将数值字符串转换为 float/int
    - 处理重复 skill_id + param_name（使用最后出现的值，输出警告）
    - 修改 load_all_configs() 调用新方法
    - _Requirements: 1.1, 1.2, 1.4, 1.5_

  - [ ]* 1.2 编写属性测试：长表 CSV 解析与类型转换
    - **Property 1: 长表 CSV 解析与类型转换正确性**
    - **Validates: Requirements 1.1, 1.2, 1.4**

  - [ ]* 1.3 编写属性测试：重复参数最后值优先
    - **Property 3: 重复参数最后值优先**
    - **Validates: Requirements 1.5**

  - [x] 1.4 将现有 13 个技能参数从宽表迁移到长表格式
    - 创建新的 skill_params.csv 长表文件
    - 迁移 skill_dash, skill_saw_path, skill_meat_stake 等 13 个现有技能
    - 值为 0 的参数不迁移
    - 保留 description 列用于中文说明
    - _Requirements: 1.3_

  - [ ]* 1.5 编写单元测试：验证迁移后现有技能参数与宽表一致
    - **Property 2: 长表与宽表迁移一致性（Round-Trip）**
    - **Validates: Requirements 1.2, 1.3**

- [x] 2. 扩展 StatusComponent 支持新状态
  - [x] 2.1 在 StatusComponent 中实现新状态处理
    - 添加 STATUS_PRIORITY 常量字典
    - 实现 freeze 状态：停止移动和攻击，灰蓝色视觉
    - 实现 silence 状态：阻止特殊技能，紫色视觉
    - 实现 fear 状态：逃跑行为（远离施法者），绿色视觉
    - 实现 marked 状态：受伤增加百分比，红色标记视觉
    - 实现 petrify 状态：完全不可行动，灰色视觉
    - 实现 poison 状态：DOT 伤害，绿色视觉
    - 实现优先级处理：get_active_control_status() 返回最高优先级状态
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 2.2 编写属性测试：标记状态伤害放大计算
    - **Property 5: 标记状态伤害放大计算**
    - **Validates: Requirements 3.4**

  - [ ]* 2.3 编写属性测试：状态优先级排序
    - **Property 6: 状态优先级排序**
    - **Validates: Requirements 3.6**

- [x] 3. 扩展 SkillEffectManager 支持新效果类型
  - [x] 3.1 实现 create_wall_effect() 方法
    - 创建 StaticBody2D 节点，沿 start→end 线段生成碰撞形状
    - 支持 block_enemies、block_bullets、reflect_bullets 配置
    - 支持 contact_damage 接触伤害
    - 支持 health 可破坏墙体（受到攻击后减少 health，归零时销毁）
    - 支持 duration 持续时间和淡出动画
    - 使用 Line2D 占位视觉效果
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 实现 create_buff_zone() 方法
    - 创建 Area2D 区域，支持 polygon 和 start/end 两种形状
    - 检测 "players" 组的单位进入区域
    - 支持 buff_type: attack_boost, speed_boost, heal, lifesteal, invincible, cooldown_reduction, ignore_collision
    - 按 tick_interval 间隔应用 Buff 效果
    - 支持 duration 持续时间和淡出动画
    - 使用 Polygon2D/Line2D 占位视觉效果
    - _Requirements: 2.3_

  - [x] 3.3 实现 create_debuff_zone() 方法
    - 创建 Area2D 区域，检测 "enemies" 组的单位
    - 通过 StatusComponent.apply_status() 应用 Debuff
    - 支持 debuff_type: slow, damage_amp, poison, freeze, fear
    - 支持可选的区域伤害（damage + damage_interval）
    - _Requirements: 2.4_

  - [x] 3.4 实现 create_summon() 和 command_summons() 方法
    - 创建召唤物节点（Area2D + 占位视觉）
    - 实现基础 AI：自动攻击范围内最近敌人
    - 实现 max_count 限制：超过时移除最早的召唤物
    - 实现 command_summons()：focus_fire、self_destruct 指令
    - 使用彩色圆形占位视觉
    - _Requirements: 2.5, 2.6_

  - [ ]* 3.5 编写属性测试：召唤物数量上限不变量
    - **Property 4: 召唤物数量上限不变量**
    - **Validates: Requirements 2.6**

- [x] 4. 检查点 - 基础设施验证
  - 确保所有测试通过，ask the user if questions arise.
  - 验证 ConfigManager 长表加载正常
  - 验证 StatusComponent 新状态工作正常
  - 验证 SkillEffectManager 新效果类型工作正常
  - 验证 SkillEffectManager 的效果节点挂载在独立于角色的场景树节点上（确保角色切换不影响效果生命周期）
  - _Requirements: 2.7, 11.1, 11.2, 11.3_

- [x] 5. 实现 A 组技能 - 元素与控制
  - [x] 5.1 实现冰河（Glacier）技能
    - 创建 skill_glacier_q.gd（继承 SkillDrawingBase）
      - _spawn_line_effect: 调用 create_wall_effect 创建冰墙（block_enemies + block_bullets）
      - _spawn_area_effect: 调用 create_debuff_zone 施加 freeze 状态
    - 创建 skill_glacier_e.gd（继承 SkillBase）
      - execute: 范围击退 + 添加护甲
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 5.2 实现特斯拉（Tesla）技能
    - 创建 skill_tesla_q.gd
      - _spawn_line_effect: 调用 create_line_effect 创建电弧线（伤害 + 0.5s 眩晕）
      - _spawn_area_effect: 调用 create_area_effect 创建雷电场（每 0.5s 伤害）
    - 创建 skill_tesla_e.gd
      - execute: 范围施加 silence 状态
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.4, 4.5, 4.6_

  - [x] 5.3 实现新火法（NewPyro）技能
    - 创建 skill_new_pyro_q.gd
      - _spawn_line_effect: 调用 create_wall_effect 创建火墙（block_enemies + contact_damage）
      - _spawn_area_effect: 调用 create_area_effect 创建火海（DOT）
    - 创建 skill_new_pyro_e.gd
      - execute: 范围击退（火焰环）
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.7, 4.8, 4.9_

  - [x] 5.4 实现瘟疫（Plague）技能
    - 创建 skill_plague_q.gd
      - _spawn_line_effect: 调用 create_debuff_zone 创建腐蚀路径（slow 50% + poison）
      - _spawn_area_effect: 调用 create_debuff_zone 创建瘴气池（damage_amp 30%）
    - 创建 skill_plague_e.gd
      - execute: 引爆所有中毒敌人的毒素层数
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.10, 4.11, 4.12_

  - [x] 5.5 实现狱警（Jailer）技能
    - 创建 skill_jailer_q.gd
      - _spawn_line_effect: 调用 create_wall_effect 创建电网（contact_damage + knockback）
      - _spawn_area_effect: 调用 create_wall_effect 沿闭合边界创建封闭墙壁
    - 创建 skill_jailer_e.gd
      - execute: 扇形范围击退
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.13, 4.14, 4.15_

  - [x] 5.6 实现新风暴（NewTempest）技能
    - 创建 skill_new_tempest_q.gd
      - _spawn_line_effect: 调用 create_buff_zone 创建风带（speed_boost）
      - _spawn_area_effect: 调用 create_area_effect 创建台风眼（pull_to_center）
    - 创建 skill_new_tempest_e.gd
      - execute: 范围抛飞敌人（龙卷风）
    - 在 skill_params.csv 中添加参数
    - _Requirements: 4.16, 4.17, 4.18_

- [x] 6. 实现 B 组技能 - 战术支援
  - [x] 6.1 实现铁匠（Blacksmith）技能
    - 创建 skill_blacksmith_q.gd
      - _spawn_line_effect: 调用 create_buff_zone 创建磨刀石（attack_boost 50%）
      - _spawn_area_effect: 调用 create_buff_zone 创建锻造炉（attack_speed_boost 100%）
    - 创建 skill_blacksmith_e.gd
      - execute: 重置 Q 技能冷却
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.2 实现军医（Medic）技能
    - 创建 skill_medic_q.gd
      - _spawn_line_effect: 调用 create_buff_zone（heal）+ create_debuff_zone（slow）
      - _spawn_area_effect: 调用 create_buff_zone（heal + invincible）
    - 创建 skill_medic_e.gd
      - execute: 5 秒 lifesteal Buff
    - _Requirements: 5.4, 5.5, 5.6_

  - [x] 6.3 实现弹药（Ammo）技能
    - 创建 skill_ammo_q.gd
      - _spawn_line_effect: 调用 create_buff_zone 创建加速轨道（projectile_boost）
      - _spawn_area_effect: 调用 create_buff_zone 创建补给站（cooldown_reduction）
    - 创建 skill_ammo_e.gd
      - execute: 能量恢复至满值
    - _Requirements: 5.7, 5.8, 5.9_

  - [x] 6.4 实现圣骑士（Paladin）技能
    - 创建 skill_paladin_q.gd
      - _spawn_line_effect: 调用 create_wall_effect 创建光墙（block_bullets）
      - _spawn_area_effect: 调用 create_buff_zone 创建净化场（cleanse + damage_reduction）
    - 创建 skill_paladin_e.gd
      - execute: 嘲讽（强制敌人攻击自身）
    - _Requirements: 5.10, 5.11, 5.12_

  - [x] 6.5 实现血族（Vampire）技能
    - 创建 skill_vampire_q.gd
      - _spawn_line_effect: 调用 create_line_effect 创建血路（消耗自身 HP，% HP 伤害）
      - _spawn_area_effect: 调用 create_buff_zone 创建血池（lifesteal 100%）
    - 创建 skill_vampire_e.gd
      - execute: 吸取附近敌人 HP
    - _Requirements: 5.13, 5.14, 5.15_

  - [x] 6.6 实现旗手（Banner）技能
    - 创建 skill_banner_q.gd
      - _spawn_line_effect: 调用 create_buff_zone 创建冲锋线（ignore_collision）
      - _spawn_area_effect: 调用 create_debuff_zone 创建决斗场（defense = 0）
    - 创建 skill_banner_e.gd
      - execute: 全队移速爆发
    - _Requirements: 5.16, 5.17, 5.18_

- [x] 7. 检查点 - A/B 组技能验证
  - 确保所有测试通过，ask the user if questions arise.
  - 验证 12 套技能（A 组 6 + B 组 6）的 Q-line、Q-circle、E-key 功能
  - 验证角色切换后效果持续

- [x] 8. 实现 C 组技能 - 奇观与召唤
  - [x] 8.1 实现火车王（Train）技能
    - 创建 skill_train_q.gd
      - _spawn_line_effect: 创建幽灵轨道（1s 延迟后冲击波）
      - _spawn_area_effect: 创建旋转光束（持续伤害）
    - 创建 skill_train_e.gd
      - execute: 致盲范围内敌人
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 8.2 实现虫母（Swarm）技能
    - 创建 skill_swarm_q.gd
      - _spawn_line_effect: 创建裂缝（每 1s 生成自爆甲虫，使用 create_summon）
      - _spawn_area_effect: 创建孵化场（生成 3 个炮塔 + 队友治疗）
    - 创建 skill_swarm_e.gd
      - execute: 调用 command_summons("focus_fire")
    - _Requirements: 6.4, 6.5, 6.6_

  - [x] 8.3 实现萨满（NewTotem）技能
    - 创建 skill_new_totem_q.gd
      - _spawn_line_effect: 在起点和终点放置图腾（create_summon），闪电链连接
      - _spawn_area_effect: 创建地震效果（伤害 + slow）
    - 创建 skill_new_totem_e.gd
      - execute: 引爆所有图腾（command_summons("self_destruct")）
    - _Requirements: 6.7, 6.8, 6.9_

  - [x] 8.4 实现工程（Turret）技能
    - 创建 skill_turret_q.gd
      - _spawn_line_effect: 沿路径等距放置 3 个炮塔（create_summon）
      - _spawn_area_effect: 创建维修站（区域内炮塔双倍攻速）
    - 创建 skill_turret_e.gd
      - execute: 引爆所有炮塔（command_summons("self_destruct")）
    - _Requirements: 6.10, 6.11, 6.12_

  - [x] 8.5 实现软泥（Goo）技能
    - 创建 skill_goo_q.gd
      - _spawn_line_effect: 调用 create_debuff_zone 创建超级胶水（slow 90%）
      - _spawn_area_effect: 创建分裂池（敌人受伤时生成迷你史莱姆）
    - 创建 skill_goo_e.gd
      - execute: 吞噬最近小型敌人（instant kill + heal）
    - _Requirements: 6.13, 6.14, 6.15_

  - [x] 8.6 实现死灵（Necro）技能
    - 创建 skill_necro_q.gd
      - _spawn_line_effect: 调用 create_wall_effect 创建骨墙（health = 3）
      - _spawn_area_effect: 创建尸爆场（敌人死亡时爆炸）
    - 创建 skill_necro_e.gd
      - execute: 范围施加 fear 状态
    - _Requirements: 6.16, 6.17, 6.18_

- [x] 9. 实现 D 组技能 - 经济与收割（技能库，不绑定角色）
  - [x] 9.1 实现商人（Merchant）技能
    - 创建 skill_merchant_q.gd + skill_merchant_e.gd
    - 在 skill_params.csv 中添加参数
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 9.2 实现炼金（Midas）技能
    - 创建 skill_midas_q.gd + skill_midas_e.gd
    - _Requirements: 7.4, 7.5, 7.6_

  - [x] 9.3 实现吸尘器（Vacuum）技能
    - 创建 skill_vacuum_q.gd + skill_vacuum_e.gd
    - _Requirements: 7.7, 7.8, 7.9_

  - [x] 9.4 实现处刑（Executioner）技能
    - 创建 skill_executioner_q.gd + skill_executioner_e.gd
    - _Requirements: 7.10, 7.11, 7.12_

  - [x] 9.5 实现赌徒（Gambler）技能
    - 创建 skill_gambler_q.gd + skill_gambler_e.gd
    - _Requirements: 7.13, 7.14, 7.15_

  - [x] 9.6 实现猎人（Hunter）技能
    - 创建 skill_hunter_q.gd + skill_hunter_e.gd
    - _Requirements: 7.16, 7.17, 7.18_

- [x] 10. 实现 E 组技能 - 特殊机制
  - [x] 10.1 实现魔术师（Illusionist）技能
    - 创建 skill_illusionist_q.gd
      - _spawn_line_effect: 调用 create_wall_effect 创建镜面（reflect_bullets）
      - _spawn_area_effect: 创建幻影分身（create_summon, phantom 类型）
    - 创建 skill_illusionist_e.gd
      - execute: 与幻影交换位置
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 10.2 实现巫毒（Voodoo）技能
    - 创建 skill_voodoo_q.gd
      - _spawn_line_effect: 调用 create_debuff_zone 施加 curse 状态
      - _spawn_area_effect: 创建钉刺坑（攻击区域内单位时伤害所有 cursed 敌人）
    - 创建 skill_voodoo_e.gd
      - execute: 自伤触发全屏 curse 伤害
    - _Requirements: 8.4, 8.5, 8.6_

- [x] 11. 检查点 - C/D/E 组技能验证
  - 确保所有测试通过，ask the user if questions arise.
  - 验证所有 26 套新技能的 Q-line、Q-circle、E-key 功能

- [x] 12. 删除旧角色与创建新角色
  - [x] 12.1 删除 20 个非原始角色的所有配置和脚本
    - 从 config/player/player_config.csv 中删除 20 个旧角色行
    - 从 config/player/player_visual.csv 中删除对应行
    - 从 config/player/player_weapons.csv 中删除对应行
    - 从 config/player/player_skill_bindings.csv 中删除对应行
    - 从 config/player/ult_config.csv 中删除对应行
    - 从 config/player/player_available_weapons.csv 中删除对应行
    - 删除 20 个 scenes/unit/players/player_xxx.gd 脚本文件及对应 .uid 文件
    - _Requirements: 10.1, 10.2_

  - [x] 12.2 创建 20 个新角色的 GDScript 文件
    - 使用模板化结构创建 scenes/unit/players/player_xxx.gd（参考 player_technology_hurricane.gd 模板）
    - 设置正确的 class_name（如 PlayerGlacier、PlayerTesla 等）
    - 设置正确的 load_skills_from_config() 参数
    - _Requirements: 10.5_

  - [x] 12.3 在所有 CSV 配置文件中添加 20 个新角色
    - 在 config/player/player_config.csv 中添加新角色行（根据定位分配合理属性值，按设计文档 3c 属性参考值）
    - 在 config/player/player_config.csv 中按设计文档 3d 羁绊系统设计设置每个新角色的 origin_tag、mastery_tag、tactic_tag
    - 在 config/player/player_visual.csv 中添加新角色行（使用通用占位视觉）
    - 在 config/player/player_weapons.csv 中添加新角色行（使用通用武器配置）
    - 在 config/player/player_available_weapons.csv 中添加新角色行
    - 在 config/player/ult_config.csv 中添加新角色行（使用通用大招配置）
    - _Requirements: 10.3, 10.4_

  - [x] 12.4 更新 player_skill_bindings.csv 绑定新技能
    - 为 20 个新角色绑定对应的新技能 Q/E
    - 保持原始六角色绑定不变
    - 验证 D 组 6 套技能（merchant, midas, vacuum, executioner, gambler, hunter）参数在 skill_params.csv 中完整保留
    - _Requirements: 10.6, 10.7, 10.8_

  - [x] 12.5 验证 SkillManager 正确加载新技能绑定
    - 确认 SkillManager 能根据 player_skill_bindings.csv 正确实例化新角色的技能脚本
    - 确认技能参数从 skill_params.csv 长表正确加载
    - _Requirements: 10.9_

  - [ ]* 12.6 编写属性测试：非原始角色技能绑定唯一性
    - **Property 7: 非原始角色技能绑定唯一性**
    - **Validates: Requirements 10.6**

  - [ ]* 12.7 编写单元测试：验证原始六角色绑定未变
    - 验证 butcher、pyro、sapper、herder、weaver、wind 的技能绑定与原始值一致
    - _Requirements: 10.7_

- [x] 13. 最终检查点 - 全系统验证
  - 确保所有测试通过，ask the user if questions arise.
  - 验证所有 26 个角色（6 原始 + 20 新）的技能加载和执行
  - 验证角色切换后效果持续性（需求 11.1-11.3）
  - 验证 D 组 6 套技能库技能参数完整（需求 10.8）
  - 验证所有新技能脚本遵循架构规范：Q 继承 SkillDrawingBase、E 继承 SkillBase、文件名规范、参数从 CSV 读取（需求 9.1-9.6）
  - 验证 20 个新角色的羁绊标签与设计文档 3d 一致

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加快 MVP 进度
- 每个任务引用具体需求以确保可追溯性
- 检查点确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
