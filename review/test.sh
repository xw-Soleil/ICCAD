#!/usr/bin/env bash

# =========================
# CLI Drill v2: 数据驱动版本
# =========================

# 必须在交互模式下运行以启用 readline
if [[ $- != *i* ]]; then
  exec bash -i "$0" "$@"
fi

set -euo pipefail

# ---------- 配置 ----------
KEEP=0
MODE="menu"
WORKROOT="${XDG_STATE_HOME:-$HOME/.local/state}/cli-drill"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXERCISES_CONF="$SCRIPT_DIR/exercises.conf"
CURRENT_SUBDIR="."  # 当前练习的工作子目录（用于 Tab 补全）

# ---------- 颜色和样式（降级友好）----------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1; then
  BOLD=$(tput bold 2>/dev/null || echo '')
  RESET=$(tput sgr0 2>/dev/null || echo '')
  GREEN=$(tput setaf 2 2>/dev/null || echo '')
  YELLOW=$(tput setaf 3 2>/dev/null || echo '')
  RED=$(tput setaf 1 2>/dev/null || echo '')
  BLUE=$(tput setaf 4 2>/dev/null || echo '')
else
  BOLD='' RESET='' GREEN='' YELLOW='' RED='' BLUE=''
fi

# ---------- gum 检测 ----------
USE_GUM=0
if command -v gum >/dev/null 2>&1; then
  USE_GUM=1
fi

# ---------- Readline 配置（Tab 补全等）----------
# 只在非 gum 模式下配置（gum 有自己的输入处理）
if [[ $USE_GUM -eq 0 ]]; then
  # 启用文件名补全
  bind 'set show-all-if-ambiguous on' 2>/dev/null || true
  bind 'set completion-ignore-case on' 2>/dev/null || true
  bind 'TAB:complete' 2>/dev/null || true

  # 加载系统补全（如果可用）
  if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck disable=SC1091
    source /usr/share/bash-completion/bash_completion 2>/dev/null || true
  elif [[ -r /etc/bash_completion ]]; then
    # shellcheck disable=SC1091
    source /etc/bash_completion 2>/dev/null || true
  fi

  # 自定义补全：在用户当前工作子目录下补全
  _drill_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local workdir="$WORKDIR/${CURRENT_SUBDIR:-.}"

    # 如果在工作目录，提供文件补全
    if [[ -d "$workdir" ]]; then
      COMPREPLY=( $(cd "$workdir" 2>/dev/null && compgen -f -- "$cur") )
    fi
  }
fi

# ---------- 参数解析 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --all) MODE="all"; shift ;;
    --quick) MODE="quick"; shift ;;
    --tag) TAG_FILTER="$2"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
用法：
  ./review-new.sh              # 菜单模式
  ./review-new.sh --all        # 运行所有练习
  ./review-new.sh --quick      # 快速模式（基础题）
  ./review-new.sh --tag basic  # 只运行特定标签的题
  ./review-new.sh --keep       # 保留沙盒目录

提示：安装 gum (https://github.com/charmbracelet/gum) 获得更好的交互体验
EOF
      exit 0
      ;;
    *) echo "未知选项: $1"; exit 1 ;;
  esac
done

# ---------- 工作目录设置 ----------
mkdir -p "$WORKROOT"
SESSION_DATE="$(date +%F)"
WORKDIR="$WORKROOT/$SESSION_DATE"
if [[ -e "$WORKDIR" ]]; then
  WORKDIR="$(mktemp -d "$WORKROOT/$SESSION_DATE.XXXX")"
else
  mkdir -p "$WORKDIR"
fi

cleanup() {
  if [[ "$KEEP" -eq 0 ]]; then
    rm -rf "$WORKDIR" >/dev/null 2>&1 || true
  else
    echo "${BLUE}🧰 练习目录已保留: $WORKDIR${RESET}"
  fi
}
trap cleanup EXIT

# ---------- 工具函数 ----------
has() { command -v "$1" >/dev/null 2>&1; }

say() { printf "%b\n" "$*"; }
hr() { say "${BOLD}────────────────────────────────────────────────────────────${RESET}"; }

