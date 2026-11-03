extends Node
## 標題畫面、音量設定、暫停選單的自動測試：
## 1. 故事場景欄位空的、找不到檔案、選到不是場景的檔案 → 顯示提示，不會換場景
## 2. 設定面板可以打開、關閉；電腦版看得到「離開遊戲」；標題音樂會自動播放、播完重播
## 3. 音量：調整後會存檔，重新讀取後音量和滑桿位置都對；拉到 0 是靜音
## 4. 預設設定（範例故事）：標題 → 按開始 → 範例故事播完 → 回到標題，跑兩輪，第二輪變數有重設
## 5. 暫停選單：打開時 Dialogic 暫停、故事不會往下走；繼續後恢復；回到標題時時間軸已停止
##
## 測試會暫時改掉 user://sound_settings.cfg，結束時還原。
##
## 在命令列執行：
##   godot --headless --path . res://tests/title_screen_test.tscn

const TITLE_SCENE: PackedScene = preload("res://title_screen/title_screen.tscn")
const TITLE_PATH: String = "res://title_screen/title_screen.tscn"
const STORY_PATH: String = "res://example/story_scene/story_scene.tscn"
const TIMEOUT_SECONDS: float = 30.0

var _failures: int = 0
var _waiting_for_choice: bool = false
## 輸入名字後要不要重新打開自動略過（暫停選單的測試要讓故事停在第一句）
var _auto_skip_after_input: bool = true


func _ready() -> void:
	# 自動略過：台詞會自己往下播，遇到選項一律選第 1 個（會加好感度的那個）
	Dialogic.Inputs.auto_skip.enabled = true
	Dialogic.Inputs.auto_skip.disable_on_user_input = false
	Dialogic.Inputs.auto_skip.time_per_event = 0.01
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	Dialogic.TextInput.input_shown.connect(_on_text_input_shown)

	await _test_problem("", "還沒有設定故事場景")
	await _test_problem("res://my_story/不存在的場景.tscn", "找不到故事場景")
	await _test_problem("res://example/characters/jane.dch", "不是場景")
	await _test_settings_panel()
	await _test_title_music()
	await _test_sound_settings()
	await _test_full_flow()
	await _test_pause_menu()

	if _failures == 0:
		print("[標題畫面測試] 全部 PASS")
		get_tree().quit(0)
	else:
		print("[標題畫面測試] FAIL：%d 項失敗" % _failures)
		get_tree().quit(1)


func _test_problem(path: String, expected_text: String) -> void:
	print("--- 故事場景設成「%s」 ---" % path)
	var title: Control = TITLE_SCENE.instantiate()
	title.set("story_scene", path)
	add_child(title)
	await get_tree().process_frame

	var message_label: Label = title.get_node("%MessageLabel")
	_expect(not message_label.visible, "一開始不顯示提示")
	(title.get_node("%StartButton") as Button).pressed.emit()
	await get_tree().process_frame
	_expect(message_label.visible, "按開始後顯示提示")
	_expect(expected_text in message_label.text, "提示內容包含「%s」" % expected_text)
	_expect(get_tree().current_scene == self, "沒有換場景")
	title.queue_free()
	await get_tree().process_frame


func _test_settings_panel() -> void:
	print("--- 設定面板 ---")
	var title: Control = TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame
	var panel: Control = title.get_node("%SettingsPanel")
	_expect((title.get_node("%QuitButton") as Button).visible, "電腦版看得到「離開遊戲」")
	_expect(not panel.visible, "一開始設定面板是關的")
	(title.get_node("%SettingsButton") as Button).pressed.emit()
	_expect(panel.visible, "按「設定」打開面板")
	(title.get_node("%BackButton") as Button).pressed.emit()
	_expect(not panel.visible, "按「返回」關掉面板")
	title.queue_free()
	await get_tree().process_frame


func _test_title_music() -> void:
	print("--- 標題音樂 ---")
	var title: Control = TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame
	_expect(not title.has_node("TitleMusicPlayer"), "預設沒有放音樂，不會建立播放器、不會出錯")
	title.queue_free()
	await get_tree().process_frame

	# 放一個 0.5 秒的靜音檔，確認會自動播放、播完會重播
	title = TITLE_SCENE.instantiate()
	title.set("title_music", load("res://tests/audio/silence.wav"))
	add_child(title)
	await get_tree().process_frame
	var music: AudioStreamPlayer = title.get_node_or_null("TitleMusicPlayer")
	_expect(music != null and music.playing, "放了音樂就會自動播放")
	_expect(music != null and music.bus == &"Music", "標題音樂走 Music 匯流排（設定裡的「音樂」管得到）")
	await get_tree().create_timer(1.2).timeout
	_expect(music != null and music.playing, "播完會從頭再播")
	title.queue_free()
	await get_tree().process_frame


