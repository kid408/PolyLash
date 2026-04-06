# 闇€姹傛枃妗ｏ細鎵归噺瑙掕壊鎶€鑳界郴缁?

## 绠€浠?

涓?PolyLash Roguelike 娓告垙鎵归噺鍒涘缓鏂拌鑹叉妧鑳斤紙鍒?A-E 浜旂粍锛夛紝姣忓鍖呭惈 Q-line锛堢敾绾匡級銆丵-circle锛堢敾鍦堥棴鍚堬級銆丒-key锛堢灛鍙戯級涓変釜鎶€鑳姐€傚悓鏃堕噸鏋?skill_params.csv 涓洪暱琛ㄦ牸寮忥紝鎵╁睍 SkillEffectManager 鏀寔鏂版晥鏋滅被鍨嬶紝鎵╁睍鏁屼汉鐘舵€佺郴缁熸敮鎸佹柊鐘舵€併€傚垹闄?20 涓棫瑙掕壊锛屾牴鎹妧鑳戒富棰樺垱寤?20 涓叏鏂拌鑹插苟缁戝畾瀵瑰簲鎶€鑳斤紝鍓╀綑鎶€鑳藉瓨鍏ユ妧鑳藉簱渚涙湭鏉ヤ娇鐢ㄣ€?

## 鏈琛?

- **SkillDrawingBase**: Q 閿敾绾挎妧鑳藉熀绫伙紝绠＄悊瑙勫垝妯″紡銆佸垝绾挎娴嬨€侀棴鍚堟娴嬨€佽兘閲忔秷鑰?
- **SkillBase**: 鎵€鏈夋妧鑳界殑鎶借薄鍩虹被锛岀鐞嗗喎鍗淬€佽兘閲忔秷鑰椼€佹墽琛岀姸鎬?
- **SkillEffectManager**: 鑷姩鍔犺浇鐨勬妧鑳芥晥鏋滅敓鍛藉懆鏈熺鐞嗗櫒锛岀嫭绔嬩簬瑙掕壊鍒囨崲
- **SkillManager**: 瑙掕壊鎶€鑳界鐞嗗櫒锛岀鐞?Q/E/LMB/RMB 鍥涗釜鎶€鑳芥Ы浣?
- **StatusComponent**: 鐘舵€佺粍浠讹紝绠＄悊鍗曚綅鐨?Buff/Debuff 鏁堟灉
- **ConfigManager**: 閰嶇疆绠＄悊鍣紝浠?CSV 鍔犺浇骞剁紦瀛樻墍鏈夐厤缃暟鎹?
- **skill_params.csv**: 鎶€鑳藉弬鏁伴厤缃枃浠讹紙褰撳墠涓哄琛紝57 鍒楋級
- **player_skill_bindings.csv**: 瑙掕壊鎶€鑳界粦瀹氶厤缃枃浠?
- **StaticBody2D**: Godot 鐗╃悊鑺傜偣锛岀敤浜庡垱寤轰笉鍙Щ鍔ㄧ殑纰版挒浣擄紙澧欏銆侀殰纰嶇墿锛?
- **闀胯〃鏍煎紡**: 鏁版嵁搴撹寖寮忓寲鐨?CSV 鏍煎紡锛屾瘡琛屼竴涓弬鏁帮紙skill_id, param_name, param_value锛?
- **瀹借〃鏍煎紡**: 褰撳墠 CSV 鏍煎紡锛屾瘡琛屼竴涓妧鑳斤紝鎵€鏈夊弬鏁颁负鍒?
- **鍘熷鍏鑹?*: butcher銆乸yro銆乻apper銆乭erder銆亀eaver銆亀ind锛屽叾鎶€鑳戒笉鍙慨鏀癸紝涓嶅彲鍒犻櫎
- **鏃ц鑹?*: 闄ゅ師濮嬪叚瑙掕壊澶栫殑 20 涓鑹诧紙technology_hurricane銆乼ankman 绛夛級锛屽皢琚垹闄?
- **鏂拌鑹?*: 鏍规嵁鎶€鑳戒富棰樺叏鏂板垱寤虹殑 20 涓鑹诧紙bulwark銆乼esla 绛夛級锛屾浛浠ｆ棫瑙掕壊
- **闃熷弸**: 褰撳墠灏忛槦涓殑鎵€鏈夎鑹叉垚鍛橈紝鍒囨崲瑙掕壊鍚庝粛鍙彈鐩婁簬鍏朵粬瑙掕壊鐨勬妧鑳芥晥鏋滃尯鍩?

## 闇€姹?

### 闇€姹?1锛氶噸鏋?skill_params.csv 涓洪暱琛ㄦ牸寮?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负閰嶇疆缁存姢浜哄憳锛屾垜甯屾湜灏?skill_params.csv 浠?57 鍒楀琛ㄩ噸鏋勪负闀胯〃鏍煎紡锛坰kill_id, param_name, param_value锛夛紝浠ヤ究杞绘澗娣诲姞鏂版妧鑳藉弬鏁拌€屾棤闇€淇敼琛ㄧ粨鏋勩€?

#### 楠屾敹鏍囧噯

