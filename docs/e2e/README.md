# E2E 綠界付款測試

## 執行方式

```powershell
npm test
npm run test:e2e
```

測試會以隔離的記憶體 SQLite 資料庫啟動本機伺服器，並使用本機 Chrome 執行 `tests/e2e/payment-flow.spec.js`。

| 驗證項目 | 自動化結果 |
| --- | --- |
| 商品頁加入購物袋 | ✅ |
| 訪客購物袋在註冊後合併 | ✅ |
| 結帳必填欄位錯誤 | ✅ |
| 建立待付款訂單 | ✅ |
| 綠界表單含 MerchantTradeNo 與 CheckMacValue | ✅ |
| 有效簽章回呼更新為 paid | ✅ |
| 付款完成頁 | ✅ |
| 未簽章 GET 不得偽造付款成功 | ✅ |

> 自動化測試使用受控的綠界頁面攔截與有效簽章回呼，因此不會建立外部測試交易。真正綠界測試環境與後台訂單的錄影，請依 [錄影清單](./recording-checklist.md) 執行。

## 重要檔案

- `playwright.config.cjs`：Chrome、報表與失敗 artefact 設定。
- `scripts/run-e2e.cjs`：在 Windows 上可靠啟動與關閉隔離測試伺服器。
- `tests/e2e/payment-flow.spec.js`：正常流程＋欄位驗證 E2E。
- `tests/ecpay.test.js`：簽章回呼與未簽章結果頁安全性測試。

## 失敗時查看資料

Playwright 會在 `test-results/` 留下失敗截圖、trace 與影片；此資料夾已排除於 Git。HTML 報表在 `playwright-report/`，同樣不會提交。
