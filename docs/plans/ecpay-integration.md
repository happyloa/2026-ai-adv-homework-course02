# ECPay 綠界金流整合計畫

> 狀態：✅ 已完成  
> 完成日：2026-04-08  
> 歸檔位置：docs/plans/archive/ecpay-integration.md

## 目標

為花店電商後端新增 ECPay 全方位金流（AIO）付款功能，讓消費者可以在下單後前往綠界測試付款頁完成付款。

## 技術選型

- **協議**：AIO 全方位金流（CMV-SHA256）
- **環境**：測試環境（payment-stage.ecpay.com.tw）
- **測試帳號**：MerchantID=3002607

## 實作內容

### 1. ECPay 工具函式（src/utils/ecpay.js）

- `ecpayUrlEncode(str)` — ECPay 專用 URL encode（符合綠界規格）
- `generateCheckMacValue(params, hashKey, hashIV)` — SHA256 簽章計算
- `generateMerchantTradeNo()` — 唯一訂單編號（時間戳，≤20 字元）
- `buildPaymentForm(order, config)` — 組裝付款表單 HTML

### 2. 資料庫異動（src/database.js）

orders 資料表新增：
- `merchant_trade_no TEXT` — 綠界端訂單編號（付款時產生）
- `ecpay_trade_no TEXT` — 綠界端交易編號（notify 後回填）

### 3. 新增 API 路由（src/routes/orderRoutes.js）

- `POST /api/orders/:id/pay` — 產生 ECPay 付款表單 HTML
- `POST /api/ecpay/notify` — ReturnURL，接收付款結果，回傳 `1|OK`
- `GET /api/ecpay/result` — 付款結果頁（消費者前端跳轉）

### 4. app.js 新增路由

確認 `/api/ecpay/notify` 可接收 ECPay POST 回調。

## 驗證方式

1. 啟動伺服器：`npm run dev:server`
2. 登入取得 JWT
3. 建立訂單（含商品）
4. 呼叫 `POST /api/orders/:id/pay`
5. 瀏覽器自動跳轉到綠界測試付款頁
6. 使用測試信用卡完成付款
7. 至綠界測試商店後台確認訂單出現

## 測試帳號資訊

> ⚠️ 此為公開共用測試帳號，僅供開發測試

- MerchantID: 3002607
- HashKey: pwFHCqoQZGmho4w6
- HashIV: EkRm7iFT261dpevs
- 測試信用卡: 4311-9522-2222-2222，有效期任意，CVV 任意三碼
