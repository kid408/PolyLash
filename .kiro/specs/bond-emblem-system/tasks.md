# 实现计划：羁绊与道具系统重构 (Bond & Item System Overhaul)

## 概述

基于双轨制架构（个人装备 + 团队护符），分阶段实现配置合并、核心管理器、商店集成、波次奖励和 UI 统一。使用 Godot 4 / GDScript，所有配置通过 CSV 驱动，管理器采用 Autoload 模式。

## 任务

- [x] 1. P0 修复：圣物标签不匹配与配置文件重构
  - [x] 1.1 创建新格式 item_config.csv，合并 item_config.csv 和 item_effect_config.csv 的内容
    - 新 CSV 包含字段：id, name, tier, type, slot_type, base_stat, base_value, mod_type, mod_value, bond_grant, icon_path, description
    - 修正所有圣物的 bond_grant 标签为与 bond_config.csv 一致的名称（inkborn, colossus, nomad 等）
    - 支持 consumable 类型（tier=0）和分号分隔的多修正字段
    - _Requirements: 2.3, 2.4, 3.1_

  - [x] 1.2 扩展 ConfigManager 加载新格式 item_config.csv
    - 新增 item_configs_new 字典和 get_item_config_by_id(item_id) 方法
    - 实现 _parse_modifiers() 支持分号分隔的多修正解析
    - 在 load_all_configs() 中加载新配置
    - _Requirements: 3.2_

  - [x] 1.3 更新 WarehouseManager 使用新配置结构
    - 修改 _load_item_configs() 读取新格式 CSV 的所有字段（含 bond_grant）
    - 更新 get_item_config() 返回完整配置数据
    - _Requirements: 2.2, 3.4_

  - [x] 1.4 修复 PlayerBase 道具装备逻辑
    - 通过 ConfigManager.get_item_config_by_id() 替代 _load_item_config() 的直接 CSV 读取
    - 移除 _infer_item_id_from_type() 硬编码映射，改用 ConfigManager 查询
    - 修复 _apply_tier3_item() 使其同时应用属性加成和注册 bond_grant 标签
    - 在 EquipmentManager 中实现 equip_or_use_item() 统一入口，根据 type 字段分支：consumable 类型调用 PlayerBase.apply_consumable_effect() 立即使用（不存入槽位），equipment 类型执行穿戴/替换逻辑
    - _Requirements: 2.2, 2.4, 3.3, 4.1, 4.2, 4.3, 4.5_

  - [ ]* 1.5 编写属性测试：分层装备效果正确性
    - **Property 3: 分层装备效果正确性**
    - **Validates: Requirements 2.2, 4.1, 4.2, 4.3**

- [x] 2. 检查点 - 确保 P0 修复通过
  - 确保所有测试通过，验证圣物标签匹配，确认 Tier 3 装备同时提供属性和羁绊标签。如有问题请询问用户。

- [x] 3. EmblemManager 核心实现
  - [x] 3.1 创建 emblem_config.csv 配置文件
    - 包含 11 个羁绊徽章（每种羁绊一个）+ 1 个万能鬼牌 + 若干通用遗物
    - 字段：emblem_id, display_name, artifact_type, bond_tag, rarity, shop_price, is_unique, icon_path, description
    - _Requirements: 6.1_

  - [x] 3.2 扩展 ConfigManager 加载 emblem_config.csv
    - 新增 emblem_configs 字典和 get_emblem_config(emblem_id)、get_all_emblem_configs()、get_emblems_by_bond_tag(bond_tag) 方法
    - _Requirements: 6.2_

  - [x] 3.3 实现 EmblemManager autoload
    - 创建 autoloads/emblem_manager.gd
    - 实现 held_emblems 数组管理：add_emblem()、remove_emblem()、clear_all()
    - 实现唯一遗物检查：has_unique_relic()
    - 实现标签查询：get_emblem_tags()、get_emblems_for_bond()
    - 实现信号：emblem_added、emblem_removed、wildcard_assignment_requested
    - 实现序列化/反序列化：serialize()、deserialize()
    - 在 project.godot 中注册为 Autoload
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 3.4 实现万能鬼牌逻辑
    - add_wildcard() 创建 is_wildcard=true 的条目并发出 wildcard_assignment_requested 信号
    - assign_wildcard(index, target_bond_tag) 验证 bond_tag 有效性后设置目标标签
    - _Requirements: 10.1, 10.2_

  - [ ]* 3.5 编写属性测试：EmblemManager 添加/计数一致性
    - **Property 5: EmblemManager 添加/计数一致性**
    - **Validates: Requirements 5.1, 5.2, 5.4, 5.5**

  - [ ]* 3.6 编写属性测试：EmblemManager 清空幂等性
    - **Property 6: EmblemManager 清空幂等性**
    - **Validates: Requirements 5.3**

  - [ ]* 3.7 编写属性测试：万能徽章分配往返一致性
    - **Property 7: 万能徽章分配往返一致性**
    - **Validates: Requirements 7.2, 10.1, 10.2**

  - [ ]* 3.8 编写属性测试：唯一遗物不可重复持有
    - **Property 10: 唯一遗物不可重复持有**
    - **Validates: Requirements 5.1, 8.2**

