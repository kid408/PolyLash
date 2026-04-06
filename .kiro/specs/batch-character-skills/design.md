# 璁捐鏂囨。锛氭壒閲忚鑹叉妧鑳界郴缁?

## 姒傝堪

鏈璁′负 PolyLash 娓告垙瀹炵幇 30 濂楁柊瑙掕壊鎶€鑳界郴缁熴€傛牳蹇冭璁″師鍒欙細

1. **鏁版嵁椹卞姩**: 灏?skill_params.csv 閲嶆瀯涓洪暱琛ㄦ牸寮忥紝鎵€鏈夋妧鑳藉弬鏁伴€氳繃 CSV 閰嶇疆锛屼笉纭紪鐮?
2. **鏁堟灉鐙珛**: 閫氳繃鎵╁睍 SkillEffectManager 绠＄悊澧欎綋銆丅uff 鍖哄煙銆佸彫鍞ょ墿锛岀‘淇濊鑹插垏鎹㈠悗鏁堟灉鎸佺画
3. **妯℃澘鍖栧紑鍙?*: 涓烘瘡绉嶆晥鏋滅被鍨嬶紙澧欎綋銆丅uff 鍖哄煙銆丏ebuff 鍖哄煙銆佸彫鍞ょ墿锛夋彁渚涘伐鍘傛柟娉曪紝鏂版妧鑳藉彧闇€缁勫悎璋冪敤
4. **鐘舵€佺郴缁熸墿灞?*: 鍦?StatusComponent 涓柊澧炲啺鍐汇€佹矇榛樸€佹亹鎯с€佹爣璁般€佺煶鍖栫姸鎬侊紝鏀寔浼樺厛绾у拰浜掓枼

鎶€鑳芥寜 A-E 浜旂粍缁勭粐锛屽叡 26 濂楁柊鎶€鑳姐€備繚鐣?6 涓師濮嬭鑹诧紙butcher銆乸yro銆乻apper銆乭erder銆亀eaver銆亀ind/tempest锛夛紝鍒犻櫎鍏朵綑 20 涓棫瑙掕壊锛岀劧鍚庢牴鎹妧鑳戒富棰樺垱寤?20 涓叏鏂拌鑹插苟缁戝畾瀵瑰簲鎶€鑳斤紝鍓╀綑 6 濂楋紙D 缁勶級瀛樺叆鎶€鑳藉簱銆?

## 鏋舵瀯

### 鏁翠綋鏋舵瀯鍥?

```mermaid
graph TB
    subgraph "閰嶇疆灞?
        CSV_LONG["skill_params.csv (闀胯〃)"]
        CSV_BIND["player_skill_bindings.csv"]
        CM["ConfigManager"]
    end

    subgraph "鎶€鑳藉眰"
        SM["SkillManager"]
        SDB["SkillDrawingBase"]
        SB["SkillBase"]
        subgraph "鏂版妧鑳借剼鏈?(scenes/skills/players/)"
            Q_SKILLS["Q鎶€鑳?(缁ф壙 SkillDrawingBase)"]
            E_SKILLS["E鎶€鑳?(缁ф壙 SkillBase)"]
        end
    end

    subgraph "鏁堟灉灞?
        SEM["SkillEffectManager (鎵╁睍)"]
        WALL["create_wall_effect()"]
        BUFF["create_buff_zone()"]
        DEBUFF["create_debuff_zone()"]
        SUMMON["create_summon()"]
        LINE["create_line_effect() (宸叉湁)"]
        AREA["create_area_effect() (宸叉湁)"]
    end

    subgraph "鐘舵€佸眰"
        SC["StatusComponent (鎵╁睍)"]
        FREEZE["freeze 鍐板喕"]
        SILENCE["silence 娌夐粯"]
        FEAR["fear 鎭愭儳"]
        MARKED["marked 鏍囪"]
        PETRIFY["petrify 鐭冲寲"]
    end

    CSV_LONG --> CM
    CSV_BIND --> CM
    CM --> SM
    SM --> Q_SKILLS
    SM --> E_SKILLS
    Q_SKILLS --> SDB
    E_SKILLS --> SB
    Q_SKILLS --> SEM
    E_SKILLS --> SEM
    SEM --> WALL
    SEM --> BUFF
    SEM --> DEBUFF
    SEM --> SUMMON
    SEM --> LINE
    SEM --> AREA
    SEM --> SC
    DEBUFF --> SC
    SC --> FREEZE
    SC --> SILENCE
    SC --> FEAR
    SC --> MARKED
    SC --> PETRIFY
```

### 鎶€鑳藉紑鍙戞祦绋?

姣忓鏂版妧鑳界殑寮€鍙戦伒寰互涓嬫祦绋嬶細

1. 鍦?`skill_params.csv` 闀胯〃涓坊鍔犳妧鑳藉弬鏁拌
2. 鍒涘缓 Q 鎶€鑳借剼鏈紙缁ф壙 SkillDrawingBase锛夛紝瀹炵幇 `_spawn_line_effect()` 鍜?`_spawn_area_effect()`
3. 鍒涘缓 E 鎶€鑳借剼鏈紙缁ф壙 SkillBase锛夛紝瀹炵幇 `execute()`
4. 鍦?`player_skill_bindings.csv` 涓粦瀹氭妧鑳藉埌瑙掕壊
5. 娴嬭瘯鎶€鑳芥晥鏋滃拰瑙掕壊鍒囨崲鍏煎鎬?

### 鍏抽敭璁捐鍐崇瓥

| 鍐崇瓥 | 閫夋嫨 | 鐞嗙敱 |
|------|------|------|
| CSV 鏍煎紡 | 闀胯〃锛坰kill_id, param_name, param_value锛?| 鏂板鍙傛暟鏃犻渶鏀硅〃缁撴瀯锛岀淮鎶ゆ垚鏈綆 |
| Q 鎶€鑳藉悎骞?| 姣忎釜瑙掕壊涓€涓?Q 鑴氭湰鍚屾椂澶勭悊 line 鍜?circle | 澶嶇敤 SkillDrawingBase 鐨勯棴鍚堟娴嬮€昏緫 |
| 鏁堟灉绠＄悊 | 鍏ㄩ儴閫氳繃 SkillEffectManager | 瑙掕壊鍒囨崲鍚庢晥鏋滄寔缁紝鐢熷懡鍛ㄦ湡缁熶竴绠＄悊 |
| 瑙嗚鍗犱綅 | 褰╄壊鍑犱綍褰㈢姸锛圠ine2D, Polygon2D锛?| 缇庢湳璧勬簮鏈氨缁紝鍚庣画鏇挎崲鏂逛究 |
| 鐘舵€佷紭鍏堢骇 | 纭紪鐮佷紭鍏堢骇琛?| 鐘舵€佺绫绘湁闄愪笖鍥哄畾锛屾棤闇€閰嶇疆鍖?|

