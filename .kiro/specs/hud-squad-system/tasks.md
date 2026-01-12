# Implementation Plan: HUD Squad System

## Overview

本实现计划将 HUD 重构和小队切换系统分解为可执行的编码任务。任务按照依赖关系排序，确保每个步骤都能在前一步的基础上构建。

## Tasks

- [x] 1. 扩展 Global.gd 小队管理功能
  - [x] 1.1 添加 session_xp 局内变量和相关信号
    - 添加 `var session_xp: int = 0`
    - 添加 `signal on_session_xp_changed(current: int)`
    - 添加 `func add_session_xp(amount: int)` 和 `func reset_session_data()`
    - _Requirements: 5.1, 5.2_
  - [x] 1.2 实现 switch_to_player_by_index 方法
    - 添加 `signal on_switch_rejected(index: int, reason: String)`
    - 添加 `signal on_active_character_changed(index: int)`
    - 实现索引有效性检查、自我屏蔽、死亡检查逻辑
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.8_
  - [x] 1.3 添加辅助方法
    - 添加 `func is_player_dead(index: int) -> bool`
    - 添加 `func get_player_state_by_index(index: int) -> Dictionary`
    - _Requirements: 2.8, 4.1, 4.2, 4.3_

- [x] 2. 创建 Character Slot 组件
  - [x] 2.1 创建 character_slot.tscn 场景
    - 创建 Control 根节点
    - 添加 Portrait (TextureRect)、HealthBar (ProgressBar)、KeyLabel (Label)
    - 添加 DeadOverlay (ColorRect)、DeadLabel (Label)、Highlight (Panel)
    - _Requirements: 2.3, 2.4_
  - [x] 2.2 实现 character_slot.gd 脚本
    - 实现 `setup(player_id: String, key_number: int)`
    - 实现 `update_health(current: float, max_health: float)`
    - 实现 `set_dead(dead: bool)` 和 `set_active(active: bool)`
    - 实现 `play_shake_animation()` 抖动动画
    - _Requirements: 2.5, 2.7, 3.7_

- [x] 3. 创建 Squad HUD 组件
  - [x] 3.1 创建 squad_hud.tscn 场景
    - 创建 Control 根节点，设置底部居中锚点
    - 添加 HBoxContainer 包含 3 个 CharacterSlot 实例
    - 添加 EnergyBar (TextureProgressBar)
    - _Requirements: 2.1, 2.2_
  - [x] 3.2 实现 squad_hud.gd 脚本
    - 实现 `init_squad(player_ids: Array[String])`
    - 实现 `update_character_state(index: int, health: float, max_health: float, is_dead: bool)`
    - 实现 `set_active_character(index: int)`
    - 实现 `update_energy(current: float, max_energy: float)`
    - 实现 `play_invalid_feedback(index: int)`
    - _Requirements: 2.5, 2.6, 2.7, 2.8_

- [x] 4. 创建 Global HUD 组件
  - [x] 4.1 创建 global_hud.tscn 场景
    - 创建 Control 根节点，设置顶部居中锚点
    - 添加 WaveLabel、XPLabel、GoldLabel
    - 使用现有字体样式保持一致性
    - _Requirements: 1.1_
  - [x] 4.2 实现 global_hud.gd 脚本
    - 实现 `update_wave(wave_number: int, wave_time: float)`
    - 实现 `update_xp(current_xp: int)`
    - 实现 `update_gold(total_gold: int)`
    - _Requirements: 1.2, 1.3, 1.4_

- [x] 5. Checkpoint - 验证 UI 组件
  - 确保所有 UI 组件可以独立实例化
  - 确保布局和样式符合设计
  - 如有问题请询问用户

- [x] 6. 修改 Arena 场景集成新 HUD
  - [x] 6.1 更新 arena.tscn 场景结构
    - 移除旧的 xpLabel 和 goldLabel 节点
    - 添加 GlobalHUD 实例到 GameUI
    - 添加 SquadHUD 实例到 GameUI
    - _Requirements: 1.1, 2.1_
  - [x] 6.2 更新 arena.gd 输入处理
    - 移除 TAB 键切换逻辑
    - 添加 1-2-3 键切换处理
    - 添加 `_try_switch_to_index(index: int)` 方法
    - 添加无效切换音效播放
    - _Requirements: 3.1, 3.2, 3.3, 3.6, 6.1, 6.2, 6.3_
  - [x] 6.3 连接 HUD 信号和更新逻辑
    - 连接 Global.on_session_xp_changed 到 GlobalHUD
    - 连接 Global.on_active_character_changed 到 SquadHUD
    - 连接 Global.on_switch_rejected 到 SquadHUD
    - 实现 _process 中的状态同步
    - _Requirements: 1.2, 1.3, 1.4, 2.5, 2.6, 2.7_

- [x] 7. 确保数据分离和持久化
  - [x] 7.1 验证 DataManager 金币持久化
    - 确认 add_gold 立即调用 save_game
    - 确认 total_gold 在游戏结束后不重置
    - _Requirements: 1.6, 1.7, 5.3, 5.4_
  - [x] 7.2 实现 session_xp 重置逻辑
    - 在 Arena._ready 中调用 Global.reset_session_data()
    - 确保 session_xp 不被持久化
    - _Requirements: 1.5, 5.2, 5.5_

- [x] 8. 添加无效操作音效资源
  - 添加 ui_reject.wav 音效文件到 assets/audio/
  - 在 Global.gd 中预加载音效
  - _Requirements: 3.6_

- [x] 9. Checkpoint - 完整功能测试
  - 测试 1-2-3 键切换功能
  - 测试死亡角色切换拒绝
  - 测试 UI 状态同步
  - 确保所有功能正常工作，如有问题请询问用户

- [x] 10. 清理和优化
  - [x] 10.1 移除废弃代码
    - 移除 switch_player action 相关代码
    - 移除 switch_to_next_player 方法（如不再需要）
    - _Requirements: 6.1_
  - [x] 10.2 添加调试日志
    - 在关键切换点添加 print 语句
    - 便于后续调试和问题排查

## Notes

- 任务按依赖关系排序：先扩展 Global.gd，再创建 UI 组件，最后集成到 Arena
- Checkpoint 任务用于验证阶段性成果
- 所有 UI 组件使用 Godot 4.x 的 Control 节点系统
- 音效文件需要用户提供或使用占位符
