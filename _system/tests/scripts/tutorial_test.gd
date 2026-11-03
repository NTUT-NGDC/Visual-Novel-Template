extends Node
## 教學關介面的自動測試（檢查邏輯本身在 tutorial_checker_test.gd 測）：
## 1. 空資料夾：11 步都未完成、不能試玩、不會當掉
## 2. 範例故事的副本（加上背景音樂）：試玩以外都完成；試玩播到結尾後第 8 步也完成
## 3. 試玩到一半按「結束試玩」：第 8 步不算完成
## 4. 試玩用了找不到角色的時間軸，而且播到一半就關掉遊戲：不會當掉（看 exit code）
##
## 在命令列執行：
##   godot --headless --path . res://_system/tests/tutorial_test.tscn

const TUTORIAL_SCENE: PackedScene = preload("res://lesson/tutorial/tutorial.tscn")
const FIXTURES: String = "res://_system/tests/tutorial_fixtures/"
const TIMEOUT_SECONDS: float = 30.0

var _failures: int = 0
var _waiting_for_choice: bool = false


func _ready() -> void:
	Dialogic.Inputs.auto_skip.enabled = true
	Dialogic.Inputs.auto_skip.disable_on_user_input = false
	Dialogic.Inputs.auto_skip.time_per_event = 0.01
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	Dialogic.TextInput.input_shown.connect(_on_text_input_shown)

	await _test_empty_folder()
	await _test_full_example()
	await _test_stop_midway()
	await _test_quit_while_playing()


func _test_empty_folder() -> void:
	print("--- 空資料夾 ---")
	var tutorial: Control = await _spawn("empty")
	_expect(tutorial.get_node("%StepList").get_child_count() == 11, "列出 11 個步驟")
	_expect(_status_texts(tutorial) == "未完成,未完成,未完成,未完成,未完成,未完成,未完成,未完成,未完成,未完成,未完成", "11 步都未完成")
	_expect((tutorial.get_node("%ProgressLabel") as Label).text == "已完成 0／8 步　額外：0／3", "進度顯示 0／8、額外 0／3")
	_expect((tutorial.get_node("%PlayButton") as Button).disabled, "沒有時間軸時不能按試玩")
	(tutorial.get_node("%CheckButton") as Button).pressed.emit()
	_expect(true, "按檢查不會當掉")
	await _free(tutorial)


func _test_full_example() -> void:
	print("--- 範例故事的副本 ---")
	var tutorial: Control = await _spawn("full_example")
	_expect(_status_texts(tutorial) == "完成！,完成！,完成！,完成！,完成！,完成！,完成！,未完成,完成！,完成！,完成！", "試玩以外都完成，第 8 步還沒")
	_expect((tutorial.get_node("%ProgressLabel") as Label).text == "已完成 7／8 步　額外：3／3", "進度顯示 7／8、額外 3／3")

	(tutorial.get_node("%PlayButton") as Button).pressed.emit()
	var main_panel: Control = tutorial.get_node("%MainPanel")
	_expect(not main_panel.visible, "試玩時藏起教學介面")
	_expect(await _wait_until(func() -> bool: return main_panel.visible), "播完後回到教學介面")
	_expect(_status_texts(tutorial) == "完成！,完成！,完成！,完成！,完成！,完成！,完成！,完成！,完成！,完成！,完成！", "播完後 11 步全部完成")
	_expect((tutorial.get_node("%ProgressLabel") as Label).text == "已完成 8／8 步　額外：3／3", "進度顯示 8／8")
	await _free(tutorial)


func _test_stop_midway() -> void:
	print("--- 試玩到一半按結束 ---")
	var tutorial: Control = await _spawn("full_example")
	(tutorial.get_node("%PlayButton") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	(tutorial.get_node("%StopButton") as Button).pressed.emit()
	var main_panel: Control = tutorial.get_node("%MainPanel")
	_expect(await _wait_until(func() -> bool: return main_panel.visible), "按結束後回到教學介面")
	_expect(_status_texts(tutorial).split(",")[7] == "未完成", "第 8 步不算完成")
	await _free(tutorial)


func _test_quit_while_playing() -> void:
	print("--- 試玩找不到角色的時間軸，播到一半就關掉 ---")
	var tutorial: Control = await _spawn("lines_pass")
	(tutorial.get_node("%PlayButton") as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	# 這裡直接結束遊戲；如果臨時角色沒清掉，結束時會當掉，exit code 不會是 0
	if _failures == 0:
		print("[教學關介面測試] 全部 PASS（最後確認 exit code 是 0）")
		get_tree().quit(0)
	else:
		print("[教學關介面測試] FAIL：%d 項失敗" % _failures)
		get_tree().quit(1)


func _spawn(folder_name: String) -> Control:
	var tutorial: Control = TUTORIAL_SCENE.instantiate()
	tutorial.set("story_folder", FIXTURES + folder_name)
	add_child(tutorial)
	await get_tree().process_frame
	return tutorial


func _free(tutorial: Control) -> void:
	tutorial.queue_free()
	await get_tree().process_frame


## 每個步驟的狀態文字，用逗號接起來
func _status_texts(tutorial: Control) -> String:
	var texts: PackedStringArray = []
	for row: Node in tutorial.get_node("%StepList").get_children():
		texts.append((row.get_node("%StatusLabel") as Label).text)
	return ",".join(texts)


func _wait_until(condition: Callable) -> bool:
	var time_left: float = TIMEOUT_SECONDS
	while time_left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		time_left -= get_process_delta_time()
	return false


func _expect(ok: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		_failures += 1


func _on_question_shown(_info: Dictionary) -> void:
	_waiting_for_choice = true
	while _waiting_for_choice:
		Dialogic.Choices.select_choice(1)
		await get_tree().create_timer(0.2).timeout


func _on_choice_selected(_info: Dictionary) -> void:
	_waiting_for_choice = false


## 遇到輸入名字（Text Input）時自動填一個名字。
## 輸入框出現之後 Dialogic 才開始等「確認」，所以等一個畫面再送出；
## Text Input 會關掉自動略過，送出後要再打開
func _on_text_input_shown(_info: Dictionary) -> void:
	await get_tree().process_frame
	Dialogic.TextInput.input_confirmed.emit("測試")
	Dialogic.Inputs.auto_skip.enabled = true
