# AI Agents 協作指南 (AGENTS.md)

本文件旨在釐清本專案中 AI 開發助手 (Agents) 的作用範圍與參考依據，避免與其他文件重複。

## 核心配置與知識入口
- **全域開發指引**：請所有 Agent (包含 Cursor, Claude Desktop, Roo Code 等) 統一以 `CLAUDE.md` 作為**主記憶與專案入口**。專案結構、指令與環境變數等一律以 `CLAUDE.md` 為準，本文件不再重複定義。
- **詳細規則約束**：專案開發的細節規範，請依照 `.claude/rules/` 目錄下的文件進行。

## Agent 協作工作流程
1. **探索與理解階段**：每次啟動新任務或對話時，Agent 應優先讀取 `CLAUDE.md` 以及 `docs/FEATURES.md` 掌握專案全貌。
2. **設計與開發階段**：在實際撰寫程式碼時，必須嚴格遵守 `docs/DEVELOPMENT.md` 中關於「資料庫操作 (better-sqlite3 同步寫法)」、「錯誤處理」與「API 回應格式」的約定。
3. **驗證與測試階段**：功能開發或重構完成後，務必查閱 `docs/TESTING.md`，並主動執行 `npm test` 進行 Vitest + Supertest 的測試驗證。

## 為什麼需要這份文件？
過去 `AGENTS.md` 與 `CLAUDE.md` 內容高度重疊。為了維持「單一真實來源 (Single Source of Truth)」，現已將專案設定的細節統一收攏至 `CLAUDE.md` 與 `.claude/rules/`，而 `AGENTS.md` 則純粹做為不同 AI 助手在操作本專案時的「行為與流程導航」。
