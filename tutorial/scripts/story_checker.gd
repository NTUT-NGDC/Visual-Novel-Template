class_name StoryChecker
extends RefCounted
## 教學關的檢查邏輯：讀一個資料夾裡的角色檔（.dch）和時間軸檔（.dtl），
## 判斷教學關第 1～5、7 步有沒有做到。第 6 步（試玩）是執行時檢查，在 tutorial.gd。
##
## 只負責判斷、不碰畫面，教學關介面和測試（tests/scripts/tutorial_checker_test.gd）都用它。
## 每次檢查都直接從硬碟讀檔，不用 load()，社員存檔後再按「檢查」才會看到新的內容。
##
## 用法：
##   var checker := StoryChecker.new("res://my_story")
##   var result: StoryChecker.Result = checker.check_character()
##   if result.passed: ...

## 一步的檢查結果
class Result:
	## 有沒有過關
	var passed: bool = false
	## 沒過：給社員看的原因。過了：哪個檔案過關的
	var message: String = ""

	func _init(p_passed: bool, p_message: String) -> void:
		passed = p_passed
		message = p_message


## 一條時間軸的統計資料，從 Dialogic 解析出來的事件整理而成
class TimelineInfo:
	var file_name: String = ""
	## 台詞（包含旁白）有幾句
	var line_count: int = 0
	## 有沒有角色登場（join）
	var has_join: bool = false
	## 有沒有換過立繪（update 角色 (立繪)，或台詞裡的 角色 (立繪): …）
	var has_portrait_change: bool = false
	## 同一組選項最多有幾個
	var biggest_choice_group: int = 0
	## 所有標籤的名字
	var labels: PackedStringArray = []
	## 跳到這條時間軸裡某個標籤的跳轉，標籤名字
	var jump_targets: PackedStringArray = []
	## 設定變數事件用到的變數名字
	var set_variables: PackedStringArray = []
	## 有沒有條件判斷（if／elif）
	var has_condition: bool = false


## 角色至少要有幾張設定了圖片的立繪
const MIN_PORTRAITS: int = 2
## 時間軸至少要有幾句台詞
const MIN_LINES: int = 3

## 要檢查的資料夾，例如 res://my_story
var folder_path: String = ""

var _folder_exists: bool = false
var _character_paths: PackedStringArray = []
var _timeline_paths: PackedStringArray = []
var _timelines: Array[TimelineInfo] = []


func _init(p_folder_path: String) -> void:
	folder_path = p_folder_path.trim_suffix("/")
	_folder_exists = DirAccess.dir_exists_absolute(folder_path)
	if not _folder_exists:
		return
	_collect_files(folder_path, _character_paths, _timeline_paths)
	for path: String in _timeline_paths:
		_timelines.append(_read_timeline(path))


## 資料夾裡所有時間軸檔的路徑（教學關的「試玩」選單用）
func get_timeline_paths() -> PackedStringArray:
	return _timeline_paths


#region 第 1 步：建立角色

