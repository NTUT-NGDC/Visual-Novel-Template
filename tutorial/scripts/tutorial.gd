extends Control
## 教學關：列出 11 個步驟，按「檢查」檢查 my_story 資料夾裡的角色和時間軸有沒有做對。
##
## 第 1～7、9～11 步：讀檔檢查（邏輯在 story_checker.gd）。
## 第 8 步：按「試玩」實際播放時間軸，有播到結尾才算過。
## 第 9～11 步是額外題，不算在「已完成幾步」裡，另外計算。
## 步驟的文字在 tutorial/data/tutorial_steps.tres，要改文字改那裡就好。

const STEP_ROW_SCENE: PackedScene = preload("res://tutorial/step_row.tscn")
## 額外題在列表裡是第幾個（從 0 開始）
const EXTRA_STEP_INDEXES: Array[int] = [8, 9, 10]

## 要檢查的資料夾，社員的角色和時間軸放這裡
@export_dir var story_folder: String = "res://my_story"
## 步驟的文字。預設是 tutorial/data/tutorial_steps.tres
@export var steps: TutorialSteps

@onready var _main_panel: Control = %MainPanel
@onready var _progress_label: Label = %ProgressLabel
@onready var _check_button: Button = %CheckButton
@onready var _timeline_option: OptionButton = %TimelineOption
@onready var _play_button: Button = %PlayButton
@onready var _step_list: VBoxContainer = %StepList
@onready var _stop_layer: CanvasLayer = %StopLayer
@onready var _stop_button: Button = %StopButton

var _rows: Array[StepRow] = []
## 試玩選單裡每一項對應的時間軸路徑
var _timeline_paths: PackedStringArray = []
## 正在試玩中
var _playing: bool = false
## 這次試玩是按「結束試玩」中途停下的
var _stopped_by_user: bool = false
## 第 8 步（試玩）有沒有過、是哪條時間軸播完的
var _play_succeeded: bool = false
var _played_file: String = ""
## 正在試玩的時間軸檔名
var _playing_file: String = ""


func _ready() -> void:
	if steps == null:
		push_warning("教學關沒有設定步驟文字（steps），會顯示空白的步驟。")
		steps = TutorialSteps.new()
	for step: TutorialStep in steps.steps:
		var row: StepRow = STEP_ROW_SCENE.instantiate()
		_step_list.add_child(row)
		row.set_step(step if step != null else TutorialStep.new())
		_rows.append(row)

	_stop_layer.hide()
	_check_button.pressed.connect(run_checks)
	_play_button.pressed.connect(_on_play_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	run_checks()


## 重新檢查所有步驟，更新畫面
func run_checks() -> void:
	var checker := StoryChecker.new(story_folder)
	var play_message: String = _played_file if _play_succeeded else "還沒有試玩成功。"
	# 順序跟 tutorial_steps.tres 一樣：1～7 步、第 8 步試玩、第 9～11 步額外題
	var results: Array[StoryChecker.Result] = [
		checker.check_character(),
		checker.check_lines(),
		checker.check_join_and_portrait(),
		checker.check_choice(),
		checker.check_label_and_jump(),
		checker.check_background(),
		checker.check_music(),
		StoryChecker.Result.new(_play_succeeded, play_message),
		checker.check_variable_and_condition(),
		checker.check_text_rhythm(),
		checker.check_name_input(),
	]

	var done_count: int = 0
	var extra_done_count: int = 0
	for index: int in results.size():
		if index < _rows.size():
			_rows[index].show_result(results[index].passed, results[index].message)
		if not results[index].passed:
			continue
		if index in EXTRA_STEP_INDEXES:
			extra_done_count += 1
		else:
			done_count += 1
	var required_count: int = results.size() - EXTRA_STEP_INDEXES.size()
	_progress_label.text = "已完成 %d／%d 步　額外：%d／%d" % [done_count, required_count, extra_done_count, EXTRA_STEP_INDEXES.size()]

	_refresh_timeline_option(checker.get_timeline_paths())


## 更新試玩選單：列出 my_story 裡的時間軸，盡量保留原本選的那一條
func _refresh_timeline_option(paths: PackedStringArray) -> void:
	var previous: String = ""
	if _timeline_option.selected >= 0 and _timeline_option.selected < _timeline_paths.size():
		previous = _timeline_paths[_timeline_option.selected]

	_timeline_paths = paths
	_timeline_option.clear()
	if paths.is_empty():
		_timeline_option.add_item("（還沒有時間軸）")
		_timeline_option.disabled = true
		_play_button.disabled = true
		return

	_timeline_option.disabled = false
	_play_button.disabled = false
	for path: String in paths:
		_timeline_option.add_item(path.trim_prefix(story_folder.trim_suffix("/") + "/"))
	var previous_index: int = paths.find(previous)
	_timeline_option.select(previous_index if previous_index >= 0 else 0)


func _exit_tree() -> void:
	# 試玩的時間軸用了找不到的角色時，Dialogic 會臨時建立角色，留到遊戲結束會當掉。
	# 離開教學關（包括試玩到一半就關掉視窗）時清掉
	StoryChecker.forget_temporary_characters()


func _on_play_pressed() -> void:
	var index: int = _timeline_option.selected
	if index < 0 or index >= _timeline_paths.size():
		return
	var path: String = _timeline_paths[index]
	if not FileAccess.file_exists(path):
		run_checks()
		return

	# 直接讀檔案內容，不用 load()：load() 會拿到快取裡的舊版本，社員改完時間軸再試玩會看不到變化
	var timeline := DialogicTimeline.new()
	timeline.from_text(FileAccess.get_file_as_string(path))

	_playing = true
	_stopped_by_user = false
	_main_panel.hide()
	_stop_layer.show()
	_playing_file = path.get_file()
	# 每次試玩都從變數的初始值開始
	Dialogic.VAR.reset()
	Dialogic.start(timeline)


func _on_stop_pressed() -> void:
	_stopped_by_user = true
	Dialogic.end_timeline(true)


func _on_timeline_ended() -> void:
	if not _playing:
		return
	_playing = false
	_stop_layer.hide()
	_main_panel.show()
	if not _stopped_by_user:
		_play_succeeded = true
		_played_file = _playing_file
	run_checks()
