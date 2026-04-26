# alias-helper

互動式 Bash 精靈，用來管理 shell 設定檔中的 alias。

## 功能

- 讀取預設目標檔案 `~/.zshrc`
- 目標檔案不存在時，可互動建立
- 列出目前 alias
- 新增或更新 alias
- 修改既有 alias
- 刪除 alias
- 變更前自動備份，若語法檢查失敗會自動還原
- 新增/修改時檢查指令內容（空值、自我呼叫、命令不存在警告）
- 特殊 alias 名稱（如 `cd`、`source`）會先警告
- 變更後嘗試重新載入目標檔案

## 使用方式

```bash
chmod +x alias-helper.sh
./alias-helper.sh
```

## 行為說明

- 預設寫入 `~/.zshrc`
- alias 名稱只允許英數、底線、點、減號
- 新增與更新共用同一個操作；若名稱已存在，會直接覆寫
- 重新載入前會先做語法檢查（`zsh -n` / `bash -n`）
- 若腳本不是以 `source` 方式執行，無法直接影響目前 shell，會提示手動執行 `source ~/.zshrc`
- 主選單輸入空白直接離開

## 選單操作

1. 列出 alias
2. 新增或更新 alias
3. 修改既有 alias
4. 刪除 alias
5. 離開