- [x] 4. BondManager 三源标签统计
  - [x] 4.1 重构 recalculate_active_bonds() 实现三源统计
    - 新增 tag_sources 字典追踪每个标签的来源（character/equipment/emblem）
    - 实现 _count_character_tags()、_count_equipment_tags()、_count_emblem_tags() 三个内部方法
    - 从 EmblemManager.get_emblem_tags() 获取徽章标签
    - 从 EquipmentManager.get_equipped_item_data() 获取装备 bond_grant
    - _Requirements: 2.1, 7.1_

  - [x] 4.2 实现羁绊等级变化检测与降级逻辑
    - 新增 bond_level_changed 信号
    - 实现 _detect_level_changes() 对比新旧 active_bonds
    - 确保 stat_mod 基于基础值重算（降级自动生效）
    - 确保 mechanic 效果通过实时查询自动失效
    - _Requirements: 7.3_

  - [x] 4.3 公开 get_activated_level() 和 get_tag_sources() 方法
    - get_activated_level(bond_id, count) 供 UI 组件调用
    - get_tag_sources(bond_tag) 返回 {character, equipment, emblem} 来源分布
    - _Requirements: 1.5_

  - [ ]* 4.4 编写属性测试：三源标签统计正确性
    - **Property 2: 三源标签统计正确性**
    - **Validates: Requirements 2.1, 7.1**

- [x] 5. 检查点 - 核心管理器集成验证
  - 确保 EmblemManager + BondManager + EquipmentManager 三者协同工作。验证：添加徽章后羁绊计数增加，装备 T3 后标签注册，万能牌分配后标签生效。如有问题请询问用户。

- [x] 6. EquipmentManager 装备替换与经济回收
  - [x] 6.1 实现 equip_or_use_item() 统一入口和 equip_item_with_replace() 方法
    - equip_or_use_item() 根据道具 type 字段分支：consumable 立即使用不存槽位，equipment 调用替换逻辑
    - 旧装备按原价 50% 自动出售为金币
    - 装备新道具后触发 BondManager 重算
    - _Requirements: 4.4, 4.5_

  - [x] 6.2 实现 get_equipped_item_data() 方法
    - 返回角色装备的完整道具数据（含 bond_grant）
    - 通过 ConfigManager.get_item_config_by_id() 查询
    - _Requirements: 7.1_

  - [ ]* 6.3 编写属性测试：装备替换经济回收一致性
    - **Property 4: 装备替换经济回收一致性**
    - **Validates: Requirements 4.4**

- [x] 7. 商店系统集成护符
  - [x] 7.1 扩展 ShopManager 支持徽章商品生成
    - 实现 EMBLEM_SPAWN_CHANCE (25%) 概率生成徽章
    - 实现 _generate_emblem_item() 从 emblem_config.csv 选择徽章
    - 实现去重池逻辑，确保单次刷新不出现重复商品
    - 已持有的唯一遗物从候选池中剔除
    - _Requirements: 8.1_

  - [x] 7.2 实现智能徽章权重选择
    - 实现 _get_smart_emblem_weights() 根据队伍羁绊状态计算权重
    - 已拥有但未满级的羁绊对应徽章权重更高
    - _Requirements: 8.2_

  - [x] 7.3 实现徽章购买流程
    - 购买徽章时调用 EmblemManager.add_emblem()
    - 使用 emblem_config.csv 中的 shop_price
    - _Requirements: 8.3, 8.4_

  - [ ]* 7.4 编写属性测试：智能徽章权重偏向未满级羁绊
    - **Property 9: 智能徽章权重偏向未满级羁绊**
    - **Validates: Requirements 8.2**

  - [ ]* 7.5 编写属性测试：商店去重
    - **Property 11: 商店去重**
    - **Validates: Requirements 8.1**

