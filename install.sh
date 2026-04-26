#!/usr/bin/env bash

set -u

REPO="lazyjerry/alias-helper"
BIN_DIR="${HOME}/.local/bin"
SCRIPT_NAME="alias-helper"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
  printf "${RED}✗ 錯誤：%s${NC}\n" "$1" >&2
}

print_success() {
  printf "${GREEN}✓ %s${NC}\n" "$1"
}

print_info() {
  printf "${YELLOW}ℹ %s${NC}\n" "$1"
}

# 檢查 gh CLI 是否可用
if ! command -v gh &>/dev/null; then
  print_error "gh CLI 未安裝，請先安裝 GitHub CLI"
  print_info "安裝指南: https://cli.github.com"
  exit 1
fi

# 檢查 gh 是否已登入
if ! gh auth status &>/dev/null; then
  print_error "gh CLI 未登入，請執行 'gh auth login'"
  exit 1
fi

# 獲取最新 release
latest_release=$(gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null)

if [[ -z "$latest_release" ]]; then
  print_error "找不到任何 release，請確認倉庫 $REPO 已發佈版本"
  exit 1
fi

print_info "發現最新版本: $latest_release"

# 建立 ~/.local/bin 目錄（如果不存在）
if [[ ! -d "$BIN_DIR" ]]; then
  print_info "建立目錄: $BIN_DIR"
  mkdir -p "$BIN_DIR"
fi

# 下載腳本
print_info "正在下載 $latest_release 版本..."
download_url="https://raw.githubusercontent.com/$REPO/$latest_release/alias-helper.sh"

if ! curl -fsSL "$download_url" -o "$BIN_DIR/$SCRIPT_NAME"; then
  print_error "下載失敗，請檢查網路連線"
  exit 1
fi

# 設置執行權限
chmod +x "$BIN_DIR/$SCRIPT_NAME"

# 檢查 ~/.local/bin 是否在 PATH 中
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  print_info "警告：$BIN_DIR 不在 PATH 中"
  print_info "請在 shell 設定檔（~/.zshrc 或 ~/.bashrc）中添加："
  printf "  export PATH=\"%s:\$PATH\"\n" "$BIN_DIR"
fi

print_success "安裝完成"
print_info "使用命令：$SCRIPT_NAME"
