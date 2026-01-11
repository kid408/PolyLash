# Implementation Plan: 角色选择面板

## Overview

本实施计划将实现角色选择面板功能，包括CSV配置扩展、动态UI生成、拖拽选择、角色切换和状态管理。

## Tasks

- [x] 1. 扩展CSV配置文件
  - [x] 1.1 修改player_config.csv添加新列
    - 添加display_order列（显示顺序，整数）
    - 添加enabled列（是否启用，1或0）
    - 添加ties列（羁绊类型，字符串）
    - 添加health_regen列（血量恢复速率，浮点数）
    - 为现有角色填入默认值
    - _Requirements: 1.1_
  - [x] 1.2 修改game_config.csv添加新行
    - 添加selection_players_per_row行（默认值5）
    - 添加max_selected_players行（默认值3）
    - _Requirements: 1.2_
  - [x] 1.3 创建player_available_weapons.csv
    - 创建config/player/player_available_weapons.csv文件
    - 定义列：player_id, weapon_type_1, weapon_type_2, weapon_type_3, weapon_type_4
    - 为每个角色配置可用武器类型
    - _Requirements: 1.3_

- [x] 2. 扩展ConfigManager
  - [x] 2.1 添加player_available_weapons加载支持
    - 添加player_available_weapons字典变量
    - 在load_all_configs()中加载player_available_weapons.csv
    - _Requirements: 1.3_
  - [x] 2.2 添加便捷访问方法
    - 实现get_enabled_players()方法（返回enabled=1的角色，按display_order排序）
    - 实现get_player_available_weapons(player_id)方法
    - 实现get_weapon_by_type_level(weapon_type, level)方法（获取指定类型和等级的武器）
    - _Requirements: 1.4, 1.5_

- [x] 3. Checkpoint - 验证CSV配置加载
  - 运行游戏，验证ConfigManager正确加载所有新配置
  - 如有问题请告知

- [x] 4. 实现SelectionPanel基础结构
  - [x] 4.1 重构selection_panel.tscn节点结构
    - 确保PlayerContainer、WeaponContainer、SelectedList、PlayerInfo节点正确命名
    - 保留每个容器中的一个按钮作为模板
    - _Requirements: 2.1, 4.1, 5.1_
  - [x] 4.2 实现selection_panel.gd基础框架
    - 添加节点引用（@onready变量）
    - 添加数据变量（selected_players、preview_player_id等）
    - 实现_ready()初始化方法
    - _Requirements: 2.1_

- [x] 5. 实现角色列表动态生成
  - [x] 5.1 实现_generate_player_buttons()方法
    - 调用ConfigManager.get_enabled_players()获取角色列表
    - 根据selection_players_per_row计算布局
    - 动态创建角色按钮（使用模板复制）
    - 设置按钮图标（从player_visual.csv的sprite_path加载）
    - 连接按钮点击信号
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [x] 5.2 实现角色按钮点击处理
    - 更新preview_player_id
    - 调用_update_player_info()
    - 调用_update_weapon_container()
    - _Requirements: 3.1_

- [x] 6. 实现角色信息显示
  - [x] 6.1 实现_update_player_info()方法
    - 加载并显示角色图标
    - 显示display_name
    - 显示ties（羁绊类型）
    - 格式化并显示属性列表（属性注释:值）
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 7. 实现武器选择功能
  - [x] 7.1 实现_update_weapon_container()方法
    - 清除现有武器按钮（保留模板）
    - 调用ConfigManager.get_player_available_weapons()获取可用武器类型
    - 为每种类型创建1级武器按钮
    - 默认选中第一把武器
    - 连接按钮点击信号
    - _Requirements: 4.1, 4.2, 4.3_
  - [x] 7.2 实现武器按钮点击处理
    - 更新当前选择的武器
    - 更新按钮选中状态
    - 如果角色已在SelectedList中，更新其武器配置
    - _Requirements: 4.4, 4.5_