pause_any() {
  if [[ $USE_GUM -eq 1 ]]; then
    gum confirm "继续？" --affirmative "是" --negative "否" || true
  else
    read -r -p "按 Enter 继续... " _ </dev/tty
  fi
}

# 兼容 Linux/macOS 的 stat
inode_of() {
  local p="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c '%i' "$p" 2>/dev/null
  else
    stat -f '%i' "$p" 2>/dev/null || ls -i "$p" | awk '{print $1}'
  fi
}

nlink_of() {
  local p="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c '%h' "$p" 2>/dev/null
  else
    stat -f '%l' "$p" 2>/dev/null || ls -l "$p" | awk '{print $2}'
  fi
}

normalize_paths() {
  sed -e "s|^$WORKDIR/||" -e 's|^\./||'
}

ensure_dir() { mkdir -p "$WORKDIR/$1"; }

run_user_cmd() {
  local cmd="$1"
  local subdir="${2:-.}"
  ( cd "$WORKDIR/$subdir" && bash --noprofile --norc -c "$cmd" )
}

# ---------- 沙盒环境设置 ----------
setup_sandbox() {
  ensure_dir "links"
  ensure_dir "data"
  ensure_dir "logs"
  ensure_dir "docs"
  ensure_dir "results"

  # links
  cat >"$WORKDIR/links/origin.txt" <<'EOF'
hello link world
EOF

  # data
  cat >"$WORKDIR/data/alpha.txt" <<'EOF'
alpha one
alpha two
EOF

  cat >"$WORKDIR/data/beta.txt" <<'EOF'
beta one
beta two
EOF

  cat >"$WORKDIR/data/colon.txt" <<'EOF'
id:1001:alice
id:1002:bob
id:1003:carol
EOF

  printf "col1\tcol2\tcol3\nA\tB\tC\n" >"$WORKDIR/data/tabbed.txt"

  cat >"$WORKDIR/data/numbers.txt" <<'EOF'
10
2
2
1
20
3
EOF

  head -c 15000 /dev/zero >"$WORKDIR/data/big.txt" 2>/dev/null || \
    dd if=/dev/zero of="$WORKDIR/data/big.txt" bs=1 count=15000 >/dev/null 2>&1

  # logs
  cat >"$WORKDIR/logs/app.log" <<'EOF'
[INFO]  start
[WARN]  low memory
[ERROR] disk error detected
[info]  retrying
[Error] network error
[OK]    done
EOF

  cat >"$WORKDIR/logs/sys.LOG" <<'EOF'
boot ok
ERROR: something bad
EOF

  # docs
  cat >"$WORKDIR/docs/v1.txt" <<'EOF'
line1
line2
line3
EOF
  cat >"$WORKDIR/docs/v2.txt" <<'EOF'
line1
line2 changed
line3
line4 new
EOF

  # fake PNG
  if has base64; then
    base64 -d >"$WORKDIR/data/fake.txt" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7WZ0cAAAAASUVORK5CYII=
EOF
  else
    printf '\x89PNG\r\n\x1a\n' >"$WORKDIR/data/fake.txt"
  fi

  touch "$WORKDIR/data/ref.timestamp"
  sleep 1
  echo "newer than ref" >"$WORKDIR/data/newer.txt"
}

# ---------- 统一检查器 ----------
file_exists() { [[ -f "$WORKDIR/$1" ]]; }
link_exists() { [[ -L "$WORKDIR/$1" ]]; }
path_exists() { [[ -e "$WORKDIR/$1" ]]; }
nonempty() { [[ -s "$WORKDIR/$1" ]]; }

contains() {
  local file="$WORKDIR/$1"
  local pat="$2"
  grep -qE "$pat" "$file" 2>/dev/null
}

not_contains() {
  local file="$WORKDIR/$1"
  local pat="$2"
  ! grep -qE "$pat" "$file" 2>/dev/null
}

same_content() {
  local a="$WORKDIR/$1"
  local b="$WORKDIR/$2"
  cmp -s "$a" "$b"
}

exact_content() {
  local file="$WORKDIR/$1"
  local expected="$2"
  printf "%s" "$expected" | diff -q "$file" - >/dev/null 2>&1
}

not_exists() {
  ! path_exists "$1"
}

no_tabs() {
  local file="$WORKDIR/$1"
  ! grep -q $'\t' "$file"
}