1. THE ConfigManager SHALL 鏀寔璇诲彇闀胯〃鏍煎紡鐨?skill_params.csv锛坰kill_id, param_name, param_value, description 鍥涘垪锛?
2. WHEN ConfigManager 鍔犺浇闀胯〃鏍煎紡鐨?skill_params.csv 鏃讹紝THE ConfigManager SHALL 灏嗘暟鎹浆鎹负涓庣幇鏈?get_skill_params(skill_id) 鎺ュ彛鍏煎鐨勫瓧鍏告牸寮?
3. WHEN 鐜版湁鍏鑹诧紙butcher銆乸yro銆乻apper銆乭erder銆亀eaver銆亀ind锛夌殑鎶€鑳藉弬鏁拌杩佺Щ鍒伴暱琛ㄦ牸寮忓悗锛孴HE ConfigManager SHALL 杩斿洖涓庡琛ㄦ牸寮忓畬鍏ㄧ浉鍚岀殑鍙傛暟鍊?
4. THE ConfigManager SHALL 鑷姩灏嗗瓧绗︿覆绫诲瀷鐨勬暟鍊煎弬鏁拌浆鎹负 float 鎴?int 绫诲瀷
5. IF skill_params.csv 涓瓨鍦ㄩ噸澶嶇殑 skill_id + param_name 缁勫悎锛孴HEN THE ConfigManager SHALL 浣跨敤鏈€鍚庡嚭鐜扮殑鍊煎苟杈撳嚭璀﹀憡鏃ュ織

### 闇€姹?2锛氭墿灞?SkillEffectManager 鏀寔鏂版晥鏋滅被鍨?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负娓告垙鏋舵瀯甯堬紝鎴戝笇鏈?SkillEffectManager 鏀寔 StaticBody2D 澧欎綋銆丅uff/Debuff 鍖哄煙鍜屽彫鍞ょ墿绠＄悊锛屼互渚挎柊鎶€鑳借兘澶熷垱寤虹墿鐞嗛樆鎸″銆佸鐩婂尯鍩熷拰鍙鐞嗙殑鍙敜鍗曚綅銆?

#### 楠屾敹鏍囧噯

1. WHEN create_wall_effect 琚皟鐢ㄦ椂锛孴HE SkillEffectManager SHALL 鍒涘缓涓€涓?StaticBody2D 鑺傜偣锛屽叾纰版挒褰㈢姸娌挎寚瀹氱嚎娈电敓鎴愶紝闃绘尅鏁屼汉鍜?鎴栧瓙寮圭Щ鍔?
2. WHEN 澧欎綋鏁堟灉鐨勬寔缁椂闂村埌鏈熸椂锛孴HE SkillEffectManager SHALL 鎾斁娣″嚭鍔ㄧ敾骞剁Щ闄よ StaticBody2D 鑺傜偣
3. WHEN create_buff_zone 琚皟鐢ㄦ椂锛孴HE SkillEffectManager SHALL 鍒涘缓涓€涓?Area2D 鍖哄煙锛屽杩涘叆鍖哄煙鐨勯槦鍙嬪簲鐢ㄦ寚瀹氱殑 Buff 鏁堟灉
4. WHEN create_debuff_zone 琚皟鐢ㄦ椂锛孴HE SkillEffectManager SHALL 鍒涘缓涓€涓?Area2D 鍖哄煙锛屽杩涘叆鍖哄煙鐨勬晫浜哄簲鐢ㄦ寚瀹氱殑 Debuff 鏁堟灉
5. WHEN create_summon 琚皟鐢ㄦ椂锛孴HE SkillEffectManager SHALL 鍒涘缓涓€涓彲绠＄悊鐨勫彫鍞ゅ崟浣嶏紝鍏锋湁鐙珛鐨勭敓鍛藉懆鏈熷拰琛屼负閫昏緫
6. WHEN 鍚屼竴鎶€鑳界殑鍙敜鐗╂暟閲忚秴杩囬厤缃殑鏈€澶у€兼椂锛孴HE SkillEffectManager SHALL 绉婚櫎鏈€鏃╁垱寤虹殑鍙敜鐗?
7. THE SkillEffectManager SHALL 鍦ㄨ鑹插垏鎹㈠悗缁х画绠＄悊鎵€鏈夊凡鍒涘缓鐨勬晥鏋滐紝淇濇寔鏁堟灉鐨勭嫭绔嬬敓鍛藉懆鏈?

### 闇€姹?3锛氭墿灞曟晫浜虹姸鎬佺郴缁?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负娓告垙璁捐甯堬紝鎴戝笇鏈涙晫浜虹姸鎬佺郴缁熸敮鎸佸啺鍐汇€佹矇榛樸€佹亹鎯с€佹爣璁般€佺煶鍖栫瓑鏂扮姸鎬侊紝浠ヤ究鏂版妧鑳借兘澶熸柦鍔犲鏍峰寲鐨勬帶鍒舵晥鏋溿€?

#### 楠屾敹鏍囧噯

1. WHEN apply_status("freeze") 琚皟鐢ㄦ椂锛孴HE StatusComponent SHALL 浣挎晫浜哄畬鍏ㄥ仠姝㈢Щ鍔ㄥ拰鏀诲嚮锛屾寔缁寚瀹氭椂闂?
2. WHEN apply_status("silence") 琚皟鐢ㄦ椂锛孴HE StatusComponent SHALL 闃绘鏁屼汉浣跨敤鐗规畩鎶€鑳斤紝鎸佺画鎸囧畾鏃堕棿
3. WHEN apply_status("fear") 琚皟鐢ㄦ椂锛孴HE StatusComponent SHALL 浣挎晫浜哄悜杩滅鏂芥硶鑰呯殑鏂瑰悜閫冭窇锛屾寔缁寚瀹氭椂闂?
4. WHEN apply_status("marked") 琚皟鐢ㄦ椂锛孴HE StatusComponent SHALL 鏍囪鏁屼汉锛屼娇鍏跺彈鍒扮殑浼ゅ澧炲姞鎸囧畾鐧惧垎姣?
5. WHEN apply_status("petrify") 琚皟鐢ㄦ椂锛孴HE StatusComponent SHALL 浣挎晫浜哄彉涓虹煶鍖栫姸鎬侊紙瀹屽叏涓嶅彲琛屽姩锛夛紝鎸佺画鎸囧畾鏃堕棿
6. WHEN 澶氫釜鎺у埗鐘舵€佸悓鏃跺瓨鍦ㄦ椂锛孴HE StatusComponent SHALL 鎸変紭鍏堢骇澶勭悊锛氱煶鍖?> 鍐板喕 > 鎭愭儳 > 娌夐粯 > 鍑忛€?
7. WHEN 鐘舵€佹寔缁椂闂村埌鏈熸椂锛孴HE StatusComponent SHALL 绉婚櫎鐘舵€佹晥鏋滃苟鎭㈠鏁屼汉鐨勫師濮嬪睘鎬?

