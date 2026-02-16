# 实现计划：音频裁剪播放（Audio Trim Playback）

## 概述

为 SoundManager 添加 `start_time` / `end_time` 裁剪播放支持。修改范围：4 个 CSV 配置文件 + sound_manager.gd。

## 任务

- [x] 1. 更新 CSV 配置文件
  - [x] 1.1 为 4 个 CSV 文件追加 `start_time,end_time` 列
    - 修改 `config/audio/ui_sounds.csv`、`combat_sounds.csv`、`skill_sounds.csv`、`environment_sounds.csv`
    - 表头行追加 `start_time,end_time`
    - 注释行（第二行）追加 `起始时间(秒),截止时间(秒)`
    - 所有现有数据行追加 `0.0,0.0`
    - _Requirements: 1.3_

- [x] 2. 修改 SoundManager 支持 start_time 播放
  - [x] 2.1 修改 `_play_stream()` 方法签名，新增 `start_time: float = 0.0` 和 `end_time: float = 0.0` 参数
    - 将 `audio_player.play()` 改为 `audio_player.play(start_time)`
    - 当 `end_time > start_time` 时，将播放器索引注册到 `_end_time_tracker`
    - _Requirements: 2.1, 2.2, 3.1, 3.2, 4.1_
  - [x] 2.2 修改 `play()` 方法，从配置中提取 `start_time` 和 `end_time` 并传递给 `_play_stream()`
    - 使用 `float(config.get("start_time", 0.0))` 和 `float(config.get("end_time", 0.0))`
    - _Requirements: 1.1, 1.2, 1.4, 2.1_
  - [x] 2.3 修改 `play_character_q_closure()` 方法，调用 `_play_stream()` 时传入默认参数
    - 确保现有调用兼容（使用默认值 `0.0, 0.0`）
    - _Requirements: 1.4_

- [x] 3. 实现 end_time 轮询停止机制
  - [x] 3.1 新增 `_end_time_tracker: Dictionary = {}` 成员变量
    - _Requirements: 4.1_
  - [x] 3.2 实现 `_process(_delta)` 方法
    - 追踪字典为空时立即返回
    - 遍历追踪字典，检查每个播放器的 `get_playback_position()`
    - 播放器已停止或位置 >= end_time 时，停止播放器并从字典中移除
    - 使用 `to_remove` 数组避免遍历中修改字典
    - _Requirements: 3.1, 3.3, 4.2, 4.3_

- [x] 4. 检查点 - 验证功能完整性
  - 确保所有修改编译通过，无语法错误
  - 确保现有音效（start_time=0.0, end_time=0.0）行为不变
  - 如有问题请向用户确认
