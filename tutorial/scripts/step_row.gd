class_name StepRow
extends PanelContainer
## 教學關列表裡的一個步驟：標題、狀態、說明、提示、檢查結果。
## 沒過是深色，過了變綠色（跟 115-1 工作坊練習關的告示牌一樣）。

const TODO_COLOR: Color = Color(0.25, 0.2, 0.15, 0.85)
const DONE_COLOR: Color = Color(0.15, 0.45, 0.2, 0.9)
const FAIL_TEXT_COLOR: Color = Color(1, 0.65, 0.55)
const PASS_TEXT_COLOR: Color = Color(0.75, 1, 0.75)

@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _hint_label: Label = %HintLabel
@onready var _message_label: Label = %MessageLabel

var _style: StyleBoxFlat


func _ready() -> void:
	# 每一列要能各自變色，所以複製一份自己的底色樣式
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)


## 填入步驟文字
func set_step(step: TutorialStep) -> void:
	_title_label.text = step.title
	_description_label.text = step.description
	_hint_label.text = "提示：" + step.hint


## 顯示檢查結果。passed 是有沒有過；message 沒過時是原因，過了時是哪個檔案過關
func show_result(passed: bool, message: String) -> void:
	_style.bg_color = DONE_COLOR if passed else TODO_COLOR
	_status_label.text = "完成！" if passed else "未完成"
	_message_label.text = ("通過：" if passed else "還差一點：") + message
	_message_label.add_theme_color_override("font_color", PASS_TEXT_COLOR if passed else FAIL_TEXT_COLOR)