## 缁勪欢涓庢帴鍙?

### 1. ConfigManager 鎵╁睍 - 闀胯〃鍔犺浇

```gdscript
# 鏂板鏂规硶锛氬姞杞介暱琛ㄦ牸寮忕殑 skill_params
func load_skill_params_long_format(path: String) -> Dictionary:
    # 杩斿洖: {skill_id: {param_name: param_value, ...}, ...}
    # 姣忚鏍煎紡: skill_id, param_name, param_value, description
    pass

# 淇敼 load_all_configs() 涓殑鍔犺浇閫昏緫
# skill_params = load_skill_params_long_format(SKILL_PARAMS)
# 鎺ュ彛 get_skill_params(skill_id) 淇濇寔涓嶅彉
```

### 2. SkillEffectManager 鎵╁睍

```gdscript
# === 鏂板锛氬浣撴晥鏋?===
func create_wall_effect(config: Dictionary) -> int:
    # config 鍙傛暟:
    #   - start: Vector2 (蹇呴渶) - 澧欎綋璧风偣
    #   - end: Vector2 (蹇呴渶) - 澧欎綋缁堢偣
    #   - width: float (鍙€? 榛樿 16) - 澧欎綋瀹藉害
    #   - duration: float (鍙€? 榛樿 5.0) - 鎸佺画鏃堕棿
    #   - health: int (鍙€? 榛樿 -1) - 澧欎綋鐢熷懡鍊硷紝-1 涓轰笉鍙牬鍧?
    #   - block_enemies: bool (鍙€? 榛樿 true) - 鏄惁闃绘尅鏁屼汉
    #   - block_bullets: bool (鍙€? 榛樿 false) - 鏄惁闃绘尅瀛愬脊
    #   - reflect_bullets: bool (鍙€? 榛樿 false) - 鏄惁鍙嶅皠瀛愬脊
    #   - contact_damage: int (鍙€? 榛樿 0) - 鎺ヨЕ浼ゅ
    #   - contact_interval: float (鍙€? 榛樿 0.5) - 鎺ヨЕ浼ゅ闂撮殧
    #   - color: Color (鍙€? - 澧欎綋棰滆壊
    # 杩斿洖: effect_id
    pass

# === 鏂板锛欱uff 鍖哄煙 ===
func create_buff_zone(config: Dictionary) -> int:
    # config 鍙傛暟:
    #   - polygon: PackedVector2Array 鎴?center+radius
    #   - start/end: Vector2 (绾挎鍨?Buff 鍖哄煙)
    #   - width: float (绾挎鍨嬪搴?
    #   - duration: float - 鎸佺画鏃堕棿
    #   - buff_type: String - Buff 绫诲瀷 ("attack_boost", "speed_boost", "heal", "lifesteal", "invincible", "cooldown_reduction", "ignore_collision")
    #   - buff_value: float - Buff 鏁板€?
    #   - tick_interval: float - 鏁堟灉瑙﹀彂闂撮殧
    #   - color: Color - 鍖哄煙棰滆壊
    #   - target_group: String (榛樿 "players") - 鐩爣缁?
    # 杩斿洖: effect_id
    pass

# === 鏂板锛欴ebuff 鍖哄煙 ===
func create_debuff_zone(config: Dictionary) -> int:
    # config 鍙傛暟:
    #   - polygon: PackedVector2Array 鎴?start/end
    #   - duration: float - 鎸佺画鏃堕棿
    #   - debuff_type: String - Debuff 绫诲瀷 ("slow", "damage_amp", "poison", "freeze", "fear")
    #   - debuff_value: float - Debuff 鏁板€?
    #   - debuff_duration: float - 鍗曟 Debuff 鎸佺画鏃堕棿
    #   - tick_interval: float - 鏁堟灉瑙﹀彂闂撮殧
    #   - damage: int (鍙€? - 鍖哄煙浼ゅ
    #   - damage_interval: float (鍙€? - 浼ゅ闂撮殧
    #   - color: Color - 鍖哄煙棰滆壊
    # 杩斿洖: effect_id
    pass

# === 鏂板锛氬彫鍞ょ墿绠＄悊 ===
func create_summon(config: Dictionary) -> int:
    # config 鍙傛暟:
    #   - position: Vector2 - 鐢熸垚浣嶇疆
    #   - summon_type: String - 鍙敜鐗╃被鍨?("turret", "beetle", "slime", "phantom")
    #   - duration: float - 瀛樻椿鏃堕棿
    #   - health: int (鍙€? - 鐢熷懡鍊?
    #   - damage: int (鍙€? - 鏀诲嚮浼ゅ
    #   - attack_interval: float (鍙€? - 鏀诲嚮闂撮殧
    #   - attack_range: float (鍙€? - 鏀诲嚮鑼冨洿
    #   - max_count: int (鍙€? 榛樿 5) - 鍚岀被鍨嬫渶澶ф暟閲?
    #   - owner_skill_id: String - 鎵€灞炴妧鑳?ID
    #   - color: Color - 鍗犱綅棰滆壊
    # 杩斿洖: effect_id
    pass

# === 鏂板锛氬彫鍞ょ墿鎸囦护 ===
func command_summons(owner_skill_id: String, command: String, target: Node2D = null) -> void:
    # command: "focus_fire", "self_destruct", "return"
    pass
```

### 3. StatusComponent 鎵╁睍

```gdscript
# 鐘舵€佷紭鍏堢骇琛紙鏁板€艰秺楂樹紭鍏堢骇瓒婇珮锛?
const STATUS_PRIORITY = {
    "petrify": 5,   # 鐭冲寲 - 鏈€楂樹紭鍏堢骇
    "freeze": 4,    # 鍐板喕
    "fear": 3,      # 鎭愭儳
    "silence": 2,   # 娌夐粯
    "slow": 1,      # 鍑忛€?
    "burn": 0,      # 鐕冪儳锛圖OT锛屼笉褰卞搷琛屽姩锛?
    "curse": 0,     # 璇呭拻锛圖OT锛屼笉褰卞搷琛屽姩锛?
    "poison": 0,    # 涓瘨锛圖OT锛屼笉褰卞搷琛屽姩锛?
    "marked": 0,    # 鏍囪锛堜笉褰卞搷琛屽姩锛?
}

# 鏂板鐘舵€佸鐞?
func _on_status_applied(status_name: String) -> void:
    match status_name:
        "freeze":
            _apply_freeze_effect()      # 鍋滄绉诲姩鍜屾敾鍑?
        "silence":
            _apply_silence_effect()     # 闃绘鐗规畩鎶€鑳?
        "fear":
            _apply_fear_effect()        # 閫冭窇琛屼负
        "marked":
            _apply_marked_effect()      # 鍙椾激澧炲姞
        "petrify":
            _apply_petrify_effect()     # 瀹屽叏涓嶅彲琛屽姩
        "poison":
            _apply_poison_effect()      # DOT

func _on_status_removed(status_name: String) -> void:
    match status_name:
        "freeze":
            _remove_freeze_effect()
        "silence":
            _remove_silence_effect()
        "fear":
            _remove_fear_effect()
        "marked":
            _remove_marked_effect()
        "petrify":
            _remove_petrify_effect()
        "poison":
            _remove_poison_effect()
```

