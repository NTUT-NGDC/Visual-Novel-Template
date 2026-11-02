extends Node
## 自動試玩測試：自動播完一條時間軸，遇到選項就選指定的那一個，
## 印出實際播到的台詞和最後的變數，用來確認每條路線都能跑到結局。
##
## 在命令列執行（-- 後面是參數，都可以省略）：
##   godot --headless --path . res://tests/auto_play_test.tscn -- timeline=res://example/example_story.dtl choice=2
## choice 是每次遇到選項時要選第幾個（從 1 開始，跟 Dialogic 選項按鈕的編號一樣）。

## 要播放的時間軸
@export_file("*.dtl") var timeline_path: String = "res://example/example_story.dtl"
## 遇到選項時選第幾個（從 1 開始）
@export var choice_index: int = 1
## 超過這個秒數還沒播完就當作失敗
@export var timeout_seconds: float = 30.0

## 是否還在等選項被選到
var _waiting_for_choice: bool = false


func _ready() -> void:
	_read_command_line_args()
	print("[自動試玩] 時間軸：", timeline_path, "，選項：", choice_index)

	# 自動略過：不用按鍵，台詞會自己一直往下播
	Dialogic.Inputs.auto_skip.enabled = true
	Dialogic.Inputs.auto_skip.disable_on_user_input = false
	Dialogic.Inputs.auto_skip.time_per_event = 0.01

	Dialogic.event_handled.connect(_on_event_handled)
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	get_tree().create_timer(timeout_seconds).timeout.connect(_on_timeout)

	Dialogic.start(timeline_path)


## 讀取命令列的 timeline=... choice=... 參數
func _read_command_line_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("timeline="):
			timeline_path = arg.trim_prefix("timeline=")
		elif arg.begins_with("choice="):
			choice_index = arg.trim_prefix("choice=").to_int()


## 每執行一個事件就印出來，方便看實際走了哪條路線
func _on_event_handled(event: DialogicEvent) -> void:
	if event is DialogicTextEvent:
		var text_event: DialogicTextEvent = event
		var speaker: String = text_event.character.display_name if text_event.character else "旁白"
		print("  %s：%s" % [speaker, text_event.text])
	elif event is DialogicChoiceEvent:
		pass  # 選項會在 _on_question_shown 統一處理
	else:
		print("  [%s] %s" % [event.event_name, event.to_text()])


## 選項剛出現時有一小段防誤觸時間（block_delay），這段時間內選了會被忽略，
## 所以每 0.2 秒重試一次，直到真的選到為止
func _on_question_shown(_info: Dictionary) -> void:
	print("  >> 選擇第 %d 個選項" % choice_index)
	_waiting_for_choice = true
	while _waiting_for_choice:
		Dialogic.Choices.select_choice(choice_index)
		await get_tree().create_timer(0.2).timeout


func _on_choice_selected(info: Dictionary) -> void:
	_waiting_for_choice = false
	print("  >> 選了：", info.get("text", ""))


func _on_timeline_ended() -> void:
	print("[自動試玩] 播放結束，好感度 = ", Dialogic.VAR.get_variable("好感度"))
	print("[自動試玩] PASS")
	get_tree().quit(0)


func _on_timeout() -> void:
	print("[自動試玩] FAIL：超過 %d 秒還沒播完" % int(timeout_seconds))
	get_tree().quit(1)