### 闇€姹?4锛欰 缁勬妧鑳?- 鍏冪礌涓庢帶鍒讹紙鍦板舰鏀归€狅級

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜鎷ユ湁浠ュ厓绱犲拰鍦板舰鎺у埗涓轰富棰樼殑鎶€鑳界粍锛屼互渚块€氳繃鍒涘缓澧欏銆佸尯鍩熷拰鎺у埗鏁堟灉鏉ユ敼鍙樻垬鍦哄湴褰€?

#### 楠屾敹鏍囧噯

1. WHEN 鍐版渤瑙掕壊鐢荤嚎鏃讹紝THE Bulwark_Q_Line_Skill SHALL 娌胯矾寰勫垱寤?StaticBody2D 鍐板锛岄樆鎸℃晫浜哄拰瀛愬脊绉诲姩锛屾寔缁厤缃殑鏃堕棿
2. WHEN 鍐版渤瑙掕壊鐢诲湀闂悎鏃讹紝THE Bulwark_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴瀵规墍鏈夋晫浜烘柦鍔犲啺鍐荤姸鎬?
3. WHEN 鍐版渤瑙掕壊鎸?E 閿椂锛孴HE Bulwark_E_Skill SHALL 鍦ㄨ鑹插懆鍥翠骇鐢熷啺鐖嗘晥鏋滐紝鍑婚€€闄勮繎鏁屼汉骞朵负瑙掕壊娣诲姞涓存椂鎶ょ浘
4. WHEN 鐗规柉鎷夎鑹茬敾绾挎椂锛孴HE Tesla_Q_Line_Skill SHALL 娌胯矾寰勫垱寤虹數寮х嚎锛屽鎺ヨЕ鐨勬晫浜洪€犳垚浼ゅ骞舵柦鍔?0.5 绉掔湬鏅?
5. WHEN 鐗规柉鎷夎鑹茬敾鍦堥棴鍚堟椂锛孴HE Tesla_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓闆风數鍦猴紝姣?0.5 绉掑鍖哄煙鍐呮晫浜洪€犳垚浼ゅ
6. WHEN 鐗规柉鎷夎鑹叉寜 E 閿椂锛孴HE Tesla_E_Skill SHALL 瀵硅寖鍥村唴鏁屼汉鏂藉姞娌夐粯鐘舵€侊紝闃绘鏁屼汉浣跨敤鐗规畩鎶€鑳?
7. WHEN 鏂扮伀娉曡鑹茬敾绾挎椂锛孴HE NewIgnis_Q_Line_Skill SHALL 娌胯矾寰勫垱寤?StaticBody2D 鐏锛岄樆鎸℃晫浜虹Щ鍔ㄥ苟瀵规帴瑙﹁€呴€犳垚鎸佺画浼ゅ
8. WHEN 鏂扮伀娉曡鑹茬敾鍦堥棴鍚堟椂锛孴HE NewIgnis_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鐏捣锛屽鍖哄煙鍐呮晫浜洪€犳垚鎸佺画浼ゅ
9. WHEN 鏂扮伀娉曡鑹叉寜 E 閿椂锛孴HE NewIgnis_E_Skill SHALL 鍦ㄨ鑹插懆鍥翠骇鐢熺伀鐒扮幆锛屽嚮閫€闄勮繎鏁屼汉
10. WHEN 鐦熺柅瑙掕壊鐢荤嚎鏃讹紝THE Matrix_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿厫铓€璺緞锛屽鎺ヨЕ鐨勬晫浜烘柦鍔?50% 鍑忛€熷拰涓瘨鐘舵€?
11. WHEN 鐦熺柅瑙掕壊鐢诲湀闂悎鏃讹紝THE Matrix_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鐦存皵姹狅紝浣垮尯鍩熷唴鏁屼汉鍙楀埌鐨勪激瀹冲鍔?30%
12. WHEN 鐦熺柅瑙掕壊鎸?E 閿椂锛孴HE Matrix_E_Skill SHALL 寮曠垎鎵€鏈変腑姣掓晫浜鸿韩涓婄殑姣掔礌灞傛暟锛岄€犳垚鍩轰簬灞傛暟鐨勭垎鍙戜激瀹?
13. WHEN 鐙辫瑙掕壊鐢荤嚎鏃讹紝THE Warden_Q_Line_Skill SHALL 娌胯矾寰勫垱寤虹數缃戯紙StaticBody2D锛夛紝瀵规帴瑙︾殑鏁屼汉閫犳垚纰版挒浼ゅ鍜屽嚮閫€
14. WHEN 鐙辫瑙掕壊鐢诲湀闂悎鏃讹紝THE Warden_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熻竟鐣屽垱寤哄皝闂殑纰版挒澧欏
15. WHEN 鐙辫瑙掕壊鎸?E 閿椂锛孴HE Warden_E_Skill SHALL 鍦ㄨ鑹插墠鏂规墖褰㈣寖鍥村唴浜х敓鐩惧嚮鏁堟灉锛屽嚮閫€鑼冨洿鍐呮晫浜?
16. WHEN 鏂伴鏆磋鑹茬敾绾挎椂锛孴HE NewTempest_Q_Line_Skill SHALL 娌胯矾寰勫垱寤洪甯︼紝涓虹粡杩囩殑闃熷弸鎻愪緵澶у箙绉婚€熷姞鎴?
17. WHEN 鏂伴鏆磋鑹茬敾鍦堥棴鍚堟椂锛孴HE NewTempest_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鍙伴鐪兼晥鏋滐紝灏嗗尯鍩熷唴鏁屼汉鎸佺画鎷夊悜涓績
18. WHEN 鏂伴鏆磋鑹叉寜 E 閿椂锛孴HE NewTempest_E_Skill SHALL 鍦ㄨ鑹插懆鍥翠骇鐢熼緳鍗烽鏁堟灉锛屽皢闄勮繎鏁屼汉鎶涘悜绌轰腑