gzip_valid() {
  local gz_file="$WORKDIR/$1"
  local orig_file="$WORKDIR/$2"
  file_exists "${gz_file#$WORKDIR/}" && file_exists "${orig_file#$WORKDIR/}" && \
  has gzip && gzip -t "$gz_file" >/dev/null 2>&1
}

hardlink() {
  local file1="$WORKDIR/$1"
  local file2="$WORKDIR/$2"
  path_exists "${file1#$WORKDIR/}" && path_exists "${file2#$WORKDIR/}" && \
  [[ "$(inode_of "$file1")" == "$(inode_of "$file2")" ]] && \
  [[ "$(nlink_of "$file1")" -ge 2 ]]
}

symlink() {
  local link="$WORKDIR/$1"
  local target_path="$WORKDIR/$2"
  link_exists "${link#$WORKDIR/}" || return 1
  local resolved
  resolved="$(cd "$(dirname "$link")" && readlink -f "$(basename "$link")" 2>/dev/null || true)"
  [[ "$resolved" == "$target_path" ]]
}

find_result() {
  local result_file="$WORKDIR/$1"
  file_exists "${result_file#$WORKDIR/}" || return 1

  local tmp_exp tmp_got
  tmp_exp="$(mktemp)"
  tmp_got="$(mktemp)"

  ( cd "$WORKDIR" && find . -type f -name '*.txt' ) | normalize_paths | sort -u >"$tmp_exp"
  normalize_paths <"$result_file" | sort -u >"$tmp_got"

  diff -q "$tmp_exp" "$tmp_got" >/dev/null 2>&1
  local ok=$?
  rm -f "$tmp_exp" "$tmp_got"
  [[ $ok -eq 0 ]]
}

# 通用检查器调度
run_checker() {
  local checker_type="$1"
  local checker_args="$2"

  case "$checker_type" in
    file_exists)
      IFS=':' read -r f1 f2 <<< "$checker_args"
      file_exists "$f1" && { [[ -z "$f2" ]] || file_exists "$f2"; }
      ;;
    not_exists)
      not_exists "$checker_args"
      ;;
    hardlink)
      IFS=':' read -r f1 f2 <<< "$checker_args"
      hardlink "$f1" "$f2"
      ;;
    symlink)
      IFS=':' read -r link target <<< "$checker_args"
      symlink "$link" "$target"
      ;;
    contains)
      IFS=':' read -r file patterns <<< "$checker_args"
      IFS=',' read -ra PATS <<< "$patterns"
      local ok=0
      for pat in "${PATS[@]}"; do
        contains "$file" "$pat" || { ok=1; break; }
      done
      [[ $ok -eq 0 ]]
      ;;
    not_contains)
      IFS=':' read -r file pattern <<< "$checker_args"
      not_contains "$file" "$pattern"
      ;;
    same_content)
      IFS=':' read -r f1 f2 <<< "$checker_args"
      same_content "$f1" "$f2"
      ;;
    exact_content)
      IFS=':' read -r file expected <<< "$checker_args"
      exact_content "$file" "$expected"
      ;;
    nonempty)
      nonempty "$checker_args"
      ;;
    no_tabs)
      no_tabs "$checker_args"
      ;;
    gzip_valid)
      IFS=':' read -r gz orig <<< "$checker_args"
      gzip_valid "$gz" "$orig"
      ;;
    find_result)
      find_result "$checker_args"
      ;;
    *)
      say "${RED}未知检查器类型: $checker_type${RESET}"
      return 1
      ;;
  esac
}