func check_character() -> Result:
	var problem: String = _check_folder("角色檔（.dch）", _character_paths.size())
	if problem != "":
		return Result.new(false, problem)

	# 有好幾個角色時，只要一個過關就算過；都沒過就回報「最接近過關」的那個
	var best_message: String = ""
	var best_score: int = -1
	for path: String in _character_paths:
		var file_name: String = path.get_file()
		var data: Variant = str_to_var(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			if best_score < 0:
				best_message = "%s 讀不出內容，檔案可能壞掉了。可以刪掉，用 Dialogic 編輯器重新建立一個角色。" % file_name
				best_score = 0
			continue

		var character: Dictionary = data
		var display_name: String = str(character.get("display_name", "")).strip_edges()
		var portrait_count: int = 0
		var empty_portrait_count: int = 0
		var portraits: Variant = character.get("portraits", {})
		if portraits is Dictionary:
			for portrait: Variant in (portraits as Dictionary).values():
				if _portrait_has_image(portrait):
					portrait_count += 1
				else:
					empty_portrait_count += 1

		if display_name != "" and portrait_count >= MIN_PORTRAITS:
			return Result.new(true, "%s（%s，%d 張立繪）" % [file_name, display_name, portrait_count])

		var score: int = 1 + portrait_count + (1 if display_name != "" else 0)
		if score <= best_score:
			continue
		best_score = score
		if display_name == "":
			best_message = "找到角色 %s，但還沒設定名字（Display Name）。" % file_name
		else:
			best_message = "找到角色「%s」（%s），但只有 %d 張有設定圖片的立繪，至少要 %d 張。" % [display_name, file_name, portrait_count, MIN_PORTRAITS]
			if empty_portrait_count > 0:
				best_message += "\n有 %d 張立繪還沒選圖片。" % empty_portrait_count
	return Result.new(false, best_message)


## 立繪有沒有設定圖片（或自訂的立繪場景）
func _portrait_has_image(portrait: Variant) -> bool:
	if not portrait is Dictionary:
		return false
	var scene: String = str((portrait as Dictionary).get("scene", ""))
	if scene != "":
		return true
	var overrides: Variant = (portrait as Dictionary).get("export_overrides", {})
	if not overrides is Dictionary:
		return false
	# 圖片路徑外面多包了一層引號，例如 "\"res://example/images/jane_happy.png\""
	var image: String = str((overrides as Dictionary).get("image", "")).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return image != ""

#endregion


#region 第 2 步：建立時間軸

func check_lines() -> Result:
	var problem: String = _check_folder("時間軸檔（.dtl）", _timelines.size())
	if problem != "":
		return Result.new(false, problem)

	var best: TimelineInfo = _timelines[0]
	for info: TimelineInfo in _timelines:
		if info.line_count >= MIN_LINES:
			return Result.new(true, "%s（%d 句台詞）" % [info.file_name, info.line_count])
		if info.line_count > best.line_count:
			best = info
	return Result.new(false, "找到時間軸 %s，但只有 %d 句台詞，至少要 %d 句。" % [best.file_name, best.line_count, MIN_LINES])

#endregion


#region 第 3 步：角色登場、換表情

func check_join_and_portrait() -> Result:
	var problem: String = _check_folder("時間軸檔（.dtl）", _timelines.size())
	if problem != "":
		return Result.new(false, problem)

	var joined: TimelineInfo = null
	for info: TimelineInfo in _timelines:
		if info.has_join and info.has_portrait_change:
			return Result.new(true, info.file_name)
		if info.has_join and joined == null:
			joined = info
	if joined == null:
		return Result.new(false, "時間軸裡還沒有角色登場（Character 事件選 Join）。")
	return Result.new(false, "%s 裡有角色登場了，但還沒換過立繪（Character 事件選 Update 並選一張立繪，或在台詞選角色時順便選立繪）。" % joined.file_name)

#endregion


#region 第 4 步：加入選項

func check_choice() -> Result:
	var problem: String = _check_folder("時間軸檔（.dtl）", _timelines.size())
	if problem != "":
		return Result.new(false, problem)

	var best: TimelineInfo = _timelines[0]
	for info: TimelineInfo in _timelines:
		if info.biggest_choice_group >= 2:
			return Result.new(true, "%s（一組 %d 個選項）" % [info.file_name, info.biggest_choice_group])
		if info.biggest_choice_group > best.biggest_choice_group:
			best = info
	if best.biggest_choice_group == 0:
		return Result.new(false, "時間軸裡還沒有選項（Choice）。")
	return Result.new(false, "%s 裡有選項，但同一組只有 1 個，至少要 2 個。\n同一組的選項要在同一層、一個接一個排在一起。" % best.file_name)

#endregion


#region 第 5 步：分支匯流

func check_label_and_jump() -> Result:
	var problem: String = _check_folder("時間軸檔（.dtl）", _timelines.size())
	if problem != "":
		return Result.new(false, problem)

	var with_label: TimelineInfo = null
	var with_jump: TimelineInfo = null
	for info: TimelineInfo in _timelines:
		for target: String in info.jump_targets:
			if target in info.labels:
				return Result.new(true, "%s（跳到「%s」）" % [info.file_name, target])
		if not info.labels.is_empty() and with_label == null:
			with_label = info
		if not info.jump_targets.is_empty() and with_jump == null:
			with_jump = info

	if with_jump != null and with_label != null and with_jump == with_label:
		return Result.new(false, "%s 裡有跳轉到「%s」，但沒有叫這個名字的標籤。\n目前有的標籤：%s（名字要一模一樣）" % [with_jump.file_name, with_jump.jump_targets[0], "、".join(with_label.labels)])
	if with_jump != null:
		return Result.new(false, "%s 裡有跳轉到「%s」，但沒有叫這個名字的標籤（Label）。" % [with_jump.file_name, with_jump.jump_targets[0]])
	if with_label != null:
		return Result.new(false, "%s 裡有標籤「%s」，但還沒有跳轉（Jump）跳到它。" % [with_label.file_name, with_label.labels[0]])
	return Result.new(false, "時間軸裡還沒有標籤（Label）和跳轉（Jump）。")

#endregion


#region 第 7 步：加分：變數＋條件

func check_variable_and_condition() -> Result:
	var problem: String = _check_folder("時間軸檔（.dtl）", _timelines.size())
	if problem != "":
		return Result.new(false, problem)

	var undefined_message: String = ""
	var partial_message: String = ""
	for info: TimelineInfo in _timelines:
		var undefined: PackedStringArray = []
		for variable_name: String in info.set_variables:
			if not _variable_exists(variable_name) and not variable_name in undefined:
				undefined.append(variable_name)

		if not undefined.is_empty():
			if undefined_message == "":
				undefined_message = "%s 用了變數「%s」，但還沒在 Dialogic 的 Variables 分頁新增。\n（已經新增了的話，關掉教學關重新執行一次）" % [info.file_name, "」「".join(undefined)]
			continue
		if not info.set_variables.is_empty() and info.has_condition:
			return Result.new(true, info.file_name)
		if partial_message == "":
			if not info.set_variables.is_empty():
				partial_message = "%s 裡有設定變數，但還沒有條件判斷（Condition 事件選 If）。" % info.file_name
			elif info.has_condition:
				partial_message = "%s 裡有條件判斷，但還沒有設定變數（Set Variable）。" % info.file_name

	if undefined_message != "":
		return Result.new(false, undefined_message)
	if partial_message != "":
		return Result.new(false, partial_message)
	return Result.new(false, "時間軸裡還沒有設定變數（Set Variable）和條件判斷（Condition）。")


## 變數有沒有在 Dialogic 的 Variables 分頁定義過（資料夾裡的變數用「資料夾.變數」）
func _variable_exists(variable_name: String) -> bool:
	var current: Variant = ProjectSettings.get_setting("dialogic/variables", {})
	for part: String in variable_name.split("."):
		if not current is Dictionary or not (current as Dictionary).has(part):
			return false
		current = (current as Dictionary)[part]
	return true

#endregion


#region 讀檔

## 時間軸的台詞用了找不到的角色時（例如教學關執行後才新增的角色），
## Dialogic 會臨時建一個角色，登記在全域的角色對照表裡。
## 這些臨時角色留到遊戲結束會讓遊戲當掉，所以用完要清掉。
static func forget_temporary_characters() -> void:
	var directory: Dictionary = DialogicResourceUtil.get_directory("dch")
	for identifier: Variant in directory.keys():
		if directory[identifier] is Resource:
			directory.erase(identifier)


## 資料夾不存在、或是找不到某種檔案時，回傳要給社員看的說明；沒問題回傳空字串
func _check_folder(file_kind: String, file_count: int) -> String:
	if not _folder_exists:
		return "找不到 %s 資料夾。" % folder_path
	if file_count == 0:
		return "在 %s 裡還沒有找到%s。" % [folder_path, file_kind]
	return ""


## 找出資料夾（包含子資料夾）裡所有的 .dch 和 .dtl
func _collect_files(path: String, character_paths: PackedStringArray, timeline_paths: PackedStringArray) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		match file_name.get_extension():
			"dch":
				character_paths.append(path.path_join(file_name))
			"dtl":
				timeline_paths.append(path.path_join(file_name))
	for dir_name: String in DirAccess.get_directories_at(path):
		if not dir_name.begins_with("."):
			_collect_files(path.path_join(dir_name), character_paths, timeline_paths)


## 用 Dialogic 的解析器讀時間軸，整理成 TimelineInfo
func _read_timeline(path: String) -> TimelineInfo:
	var info := TimelineInfo.new()
	info.file_name = path.get_file()
	var own_identifier: String = path.get_file().get_basename()

	var timeline := DialogicTimeline.new()
	timeline.from_text(FileAccess.get_file_as_string(path))
	timeline.process()
	forget_temporary_characters()

	# 選項分組：同一層、一個接一個的選項算同一組（跟 Dialogic 播放時的判斷一樣）。
	# depth 是目前在第幾層分支裡，choice_groups[depth] 是這一層目前這組選項的數量
	var depth: int = 0
	var choice_groups: Dictionary[int, int] = {}

	for event: Variant in timeline.events:
		if not event is DialogicEvent:
			continue

		if event is DialogicEndBranchEvent:
			choice_groups.erase(depth)
			depth = maxi(depth - 1, 0)
			continue

		if event is DialogicChoiceEvent:
			choice_groups[depth] = choice_groups.get(depth, 0) + 1
			info.biggest_choice_group = maxi(info.biggest_choice_group, choice_groups[depth])
		else:
			choice_groups[depth] = 0

		if event is DialogicTextEvent:
			info.line_count += 1
			if (event as DialogicTextEvent).portrait != "":
				info.has_portrait_change = true
		elif event is DialogicCharacterEvent:
			var character_event: DialogicCharacterEvent = event
			if character_event.action == DialogicCharacterEvent.Actions.JOIN:
				info.has_join = true
			elif character_event.action == DialogicCharacterEvent.Actions.UPDATE and character_event.portrait != "":
				info.has_portrait_change = true
		elif event is DialogicLabelEvent:
			var label_name: String = (event as DialogicLabelEvent).name
			if label_name != "":
				info.labels.append(label_name)
		elif event is DialogicJumpEvent:
			var jump_event: DialogicJumpEvent = event
			# 只算跳到同一條時間軸的跳轉（沒寫時間軸，或寫的就是自己）
			var target_timeline: String = jump_event.timeline_identifier
			if jump_event.label_name != "" and (target_timeline == "" or target_timeline == own_identifier):
				info.jump_targets.append(jump_event.label_name)
		elif event is DialogicVariableEvent:
			var variable_name: String = (event as DialogicVariableEvent).name
			if variable_name != "":
				info.set_variables.append(variable_name)
		elif event is DialogicConditionEvent:
			if (event as DialogicConditionEvent).condition_type != DialogicConditionEvent.ConditionTypes.ELSE:
				info.has_condition = true

		if (event as DialogicEvent).can_contain_events:
			depth += 1

	return info

#endregion