### 闇€姹?5锛欱 缁勬妧鑳?- 鎴樻湳鏀彺锛堝皬闃熷鐩婏級

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜鎷ユ湁浠ュ皬闃熷鐩婁负涓婚鐨勬妧鑳界粍锛屼互渚块€氳繃鍒涘缓澧炵泭鍖哄煙鏉ュ己鍖栭槦鍙嬬殑鎴樻枟鑳藉姏銆?

#### 楠屾敹鏍囧噯

1. WHEN 閾佸尃瑙掕壊鐢荤嚎鏃讹紝THE Furnace_Q_Line_Skill SHALL 娌胯矾寰勫垱寤虹（鍒€鐭冲尯鍩燂紝涓虹粡杩囩殑闃熷弸鎻愪緵 +50% 鏀诲嚮鍔涘姞鎴?
2. WHEN 閾佸尃瑙掕壊鐢诲湀闂悎鏃讹紝THE Furnace_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓閿婚€犵倝锛屼负鍖哄煙鍐呴槦鍙嬫彁渚?+100% 鏀诲嚮閫熷害鍔犳垚
3. WHEN 閾佸尃瑙掕壊鎸?E 閿椂锛孴HE Furnace_E_Skill SHALL 閲嶇疆褰撳墠瑙掕壊鐨?Q 鎶€鑳藉喎鍗存椂闂?
4. WHEN 鍐涘尰瑙掕壊鐢荤嚎鏃讹紝THE Inkweaver_Q_Line_Skill SHALL 娌胯矾寰勫垱寤烘秷姣掑甫锛屼负缁忚繃鐨勯槦鍙嬫仮澶嶇敓鍛藉€硷紝瀵圭粡杩囩殑鏁屼汉鏂藉姞鍑忛€?
5. WHEN 鍐涘尰瑙掕壊鐢诲湀闂悎鏃讹紝THE Inkweaver_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鏃犺弻瀹わ紝涓哄尯鍩熷唴闃熷弸姣忕鎭㈠鐢熷懡鍊煎苟鎻愪緵鏃犳晫鐘舵€?
6. WHEN 鍐涘尰瑙掕壊鎸?E 閿椂锛孴HE Inkweaver_E_Skill SHALL 涓哄綋鍓嶈鑹叉彁渚?5 绉掔殑鐢熷懡鍋峰彇 Buff
7. WHEN 寮硅嵂瑙掕壊鐢荤嚎鏃讹紝THE Ammo_Q_Line_Skill SHALL 娌胯矾寰勫垱寤哄姞閫熻建閬擄紝闃熷弸鐨勫瓙寮圭┛杩囪绾挎鏃跺彉澶у苟澧炲姞浼ゅ
8. WHEN 寮硅嵂瑙掕壊鐢诲湀闂悎鏃讹紝THE Ammo_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓琛ョ粰绔欙紝鍑忓皯鍖哄煙鍐呴槦鍙嬬殑鎶€鑳藉喎鍗存椂闂?
9. WHEN 寮硅嵂瑙掕壊鎸?E 閿椂锛孴HE Ammo_E_Skill SHALL 绔嬪嵆灏嗗綋鍓嶈鑹茬殑鑳介噺鎭㈠鑷虫弧鍊?
10. WHEN 鍦ｉ獞澹鑹茬敾绾挎椂锛孴HE Earthshaker_Q_Line_Skill SHALL 娌胯矾寰勫垱寤哄厜澧欙紝闃绘尅鏁屼汉瀛愬脊閫氳繃
11. WHEN 鍦ｉ獞澹鑹茬敾鍦堥棴鍚堟椂锛孴HE Earthshaker_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鍑€鍖栧満锛屾竻闄ら槦鍙嬬殑 Debuff 骞舵彁渚涗激瀹冲噺鍏?
12. WHEN 鍦ｉ獞澹鑹叉寜 E 閿椂锛孴HE Earthshaker_E_Skill SHALL 鏂芥斁鍢茶鏁堟灉锛屽己鍒惰寖鍥村唴鏁屼汉鏀诲嚮褰撳墠瑙掕壊
13. WHEN 琛€鏃忚鑹茬敾绾挎椂锛孴HE Vampire_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿璺紙娑堣€楄嚜韬敓鍛藉€硷級锛屽鎺ヨЕ鐨勬晫浜洪€犳垚鍩轰簬鍏舵渶澶х敓鍛藉€肩櫨鍒嗘瘮鐨勪激瀹?
14. WHEN 琛€鏃忚鑹茬敾鍦堥棴鍚堟椂锛孴HE Vampire_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓琛€姹狅紝涓哄尯鍩熷唴闃熷弸鎻愪緵 100% 鐢熷懡鍋峰彇
15. WHEN 琛€鏃忚鑹叉寜 E 閿椂锛孴HE Vampire_E_Skill SHALL 鍚稿彇闄勮繎鏁屼汉鐨勭敓鍛藉€煎苟鎭㈠鑷韩
16. WHEN 鏃楁墜瑙掕壊鐢荤嚎鏃讹紝THE Gunslinger_Q_Line_Skill SHALL 娌胯矾寰勫垱寤哄啿閿嬬嚎锛屼娇缁忚繃鐨勯槦鍙嬪拷鐣ュ崟浣嶇鎾?
17. WHEN 鏃楁墜瑙掕壊鐢诲湀闂悎鏃讹紝THE Gunslinger_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鍐虫枟鍦猴紝浣垮尯鍩熷唴鏁屼汉鐨勯槻寰″姏闄嶄负 0
18. WHEN 鏃楁墜瑙掕壊鎸?E 閿椂锛孴HE Gunslinger_E_Skill SHALL 鍚瑰搷鍙疯锛屼负鍏ㄩ槦鎻愪緵鐭殏鐨勭Щ閫熺垎鍙戝姞鎴?

