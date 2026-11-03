class_name TutorialSteps
extends Resource
## 教學關 11 個步驟的文字。實際內容寫在 tutorial/data/tutorial_steps.tres。
##
## 想改文字：在 Godot 的檔案系統面板點兩下 tutorial_steps.tres，
## 在右邊的檢查器展開 Steps，點開每一步改 Title、Description、Hint。
## 步驟的順序和數量不要改，檢查邏輯是照這個順序對應的。

## 11 個步驟，順序：建立角色、建立時間軸、登場換表情、選項、匯流、換背景、背景音樂、試玩，
## 最後 3 個是額外題：變數＋條件、文字節奏、輸入名字
@export var steps: Array[TutorialStep] = []
