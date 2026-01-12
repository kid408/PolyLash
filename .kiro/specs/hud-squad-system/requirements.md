# Requirements Document

## Introduction

本功能对游戏的 HUD（战斗界面）和输入系统进行重构。目前的 UI 左上角过于拥挤（XP、金币、能量叠在一起），需要将 UI 拆分为顶部全局信息栏和底部小队状态栏。同时，操作方案需要从原本的 TAB 轮切改为 1-2-3 键精准切换，以适配"3人小队"机制。

## Glossary

- **Global_HUD**: 顶部全局信息栏，显示波次、XP、金币等不影响战斗操作的信息
- **Squad_HUD**: 底部小队状态栏，显示3个角色卡槽、独立血条、能量条等战斗相关信息
- **Character_Slot**: 角色卡槽，对应键盘按键 [1]、[2]、[3]，显示角色头像、血条和选中状态
- **Session_XP**: 局内经验值，每次重新开始游戏时重置为 0
- **Total_Gold**: 累计金币，局外成长资源，需要持久化保存
- **Energy_Bar**: 能量条，画线玩法的核心资源，关联到当前选中的角色
- **Squad_Index**: 小队索引，0-2 对应 1-2-3 号位角色

## Requirements

### Requirement 1: 顶部全局信息栏

**User Story:** As a player, I want to see global game information at the top of the screen, so that I can track my progress without blocking combat view.

#### Acceptance Criteria

1. THE Global_HUD SHALL display at the top-center or top-right of the screen
2. THE Global_HUD SHALL display current wave number (Wave)
3. THE Global_HUD SHALL display session XP (局内经验值)
4. THE Global_HUD SHALL display total gold (累计金币)
5. WHEN a new game session starts, THE System SHALL reset Session_XP to 0
6. WHEN gold is earned, THE System SHALL persist Total_Gold to save file immediately
7. WHEN the game ends, THE System SHALL NOT reset Total_Gold

### Requirement 2: 底部小队状态栏

**User Story:** As a player, I want to see my squad status at the bottom of the screen, so that I can monitor all three characters' health and quickly switch between them.

#### Acceptance Criteria

1. THE Squad_HUD SHALL display at the bottom-center or bottom-left of the screen
2. THE Squad_HUD SHALL contain exactly 3 Character_Slots corresponding to keys [1], [2], [3]
3. WHEN displaying a Character_Slot, THE System SHALL show the character's portrait/avatar
4. WHEN displaying a Character_Slot, THE System SHALL show an independent HP bar above the slot
5. WHEN a character is currently controlled, THE System SHALL highlight or enlarge that Character_Slot
6. THE Energy_Bar SHALL be prominently displayed and associated with the currently selected character
7. WHEN a character dies (HP <= 0), THE System SHALL gray out the portrait and display "DEAD" text
8. WHEN a character dies, THE System SHALL disable the corresponding key input for that slot

### Requirement 3: 1-2-3 键精准切换

**User Story:** As a player, I want to switch characters using 1-2-3 keys directly, so that I can maintain muscle memory and precisely control which character I'm using.

#### Acceptance Criteria

1. WHEN key 1 (key_code: 49) is pressed, THE System SHALL attempt to switch to Squad_Index 0
2. WHEN key 2 (key_code: 50) is pressed, THE System SHALL attempt to switch to Squad_Index 1
3. WHEN key 3 (key_code: 51) is pressed, THE System SHALL attempt to switch to Squad_Index 2
4. WHEN the target character is already active, THE System SHALL ignore the switch request (self-blocking)
5. IF the target character is dead (HP <= 0), THEN THE System SHALL reject the switch request
6. IF the target character is dead, THEN THE System SHALL play an "invalid operation" sound effect
7. IF the target character is dead, THEN THE System SHALL shake the corresponding Character_Slot icon
8. WHEN a dead character's key is pressed, THE System SHALL NOT auto-skip to the next alive character

### Requirement 4: 独立角色属性

**User Story:** As a player, I want each character to have independent health and energy, so that character management becomes a strategic element.

#### Acceptance Criteria

1. THE System SHALL maintain independent current_health for each character instance
2. THE System SHALL maintain independent max_health for each character instance
3. THE System SHALL maintain independent energy for each character instance
4. WHEN switching characters, THE System SHALL preserve the previous character's health and energy state
5. WHEN switching characters, THE System SHALL restore the new character's previously saved health and energy state

### Requirement 5: 资源分离

**User Story:** As a developer, I want clear separation between session resources and persistent resources, so that the code is maintainable and the game economy is correct.

#### Acceptance Criteria

1. THE System SHALL clearly distinguish Session_XP (局内变量) from Total_Gold (持久化数据)
2. WHEN a game session ends, THE System SHALL reset Session_XP to 0
3. WHEN a game session ends, THE System SHALL persist Total_Gold to storage
4. THE System SHALL load Total_Gold from storage when the game starts
5. THE System SHALL NOT persist Session_XP between game sessions

### Requirement 6: 废弃 TAB 轮切

**User Story:** As a player, I want the TAB key cycling to be removed, so that I only use the 1-2-3 keys for character switching.

#### Acceptance Criteria

1. THE System SHALL remove or disable TAB key character cycling functionality
2. THE System SHALL only respond to 1-2-3 keys for character switching
3. WHEN TAB is pressed, THE System SHALL NOT switch characters