### 4. 鏂版妧鑳借剼鏈ā鏉?

姣忎釜瑙掕壊鐨?Q 鎶€鑳界户鎵?SkillDrawingBase锛屽彧闇€瀹炵幇涓や釜鏂规硶锛?

```gdscript
# 绀轰緥锛歴kill_bulwark_q.gd
extends SkillDrawingBase
class_name SkillBulwarkQ

# 鍙傛暟浠?CSV 鍔犺浇
var wall_duration: float = 5.0
var freeze_duration: float = 2.0
var wall_width: float = 16.0

func _get_line_color() -> Color:
    return Color(0.5, 0.8, 1.0, 1.0)  # 鍐拌摑鑹?

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    # 鍒涘缓鍐板锛圫taticBody2D锛?
    SkillEffectManager.create_wall_effect({
        "start": start, "end": end,
        "width": wall_width,
        "duration": _get_line_duration(),
        "block_enemies": true, "block_bullets": true,
        "color": Color(0.5, 0.8, 1.0, 0.7)
    })

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    # 鍐板喕鍖哄煙鍐呮晫浜?
    var damage = int(_calculate_closed_shape_damage(0))
    SkillEffectManager.create_debuff_zone({
        "polygon": polygon,
        "duration": freeze_duration,
        "debuff_type": "freeze",
        "debuff_value": freeze_duration,
        "debuff_duration": freeze_duration,
        "tick_interval": 999.0,  # 鍙Е鍙戜竴娆?
        "color": Color(0.3, 0.6, 1.0, 0.5)
    })
```

姣忎釜瑙掕壊鐨?E 鎶€鑳界户鎵?SkillBase锛?

```gdscript
# 绀轰緥锛歴kill_bulwark_e.gd
extends SkillBase
class_name SkillBulwarkE

var knockback_force: float = 500.0
var shield_amount: int = 3
var explosion_radius: float = 150.0

func execute() -> void:
    if not can_execute():
        return
    consume_energy()
    
    # 鍑婚€€闄勮繎鏁屼汉
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if is_instance_valid(enemy):
            var dist = skill_owner.global_position.distance_to(enemy.global_position)
            if dist < explosion_radius:
                var dir = (enemy.global_position - skill_owner.global_position).normalized()
                enemy.global_position += dir * knockback_force * 0.1
    
    # 娣诲姞鎶ょ浘
    if "armor" in skill_owner:
        skill_owner.armor = min(skill_owner.armor + shield_amount, skill_owner.max_armor)
    
    start_cooldown()
```

### 5. 鎶€鑳藉垎缁勪笌鏂囦欢鍛藉悕