### 闇€姹?6锛欳 缁勬妧鑳?- 濂囪涓庡彫鍞わ紙绠€鍖栫増锛?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜鎷ユ湁浠ュ彫鍞ゅ拰澶ц妯℃晥鏋滀负涓婚鐨勬妧鑳界粍锛屼互渚块€氳繃鍙敜鍗曚綅鍜岃Е鍙戝．瑙傛晥鏋滄潵鎺у埗鎴樺満銆?

#### 楠屾敹鏍囧噯

1. WHEN 鐏溅鐜嬭鑹茬敾绾挎椂锛孴HE Train_Q_Line_Skill SHALL 娌胯矾寰勫垱寤哄菇鐏佃建閬擄紝寤惰繜 1 绉掑悗娌胯建閬撻噴鏀惧啿鍑绘尝閫犳垚澶ч噺浼ゅ
2. WHEN 鐏溅鐜嬭鑹茬敾鍦堥棴鍚堟椂锛孴HE Train_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鏃嬭浆鍏夋潫锛屾寔缁鍖哄煙鍐呮晫浜洪€犳垚浼ゅ
3. WHEN 鐏溅鐜嬭鑹叉寜 E 閿椂锛孴HE Train_E_Skill SHALL 鍙戝嚭姹界瑳澹帮紝鑷寸洸鑼冨洿鍐呮墍鏈夋晫浜?
4. WHEN 铏瘝瑙掕壊鐢荤嚎鏃讹紝THE Dealer_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿缂濓紝姣?1 绉掔敓鎴愪竴鍙嚜鐖嗙敳铏?
5. WHEN 铏瘝瑙掕壊鐢诲湀闂悎鏃讹紝THE Dealer_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓瀛靛寲鍦猴紝鐢熸垚 3 涓繙绋嬬偖濉斿苟涓哄尯鍩熷唴闃熷弸鎭㈠鐢熷懡
6. WHEN 铏瘝瑙掕壊鎸?E 閿椂锛孴HE Dealer_E_Skill SHALL 鍛戒护鎵€鏈夊彫鍞ょ墿闆嗙伀鏀诲嚮鏈€杩戠殑鏁屼汉
7. WHEN 钀ㄦ弧瑙掕壊鐢荤嚎鏃讹紝THE Totem_Q_Line_Skill SHALL 鍦ㄨ矾寰勮捣鐐瑰拰缁堢偣鍚勬斁缃竴涓浘鑵撅紝涓や釜鍥捐吘涔嬮棿浠ラ棯鐢甸摼杩炴帴骞跺缁忚繃鐨勬晫浜洪€犳垚浼ゅ
8. WHEN 钀ㄦ弧瑙掕壊鐢诲湀闂悎鏃讹紝THE Totem_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鍦伴渿鏁堟灉锛屾瘡绉掑鍖哄煙鍐呮晫浜洪€犳垚浼ゅ骞舵柦鍔犲噺閫?
9. WHEN 钀ㄦ弧瑙掕壊鎸?E 閿椂锛孴HE Totem_E_Skill SHALL 寮曠垎鍦轰笂鎵€鏈夊浘鑵撅紝瀵瑰浘鑵惧懆鍥存晫浜洪€犳垚鑼冨洿浼ゅ
10. WHEN 宸ョ▼瑙掕壊鐢荤嚎鏃讹紝THE Turret_Q_Line_Skill SHALL 娌胯矾寰勭瓑璺濇斁缃?3 涓嚜鍔ㄧ偖濉旓紝鐐鑷姩鏀诲嚮鑼冨洿鍐呮晫浜?
11. WHEN 宸ョ▼瑙掕壊鐢诲湀闂悎鏃讹紝THE Turret_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓缁翠慨绔欙紝浣垮尯鍩熷唴鐐鑾峰緱鍙屽€嶆敾鍑婚€熷害
12. WHEN 宸ョ▼瑙掕壊鎸?E 閿椂锛孴HE Turret_E_Skill SHALL 寮曠垎鎵€鏈夌偖濉旓紝瀵圭偖濉斿懆鍥存晫浜洪€犳垚鑼冨洿浼ゅ
13. WHEN 杞偿瑙掕壊鐢荤嚎鏃讹紝THE Goo_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿秴绾ц兌姘村尯鍩燂紝瀵圭粡杩囩殑鏁屼汉鏂藉姞 90% 鍑忛€?
14. WHEN 杞偿瑙掕壊鐢诲湀闂悎鏃讹紝THE Goo_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鍒嗚姹狅紝褰撳尯鍩熷唴鏁屼汉鍙楀埌浼ゅ鏃剁敓鎴愯糠浣犲彶鑾卞
15. WHEN 杞偿瑙掕壊鎸?E 閿椂锛孴HE Goo_E_Skill SHALL 鍚炲櫖鏈€杩戠殑灏忓瀷鏁屼汉锛堢珛鍗冲嚮鏉€锛夊苟鎭㈠鑷韩鐢熷懡鍊?
16. WHEN 姝荤伒瑙掕壊鐢荤嚎鏃讹紝THE Illusionist_Q_Line_Skill SHALL 娌胯矾寰勫垱寤洪澧欙紙StaticBody2D锛夛紝楠ㄥ鍦ㄥ彈鍒?3 娆℃敾鍑诲悗鐮寸
17. WHEN 姝荤伒瑙掕壊鐢诲湀闂悎鏃讹紝THE Illusionist_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓灏哥垎鍦猴紝鍖哄煙鍐呮晫浜烘浜℃椂浼氱垎鐐稿鍛ㄥ洿鏁屼汉閫犳垚浼ゅ
18. WHEN 姝荤伒瑙掕壊鎸?E 閿椂锛孴HE Illusionist_E_Skill SHALL 鍙戝嚭鎭愭儳灏栧暩锛屽鑼冨洿鍐呮晫浜烘柦鍔犳亹鎯х姸鎬?