- [x] 8. 实现SelectedList动态生成
  - [x] 8.1 实现_generate_selected_slots()方法
    - 从game_config读取max_selected_players
    - 动态创建槽位按钮
    - 设置槽位为空状态
    - _Requirements: 5.1_

- [x] 9. 实现拖拽选择功能
  - [x] 9.1 实现角色按钮拖拽
    - 为角色按钮添加拖拽数据（_get_drag_data）
    - 实现拖拽预览
    - _Requirements: 5.2_
  - [x] 9.2 实现SelectedList接收拖拽
    - 为槽位按钮实现_can_drop_data()
    - 实现_drop_data()处理拖拽放置
    - 检查是否已选满
    - 自动选择默认武器（如果未选择）
    - 更新角色按钮"已选中"状态
    - _Requirements: 5.2, 5.3, 5.4, 5.6_
  - [x] 9.3 实现移除已选角色
    - 点击SelectedList中的角色移除
    - 恢复角色按钮"未选中"状态
    - _Requirements: 5.5_

- [ ] 10. Checkpoint - 验证选择界面功能
  - 测试角色列表显示、信息显示、武器选择、拖拽功能
  - 如有问题请告知

- [x] 11. 实现Continue按钮功能
  - [x] 11.1 实现Continue按钮状态管理
    - 未选择角色时禁用按钮
    - 选择角色后启用按钮
    - _Requirements: 6.1_
  - [x] 11.2 实现开始游戏逻辑
    - 将selected_player_ids保存到Global
    - 将selected_player_weapons保存到Global
    - 初始化player_states
    - 切换到arena场景
    - _Requirements: 6.2, 6.3, 6.4, 6.5_

- [x] 12. 扩展Global角色管理
  - [x] 12.1 添加角色选择相关变量
    - 添加selected_player_ids数组
    - 添加selected_player_weapons字典
    - 添加current_player_index变量
    - 添加player_states字典
    - _Requirements: 6.4, 6.5, 8.1, 8.2_
  - [x] 12.2 实现角色状态初始化
    - 实现init_player_states()方法
    - 从CSV加载每个角色的初始状态和恢复配置
    - _Requirements: 8.2, 8.5_

- [x] 13. 实现TAB键角色切换
  - [x] 13.1 实现switch_to_next_player()方法
    - 保存当前角色状态
    - 计算下一个角色索引
    - 销毁当前角色实例
    - 生成新角色并恢复状态
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  - [x] 13.2 添加TAB键输入处理
    - 在Global或Arena中监听TAB键
    - 调用switch_to_next_player()
    - _Requirements: 7.1_

- [x] 14. 实现未激活角色后台恢复
  - [x] 14.1 实现_update_inactive_players_regen()方法
    - 在Global._process()中调用
    - 遍历未激活角色
    - 恢复能量（使用energy_regen）
    - 恢复血量（使用health_regen，如果>0）
    - _Requirements: 8.3, 8.4, 8.5_

- [x] 15. 修改角色死亡逻辑
  - [x] 15.1 修改PlayerBase._on_death()方法
    - 调用Global.game_over()
    - 保留原有死亡效果
    - _Requirements: 9.1, 9.2_
  - [x] 15.2 实现Global.game_over()方法
    - 显示Game Over效果
    - 重新加载场景或返回主菜单
    - _Requirements: 9.2, 9.3_

- [ ] 16. Checkpoint - 完整功能测试
  - 测试完整流程：选择角色 → 开始游戏 → TAB切换 → 状态保持 → 后台恢复 → 死亡结束
  - 如有问题请告知

## Notes

- 所有按钮动态生成时使用场景中保留的模板按钮复制
- 角色图标使用player_visual.csv的sprite_path
- 武器只显示1级（如punch_1、laser_1）
- 羁绊系统本次只显示，不实现加成逻辑
- 任意角色死亡即游戏结束
