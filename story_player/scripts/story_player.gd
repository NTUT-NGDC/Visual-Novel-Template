extends Node
## 播放場景：執行時直接播放一條時間軸，播完顯示「結束」畫面，可以重玩。
##
## 想播自己的故事：點選場景最上層的 StoryPlayer 節點，
## 在右邊的檢查器把「Timeline Path」改成自己的時間軸（.dtl）。
## 匯出 Web 版時，要把這個場景設成主場景。

## 要播放的時間軸。預設是 my_story 資料夾裡的 my_story.dtl
@export_file("*.dtl") var timeline_path: String = "res://my_story/timelines/my_story.dtl"

## 找不到時間軸時顯示提示的面板
@onready var _message_panel: Control = %MessagePanel
@onready var _message_label: Label = %MessageLabel
## 故事播完後的結束畫面
@onready var _end_panel: Control = %EndPanel
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	_message_panel.hide()
	_end_panel.hide()
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	_replay_button.pressed.connect(_on_replay_pressed)
	_play()


## 檢查時間軸，沒問題就開始播放；有問題就顯示中文提示
func _play() -> void:
	var problem: String = _check_timeline()
	if problem != "":
		_message_label.text = problem
		_message_panel.show()
		return

	_end_panel.hide()
	Dialogic.start(timeline_path)


## 回傳空字串代表時間軸沒問題，否則回傳要顯示給社員看的說明
func _check_timeline() -> String:
	if timeline_path == "":
		return "還沒有指定要播放的時間軸。\n\n請點選 StoryPlayer 節點，在檢查器的「Timeline Path」選擇你的時間軸（.dtl）。"

	# 在檢查器選檔案時，路徑可能會存成 uid://… 的格式，這裡轉回一般路徑方便閱讀
	var readable_path: String = timeline_path
	if timeline_path.begins_with("uid://"):
		readable_path = ResourceUID.ensure_path(timeline_path)

	if not ResourceLoader.exists(timeline_path):
		return "找不到時間軸：\n%s\n\n請確認：\n・已經用 Dialogic 建立了這個時間軸\n・或是點選 StoryPlayer 節點，在檢查器的「Timeline Path」改成你的時間軸" % readable_path

	if not load(timeline_path) is DialogicTimeline:
		return "這個檔案不是時間軸：\n%s\n\n「Timeline Path」要選 .dtl 結尾的時間軸檔，不是角色檔（.dch）或其他檔案。" % readable_path

	return ""


func _on_timeline_ended() -> void:
	_end_panel.show()


func _on_replay_pressed() -> void:
	# Dialogic 重新播放時不會把變數重設回初始值，
	# 不重設的話「好感度」這類變數會接著上一輪繼續加，可能走到錯的結局
	Dialogic.VAR.reset()
	_play()