- [x] 8. 波次奖励三选一系统
  - [x] 8.1 创建 WaveRewardSystem 节点
    - 实现 check_wave_reward(wave_number) 检查是否触发奖励
    - 奖励波次从配置读取（默认第 5、10、15 波）
    - _Requirements: 9.1_

  - [x] 8.2 实现 generate_reward_options() 三选一生成
    - 选项 A: 随机团队徽章/遗物（排除已持有唯一遗物）
    - 选项 B: 随机 T3 装备
    - 选项 C: 大量金币/恢复/属性提升
    - _Requirements: 9.2_

  - [x] 8.3 创建 WaveRewardUI 场景和脚本
    - 创建 scenes/ui/wave_reward/wave_reward_panel.tscn 和 .gd
    - 创建 reward_card.tscn 和 .gd
    - 显示三个奖励卡片，玩家点击选择
    - 选择后暂停游戏、应用奖励、关闭面板
    - _Requirements: 9.3, 9.4_

  - [x] 8.4 集成 WaveRewardSystem 到 Arena 战斗流程
    - 在波次结束回调中检查是否触发奖励
    - 触发时暂停游戏并显示 WaveRewardUI
    - _Requirements: 9.1, 9.4_

  - [ ]* 8.5 编写属性测试：波次奖励选项结构正确性
    - **Property 12: 波次奖励选项结构正确性**
    - **Validates: Requirements 9.2**

- [x] 9. 检查点 - 商店与波次奖励验证
  - 确保商店能刷出徽章、购买后羁绊计数增加、波次奖励三选一正常工作。如有问题请询问用户。

- [x] 10. 万能鬼牌 UI
  - [x] 10.1 创建 WildcardUI 场景和脚本
    - 创建 scenes/ui/wildcard/wildcard_panel.tscn 和 .gd
    - 显示所有 12 种羁绊供选择，当前队伍已有的羁绊置顶高亮
    - 每个选项显示羁绊名称、当前标签数量和下一级需求
    - 选择后调用 EmblemManager.assign_wildcard()
    - _Requirements: 10.1, 10.2_

  - [x] 10.2 实现 UI 弹窗栈机制并连接万能鬼牌信号
    - 在 Arena 或全局 UI 管理器中实现 ui_panel_stack（push_panel / pop_panel）
    - 确保多个弹窗不会重叠显示：商店/奖励界面关闭后再弹出 WildcardUI
    - 监听 EmblemManager.wildcard_assignment_requested 信号，push WildcardUI
    - WildcardUI 选择完毕后 pop_panel，栈空则恢复游戏/解除暂停
    - _Requirements: 10.1, 10.4_

- [x] 11. 羁绊阈值调整
  - [x] 11.1 修改 bond_config.csv 阈值
    - Origin 和 Mastery 类羁绊 Lv.2 需求从 4 调整为 3
    - Origin 和 Mastery 类羁绊 Lv.3 需求从 6 调整为 5
    - Tactic 类保持不变
    - _Requirements: 11.1, 11.2_

- [x] 12. 羁绊 UI 显示统一与视觉反馈
  - [x] 12.1 实现共享的 format_bond_status() 工具函数
    - 统一格式：未激活 "0/N"、已激活 "Lv.X (cur/next)"、满级 "Lv.MAX" 或溢出格式
    - 放置在 BondManager 或独立工具脚本中
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 12.2 更新 BondHUD 使用新格式化逻辑
    - 替换现有的显示逻辑为 format_bond_status()
    - tooltip 中显示标签来源分布（角色/装备/徽章）
    - _Requirements: 1.1, 1.6_

  - [x] 12.3 更新 BondSummaryItem（选择界面）使用新格式化逻辑
    - 与 BondHUD 使用相同的 format_bond_status()
    - _Requirements: 1.1_

  - [x] 12.4 实现羁绊等级变化视觉反馈
    - 连接 BondManager.bond_level_changed 信号
    - 升级时：图标放大弹跳动画 + 屏幕中央飘字 + 播放 bond_generic.wav
    - 降级时：图标缩小动画 + 降级提示
    - _Requirements: 12.1, 12.2, 12.3_

  - [ ]* 12.5 编写属性测试：羁绊状态格式化一致性
    - **Property 1: 羁绊状态格式化一致性**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.6**

- [x] 13. 局内存档集成
  - [x] 13.1 扩展 DataManager 支持局内会话存档
    - 在每波结束时调用 EmblemManager.serialize() 保存到 session_data.json
    - 游戏启动时检查 session_data.json 并恢复 EmblemManager 状态
    - 局结束时清理 session_data.json
    - _Requirements: 5.3_

- [x] 14. 最终检查点 - 全系统集成验证
  - 确保所有测试通过。验证完整流程：选择3个同 Origin 角色 + 购买徽章 + 波次奖励 → 激活 Lv.3 羁绊。UI 显示统一。如有问题请询问用户。

## 备注

- 标记 `*` 的任务为可选测试任务，可跳过以加速 MVP 开发
- 每个任务引用具体需求编号以确保可追溯性
- 检查点确保增量验证
- 属性测试验证通用正确性属性，单元测试验证具体示例和边界情况