# ---------- 练习循环 ----------
exercise_loop() {
  local id="$1" title="$2" goal="$3" hint="$4" solution="$5"
  local checker_type="$6" checker_args="$7" subdir="${8:-.}"

  # 设置当前子目录（用于 Tab 补全上下文）
  CURRENT_SUBDIR="$subdir"

  hr
  say "${BOLD}${BLUE}🧩 $title${RESET}"
  say "${BOLD}🎯 目标:${RESET} $goal"
  say "${BOLD}📁 目录:${RESET} $WORKDIR/$subdir"

  if [[ $USE_GUM -eq 1 ]]; then
    say "${YELLOW}提示: 输入命令，或选择 h=提示 s=答案 sh=shell q=退出${RESET}"
  else
    say "${YELLOW}提示: h=提示 s=答案 sh=进入shell(有完整Tab补全) q=退出${RESET}"
    say "${BLUE}💡 可用 Tab 补全文件名，↑↓ 浏览历史${RESET}"
  fi

  while true; do
    local cmd
    if [[ $USE_GUM -eq 1 ]]; then
      cmd=$(gum input --placeholder "输入命令..." --prompt "drill> " || echo "q")
    else
      read -r -e -p "drill> " cmd </dev/tty || exit 0
    fi

    case "$cmd" in
      quit|exit|q)
        exit 0
        ;;
      hint|h)
        if [[ $USE_GUM -eq 1 ]]; then
          gum style --border rounded --padding "1 2" --border-foreground 214 "💡 提示: $hint"
        else
          say "${YELLOW}💡 提示: $hint${RESET}"
        fi
        continue
        ;;
      solution|s)
        if [[ $USE_GUM -eq 1 ]]; then
          gum style --border rounded --padding "1 2" --border-foreground 82 "✅ 参考答案: $solution"
        else
          say "${GREEN}✅ 参考答案: $solution${RESET}"
        fi
        continue
        ;;
      shell|sh)
        say "${BLUE}进入子 shell（目录：$WORKDIR/$subdir）。退出请输 exit / Ctrl-D${RESET}"
        ( cd "$WORKDIR/$subdir" && bash --noprofile --norc )
        continue
        ;;
      skip|sk)
        say "${YELLOW}⏭️  已跳过${RESET}"
        return 2
        ;;
      quit|exit|q)
        exit 0
        ;;
      "")
        continue
        ;;
    esac

    set +e
    run_user_cmd "$cmd" "$subdir"
    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      say "${YELLOW}⚠️  命令退出码: $rc（不一定错误）${RESET}"
    fi

    if run_checker "$checker_type" "$checker_args"; then
      if [[ $USE_GUM -eq 1 ]]; then
        gum style --border double --padding "1 3" --border-foreground 82 "🎉 通过！"
      else
        say "${GREEN}${BOLD}🎉 通过！${RESET}"
      fi
      return 0
    else
      say "${RED}❌ 还未达到目标${RESET}"
      say "   - 输入 ${BOLD}h${RESET} 看提示"
      say "   - 输入 ${BOLD}sh${RESET} 进入 shell 检查"
      say "   - 继续输入命令修正"
    fi
  done
}

# ---------- 加载题目 ----------
load_exercises() {
  if [[ ! -f "$EXERCISES_CONF" ]]; then
    say "${RED}错误: 找不到题目配置文件 $EXERCISES_CONF${RESET}"
    exit 1
  fi

  EXERCISE_IDS=()
  EXERCISE_TITLES=()
  EXERCISE_GOALS=()
  EXERCISE_HINTS=()
  EXERCISE_SOLUTIONS=()
  EXERCISE_CHECKER_TYPES=()
  EXERCISE_CHECKER_ARGS=()
  EXERCISE_SUBDIRS=()
  EXERCISE_TAGS=()

  while IFS='|' read -r id title goal hint solution checker_type checker_args subdir tags; do
    # 跳过注释和空行
    [[ "$id" =~ ^#.*$ || -z "$id" ]] && continue

    EXERCISE_IDS+=("$id")
    EXERCISE_TITLES+=("$title")
    EXERCISE_GOALS+=("$goal")
    EXERCISE_HINTS+=("$hint")
    EXERCISE_SOLUTIONS+=("$solution")
    EXERCISE_CHECKER_TYPES+=("$checker_type")
    EXERCISE_CHECKER_ARGS+=("$checker_args")
    EXERCISE_SUBDIRS+=("$subdir")
    EXERCISE_TAGS+=("$tags")
  done < "$EXERCISES_CONF"
}

# ---------- 运行练习 ----------
run_exercise() {
  local idx="$1"
  local id="${EXERCISE_IDS[$idx]}"

  # 检查必需命令（optional 标签除外）
  local tags="${EXERCISE_TAGS[$idx]}"
  if [[ "$tags" == *"optional"* ]]; then
    # 尝试从solution提取命令
    local main_cmd
    main_cmd=$(echo "${EXERCISE_SOLUTIONS[$idx]}" | awk '{print $1}')
    if ! has "$main_cmd"; then
      say "${YELLOW}⏭️  $main_cmd 不存在，跳过${RESET}"
      return 2
    fi
  fi

  exercise_loop \
    "$id" \
    "${EXERCISE_TITLES[$idx]}" \
    "${EXERCISE_GOALS[$idx]}" \
    "${EXERCISE_HINTS[$idx]}" \
    "${EXERCISE_SOLUTIONS[$idx]}" \
    "${EXERCISE_CHECKER_TYPES[$idx]}" \
    "${EXERCISE_CHECKER_ARGS[$idx]}" \
    "${EXERCISE_SUBDIRS[$idx]}"
}

run_all() {
  local passed=0 skipped=0 failed=0
  local total="${#EXERCISE_IDS[@]}"

  for i in $(seq 0 $((total - 1))); do
    set +e
    run_exercise "$i"
    rc=$?
    set -e
    case "$rc" in
      0) ((passed++)) ;;
      2) ((skipped++)) ;;
      *) ((failed++)) ;;
    esac
  done

  show_summary "$passed" "$skipped" "$failed"
}