### 闇€姹?7锛欴 缁勬妧鑳?- 缁忔祹涓庢敹鍓诧紙浠峰€兼祦锛?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜鎷ユ湁浠ョ粡娴庢敹鐩婂拰澶勫喅涓轰富棰樼殑鎶€鑳界粍锛屼互渚块€氳繃鍑绘潃鏁屼汉鑾峰緱棰濆閲戝竵鍜岃祫婧愩€?

#### 楠屾敹鏍囧噯

1. WHEN 鍟嗕汉瑙掕壊鐢荤嚎鏃讹紝THE Merchant_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿祻閲戠嚎锛屾帴瑙﹁绾跨殑鏁屼汉姝讳骸鏃舵帀钀藉弻鍊嶉噾甯?
2. WHEN 鍟嗕汉瑙掕壊鐢诲湀闂悎鏃讹紝THE Merchant_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓榛戝競锛屽尯鍩熷唴鏁屼汉姣忕鎺夎惤 1 閲戝竵骞惰繘鍏ラ€冭窇鐘舵€?
3. WHEN 鍟嗕汉瑙掕壊鎸?E 閿椂锛孴HE Merchant_E_Skill SHALL 鎶曟幏閲戝竵鐐稿脊锛屽鑼冨洿鍐呮晫浜洪€犳垚浼ゅ
4. WHEN 鐐奸噾瑙掕壊鐢荤嚎鏃讹紝THE Midas_Q_Line_Skill SHALL 娌胯矾寰勫垱寤洪噾鍏夊皠绾匡紝瀵规帴瑙︾殑鏁屼汉鏂藉姞 1 绉掔煶鍖栫姸鎬?
5. WHEN 鐐奸噾瑙掕壊鐢诲湀闂悎鏃讹紝THE Midas_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓杞寲闃碉紝鍖哄煙鍐呮晫浜烘浜℃椂鍙樹负閲戝爢闅滅鐗╋紙StaticBody2D锛?
6. WHEN 鐐奸噾瑙掕壊鎸?E 閿椂锛孴HE Midas_E_Skill SHALL 鎶曟幏鑽按鐡讹紝瀵瑰懡涓尯鍩熺殑鏁屼汉鏂藉姞闅忔満 Debuff
7. WHEN 鍚稿皹鍣ㄨ鑹茬敾绾挎椂锛孴HE Vacuum_Q_Line_Skill SHALL 娌胯矾寰勫垱寤轰紶閫佸甫锛屾瘡 1 绉掑皢鏈€杩滅殑鎺夎惤鐗╀紶閫佸埌鐜╁浣嶇疆
8. WHEN 鍚稿皹鍣ㄨ鑹茬敾鍦堥棴鍚堟椂锛孴HE Vacuum_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓纾佸満锛屽皢鎷惧彇鑼冨洿鎵╁ぇ 5 鍊?
9. WHEN 鍚稿皹鍣ㄨ鑹叉寜 E 閿椂锛孴HE Vacuum_E_Skill SHALL 绔嬪嵆鍚稿彇灞忓箷鍐呮墍鏈夋帀钀界墿
10. WHEN 澶勫垜瑙掕壊鐢荤嚎鏃讹紝THE Bloodhowl_Q_Line_Skill SHALL 娌胯矾寰勫垱寤虹孩绾匡紝鎺ヨЕ绾㈢嚎鐨勭敓鍛藉€间綆浜?30% 鐨勬晫浜虹珛鍗虫浜?
11. WHEN 澶勫垜瑙掕壊鐢诲湀闂悎鏃讹紝THE Bloodhowl_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鏂ご鍙版晥鏋滐紝鍖哄煙鍐呮晫浜哄彈鍒颁激瀹虫椂鏈夋鐜囪绔嬪嵆鍑绘潃
12. WHEN 澶勫垜瑙掕壊鎸?E 閿椂锛孴HE Bloodhowl_E_Skill SHALL 浣胯鑹茬灛绉诲埌鏈€杩戞晫浜轰綅缃苟閫犳垚浼ゅ
13. WHEN 璧屽緬瑙掕壊鐢荤嚎鏃讹紝THE Gambler_Q_Line_Skill SHALL 娌胯矾寰勫垱寤洪殢鏈哄彉鑹插甫锛堢孩鑹?浼ゅ銆佺豢鑹?娌荤枟銆佽摑鑹?鍔犻€燂級锛岄鑹查殢鏈哄彉鍖?
14. WHEN 璧屽緬瑙掕壊鐢诲湀闂悎鏃讹紝THE Gambler_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓杞洏鏁堟灉锛岄殢鏈虹粰浜堝己鍔?Buff 鎴栧急 Debuff
15. WHEN 璧屽緬瑙掕壊鎸?E 閿椂锛孴HE Gambler_E_Skill SHALL 鎺烽瀛愶紝鏍规嵁缁撴灉浜х敓闅忔満鏁堟灉
16. WHEN 鐚庝汉瑙掕壊鐢荤嚎鏃讹紝THE Hunter_Q_Line_Skill SHALL 娌胯矾寰勬爣璁版墍鏈夋帴瑙︾殑鏁屼汉锛岃鏍囪鏁屼汉鍙楀埌鐨勮嚜鍔ㄦ敾鍑讳激瀹冲鍔?50%
17. WHEN 鐚庝汉瑙掕壊鐢诲湀闂悎鏃讹紝THE Hunter_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓鐚庡満锛屽尯鍩熷唴琚爣璁扮殑鏁屼汉琚嚜鍔ㄦ敾鍑讳紭鍏堥€夋嫨
18. WHEN 鐚庝汉瑙掕壊鎸?E 閿椂锛孴HE Hunter_E_Skill SHALL 浣胯鑹叉墽琛岀炕婊氶棯閬匡紝鑾峰緱鐭殏鏃犳晫甯?