| 缁?| 瑙掕壊 | Q 鎶€鑳芥枃浠?| E 鎶€鑳芥枃浠?|
|----|------|-----------|-----------|
| A | bulwark (鍐版渤) | skill_bulwark_q.gd | skill_bulwark_e.gd |
| A | tesla (鐗规柉鎷? | skill_tesla_q.gd | skill_tesla_e.gd |
| A | new_ignis (鏂扮伀娉? | skill_new_ignis_q.gd | skill_new_ignis_e.gd |
| A | matrix (鐦熺柅) | skill_matrix_q.gd | skill_matrix_e.gd |
| A | warden (鐙辫) | skill_warden_q.gd | skill_warden_e.gd |
| A | new_tempest (鏂伴鏆? | skill_new_tempest_q.gd | skill_new_tempest_e.gd |
| B | furnace (閾佸尃) | skill_furnace_q.gd | skill_furnace_e.gd |
| B | inkweaver (鍐涘尰) | skill_inkweaver_q.gd | skill_inkweaver_e.gd |
| B | ammo (寮硅嵂) | skill_ammo_q.gd | skill_ammo_e.gd |
| B | earthshaker (鍦ｉ獞澹? | skill_earthshaker_q.gd | skill_earthshaker_e.gd |
| B | vampire (琛€鏃? | skill_vampire_q.gd | skill_vampire_e.gd |
| B | gunslinger (鏃楁墜) | skill_gunslinger_q.gd | skill_gunslinger_e.gd |
| C | train (鐏溅鐜? | skill_train_q.gd | skill_train_e.gd |
| C | dealer (铏瘝) | skill_dealer_q.gd | skill_dealer_e.gd |
| C | new_totem (钀ㄦ弧) | skill_new_totem_q.gd | skill_new_totem_e.gd |
| C | turret (宸ョ▼) | skill_turret_q.gd | skill_turret_e.gd |
| C | goo (杞偿) | skill_goo_q.gd | skill_goo_e.gd |
| C | illusionist (姝荤伒) | skill_illusionist_q.gd | skill_illusionist_e.gd |
| D | merchant (鍟嗕汉) | skill_merchant_q.gd | skill_merchant_e.gd |
| D | midas (鐐奸噾) | skill_midas_q.gd | skill_midas_e.gd |
| D | vacuum (鍚稿皹鍣? | skill_vacuum_q.gd | skill_vacuum_e.gd |
| D | bloodhowl (澶勫垜) | skill_bloodhowl_q.gd | skill_bloodhowl_e.gd |
| D | gambler (璧屽緬) | skill_gambler_q.gd | skill_gambler_e.gd |
| D | hunter (鐚庝汉) | skill_hunter_q.gd | skill_hunter_e.gd |
| E | viper (榄旀湳甯? | skill_viper_q.gd | skill_viper_e.gd |
| E | voodoo (宸瘨) | skill_voodoo_q.gd | skill_voodoo_e.gd |

## 鏁版嵁妯″瀷

### 1. skill_params.csv 闀胯〃鏍煎紡

```csv
skill_id,param_name,param_value,description
-1,鍙傛暟鍚?鍙傛暟鍊?璇存槑
skill_bulwark_q,energy_per_10px,0.4,姣?0鍍忕礌鑳介噺娑堣€?
skill_bulwark_q,energy_threshold_distance,1800,鑳介噺閫掑闃堝€?
skill_bulwark_q,energy_scale_multiplier,0.0005,鑳介噺閫掑绯绘暟
skill_bulwark_q,wall_duration,5.0,鍐板鎸佺画鏃堕棿
skill_bulwark_q,wall_width,16.0,鍐板瀹藉害
skill_bulwark_q,freeze_duration,2.0,鍐板喕鎸佺画鏃堕棿
skill_bulwark_q,base_line_duration,5.0,绾挎潯鍩虹鎸佺画鏃堕棿
skill_bulwark_q,cooldown,0,鍐峰嵈鏃堕棿
skill_bulwark_e,energy_cost,40,鑳介噺娑堣€?
skill_bulwark_e,cooldown,8,鍐峰嵈鏃堕棿
skill_bulwark_e,knockback_force,500,鍑婚€€鍔涘害
skill_bulwark_e,shield_amount,3,鎶ょ浘鍊?
skill_bulwark_e,explosion_radius,150,鐖嗙偢鍗婂緞
```

### 2. 鐜版湁瀹借〃鏁版嵁杩佺Щ

鐜版湁 13 涓妧鑳界殑鍙傛暟灏嗕粠瀹借〃杩佺Щ鍒伴暱琛ㄣ€傝縼绉昏鍒欙細
- 瀹借〃涓€间负 0 鐨勫弬鏁颁笉杩佺Щ锛堝噺灏戞暟鎹噺锛?
- 淇濈暀 skill_id銆乪nergy_cost銆乧ooldown 绛夐€氱敤鍙傛暟
- 淇濈暀鍚勬妧鑳界壒鏈夌殑闈為浂鍙傛暟

绀轰緥杩佺Щ锛坰kill_saw_path锛夛細
```csv
skill_saw_path,energy_cost,10,鑳介噺娑堣€?
skill_saw_path,cooldown,0,鍐峰嵈鏃堕棿
skill_saw_path,fixed_segment_length,400,绾挎闀垮害
skill_saw_path,saw_fly_speed,1100,閿潯閫熷害
skill_saw_path,saw_damage_tick,3,閿潯浼ゅ(闂?
skill_saw_path,saw_damage_open,1,閿潯浼ゅ(寮€)
skill_saw_path,chain_radius,250,閾炬潯鍗婂緞
skill_saw_path,energy_per_10px,0.4,姣?0鍍忕礌鑳介噺
skill_saw_path,energy_threshold_distance,1800,鑳介噺闃堝€?
skill_saw_path,energy_scale_multiplier,0.001,鑳介噺閫掑
skill_saw_path,stake_duration,6,鑲夋々鎸佺画
skill_saw_path,saw_rotation_speed,25,閿潯鏃嬭浆閫熷害
skill_saw_path,saw_push_force,1000,閿潯鍑婚€€鍔?
skill_saw_path,dismember_damage,200,鑲㈣В浼ゅ
skill_saw_path,saw_max_distance,900,閿潯鏈€澶ц窛绂?
```

### 3. 鍒犻櫎鏃ц鑹蹭笌鍒涘缓鏂拌鑹?

#### 3a. 闇€瑕佸垹闄ょ殑 20 涓棫瑙掕壊

浠ヤ笅鏃ц鑹插皢浠庢墍鏈夐厤缃枃浠跺拰鑴氭湰涓畬鍏ㄥ垹闄わ細

| 鏃?player_id | 鏃т腑鏂囧悕 | 闇€鍒犻櫎鐨勮剼鏈枃浠?|
|---|---|---|
| technology_hurricane | 绉戞妧椋撻 | player_technology_hurricane.gd |
| tankman | 鍧﹀厠鎵?| player_tankman.gd |
| heavy_support | 閲嶅瀷鎻村叺 | player_heavy_support.gd |
| warrior | 姝﹀＋ | player_warrior.gd |
| electric_shock | 鐢靛嚮 | player_electric_shock.gd |
| wizard | 宸笀 | player_wizard.gd |
| fortune_teller | 鍗犲崪甯?| player_fortune_teller.gd |
| tarot_reader | 濉旂綏甯?| player_tarot_reader.gd |
| necromancer | 姝荤伒娉曞笀 | player_necromancer.gd |
| magician | 榄旀硶甯?| player_magician.gd |
| witch_doctor | 宸尰 | player_witch_doctor.gd |
| lovely | 灏忓彲鐖?| player_lovely.gd |
| camouflage | 杩峰僵 | player_camouflage.gd |
| the_flash | 闂數渚?| player_the_flash.gd |
| information_Support | 淇℃伅鏀彺 | player_information_Support.gd |
| technical_support | 绉戞妧鎻村叺 | player_technical_support.gd |
| light_support | 杞诲瀷鎻村叺 | player_light_support.gd |
| dryad | 寰烽瞾浼?| player_dryad.gd |
| doctor | 鍖荤敓 | player_doctor.gd |
| nurse | 鎶ゅ＋ | player_nurse.gd |

鍒犻櫎娑夊強鐨勬枃浠讹細
- `config/player/player_config.csv` - 鍒犻櫎瀵瑰簲琛?
- `config/player/player_visual.csv` - 鍒犻櫎瀵瑰簲琛?
- `config/player/player_weapons.csv` - 鍒犻櫎瀵瑰簲琛?
- `config/player/player_skill_bindings.csv` - 鍒犻櫎瀵瑰簲琛?
- `config/player/ult_config.csv` - 鍒犻櫎瀵瑰簲琛?
- `config/player/player_available_weapons.csv` - 鍒犻櫎瀵瑰簲琛?
- `scenes/unit/players/player_xxx.gd` - 鍒犻櫎鑴氭湰鏂囦欢鍙?.uid 鏂囦欢

#### 3b. 闇€瑕佸垱寤虹殑 20 涓柊瑙掕壊

鏍规嵁鎶€鑳戒富棰樺垱寤哄叏鏂拌鑹诧紝姣忎釜瑙掕壊浣跨敤妯℃澘鍖栫殑 GDScript 鑴氭湰锛堝弬鑰?player_technology_hurricane.gd 鐨勬ā鏉跨粨鏋勶級銆傛柊瑙掕壊鐨勫睘鎬у€煎弬鑰冨師濮嬪叚瑙掕壊鐨勫钩鍧囧€艰繘琛屽悎鐞嗗垎閰嶃€?

| 鏂?player_id | 涓枃鍚?| 鍒嗛厤鎶€鑳界粍 | 韬笘鏍囩 | 鑱岃兘鏍囩 | 鎴樻湳鏍囩 |
|---|---|---|---|---|---|
| bulwark | 鍐版渤 | A 缁?| colossus | architect | vanguard |
| tesla | 鐗规柉鎷?| A 缁?| nomad | blaster | vanguard |
| new_ignis | 鏂扮伀娉?| A 缁?| inkborn | blaster | vanguard |
| matrix | 鐦熺柅 | A 缁?| alchemist | hexer | commander |
| warden | 鐙辫 | A 缁?| colossus | architect | vanguard |
| new_tempest | 鏂伴鏆?| A 缁?| nomad | geometrist | commander |
| furnace | 閾佸尃 | B 缁?| colossus | blaster | assist |
| inkweaver | 鍐涘尰 | B 缁?| alchemist | hexer | assist |
| ammo | 寮硅嵂 | B 缁?| alchemist | blaster | assist |
| earthshaker | 鍦ｉ獞澹?| B 缁?| colossus | geometrist | assist |
| vampire | 琛€鏃?| B 缁?| inkborn | hexer | vanguard |
| gunslinger | 鏃楁墜 | B 缁?| nomad | geometrist | commander |
| train | 鐏溅鐜?| C 缁?| colossus | blaster | commander |
| dealer | 铏瘝 | C 缁?| alchemist | hexer | commander |
| new_totem | 钀ㄦ弧 | C 缁?| inkborn | architect | commander |
| turret_eng | 宸ョ▼ | C 缁?| nomad | blaster | assist |
| goo | 杞偿 | C 缁?| inkborn | hexer | assist |
| illusionist | 姝荤伒 | C 缁?| inkborn | architect | vanguard |
| viper | 榄旀湳甯?| E 缁?| nomad | geometrist | assist |
| voodoo | 宸瘨 | E 缁?| colossus | geometrist | vanguard |

鏂拌鑹插垱寤烘秹鍙婄殑鏂囦欢锛?
- `config/player/player_config.csv` - 娣诲姞鏂拌鑹茶锛堝睘鎬у€煎悎鐞嗗垎閰嶏級
- `config/player/player_visual.csv` - 娣诲姞鏂拌鑹茶锛堜娇鐢ㄩ€氱敤鍗犱綅瑙嗚锛?
- `config/player/player_weapons.csv` - 娣诲姞鏂拌鑹茶锛堜娇鐢ㄩ€氱敤姝﹀櫒閰嶇疆锛?
- `config/player/player_skill_bindings.csv` - 娣诲姞鏂拌鑹茶 + 缁戝畾鏂版妧鑳?
- `config/player/ult_config.csv` - 娣诲姞鏂拌鑹茶锛堜娇鐢ㄩ€氱敤澶ф嫑閰嶇疆锛?
- `config/player/player_available_weapons.csv` - 娣诲姞鏂拌鑹茶
- `scenes/unit/players/player_xxx.gd` - 鍒涘缓鏂拌剼鏈枃浠讹紙浣跨敤妯℃澘锛?

#### 3c. 鏂拌鑹插睘鎬у弬鑰冨€?

鏂拌鑹茬殑鍩虹灞炴€ф牴鎹叾瀹氫綅鍒嗛厤锛?

| 瀹氫綅 | 鐢熷懡鍊?| 琛€閲忔仮澶?| 鏈€澶ц兘閲?| 鏈€澶ф姢鐢?| 绉诲姩閫熷害 | 鑳介噺鎭㈠ |
|------|--------|---------|---------|---------|---------|---------|
| 鍧﹀厠鍨嬶紙bulwark, warden, earthshaker锛?| 140-160 | 0.5-1.0 | 1000 | 5-7 | 350-450 | 0.4-0.6 |
| 娉曞笀鍨嬶紙tesla, new_ignis, matrix, new_tempest, illusionist, voodoo锛?| 85-100 | 0-0.3 | 1000 | 1-2 | 480-520 | 0.8-1.2 |
| 杈呭姪鍨嬶紙furnace, inkweaver, ammo, gunslinger锛?| 95-110 | 0.3-0.5 | 1000 | 2-3 | 480-520 | 0.6-1.0 |
| 鍙敜鍨嬶紙dealer, new_totem, turret_eng, goo锛?| 90-110 | 0.2-0.5 | 1000 | 2-3 | 480-510 | 0.6-0.8 |
| 鐗规畩鍨嬶紙train, vampire, viper锛?| 90-120 | 0.2-0.5 | 1000 | 2-3 | 480-550 | 0.6-1.0 |

### 3d. 缇佺粖绯荤粺閲嶈璁?

#### 璁捐鐞嗗康

鏃х殑缇佺粖鏍囩鍒嗛厤鏄熀浜?26 涓鑹诧紙鍚?20 涓棫瑙掕壊锛夎璁＄殑锛屽垹闄ゆ棫瑙掕壊骞跺垱寤烘柊瑙掕壊鍚庯紝闇€瑕侀噸鏂板钩琛℃爣绛惧垎甯冦€傝璁＄洰鏍囷細

1. 姣忎釜鏍囩绫诲埆鍐呭悇鏍囩鐨勮鑹叉暟閲忓敖閲忓潎琛★紙卤1 鐨勫樊寮傚彲鎺ュ彈锛?
2. 鏍囩鍒嗛厤搴斾笌瑙掕壊鐨勬妧鑳戒富棰樺拰瀹氫綅鍚诲悎
3. 淇濇寔鍘熷鍏鑹茬殑鏍囩涓嶅彉
4. 婵€娲婚槇鍊间繚鎸?2/4/6 涓嶅彉锛堥€傞厤 4-6 浜洪槦浼嶏級

#### 鍘熷鍏鑹叉爣绛撅紙涓嶅彲淇敼锛?

| player_id | origin_tag | mastery_tag | tactic_tag |
|-----------|-----------|-------------|------------|
| butcher | colossus | architect | vanguard |
| ignis | inkborn | blaster | vanguard |
| diva | alchemist | architect | assist |
| herder | alchemist | architect | commander |
| nexus | inkborn | hexer | assist |
| windblade | nomad | geometrist | commander |

#### 鏂?20 瑙掕壊鏍囩閲嶆柊鍒嗛厤

鐩爣鍒嗗竷锛?6 瑙掕壊鎬昏锛夛細
- Origin: colossus=7, inkborn=7, nomad=6, alchemist=6
- Mastery: architect=7, blaster=7, hexer=6, geometrist=6
- Tactic: vanguard=9, assist=9, commander=8

| 鏂?player_id | 涓枃鍚?| origin_tag | mastery_tag | tactic_tag | 璁捐鐞嗙敱 |
|---|---|---|---|---|---|
| bulwark | 鍐版渤 | colossus | architect | vanguard | 鍐板=绛戝锛岄噸瑁呭墠鎺?|
| tesla | 鐗规柉鎷?| nomad | blaster | vanguard | 鐢靛姬鏈哄姩锛屾父渚犵獊鍑?|
| new_ignis | 鏂扮伀娉?| inkborn | blaster | vanguard | 鐏劙鐖嗙牬锛岄瓟娉曠獊鍑?|
| matrix | 鐦熺柅 | alchemist | hexer | commander | 鐐奸噾姣掔礌锛岃瘏鍜掓寚鎸?|
| warden | 鐙辫 | colossus | architect | vanguard | 鐢电綉绛戝锛岄噸瑁呭墠鎺?|
| new_tempest | 鏂伴鏆?| nomad | geometrist | commander | 椋庡甫鏈哄姩锛屽嚑浣曟寚鎸?|
| furnace | 閾佸尃 | colossus | blaster | assist | 閿婚€犲己鍖栵紝閲嶈杈呭姪 |
| inkweaver | 鍐涘尰 | alchemist | hexer | assist | 鐐奸噾娌荤枟锛屽拻鏈緟鍔?|
| ammo | 寮硅嵂 | alchemist | blaster | assist | 鍚庡嫟寮硅嵂锛岀垎鐮磋緟鍔?|
| earthshaker | 鍦ｉ獞澹?| colossus | geometrist | assist | 閲嶈鎶ょ浘锛屽嚑浣曡緟鍔?|
| vampire | 琛€鏃?| inkborn | hexer | vanguard | 榄旀硶琛€鏃忥紝璇呭拻绐佸嚮 |
| gunslinger | 鏃楁墜 | nomad | geometrist | commander | 娓镐緺鏃楁墜锛屽嚑浣曟寚鎸?|
| train | 鐏溅鐜?| colossus | blaster | commander | 閲嶈鍐插嚮锛岀垎鐮存寚鎸?|
| dealer | 铏瘝 | alchemist | hexer | commander | 鐐奸噾铏兢锛屽拻鏈寚鎸?|
| new_totem | 钀ㄦ弧 | inkborn | architect | commander | 榄旀硶鍥捐吘锛岀瓚澧欐寚鎸?|
| turret_eng | 宸ョ▼ | nomad | blaster | assist | 娓镐緺宸ョ▼锛岀垎鐮磋緟鍔?|
| goo | 杞偿 | inkborn | hexer | assist | 榄旀硶杞偿锛屽拻鏈緟鍔?|
| illusionist | 姝荤伒 | inkborn | architect | vanguard | 榄旀硶楠ㄥ锛岀瓚澧欑獊鍑?|
| viper | 榄旀湳甯?| nomad | geometrist | assist | 娓镐緺骞绘湳锛屽嚑浣曡緟鍔?|
| voodoo | 宸瘨 | colossus | geometrist | vanguard | 宸瘨閲嶈锛屽嚑浣曠獊鍑?|

#### 鏍囩鍒嗗竷楠岃瘉

| 鏍囩 | 绫诲瀷 | 鏁伴噺 | 瑙掕壊鍒楄〃 |
|------|------|------|---------|
| colossus | origin | 7 | butcher, bulwark, warden, furnace, earthshaker, train, voodoo |
| inkborn | origin | 7 | ignis, nexus, new_ignis, vampire, new_totem, goo, illusionist |
| nomad | origin | 6 | windblade, tesla, new_tempest, gunslinger, turret_eng, viper |
| alchemist | origin | 6 | diva, herder, matrix, inkweaver, ammo, dealer |
| architect | mastery | 7 | butcher, diva, herder, bulwark, warden, new_totem, illusionist |
| blaster | mastery | 7 | ignis, new_ignis, tesla, furnace, ammo, train, turret_eng |
| hexer | mastery | 6 | nexus, matrix, inkweaver, vampire, dealer, goo |
| geometrist | mastery | 6 | windblade, new_tempest, earthshaker, gunslinger, viper, voodoo |
| vanguard | tactic | 9 | butcher, ignis, bulwark, warden, new_ignis, tesla, vampire, illusionist, voodoo |
| assist | tactic | 9 | diva, nexus, furnace, inkweaver, ammo, earthshaker, turret_eng, goo, viper |
| commander | tactic | 8 | herder, windblade, matrix, new_tempest, gunslinger, train, dealer, new_totem |

> 娉細鎵€鏈夋爣绛惧潎琛″垎甯冿紝姣忎釜鏍囩鑷冲皯 6 涓鑹诧紝4 浜洪槦浼嶈兘鍑戝嚭 2 绾х緛缁娿€? 浜洪槦浼嶈兘鍑戝嚭 3 绾х緛缁娿€?

#### 缇佺粖鏁堟灉閲嶈璁?

淇濇寔鐜版湁 bond_config.csv 鐨勭粨鏋勫拰鏁堟灉涓嶅彉锛屽洜涓猴細
- 鐜版湁鏁堟灉璁捐宸茬粡寰堟垚鐔燂紝涓庣敾绾?闂悎鐨勬牳蹇冪帺娉曠揣瀵嗙粨鍚?
- 鏍囩閲嶆柊鍒嗛厤鍚庯紝鍚勬爣绛捐鑹叉暟閲忓潎琛★紝涓嶉渶瑕佽皟鏁存縺娲婚槇鍊?
- BondManager 浠ｇ爜鏃犻渶淇敼锛屽彧闇€鏇存柊 player_config.csv 涓殑鏍囩鍒?

### 4. player_skill_bindings.csv 鏇存柊

```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
bulwark,skill_bulwark_q,skill_bulwark_e,skill_dash,
tesla,skill_tesla_q,skill_tesla_e,skill_dash,
new_ignis,skill_new_ignis_q,skill_new_ignis_e,skill_dash,
matrix,skill_matrix_q,skill_matrix_e,skill_dash,
warden,skill_warden_q,skill_warden_e,skill_dash,
new_tempest,skill_new_tempest_q,skill_new_tempest_e,skill_dash,
furnace,skill_furnace_q,skill_furnace_e,skill_dash,
inkweaver,skill_inkweaver_q,skill_inkweaver_e,skill_dash,
ammo,skill_ammo_q,skill_ammo_e,skill_dash,
earthshaker,skill_earthshaker_q,skill_earthshaker_e,skill_dash,
vampire,skill_vampire_q,skill_vampire_e,skill_dash,
gunslinger,skill_gunslinger_q,skill_gunslinger_e,skill_dash,
train,skill_train_q,skill_train_e,skill_dash,
dealer,skill_dealer_q,skill_dealer_e,skill_dash,
new_totem,skill_new_totem_q,skill_new_totem_e,skill_dash,
turret_eng,skill_turret_q,skill_turret_e,skill_dash,
goo,skill_goo_q,skill_goo_e,skill_dash,
illusionist,skill_illusionist_q,skill_illusionist_e,skill_dash,
viper,skill_viper_q,skill_viper_e,skill_dash,
voodoo,skill_voodoo_q,skill_voodoo_e,skill_dash,
```

鏈垎閰嶇殑 6 濂楁妧鑳斤紙D 缁勫叏閮級瀛樺叆鎶€鑳藉簱锛?
- merchant, midas, vacuum, bloodhowl, gambler, hunter锛圖 缁?6 濂楋級

### 4. 鏁堟灉鏁版嵁缁撴瀯

SkillEffectManager 涓殑 active_effects 瀛楀吀鎵╁睍锛?

```gdscript
# 澧欎綋鏁堟灉鏁版嵁
{
    "type": "wall",
    "static_body": StaticBody2D,  # 鐗╃悊鑺傜偣
    "vis_line": Line2D,           # 瑙嗚鑺傜偣
    "config": Dictionary,
    "elapsed": float,
    "health": int,                # 鍓╀綑鐢熷懡鍊硷紙-1 = 涓嶅彲鐮村潖锛?
}

# Buff 鍖哄煙鏁版嵁
{
    "type": "buff_zone",
    "area": Area2D,
    "vis_poly": Polygon2D,        # 鎴?vis_line: Line2D
    "config": Dictionary,
    "elapsed": float,
    "buff_timer": float,
}

# Debuff 鍖哄煙鏁版嵁
{
    "type": "debuff_zone",
    "area": Area2D,
    "vis_poly": Polygon2D,
    "config": Dictionary,
    "elapsed": float,
    "debuff_timer": float,
}

# 鍙敜鐗╂暟鎹?
{
    "type": "summon",
    "node": Node2D,               # 鍙敜鐗╄妭鐐?
    "config": Dictionary,
    "elapsed": float,
    "attack_timer": float,
    "owner_skill_id": String,
}
```

### 5. 鐘舵€佹暟鎹粨鏋勬墿灞?

StatusComponent 涓柊澧炵姸鎬佺殑鏁版嵁鏍煎紡涓庣幇鏈夋牸寮忎竴鑷达細

```gdscript
# 鍐板喕鐘舵€?
active_statuses["freeze"] = {
    "duration": 2.0,
    "stacks": 1,
    "value": 0.0,          # 鍐板喕涓嶉渶瑕佹暟鍊?
    "tick_interval": 999.0, # 涓嶉渶瑕?tick
    "tick_timer": 0.0
}

# 鏍囪鐘舵€?
active_statuses["marked"] = {
    "duration": 5.0,
    "stacks": 1,
    "value": 0.5,          # 鍙椾激澧炲姞 50%
    "tick_interval": 999.0,
    "tick_timer": 0.0
}

# 鎭愭儳鐘舵€?
active_statuses["fear"] = {
    "duration": 3.0,
    "stacks": 1,
    "value": 300.0,        # 閫冭窇閫熷害
    "tick_interval": 0.1,  # 姣?0.1 绉掓洿鏂伴€冭窇鏂瑰悜
    "tick_timer": 0.0
}
```

## 姝ｇ‘鎬у睘鎬?

*姝ｇ‘鎬у睘鎬ф槸涓€绉嶅湪绯荤粺鎵€鏈夋湁鏁堟墽琛屼腑閮藉簲鎴愮珛鐨勭壒寰佹垨琛屼负鈥斺€旀湰璐ㄤ笂鏄叧浜庣郴缁熷簲璇ュ仛浠€涔堢殑褰㈠紡鍖栭檲杩般€傚睘鎬т綔涓轰汉绫诲彲璇昏鑼冨拰鏈哄櫒鍙獙璇佹纭€т繚璇佷箣闂寸殑妗ユ銆?

鍩轰簬闇€姹傛枃妗ｄ腑鐨勯獙鏀舵爣鍑嗗垎鏋愶紝浠ヤ笅灞炴€у彲閫氳繃鑷姩鍖栨祴璇曢獙璇侊細

### Property 1: 闀胯〃 CSV 瑙ｆ瀽涓庣被鍨嬭浆鎹㈡纭€?
*For any* 闀胯〃鏍煎紡鐨?skill_params.csv 鏁版嵁锛堝寘鍚?skill_id, param_name, param_value 鍒楋級锛孋onfigManager 鐨?`load_skill_params_long_format()` 鏂规硶瑙ｆ瀽鍚庡簲杩斿洖涓€涓瓧鍏革紝鍏朵腑姣忎釜 skill_id 瀵瑰簲涓€涓弬鏁板瓧鍏革紝涓旀墍鏈夋暟鍊煎瀷瀛楃涓插弬鏁板€煎簲琚纭浆鎹负 float 鎴?int 绫诲瀷銆?
**Validates: Requirements 1.1, 1.2, 1.4**

### Property 2: 闀胯〃涓庡琛ㄨ縼绉讳竴鑷存€э紙Round-Trip锛?
*For any* 瀹借〃鏍煎紡鐨勬妧鑳藉弬鏁版暟鎹紝灏嗗叾杞崲涓洪暱琛ㄦ牸寮忓悗鍐嶉€氳繃 `load_skill_params_long_format()` 鍔犺浇锛屽簲浜х敓涓庣洿鎺ヤ粠瀹借〃鍔犺浇 `load_csv_as_dict()` 瀹屽叏鐩稿悓鐨勫弬鏁板瓧鍏革紙蹇界暐鍊间负 0 鐨勫弬鏁帮級銆?
**Validates: Requirements 1.2, 1.3**

### Property 3: 閲嶅鍙傛暟鏈€鍚庡€间紭鍏?
*For any* 鍖呭惈閲嶅 skill_id + param_name 缁勫悎鐨勯暱琛?CSV 鏁版嵁锛宍load_skill_params_long_format()` 搴旇繑鍥炴瘡涓噸澶嶇粍鍚堜腑鏈€鍚庡嚭鐜扮殑 param_value銆?
**Validates: Requirements 1.5**

### Property 4: 鍙敜鐗╂暟閲忎笂闄愪笉鍙橀噺
*For any* 鎶€鑳?ID 鍜屾渶澶у彫鍞ょ墿鏁伴噺 N锛岃繛缁皟鐢?`create_summon()` 瓒呰繃 N 娆″悗锛岃鎶€鑳?ID 瀵瑰簲鐨勬椿璺冨彫鍞ょ墿鏁伴噺搴斿缁堜笉瓒呰繃 N銆?
**Validates: Requirements 2.6**

### Property 5: 鏍囪鐘舵€佷激瀹虫斁澶ц绠?
*For any* 鍩虹浼ゅ鍊煎拰鏍囪鐧惧垎姣斿€硷紝褰撴晫浜哄浜?"marked" 鐘舵€佹椂锛屾渶缁堝彈鍒扮殑浼ゅ搴旂瓑浜?`base_damage * (1 + marked_value)`銆?
**Validates: Requirements 3.4**

### Property 6: 鐘舵€佷紭鍏堢骇鎺掑簭
*For any* 鍚屾椂瀛樺湪鐨勬帶鍒剁姸鎬侀泦鍚堬紝绯荤粺搴旂敤鐨勬湁鏁堟帶鍒剁姸鎬佸簲涓轰紭鍏堢骇鏈€楂樼殑鐘舵€侊紙鐭冲寲 > 鍐板喕 > 鎭愭儳 > 娌夐粯 > 鍑忛€燂級銆?
**Validates: Requirements 3.6**

### Property 7: 闈炲師濮嬭鑹叉妧鑳界粦瀹氬敮涓€鎬?
*For any* 涓や釜涓嶅悓鐨勯潪鍘熷瑙掕壊锛屽叾鍦?player_skill_bindings.csv 涓殑 Q 鎶€鑳界粦瀹氬簲浜掍笉鐩稿悓銆?
**Validates: Requirements 10.6**

## 閿欒澶勭悊

### ConfigManager 閿欒澶勭悊

| 鍦烘櫙 | 澶勭悊鏂瑰紡 |
|------|---------|
| skill_params.csv 鏂囦欢涓嶅瓨鍦?| 杈撳嚭璀﹀憡鏃ュ織锛岃繑鍥炵┖瀛楀吀 |
| CSV 琛屾牸寮忎笉姝ｇ‘锛堝垪鏁颁笉瓒筹級 | 璺宠繃璇ヨ锛岃緭鍑鸿鍛?|
| param_value 鏃犳硶杞崲涓烘暟鍊?| 淇濈暀涓哄瓧绗︿覆绫诲瀷 |
| skill_id 涓虹┖ | 璺宠繃璇ヨ |
| 閲嶅鐨?skill_id + param_name | 浣跨敤鏈€鍚庡嚭鐜扮殑鍊硷紝杈撳嚭璀﹀憡 |

### SkillEffectManager 閿欒澶勭悊

| 鍦烘櫙 | 澶勭悊鏂瑰紡 |
|------|---------|
| create_wall_effect 缂哄皯 start/end | 杈撳嚭閿欒鏃ュ織锛岃繑鍥?-1 |
| create_buff_zone 缂哄皯 polygon 鍜?start/end | 杈撳嚭閿欒鏃ュ織锛岃繑鍥?-1 |
| 鏁堟灉鑺傜偣鍦ㄧ敓鍛藉懆鏈熷唴琚閮ㄥ垹闄?| 浠?active_effects 涓Щ闄わ紝涓嶅穿婧?|
| 鍙敜鐗╄秴杩囨渶澶ф暟閲?| 鑷姩绉婚櫎鏈€鏃╃殑鍙敜鐗?|
| 瑙掕壊鍒囨崲鏃舵妧鑳藉疄渚嬭閿€姣?| 鏁堟灉缁х画鐢?SkillEffectManager 绠＄悊 |

### StatusComponent 閿欒澶勭悊

| 鍦烘櫙 | 澶勭悊鏂瑰紡 |
|------|---------|
| 瀵瑰凡鏈夌姸鎬侀噸澶嶅簲鐢?| 鍒锋柊鎸佺画鏃堕棿锛屽彔鍔犲眰鏁?|
| owner_unit 琚攢姣?| 鍋滄鐘舵€佹洿鏂帮紝涓嶅穿婧?|
| 鏈煡鐘舵€佸悕绉?| 浠嶇劧瀛樺偍鍜岀鐞嗭紝浣嗘棤鐗规畩鏁堟灉 |
| 鎭愭儳鐘舵€佷笅鏃犳硶璁＄畻閫冭窇鏂瑰悜 | 浣跨敤闅忔満鏂瑰悜 |

### 鎶€鑳借剼鏈敊璇鐞?

| 鍦烘櫙 | 澶勭悊鏂瑰紡 |
|------|---------|
| skill_owner 涓?null | 杈撳嚭閿欒鏃ュ織锛屼笉鎵ц鎶€鑳?|
| CSV 涓己灏戞妧鑳藉弬鏁?| 浣跨敤浠ｇ爜涓殑榛樿鍊?|
| 鑳介噺涓嶈冻 | 鏄剧ず "No Energy!" 鎻愮ず锛屼笉鎵ц |
| 鍐峰嵈涓?| 涓嶆墽琛岋紝SkillManager 杈撳嚭璋冭瘯鏃ュ織 |

## 娴嬭瘯绛栫暐

### 鍙岄噸娴嬭瘯鏂规硶

鏈」鐩噰鐢ㄥ崟鍏冩祴璇曞拰灞炴€ф祴璇曠浉缁撳悎鐨勬柟寮忥細

- **鍗曞厓娴嬭瘯**: 楠岃瘉鍏蜂綋绀轰緥銆佽竟鐣屾儏鍐靛拰閿欒鏉′欢
- **灞炴€ф祴璇?*: 楠岃瘉璺ㄦ墍鏈夎緭鍏ョ殑閫氱敤灞炴€?

### 灞炴€ф祴璇曢厤缃?

- **娴嬭瘯妗嗘灦**: GDScript 鍐呯疆娴嬭瘯 + GUT (Godot Unit Testing) 妗嗘灦
- **灞炴€ф祴璇曞簱**: 浣跨敤 GUT 鐨勫弬鏁板寲娴嬭瘯鍔熻兘妯℃嫙灞炴€ф祴璇曪紝姣忎釜灞炴€ц嚦灏戣繍琛?100 娆¤凯浠?
- **鏍囩鏍煎紡**: `# Feature: batch-character-skills, Property {number}: {property_text}`

### 娴嬭瘯鑼冨洿

| 娴嬭瘯绫诲瀷 | 瑕嗙洊鑼冨洿 |
|---------|---------|
| 灞炴€ф祴璇?| CSV 瑙ｆ瀽姝ｇ‘鎬с€佺被鍨嬭浆鎹€侀噸澶嶅鐞嗐€佸彫鍞ょ墿涓婇檺銆佷激瀹宠绠椼€佺姸鎬佷紭鍏堢骇銆佺粦瀹氬敮涓€鎬?|
| 鍗曞厓娴嬭瘯 | 鐜版湁鎶€鑳借縼绉婚獙璇併€佸師濮嬭鑹茬粦瀹氫笉鍙樸€佹妧鑳芥枃浠跺瓨鍦ㄦ€ф鏌?|
| 闆嗘垚娴嬭瘯 | 鎶€鑳藉姞杞解啋鎵ц鈫掓晥鏋滃垱寤哄畬鏁存祦绋嬶紙闇€ Godot 杩愯鏃讹級 |

### 涓嶅彲鑷姩鍖栨祴璇曠殑闇€姹?

浠ヤ笅闇€姹傞渶瑕佸湪 Godot 缂栬緫鍣ㄤ腑鎵嬪姩娴嬭瘯锛?
- 鎵€鏈夋妧鑳界殑瑙嗚鏁堟灉鍜屾父鎴忎綋楠岋紙闇€姹?4-8锛?
- 瑙掕壊鍒囨崲鍚庢晥鏋滄寔缁€э紙闇€姹?11锛?
- StaticBody2D 鐗╃悊纰版挒琛屼负锛堥渶姹?2.1锛?
- 鐘舵€佽瑙夊弽棣堬紙闇€姹?3锛?

