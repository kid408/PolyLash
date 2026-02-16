# 需求文档

## 简介

为现有的 SoundManager 音效管理系统添加音频裁剪播放功能。通过在 CSV 配置中新增 `start_time` 和 `end_time` 两个字段，允许每个音效配置独立的播放起止时间，实现跳过前导静音或截断尾部内容的效果。该功能对现有音效零侵入——当两个字段均为默认值 `0.0` 时，行为与当前完全一致。

## 术语表

- **SoundManager**: 自动加载的音效管理节点，维护 32 槽 AudioStreamPlayer 对象池，通过 CSV 配置驱动音效播放
- **AudioStreamPlayer**: Godot 引擎的音频播放器节点
- **start_time**: 音频播放起始时间偏移量（秒），指定从音频文件的哪个时间点开始播放
- **end_time**: 音频播放截止时间（秒），指定播放到音频文件的哪个时间点停止
- **_end_time_tracker**: 内部字典，追踪需要进行 end_time 检测的播放器索引与对应截止时间
- **对象池**: SoundManager 中预创建的 32 个 AudioStreamPlayer 实例，通过轮询方式分配使用

## 需求

### 需求 1：CSV 配置扩展

**用户故事：** 作为音效设计师，我希望在 CSV 配置文件中为每个音效指定播放起止时间，以便精确控制音频裁剪而无需编辑音频文件本身。

#### 验收标准

1. THE SoundManager SHALL 在加载 CSV 配置时解析 `start_time` 和 `end_time` 两个浮点数字段
2. WHEN CSV 行中缺少 `start_time` 或 `end_time` 字段时，THE SoundManager SHALL 将缺失字段默认为 `0.0`
3. THE 四个 CSV 配置文件（ui_sounds.csv、combat_sounds.csv、skill_sounds.csv、environment_sounds.csv）SHALL 在表头行和注释行中包含 `start_time` 和 `end_time` 列
4. WHEN `start_time` 和 `end_time` 均为 `0.0` 时，THE SoundManager SHALL 保持与当前完全一致的播放行为

### 需求 2：起始时间偏移播放

**用户故事：** 作为音效设计师，我希望音效从指定的起始时间开始播放，以便跳过音频文件开头的静音或不需要的部分。

#### 验收标准

1. WHEN 播放一个 `start_time` 大于 `0.0` 的音效时，THE SoundManager SHALL 从该 `start_time`（秒）位置开始播放音频
2. WHEN 播放一个 `start_time` 为 `0.0` 的音效时，THE SoundManager SHALL 从音频文件开头播放

### 需求 3：截止时间停止播放

**用户故事：** 作为音效设计师，我希望音效在指定的截止时间自动停止，以便截断音频文件尾部不需要的内容。

#### 验收标准

1. WHEN 播放一个 `end_time` 大于 `start_time` 的音效时，THE SoundManager SHALL 在播放位置到达 `end_time` 时停止该播放器
2. WHEN `end_time` 为 `0.0` 或 `end_time` 小于等于 `start_time` 时，THE SoundManager SHALL 让音频自然播放至结束
3. THE SoundManager SHALL 通过 `_process()` 帧轮询方式检测播放位置，而非使用 Timer 节点

### 需求 4：end_time 追踪器管理

**用户故事：** 作为开发者，我希望 end_time 检测仅在必要时运行，以便最小化性能开销。

#### 验收标准

1. THE SoundManager SHALL 仅对 `end_time` 大于 `start_time` 的播放器进行播放位置检测
2. WHEN 一个被追踪的播放器停止播放（自然结束或被新音效覆盖）时，THE SoundManager SHALL 将该播放器从追踪字典中移除
3. WHEN 追踪字典为空时，THE SoundManager 的 `_process()` SHALL 立即返回，不执行任何遍历操作
