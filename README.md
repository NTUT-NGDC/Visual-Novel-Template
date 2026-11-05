# Visual Novel Template

北科遊戲研究社「每週交流會」W1 Dialogic 主題課的模板專案。

用 Godot 和 Dialogic 做一個**有選項、有兩種結局**的短篇視覺小說，匯出網頁版，上傳到 itch.io 和大家互相試玩，**整堂課都不用寫程式。**

## 📖 學員手冊

**👉 [交流會學員手冊（Notion）](https://app.notion.com/p/2949b83c066846079f3a609f8808d513?source=copy_link)**

操作步驟、教學關的每一步、匯出上傳、常見問題都在手冊裡，上課時打開 W1 那一頁照著做就好。

## 需要準備

| 項目 | 版本 | 說明 |
| --- | --- | --- |
| Godot | **4.7.2**（標準版，非 .NET） | [下載頁面](https://godotengine.org/download/archive/4.7.2-stable/)。請用這個版本，其他版本可能打不開專案 |
| Godot 匯出模板 | 4.7.2 | 匯出網頁版需要，同一個下載頁面有，或在 Godot 裡「編輯器 → 管理匯出模板」下載 |
| Dialogic | 2.0 Alpha 20 | **專案裡已經裝好了，不用另外裝** |

> 上課時教室網路慢，Godot 和匯出模板會放在社課的 USB 裡。

## 取得專案

- **會用 git 的人**：fork 這個 repo，再 clone 到自己的電腦
- **其他人**：按上方綠色的 **Code → Download ZIP**，下載後解壓縮

接著打開 Godot，在專案管理員按「匯入（Import）」，選資料夾裡的 `project.godot`，再按「匯入並編輯」。第一次打開會花一點時間匯入圖片，等進度條跑完再開始。

## 快速開始

| 想做什麼 | 怎麼做 |
| --- | --- |
| 看範例遊戲 | 按 `F5`，從標題畫面按「開始遊戲」 |
| 沒靈感，抽一組題目 | 打開 `lesson/card_draw/card_draw.tscn`，按 `F6` |
| 跟著教學關做故事 | 打開 `lesson/tutorial/tutorial.tscn`，按 `F6` |

## 專案結構

| 資料夾 | 內容 | 要不要動 |
| --- | --- | --- |
| `my_story/` | **你自己的角色、時間軸、圖片、音樂、故事場景** | ✅ 你的東西全部放這裡 |
| `example/` | 範例角色、背景、範例故事 | 👀 參考用，不要改 |
| `game/` | 標題畫面、暫停選單、音量設定 | ⚙️ 只改標題畫面 |
| `lesson/` | 抽卡、教學關 | ▶️ 打開來用就好 |
| `_system/` | 字型、測試用的東西 | 不用管 |
| `addons/dialogic/` | Dialogic 本體 | ❌ 絕對不要動 |

## ⚠️ 一定要記得

- **不要按 Dialogic 的更新。** Dialogic 編輯器左下角的版本號變色、顯示「Update Available!」時也不要按。Dialogic 還在測試階段，更新後模板和教學關可能會壞掉
- **搬移、改名檔案一律在 Godot 的「檔案系統」面板裡做**，不要用檔案總管，不然 Dialogic 可能找不到角色和時間軸
- 改完記得 `Ctrl+S` 存檔

## 上傳作品

做好之後匯出網頁版，上傳到 itch.io，再提交到社團的 Jam：

**🎮 [115-1 北科遊戲研究社交流會作品集](https://itch.io/jam/ntut-ngdc-meetup-115-1)**