### 闇€姹?8锛欵 缁勬妧鑳?- 鐗规畩鏈哄埗

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜鎷ユ湁鍏锋湁鐙壒鏈哄埗鐨勬妧鑳界粍锛屼互渚夸綋楠屽弽灏勩€佽瘏鍜掗摼鎺ョ瓑鍒涙柊鐜╂硶銆?

#### 楠屾敹鏍囧噯

1. WHEN 榄旀湳甯堣鑹茬敾绾挎椂锛孴HE Viper_Q_Line_Skill SHALL 娌胯矾寰勫垱寤洪暅闈紙StaticBody2D锛夛紝鍙嶅皠鏁屼汉瀛愬脊
2. WHEN 榄旀湳甯堣鑹茬敾鍦堥棴鍚堟椂锛孴HE Viper_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熶腑蹇冨垱寤哄够褰卞垎韬紝鍚稿紩鏁屼汉浠囨仺
3. WHEN 榄旀湳甯堣鑹叉寜 E 閿椂锛孴HE Viper_E_Skill SHALL 浣胯鑹蹭笌骞诲奖鍒嗚韩浜ゆ崲浣嶇疆
4. WHEN 宸瘨瑙掕壊鐢荤嚎鏃讹紝THE Voodoo_Q_Line_Skill SHALL 娌胯矾寰勫垱寤鸿瘏鍜掔嚎锛屽鎺ヨЕ鐨勬晫浜烘柦鍔犺瘏鍜掔姸鎬?
5. WHEN 宸瘨瑙掕壊鐢诲湀闂悎鏃讹紝THE Voodoo_Q_Circle_Skill SHALL 鍦ㄩ棴鍚堝尯鍩熷唴鍒涘缓閽夊埡鍧戯紝鏀诲嚮鍖哄煙鍐呬换鎰忓崟浣嶆椂瀵规墍鏈夊甫璇呭拻鐘舵€佺殑鏁屼汉閫犳垚绛夐噺浼ゅ
6. WHEN 宸瘨瑙掕壊鎸?E 閿椂锛孴HE Voodoo_E_Skill SHALL 鑷激瑙﹀彂鍏ㄥ睆璇呭拻浼ゅ锛屽鎵€鏈夊甫璇呭拻鐘舵€佺殑鏁屼汉閫犳垚浼ゅ

### 闇€姹?9锛氭妧鑳借剼鏈灦鏋勪笌浠ｇ爜缁勭粐

**鐢ㄦ埛鏁呬簨锛?* 浣滀负娓告垙鏋舵瀯甯堬紝鎴戝笇鏈涙柊鎶€鑳借剼鏈伒寰粺涓€鐨勬灦鏋勬ā寮忥紝浠ヤ究浠ｇ爜鍙淮鎶ゃ€佸彲鎵╁睍涓斾笌鐜版湁绯荤粺鍏煎銆?

#### 楠屾敹鏍囧噯

1. THE 鎵€鏈夋柊 Q 鎶€鑳?SHALL 缁ф壙 SkillDrawingBase锛屽疄鐜?_spawn_line_effect() 鍜?_spawn_area_effect() 鏂规硶
2. THE 鎵€鏈夋柊 E 鎶€鑳?SHALL 缁ф壙 SkillBase锛屽疄鐜?execute() 鏂规硶
3. THE 鎵€鏈夋柊鎶€鑳借剼鏈?SHALL 瀛樻斁鍦?scenes/skills/players/ 鐩綍涓嬶紝鏂囦欢鍚嶉伒寰?skill_{character}_{type}.gd 鍛藉悕瑙勮寖
4. THE 鎵€鏈夋柊鎶€鑳?SHALL 閫氳繃 SkillEffectManager 鍒涘缓鏁堟灉锛岀‘淇濇晥鏋滃湪瑙掕壊鍒囨崲鍚庣户缁瓨鍦?
5. THE 鎵€鏈夋柊鎶€鑳界殑鍙傛暟 SHALL 浠?skill_params.csv 闀胯〃涓鍙栵紝涓嶅湪浠ｇ爜涓‖缂栫爜鏁板€?
6. THE 鎵€鏈夋柊鎶€鑳?SHALL 浣跨敤涓存椂鍗犱綅瑙嗚鏁堟灉锛堝僵鑹插嚑浣曞舰鐘讹級锛屼笉渚濊禆缇庢湳璧勬簮

