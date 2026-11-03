extends Node
## 教學關檢查邏輯（StoryChecker）的自動測試：
## 用 _system/tests/tutorial_fixtures/ 裡每個資料夾當成社員的 my_story，確認該過的會過、不該過的不會過，
## 沒過時的原因有寫到重點，而且壞掉的檔案、空資料夾不會讓遊戲當掉。
##
## 在命令列執行：
##   godot --headless --path . res://_system/tests/tutorial_checker_test.tscn

const FIXTURES: String = "res://_system/tests/tutorial_fixtures/"
## 檢查的步驟，順序跟 CASES 裡的結果字串一樣
## 第 8 步（試玩）是執行時檢查，不在這裡測（在 tutorial_test.gd）
const STEP_NAMES: PackedStringArray = ["1 角色", "2 台詞", "3 登場換表情", "4 選項", "5 匯流", "6 背景", "7 音樂", "9 變數條件", "10 文字節奏", "11 輸入名字"]
const STEP_NUMBERS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11]

## 每個測試案例：[資料夾, 預期結果, {步驟編號: 原因裡要出現的文字}]
## 預期結果 10 個字對應 STEP_NAMES：P = 要過、F = 不能過、. = 不管
const CASES: Array[Array] = [
	["不存在的資料夾", "FFFFFFFFFF", {1: "找不到", 2: "找不到"}],
	["empty", "FFFFFFFFFF", {1: "還沒有找到角色檔", 2: "還沒有找到時間軸檔"}],
	["garbage", "F.........", {1: "讀不出內容"}],
	["char_pass", "PFFFFFFFFF", {}],
	["char_no_name", "F.........", {1: "還沒設定名字"}],
	["char_one_portrait", "F.........", {1: "只有 1 張"}],
	["char_multi", "P.........", {}],
	["lines_pass", ".PF.......", {3: "還沒有角色登場"}],
	["lines_two", ".F........", {2: "只有 2 句台詞"}],
	["join_update", "..P.......", {}],
	["join_text_portrait", "..P.......", {}],
	["join_no_change", "..F.......", {3: "還沒換過立繪"}],
	["join_other_character", "..F.......", {3: "換表情的是「hana」"}],
	["join_example_character", "..F.......", {3: "不是你在"}],
	["choice_pass", "...P......", {}],
	["choice_single", "...F......", {4: "同一組只有 1 個"}],
	["choice_nested", "...F......", {4: "同一組只有 1 個"}],
	["label_pass", "...PP.....", {}],
	["label_only", "....F.....", {5: "還沒有跳轉"}],
	["jump_wrong", "....F.....", {5: "目前有的標籤：匯流"}],
	["var_pass", ".......P..", {}],
	["var_set_only", ".......F..", {9: "還沒有條件判斷"}],
	["var_undefined", ".......F..", {9: "Variables 分頁"}],
	["multi_timeline", ".P........", {}],
	["bg_pass", ".....P....", {}],
	["bg_empty", ".....F....", {6: "還沒選圖片"}],
	["bg_color", ".....F....", {6: "還沒選圖片"}],
	["music_pass", "......P...", {}],
	["music_sound_only", "......F...", {7: "沒有選頻道"}],
	["music_empty", "......F...", {7: "還沒選音檔"}],
	["rhythm_effect", "........P.", {}],
	["rhythm_wait", "........P.", {}],
	["rhythm_none", "........F.", {10: "還沒有文字效果"}],
	["name_pass", ".........P", {}],
	["name_unused", ".........F", {11: "台詞裡還沒用到"}],
	["name_undefined", ".........F", {11: "Variables 分頁"}],
	["name_no_var", ".........F", {11: "還沒選要存進哪個變數"}],
	["full_example", "PPPPPPPPPP", {}],
]

var _failures: int = 0


func _ready() -> void:
	for test_case: Array in CASES:
		_run_case(test_case[0], test_case[1], test_case[2])

	if _failures == 0:
		print("[教學關檢查測試] 全部 PASS")
		get_tree().quit(0)
	else:
		print("[教學關檢查測試] FAIL：%d 項失敗" % _failures)
		get_tree().quit(1)


func _run_case(folder_name: String, expected: String, expected_messages: Dictionary) -> void:
	print("--- %s ---" % folder_name)
	var checker := StoryChecker.new(FIXTURES + folder_name)
	var results: Array[StoryChecker.Result] = [
		checker.check_character(),
		checker.check_lines(),
		checker.check_join_and_portrait(),
		checker.check_choice(),
		checker.check_label_and_jump(),
		checker.check_background(),
		checker.check_music(),
		checker.check_variable_and_condition(),
		checker.check_text_rhythm(),
		checker.check_name_input(),
	]

	for index: int in results.size():
		var result: StoryChecker.Result = results[index]
		var want: String = expected[index]
		var step_number: int = STEP_NUMBERS[index]
		var ok: bool = true
		if want == "P" and not result.passed:
			ok = false
		elif want == "F" and result.passed:
			ok = false
		if expected_messages.has(step_number) and not (expected_messages[step_number] as String) in result.message:
			ok = false
		if want == "." and not expected_messages.has(step_number):
			continue
		_expect(ok, "%s：%s｜%s" % [STEP_NAMES[index], "過" if result.passed else "沒過", result.message.replace("\n", " ")])


func _expect(ok: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		_failures += 1
