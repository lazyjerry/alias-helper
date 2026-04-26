# alias-helper

互動式 Bash 精靈，用來管理 shell 設定檔中的 alias。

## 功能

- 讀取預設目標檔案 `~/.zshrc`
- 目標檔案不存在時，可互動建立
- 列出目前 alias
- 新增或更新 alias
- 修改既有 alias
- 刪除 alias
- 變更後嘗試重新載入目標檔案

## 使用方式

```bash
chmod +x alias-wizard.sh
./alias-wizard.sh
```

## 行為說明

- 預設寫入 `~/.zshrc`
- alias 名稱只允許英數、底線、點、減號
- 新增與更新共用同一個操作；若名稱已存在，會直接覆寫
- 重新載入會依檔名判斷使用 `zsh`、`bash` 或目前 shell

## 選單操作

1. 列出 alias
2. 新增或更新 alias
3. 修改既有 alias
4. 刪除 alias
5. 離開
New content line
