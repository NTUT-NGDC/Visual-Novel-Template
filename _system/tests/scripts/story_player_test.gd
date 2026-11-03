extends Node
## 播放場景的自動測試：
## 1. 指向範例時間軸 → 能播完、出現結束畫面；按重玩後變數有重設、能再播完一次
## 2. 指向不存在的檔案、角色檔、空路徑 → 顯示提示，不會開始播放
##
## 在命令列執行：
##   godot --headless --path . res://_system/tests/story_player_test.tscn

const STORY_PLAYER_SCENE: PackedScene = preload("res://example/story_player/story_player.tscn")
## 每一段等待最多幾秒
const TIMEOUT_SECONDS: float = 30.0

var _failures: int = 0
## 是否還在等選項被選到
var _waiting_for_choice: bool = false


func _ready() -> void:
	# 自動略過：台詞會自己往下播，遇到選項一律選第 1 個（會加好感度的那個）
	Dialogic.Inputs.auto_skip.enabled = true
	Dialogic.Inputs.auto_skip.disable_on_user_input = false
	Dialogic.Inputs.auto_skip.time_per_event = 0.01
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	Dialogic.TextInput.input_shown.connect(_on_text_input_shown)

	await _test_play_and_replay()
	await _test_problem_path("res://my_story/timelines/不存在的時間軸.dtl", "找不到時間軸")
	await _test_problem_path("res://example/characters/jane.dch", "不是時間軸")
	await _test_problem_path("", "還沒有指定")

	if _failures == 0:
		print("[播放場景測試] 全部 PASS")
		get_tree().quit(0)
	else:
		print("[播放場景測試] FAIL：%d 項失敗" % _failures)
		get_tree().quit(1)


func _test_play_and_replay() -> void:
	print("--- 範例時間軸：播完 → 重玩 ---")
	var player: Node = _spawn_player("res://example/timelines/example_story.dtl")
	var end_panel: Control = player.get_node("%EndPanel")

	_expect(not end_panel.visible, "剛開始時不顯示結束畫面")
	_expect(await _wait_until(func() -> bool: return end_panel.visible), "第一次播完後出現結束畫面")
	var first_value: Variant = Dialogic.VAR.get_variable("好感度")
	print("  第一次播完，好感度 = ", first_value)

	(player.get_node("%ReplayButton") as Button).pressed.emit()
	_expect(not end_panel.visible, "按重玩後結束畫面消失")
	_expect(await _wait_until(func() -> bool: return end_panel.visible), "重玩後再次播完")
	var second_value: Variant = Dialogic.VAR.get_variable("好感度")
	print("  第二次播完，好感度 = ", second_value)
	_expect(is_equal_approx(float(first_value), float(second_value)), "重玩後好感度跟第一次一樣（變數有重設）")

	player.queue_free()
	await get_tree().process_frame


func _test_problem_path(path: String, expected_text: String) -> void:
	print("--- 有問題的路徑：「%s」 ---" % path)
	var player: Node = _spawn_player(path)
	await get_tree().process_frame
	var message_panel: Control = player.get_node("%MessagePanel")
	var message_label: Label = player.get_node("%MessageLabel")
	_expect(message_panel.visible, "顯示提示面板")
	_expect(expected_text in message_label.text, "提示內容包含「%s」" % expected_text)
	_expect(Dialogic.current_timeline == null, "沒有開始播放")
	player.queue_free()
	await get_tree().process_frame


## 建立播放場景，在加進場景樹之前改掉時間軸路徑
func _spawn_player(path: String) -> Node:
	var player: Node = STORY_PLAYER_SCENE.instantiate()
	player.set("timeline_path", path)
	add_child(player)
	return player


## 每一幀檢查 condition，變成 true 就回傳 true；超過時間回傳 false
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


## 選項剛出現時有防誤觸時間，選了會被忽略，所以重試到真的選到為止
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