run_quick() {
  local passed=0 skipped=0 failed=0
  local total="${#EXERCISE_IDS[@]}"

  for i in $(seq 0 $((total - 1))); do
    local tags="${EXERCISE_TAGS[$i]}"
    [[ "$tags" != *"basic"* ]] && continue

    set +e
    run_exercise "$i"
    rc=$?
    set -e
    case "$rc" in
      0) ((passed++)) ;;
      2) ((skipped++)) ;;
      *) ((failed++)) ;;
    esac
  done

  show_summary "$passed" "$skipped" "$failed"
}

run_by_tag() {
  local tag="$1"
  local passed=0 skipped=0 failed=0
  local total="${#EXERCISE_IDS[@]}"

  for i in $(seq 0 $((total - 1))); do
    local tags="${EXERCISE_TAGS[$i]}"
    [[ "$tags" != *"$tag"* ]] && continue

    set +e
    run_exercise "$i"
    rc=$?
    set -e
    case "$rc" in
      0) ((passed++)) ;;
      2) ((skipped++)) ;;
      *) ((failed++)) ;;
    esac
  done

  show_summary "$passed" "$skipped" "$failed"
}

show_summary() {
  local passed="$1" skipped="$2" failed="$3"
  hr
  say "${BOLD}📊 今日结果 Summary${RESET}"
  say "${GREEN}✅ 通过: $passed${RESET}"
  say "${YELLOW}⏭️  跳过: $skipped${RESET}"
  say "${RED}❌ 失败: $failed${RESET}"
  say "${BLUE}📁 目录: $WORKDIR${RESET}"
  [[ "$KEEP" -eq 0 ]] && say "（未使用 --keep，退出后自动清理）"
}

main_menu() {
  hr
  say "${BOLD}${BLUE}🧠 CLI Drill v2 | 每日练习${RESET}"
  say "${BOLD}练习目录:${RESET} $WORKDIR"
  say ""

  if [[ $USE_GUM -eq 1 ]]; then
    choice=$(gum choose "全量练习（所有题目）" "快速练习（基础题）" "只创建沙盒" || echo "快速练习（基础题）")
    case "$choice" in
      "全量练习（所有题目）") run_all ;;
      "快速练习（基础题）") run_quick ;;
      "只创建沙盒") say "已创建沙盒：$WORKDIR"; KEEP=1 ;;
      *) run_quick ;;
    esac
  else
    say "1) 全量练习（所有题目）"
    say "2) 快速练习（基础题）"
    say "3) 只创建沙盒"
    say ""
    read -r -p "选择 1/2/3 [默认2]: " choice </dev/tty
    case "$choice" in
      1) run_all ;;
      2|"") run_quick ;;
      3) say "已创建沙盒：$WORKDIR"; KEEP=1 ;;
      *) run_quick ;;
    esac
  fi
}

# ---------- 主流程 ----------
setup_sandbox
load_exercises

case "$MODE" in
  all) run_all ;;
  quick) run_quick ;;
  menu|*) main_menu ;;
esac