func _test_sound_settings() -> void:
	print("--- 音量存檔 ---")
	var save_path: String = SoundSettings.SAVE_PATH
	var backup: String = FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""

	SoundSettings.set_volume("Music", 0.4)
	SoundSettings.set_volume("SFX", 0.0)
	await get_tree().create_timer(SoundSettings.SAVE_DELAY + 0.2).timeout
	_expect(FileAccess.file_exists(save_path), "調整後有存檔")
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "音效拉到 0 是靜音")

	# 模擬重新開遊戲：先把音量改回 1，再讓一個新的 SoundSettings 讀檔
	for bus_name: String in ["Music", "SFX"]:
		var index: int = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_mute(index, false)
		AudioServer.set_bus_volume_db(index, 0.0)
	var reloaded: Node = (SoundSettings.get_script() as GDScript).new()
	add_child(reloaded)
	_expect(is_equal_approx(SoundSettings.get_volume("Music"), 0.4), "重新讀檔後音樂是 0.4")
	_expect(is_equal_approx(SoundSettings.get_volume("SFX"), 0.0), "重新讀檔後音效是 0（靜音）")
	reloaded.queue_free()

	var title: Control = TITLE_SCENE.instantiate()
	add_child(title)
	await get_tree().process_frame
	_expect(is_equal_approx((title.get_node("%MusicSlider") as HSlider).value, 0.4), "設定面板的音樂滑桿在 0.4")
	(title.get_node("%MusicSlider") as HSlider).value = 0.8
	_expect(is_equal_approx(SoundSettings.get_volume("Music"), 0.8), "拖滑桿會改變音量")
	title.queue_free()
	await get_tree().process_frame

	# 還原：音量回到 1，存檔回到測試前的內容
	SoundSettings.set_volume("Music", 1.0)
	SoundSettings.set_volume("SFX", 1.0)
	await get_tree().create_timer(SoundSettings.SAVE_DELAY + 0.2).timeout
	if backup == "":
		DirAccess.remove_absolute(save_path)
	else:
		var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		file.store_string(backup)
		file.close()


func _test_pause_menu() -> void:
	print("--- 暫停選單 ---")
	# 關掉自動略過，讓故事停在第一句台詞，才能確認暫停時點畫面不會往下走
	_auto_skip_after_input = false
	Dialogic.Inputs.auto_skip.enabled = false
	var current_title: Node = get_tree().current_scene
	(current_title.get_node("%StartButton") as Button).pressed.emit()
	_expect(await _wait_until(func() -> bool: return _current_scene_path() == STORY_PATH and Dialogic.current_timeline != null), "進到故事場景")
	await get_tree().create_timer(0.3).timeout

	var story: Node = get_tree().current_scene
	var menu_panel: Control = story.get_node("PauseMenu/%MenuPanel")
	(story.get_node("PauseMenu/%MenuButton") as Button).pressed.emit()
	_expect(menu_panel.visible and Dialogic.paused, "按「選單」打開選單，Dialogic 暫停")
	var index_before: int = Dialogic.current_event_idx
	for i: int in 3:
		Dialogic.Inputs.handle_input()  # 模擬玩家點畫面
		await get_tree().create_timer(0.2).timeout
	_expect(Dialogic.current_event_idx == index_before, "暫停時點畫面，故事沒有往下走")

	(story.get_node("PauseMenu/%ResumeButton") as Button).pressed.emit()
	_expect(not menu_panel.visible and not Dialogic.paused, "按「繼續遊戲」關掉選單，解除暫停")
	for i: int in 3:
		Dialogic.Inputs.handle_input()
		await get_tree().create_timer(0.3).timeout
	_expect(Dialogic.current_event_idx != index_before, "解除暫停後點畫面，故事會往下走（對照組）")

	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(menu_panel.visible and Dialogic.paused, "按 Esc 也能打開選單")

	# 故事場景要等時間軸完全停止（timeline_ended 送出）之後才能離開場景樹，
	# 不然故事場景的 _on_timeline_ended 收到訊號時已經不在場景樹，拿不到 get_tree() 會報錯（社長試玩時遇過）
	var timeline_running_when_story_left: Array[bool] = []
	story.tree_exiting.connect(func() -> void: timeline_running_when_story_left.append(Dialogic.current_timeline != null), CONNECT_ONE_SHOT)
	(story.get_node("PauseMenu/%TitleButton") as Button).pressed.emit()
	_expect(await _wait_until(func() -> bool: return _current_scene_path() == TITLE_PATH), "按「回到標題」回到標題畫面")
	_expect(timeline_running_when_story_left == [false], "故事場景離開時，時間軸已經停完（不會報 get_tree() 的錯）")
	await get_tree().create_timer(0.3).timeout
	_expect(Dialogic.current_timeline == null, "時間軸已經停止")
	_expect(not Dialogic.paused, "已經解除暫停")


## 用真正的換場景流程跑：把標題畫面設成目前的場景，這個測試節點留在旁邊不會被換掉
func _test_full_flow() -> void:
	print("--- 標題 → 範例故事 → 回標題，跑兩輪 ---")
	var title: Control = TITLE_SCENE.instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	get_tree().current_scene = title

	var values: Array[Variant] = []
	for round_number: int in [1, 2]:
		var current_title: Node = get_tree().current_scene
		(current_title.get_node("%StartButton") as Button).pressed.emit()
		_expect(await _wait_until(func() -> bool: return _current_scene_path() == STORY_PATH), "第 %d 輪：按開始後換到故事場景" % round_number)
		_expect(await _wait_until(func() -> bool: return _current_scene_path() == TITLE_PATH), "第 %d 輪：故事播完回到標題畫面" % round_number)
		values.append(Dialogic.VAR.get_variable("好感度"))
		print("  第 %d 輪播完，好感度 = %s，玩家名字 = %s" % [round_number, values[-1], Dialogic.VAR.get_variable("玩家名字")])

	_expect(is_equal_approx(float(values[0]), float(values[1])), "第二輪的好感度跟第一輪一樣（變數有重設）")
	_expect(Dialogic.VAR.get_variable("玩家名字") == "測試", "輸入的名字有存進變數")


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


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
	Dialogic.Inputs.auto_skip.enabled = _auto_skip_after_input
