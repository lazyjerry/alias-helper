#!/usr/bin/env bash

set -u

VERSION="1.0.0"
target_file="$HOME/.zshrc"

ALIAS_NAMES=()
ALIAS_VALUES=()

confirm_yes() {
  local prompt="$1"
  local answer
  read -r -p "$prompt" answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

expand_path() {
  local path="$1"
  if [[ "$path" == ~* ]]; then
    path="$HOME${path:1}"
  fi
  printf '%s\n' "$path"
}

ensure_target_file() {
  if [[ -f "$target_file" ]]; then
    return
  fi

  printf '目標檔案不存在：%s\n' "$target_file"
  if confirm_yes '是否建立此檔案？(y/N): '; then
    mkdir -p "$(dirname "$target_file")"
    touch "$target_file"
    printf '已建立：%s\n' "$target_file"
  else
    printf '已取消操作。\n'
  fi
}

load_aliases() {
  ALIAS_NAMES=()
  ALIAS_VALUES=()

  if [[ ! -f "$target_file" ]]; then
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]*alias[[:space:]]+([A-Za-z0-9_.-]+)= ]]; then
      local name="${BASH_REMATCH[1]}"
      local rhs="${line#*=}"

      if [[ "$rhs" == \"*\" && "$rhs" == *\" ]]; then
        rhs="${rhs:1:${#rhs}-2}"
      elif [[ "$rhs" == \'.*\' ]]; then
        rhs="${rhs:1:${#rhs}-2}"
      fi

      ALIAS_NAMES+=("$name")
      ALIAS_VALUES+=("$rhs")
    fi
  done < "$target_file"
}

print_aliases() {
  load_aliases
  if [[ ${#ALIAS_NAMES[@]} -eq 0 ]]; then
    printf '目前找不到 alias。\n'
    return 1
  fi

  printf '目前 alias（檔案：%s）：\n' "$target_file"
  local i
  for (( i=0; i<${#ALIAS_NAMES[@]}; i++ )); do
    printf '%d) %s -> %s\n' "$((i + 1))" "${ALIAS_NAMES[$i]}" "${ALIAS_VALUES[$i]}"
  done
  return 0
}

escape_single_quotes() {
  local raw="$1"
  printf "%s" "${raw//\'/\'\\\'\'}"
}

replace_alias_by_name() {
  local name="$1"
  local new_line="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  awk -v n="$name" -v new_line="$new_line" '
    BEGIN {
      replaced = 0
      pattern = "^[[:space:]]*alias[[:space:]]+" n "="
    }
    {
      if (!replaced && $0 ~ pattern) {
        print new_line
        replaced = 1
        next
      }
      print
    }
    END {
      if (!replaced) {
        print new_line
      }
    }
  ' "$target_file" > "$tmp_file"

  mv "$tmp_file" "$target_file"
}

delete_alias_by_name() {
  local name="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  awk -v n="$name" '
    BEGIN {
      deleted = 0
      pattern = "^[[:space:]]*alias[[:space:]]+" n "="
    }
    {
      if (!deleted && $0 ~ pattern) {
        deleted = 1
        next
      }
      print
    }
  ' "$target_file" > "$tmp_file"

  mv "$tmp_file" "$target_file"
}

reload_target_file() {
  local base_name
  base_name="$(basename "$target_file")"

  # 先做語法檢查，避免寫入後造成 RC 檔案損壞
  if [[ "$base_name" == ".zshrc" ]] || [[ "$target_file" == *.zsh ]]; then
    zsh -n "$target_file" >/dev/null 2>&1 || {
      printf '重新載入失敗（語法錯誤）：%s\n' "$target_file"
      return 1
    }

    # 僅在「本腳本被 source 進目前 shell」時，才能直接影響使用者當前 session
    if [[ "${BASH_SOURCE[0]}" != "$0" ]] && source "$target_file"; then
      printf '已在目前 shell 套用：%s\n' "$target_file"
      return 0
    fi

    printf '\n✓ 已新增\n'
    printf '\n無法直接套用到你目前的 shell，請手動執行：\n'
    printf '  \033[36m%s\033[0m\n\n' "source $target_file"
    return 0
  fi

  if [[ "$base_name" == ".bashrc" ]] || [[ "$base_name" == ".bash_profile" ]] || [[ "$target_file" == *.bash ]]; then
    bash -n "$target_file" >/dev/null 2>&1 || {
      printf '重新載入失敗（語法錯誤）：%s\n' "$target_file"
      return 1
    }

    if [[ "${BASH_SOURCE[0]}" != "$0" ]] && source "$target_file"; then
      printf '已在目前 shell 套用：%s\n' "$target_file"
      return 0
    fi

    printf '\n✓ 已新增\n'
    printf '\n無法直接套用到你目前的 shell，請手動執行：\n'
    printf '  \033[36m%s\033[0m\n\n' "source $target_file"
    return 0
  fi

  printf '✓ 已新增至設定檔\n'
  return 0
}

warn_if_special_alias_name() {
  local name="$1"
  case "$name" in
    test|\[|\[\]|alias|unalias|source|cd|pwd|exit)
      printf '警告：%s 可能與 shell 內建指令衝突。\n' "$name"
      if ! confirm_yes '仍要繼續嗎？(y/N): '; then
        printf '已取消操作。\n'
        return 1
      fi
      ;;
  esac
  return 0
}

validate_alias_command() {
  local alias_name="$1"
  local command="$2"
  local head base_name

  if [[ -z "$command" ]]; then
    printf '指令內容不可為空。\n'
    return 1
  fi

  head="${command%%[[:space:]]*}"
  if [[ -z "$head" ]]; then
    printf '指令內容不可為空。\n'
    return 1
  fi

  if [[ "$head" == "$alias_name" ]]; then
    printf '偵測到 alias 可能自我呼叫（%s）。\n' "$alias_name"
    return 1
  fi

  if [[ "$head" == /* ]] || [[ "$head" == ./* ]] || [[ "$head" == ../* ]] || [[ "$head" == ~/* ]]; then
    return 0
  fi

  base_name="$(basename "$target_file")"
  if [[ "$base_name" == ".zshrc" ]] || [[ "$target_file" == *.zsh ]]; then
    if ! zsh -ic "whence -w -- '$head' >/dev/null 2>&1"; then
      printf '警告：找不到命令或 alias：%s\n' "$head"
      if ! confirm_yes '仍要繼續寫入嗎？(y/N): '; then
        printf '已取消操作。\n'
        return 1
      fi
    fi
    return 0
  fi

  if [[ "$base_name" == ".bashrc" ]] || [[ "$base_name" == ".bash_profile" ]] || [[ "$target_file" == *.bash ]]; then
    if ! bash -ic "type '$head' >/dev/null 2>&1"; then
      printf '警告：找不到命令或 alias：%s\n' "$head"
      if ! confirm_yes '仍要繼續寫入嗎？(y/N): '; then
        printf '已取消操作。\n'
        return 1
      fi
    fi
  fi

  return 0
}

add_or_update_alias() {
  ensure_target_file
  [[ -f "$target_file" ]] || return

  local name command escaped alias_line
  read -r -p '輸入 alias 名稱（例如 ll）: ' name
  if [[ -z "$name" ]]; then
    printf '名稱不可為空。\n'
    return
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    printf '名稱格式錯誤，只允許英數、底線、點、減號。\n'
    return
  fi

  warn_if_special_alias_name "$name" || return

  read -r -p '輸入 alias 指令內容（例如 ls -lah）: ' command
  validate_alias_command "$name" "$command" || return

  local backup_file
  backup_file="$(mktemp)"
  cp "$target_file" "$backup_file"

  escaped="$(escape_single_quotes "$command")"
  alias_line="alias ${name}='${escaped}'"

  replace_alias_by_name "$name" "$alias_line"
  printf '已新增或更新 alias：%s\n' "$name"
  if ! reload_target_file; then
    cp "$backup_file" "$target_file"
    printf '已還原變更，請檢查檔案語法後再重試。\n'
    rm -f "$backup_file"
    return
  fi

  rm -f "$backup_file"
}

modify_alias() {
  ensure_target_file
  [[ -f "$target_file" ]] || return

  print_aliases || return

  local index name command escaped alias_line
  read -r -p '選擇要修改的編號: ' index
  if [[ ! "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > ${#ALIAS_NAMES[@]} )); then
    printf '編號無效。\n'
    return
  fi

  name="${ALIAS_NAMES[$((index - 1))]}"
  read -r -p "輸入新的指令內容（${name}）: " command
  validate_alias_command "$name" "$command" || return

  local backup_file
  backup_file="$(mktemp)"
  cp "$target_file" "$backup_file"

  escaped="$(escape_single_quotes "$command")"
  alias_line="alias ${name}='${escaped}'"

  replace_alias_by_name "$name" "$alias_line"
  printf '已修改 alias：%s\n' "$name"
  if ! reload_target_file; then
    cp "$backup_file" "$target_file"
    printf '已還原變更，請檢查檔案語法後再重試。\n'
    rm -f "$backup_file"
    return
  fi

  rm -f "$backup_file"
}

remove_alias() {
  ensure_target_file
  [[ -f "$target_file" ]] || return

  print_aliases || return

  local index name
  read -r -p '選擇要刪除的編號: ' index
  if [[ ! "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > ${#ALIAS_NAMES[@]} )); then
    printf '編號無效。\n'
    return
  fi

  name="${ALIAS_NAMES[$((index - 1))]}"
  if ! confirm_yes "確認刪除 alias ${name}？(y/N): "; then
    printf '已取消刪除。\n'
    return
  fi

  local backup_file
  backup_file="$(mktemp)"
  cp "$target_file" "$backup_file"

  delete_alias_by_name "$name"
  printf '已刪除 alias：%s\n' "$name"
  if ! reload_target_file; then
    cp "$backup_file" "$target_file"
    printf '已還原變更，請檢查檔案語法後再重試。\n'
    rm -f "$backup_file"
    return
  fi

  rm -f "$backup_file"
}

show_menu() {
  printf '\nAlias 指令精靈 v%s\n' "$VERSION"
  printf '目前目標檔案：%s\n' "$target_file"
  printf '1) 列出 alias\n'
  printf '2) 新增或更新 alias\n'
  printf '3) 修改既有 alias\n'
  printf '4) 刪除 alias\n'
  printf '5) 離開\n'
}

main() {
  while true; do
    show_menu
    read -r -p '請選擇操作（1-5）: ' choice

    if [[ -z "$choice" ]]; then
      printf '已離開。\n'
      break
    fi

    case "$choice" in
      1)
        printf '執行動作：列出 alias\n'
        sleep 0.4
        ensure_target_file
        print_aliases
        ;;
      2)
        printf '執行動作：新增或更新 alias\n'
        sleep 0.4
        add_or_update_alias
        ;;
      3)
        printf '執行動作：修改既有 alias\n'
        sleep 0.4
        modify_alias
        ;;
      4)
        printf '執行動作：刪除 alias\n'
        sleep 0.4
        remove_alias
        ;;
      5)
        printf '已離開。\n'
        break
        ;;
      *)
        printf '無效選項，請輸入 1-5。\n'
        ;;
    esac
  done
}

main