### 闇€姹?10锛氬垹闄ゆ棫瑙掕壊銆佸垱寤烘柊瑙掕壊涓庢妧鑳界粦瀹?

**鐢ㄦ埛鏁呬簨锛?* 浣滀负娓告垙璁捐甯堬紝鎴戝笇鏈涘垹闄?20 涓潪鍘熷瑙掕壊锛岀劧鍚庢牴鎹柊鎶€鑳戒富棰樺垱寤?20 涓叏鏂拌鑹诧紝骞跺皢 20 濂楁柊鎶€鑳藉垎閰嶇粰杩欎簺鏂拌鑹诧紝鍓╀綑鎶€鑳藉瓨鍏ユ妧鑳藉簱銆?

#### 楠屾敹鏍囧噯

1. THE 20 涓潪鍘熷瑙掕壊锛坱echnology_hurricane銆乼ankman銆乭eavy_support銆亀arrior銆乪lectric_shock銆亀izard銆乫ortune_teller銆乼arot_reader銆乶ecromancer銆乵agician銆亀itch_doctor銆乴ovely銆乧amouflage銆乼he_flash銆乮nformation_Support銆乼echnical_support銆乴ight_support銆乨ryad銆乨octor銆乶urse锛塖HALL 浠庢墍鏈夐厤缃枃浠跺拰鑴氭湰涓畬鍏ㄥ垹闄?
2. WHEN 鏃ц鑹茶鍒犻櫎鍚庯紝THE 瀵瑰簲鐨?player_xxx.gd 鑴氭湰鏂囦欢鍜?.uid 鏂囦欢 SHALL 琚垹闄?
3. THE 20 涓柊瑙掕壊 SHALL 琚垱寤猴紝鍏?player_id 涓庢柊鎶€鑳戒富棰樺尮閰嶏紙濡?bulwark銆乼esla銆乶ew_ignis 绛夛級
4. WHEN 鏂拌鑹茶鍒涘缓鍚庯紝THE 鎵€鏈夌浉鍏?CSV 鏂囦欢锛坧layer_config銆乸layer_visual銆乸layer_weapons銆乸layer_skill_bindings銆乽lt_config銆乸layer_available_weapons锛塖HALL 鍖呭惈鏂拌鑹茬殑閰嶇疆琛?
5. WHEN 鏂拌鑹茶鍒涘缓鍚庯紝THE 瀵瑰簲鐨?player_xxx.gd 鑴氭湰鏂囦欢 SHALL 浣跨敤妯℃澘鍖栫粨鏋勫垱寤猴紝鍖呭惈姝ｇ‘鐨?class_name 鍜?load_skills_from_config 鍙傛暟
6. WHEN player_skill_bindings.csv 琚洿鏂板悗锛孴HE 20 涓柊瑙掕壊 SHALL 鍚勮嚜缁戝畾涓€濂楃嫭鐗圭殑鏂版妧鑳斤紙Q-line + Q-circle + E-key锛?
7. THE 鍘熷鍏鑹诧紙butcher銆乸yro銆乻apper銆乭erder銆亀eaver銆亀ind锛夌殑 player_id 鍜屾妧鑳界粦瀹?SHALL 淇濇寔涓嶅彉
8. THE 鍓╀綑鏈垎閰嶇殑鎶€鑳?SHALL 鍦?skill_params.csv 涓繚鐣欏畬鏁村弬鏁伴厤缃紝鍙€氳繃淇敼 player_skill_bindings.csv 鍒嗛厤缁欐湭鏉ヨ鑹?
9. WHEN SkillManager 鍔犺浇鏂版妧鑳界粦瀹氭椂锛孴HE SkillManager SHALL 姝ｇ‘瀹炰緥鍖栧搴旂殑鎶€鑳借剼鏈苟璁剧疆鍙傛暟

### 闇€姹?11锛氭妧鑳芥晥鏋滄寔涔呮€т笌瑙掕壊鍒囨崲鍏煎

**鐢ㄦ埛鏁呬簨锛?* 浣滀负鐜╁锛屾垜甯屾湜瑙掕壊 A 鍒涘缓鐨勬妧鑳芥晥鏋滃湪鍒囨崲鍒拌鑹?B 鍚庝粛鐒舵湁鏁堬紝浠ヤ究瑙掕壊 B 鑳藉鍙楃泭浜庤鑹?A 鐨勫鐩婂尯鍩熴€?

#### 楠屾敹鏍囧噯

1. WHEN 瑙掕壊 A 鍒涘缓浜嗕竴涓?Buff 鍖哄煙鍚庡垏鎹㈠埌瑙掕壊 B 鏃讹紝THE SkillEffectManager SHALL 缁х画缁存姢璇?Buff 鍖哄煙鐨勭敓鍛藉懆鏈?
2. WHEN 瑙掕壊 B 杩涘叆瑙掕壊 A 鍒涘缓鐨?Buff 鍖哄煙鏃讹紝THE Buff 鍖哄煙 SHALL 瀵硅鑹?B 搴旂敤鐩稿簲鐨勫鐩婃晥鏋?
3. WHEN 瑙掕壊 A 鍒涘缓浜?StaticBody2D 澧欎綋鍚庡垏鎹㈠埌瑙掕壊 B 鏃讹紝THE 澧欎綋 SHALL 缁х画闃绘尅鏁屼汉绉诲姩鐩村埌鎸佺画鏃堕棿鍒版湡

