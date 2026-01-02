#!/usr/bin/env bash

# 如果不是交互模式，用 -i 重新执行自己
if [[ $- != *i* ]]; then
  exec bash -i "$0" "$@"
fi

set -u

# =========================
# CLI Drill: daily practice
# =========================

# ---------- config ----------
KEEP=0
MODE="menu"    # menu | all | quick
WORKROOT="${XDG_STATE_HOME:-$HOME/.local/state}/cli-drill"


# --- readline niceties (for read -e) ---
# 让 TAB 行为更像交互 bash
bind 'set show-all-if-ambiguous on'        # 有多个候选就直接列出来
bind 'set menu-complete-display-prefix on' # 菜单补全显示前缀
bind 'TAB:menu-complete'                   # TAB 循环补全（再按TAB切换）
bind 'set completion-ignore-case on'       # 忽略大小写（可选）

# --- load programmable completion if available ---
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  # shellcheck disable=SC1091
  source /usr/share/bash-completion/bash_completion
elif [[ -r /etc/bash_completion ]]; then
  # shellcheck disable=SC1091
  source /etc/bash_completion
fi


# ---------- args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --all) MODE="all"; shift ;;
    --quick) MODE="quick"; shift ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./cli_drill.sh           # menu
  ./cli_drill.sh --all     # run all exercises
  ./cli_drill.sh --quick   # shorter session
  ./cli_drill.sh --keep    # keep sandbox directory
EOF
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$WORKROOT"

SESSION_DATE="$(date +%F)"
WORKDIR="$WORKROOT/$SESSION_DATE"
if [[ -e "$WORKDIR" ]]; then
  # avoid clobbering old session
  WORKDIR="$(mktemp -d "$WORKROOT/$SESSION_DATE.XXXX")"
else
  mkdir -p "$WORKDIR"
fi

cleanup() {
  if [[ "$KEEP" -eq 0 ]]; then
    rm -rf "$WORKDIR" >/dev/null 2>&1 || true
  else
    echo "🧰 已保留练习目录: $WORKDIR"
  fi
}
trap cleanup EXIT

has() { command -v "$1" >/dev/null 2>&1; }

# GNU stat preferred; provide fallback
inode_of() {
  local p="$1"
  if has stat && stat --version >/dev/null 2>&1; then
    stat -c '%i' "$p"
  else
    ls -i "$p" | awk '{print $1}'
  fi
}
nlink_of() {
  local p="$1"
  if has stat && stat --version >/dev/null 2>&1; then
    stat -c '%h' "$p"
  else
    # fallback: parse ls -l (not perfect but OK)
    ls -l "$p" | awk '{print $2}'
  fi
}

# Normalize paths so outputs like "./x" or "/abs/.../x" compare cleanly
normalize_paths() {
  sed -e "s|^$WORKDIR/||" -e 's|^\./||'
}

ensure_dir() { mkdir -p "$WORKDIR/$1"; }

say() { printf "%b\n" "$*"; }
hr() { say "------------------------------------------------------------"; }

pause_any() {
  read -r -p "按 Enter 继续... " _ </dev/tty
}

run_user_cmd() {
  local cmd="$1"
  local subdir="${2:-.}"
  ( cd "$WORKDIR/$subdir" && bash --noprofile --norc -c "$cmd" )
  return $?
}

# loop until checker passes or user skips
# usage: exercise_loop title goal hint solution checker_fn [subdir]
exercise_loop() {
  local title="$1"
  local goal="$2"
  local hint="$3"
  local solution="$4"
  local checker_fn="$5"
  local subdir="${6:-.}"
  
  hr
  say "🧩 $title"
  say "🎯 目标: $goal"
  say "📁 练习目录: $WORKDIR/$subdir"
  say "（提示：输入 h(int) / s(olution) / sh(ell) / sk(ip) / q(uit)）"

  while true; do
    read -r -e -p "drill> " cmd </dev/tty || exit 0
    case "$cmd" in
      hint|h|\?) say "💡 提示: $hint"; continue ;;
      solution|s|\!) say "✅ 参考答案: $solution"; continue ;;
      shell|sh)
        say "进入子 shell（目录：$WORKDIR/$subdir）。退出请输 exit / Ctrl-D"
        ( cd "$WORKDIR/$subdir" && bash --noprofile --norc )
        continue
        ;;
      skip|sk) say "⏭️ 已跳过"; return 2 ;;
      quit|exit|q) exit 0 ;;
      "") continue ;;
    esac

    set +e
    run_user_cmd "$cmd" "$subdir"
    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      say "⚠️ 命令退出码: $rc（不一定错，但通常表示没成功）"
    fi

    if "$checker_fn"; then
      say "🎉 通过！"
      return 0
    else
      say "❌ 还没达到目标。你可以："
      say "   - 输入 hint 看提示"
      say "   - 输入 shell 自己 ls/stat/cat 检查"
      say "   - 再输入一条命令继续修正"
    fi
  done
}

# ---------- sandbox data ----------
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

  # data for find/cut/expand/sort/file/gzip/bzip2
  cat >"$WORKDIR/data/alpha.txt" <<'EOF'
alpha one
alpha two
EOF

  cat >"$WORKDIR/data/beta.txt" <<'EOF'
beta one
beta two
EOF

  # colon separated for cut
  cat >"$WORKDIR/data/colon.txt" <<'EOF'
id:1001:alice
id:1002:bob
id:1003:carol
EOF

  # tabbed file for expand (real tab chars)
  printf "col1\tcol2\tcol3\nA\tB\tC\n" >"$WORKDIR/data/tabbed.txt"

  # numbers with duplicates (string-sort trap)
  cat >"$WORKDIR/data/numbers.txt" <<'EOF'
10
2
2
1
20
3
EOF

  # make a "big" file for size/compression
  # 15000 bytes
  head -c 15000 /dev/zero >"$WORKDIR/data/big.txt" 2>/dev/null || dd if=/dev/zero of="$WORKDIR/data/big.txt" bs=1 count=15000 >/dev/null 2>&1

  # logs for grep/wc/find -exec
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

  # docs for diff
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

  # fake .txt that is actually a PNG (1x1)
  if has base64; then
    base64 -d >"$WORKDIR/data/fake.txt" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7WZ0cAAAAASUVORK5CYII=
EOF
  else
    printf '\x89PNG\r\n\x1a\n' >"$WORKDIR/data/fake.txt"
  fi

  # find -newer reference (for the -newer exercise only)
  touch "$WORKDIR/data/ref.timestamp"
  sleep 1
  echo "newer than ref" >"$WORKDIR/data/newer.txt"
}

# ---------- check helpers ----------
file_exists() { [[ -f "$WORKDIR/$1" ]]; }
link_exists() { [[ -L "$WORKDIR/$1" ]]; }
path_exists() { [[ -e "$WORKDIR/$1" ]]; }

content_equals() {
  local a="$WORKDIR/$1"
  local b="$WORKDIR/$2"
  cmp -s "$a" "$b"
}

contains() {
  local file="$WORKDIR/$1"
  local pat="$2"
  grep -qE "$pat" "$file" 2>/dev/null
}

nonempty() { [[ -s "$WORKDIR/$1" ]]; }

# ---------- exercises ----------
# 1) ln hardlink
check_ln_hard() {
  path_exists "links/origin.txt" || return 1
  path_exists "links/hardlink" || return 1
  [[ "$(inode_of "$WORKDIR/links/origin.txt")" == "$(inode_of "$WORKDIR/links/hardlink")" ]] || return 1
  [[ "$(nlink_of "$WORKDIR/links/origin.txt")" -ge 2 ]] || return 1
  return 0
}

ex_ln_hard() {
  exercise_loop \
    "ln ｜ hard link（硬链接）" \
    "在 links/origin.txt 上创建硬链接 hardlink（本题自动进入 links/ 目录）" \
    "不加 -s 就是硬链接；做完用 ls -li 看 inode，第二列链接数会变大" \
    "ln -f origin.txt hardlink" \
    check_ln_hard \
    "links"
}

# 2) ln -s symlink
check_ln_symlink() {
  link_exists "links/sym" || return 1
  local tgt resolved
  tgt="$(readlink "$WORKDIR/links/sym" 2>/dev/null || true)"
  [[ -n "$tgt" ]] || return 1
  resolved="$(cd "$WORKDIR/links" && readlink -f "sym" 2>/dev/null || true)"
  [[ "$resolved" == "$WORKDIR/links/origin.txt" ]] || return 1
  return 0
}

ex_ln_symlink() {
  exercise_loop \
    "ln -s ｜ symbolic link（符号链接）" \
    "创建符号链接 sym 指向 origin.txt（本题自动进入 links/ 目录）" \
    "相对路径会按“链接所在目录”解释；用 ln -sf 方便重复练习不怕 File exists" \
    "ln -sf origin.txt sym" \
    check_ln_symlink \
    "links"
}

# 3) unlink remove link
check_unlink_sym() {
  ! path_exists "links/sym"
}

ex_unlink() {
  exercise_loop \
    "unlink ｜ remove a name（移除单个文件名）" \
    "删除 sym（只删这个名字，不影响 origin.txt）（本题自动进入 links/ 目录）" \
    "unlink 只能对文件名；没有 -r 递归" \
    "unlink sym" \
    check_unlink_sym \
    "links"
}

# 4) find -name/-type -> write file
check_find_txt_list() {
  file_exists "results/find_txt.txt" || return 1

  local tmp_exp tmp_got
  tmp_exp="$(mktemp)"
  tmp_got="$(mktemp)"

  # Expected: only *.txt under data/docs/links (NOT results)
  ( cd "$WORKDIR" && find . -type f -name '*.txt' ) \
    | normalize_paths | sort -u >"$tmp_exp"

  normalize_paths <"$WORKDIR/results/find_txt.txt" | sort -u >"$tmp_got"

  diff -q "$tmp_exp" "$tmp_got" >/dev/null 2>&1
  local ok=$?
  rm -f "$tmp_exp" "$tmp_got" 2>/dev/null || true
  [[ $ok -eq 0 ]]
}

ex_find_name_type() {
  exercise_loop \
    "find ｜ -name + -type（按名+类型）" \
    "在 data/docs/links 里找出所有 .txt 文件，并写入 results/find_txt.txt" \
    "建议：find data docs links -type f -name '*.txt' > results/find_txt.txt" \
    "find data docs links -type f -name '*.txt' > results/find_txt.txt" \
    check_find_txt_list
}

# 5) find -size (+ boolean) -> write file
check_find_size_or_name() {
  file_exists "results/find_big_or_newer.txt" || return 1
  contains "results/find_big_or_newer.txt" "data/big\.txt" || return 1
  contains "results/find_big_or_newer.txt" "data/newer\.txt" || return 1
  return 0
}

ex_find_size_bool() {
  exercise_loop \
    "find ｜ -size + 逻辑组（-o / \\( \\) ）" \
    "找出：size > 10k 的文件 或者 比 data/ref.timestamp 更新的文件；写入 results/find_big_or_newer.txt" \
    "用 \\( ... -o ... \\) 分组；-size +10000c；-newer data/ref.timestamp" \
    "find . \\( -size +10000c -o -newer data/ref.timestamp \\) -type f > results/find_big_or_newer.txt" \
    check_find_size_or_name
}

# 6) find -exec wc -l {} \; -> write file
check_find_exec_wc() {
  file_exists "results/log_lines.txt" || return 1
  contains "results/log_lines.txt" "logs/app\.log" || return 1
  contains "results/log_lines.txt" "logs/sys\.LOG" || return 1
  return 0
}

ex_find_exec() {
  exercise_loop \
    "find ｜ -exec（对命中文件执行命令）" \
    "对 logs 目录下所有文件执行 wc -l，把输出写入 results/log_lines.txt" \
    "find logs -type f -exec wc -l {} \\; > results/log_lines.txt" \
    "find logs -type f -exec wc -l {} \\; > results/log_lines.txt" \
    check_find_exec_wc
}

# 7) cut -d -f
check_cut_fields() {
  file_exists "results/cut_field2.txt" || return 1
  diff -q "$WORKDIR/results/cut_field2.txt" - >/dev/null 2>&1 <<'EOF'
1001
1002
1003
EOF
}

ex_cut_fields() {
  exercise_loop \
    "cut ｜ -d + -f（按分隔符切列）" \
    "从 data/colon.txt 提取第2列（数字），写入 results/cut_field2.txt" \
    "cut -d ':' -f2 data/colon.txt > results/cut_field2.txt" \
    "cut -d ':' -f2 data/colon.txt > results/cut_field2.txt" \
    check_cut_fields
}

# 8) cut -c
check_cut_chars() {
  file_exists "results/cut_chars.txt" || return 1
  diff -q "$WORKDIR/results/cut_chars.txt" - >/dev/null 2>&1 <<'EOF'
alph
beta
EOF
}

ex_cut_chars() {
  exercise_loop \
    "cut ｜ -c（按字符范围）" \
    "输出两行（alph / beta）到 results/cut_chars.txt" \
    "例如：printf 'alpha\nbeta\n' | cut -c1-4 > results/cut_chars.txt" \
    "printf 'alpha\nbeta\n' | cut -c1-4 > results/cut_chars.txt" \
    check_cut_chars
}

# 9) expand
check_expand() {
  file_exists "results/expanded.txt" || return 1
  ! grep -q $'\t' "$WORKDIR/results/expanded.txt"
}

ex_expand() {
  exercise_loop \
    "expand ｜ tabs -> spaces（Tab 转空格）" \
    "把 data/tabbed.txt 的 Tab 转成 4 个空格，写入 results/expanded.txt" \
    "expand -t 4 data/tabbed.txt > results/expanded.txt" \
    "expand -t 4 data/tabbed.txt > results/expanded.txt" \
    check_expand
}

# 10) grep -in
check_grep_error() {
  file_exists "results/grep_error.txt" || return 1
  contains "results/grep_error.txt" "^[0-9]+:" || return 1
  contains "results/grep_error.txt" "error" || return 1
  return 0
}

ex_grep() {
  exercise_loop \
    "grep ｜ -i + -n（忽略大小写 + 行号）" \
    "在 logs/app.log 里查找 error（忽略大小写），带行号输出到 results/grep_error.txt" \
    "grep -in 'error' logs/app.log > results/grep_error.txt" \
    "grep -in 'error' logs/app.log > results/grep_error.txt" \
    check_grep_error
}

# 11) sort -n -u
check_sort_nu() {
  file_exists "results/sorted_unique.txt" || return 1
  diff -q "$WORKDIR/results/sorted_unique.txt" - >/dev/null 2>&1 <<'EOF'
1
2
3
10
20
EOF
}

ex_sort() {
  exercise_loop \
    "sort ｜ -n + -u（数值排序 + 去重）" \
    "对 data/numbers.txt 数值排序并去重，写入 results/sorted_unique.txt" \
    "sort -n -u data/numbers.txt > results/sorted_unique.txt" \
    "sort -n -u data/numbers.txt > results/sorted_unique.txt" \
    check_sort_nu
}

# 12) wc -l
check_wc_lines() {
  file_exists "results/wc_lines.txt" || return 1
  grep -qE '^6([[:space:]]|$)' "$WORKDIR/results/wc_lines.txt"
}

ex_wc() {
  exercise_loop \
    "wc ｜ -l（行数）" \
    "统计 logs/app.log 行数，写入 results/wc_lines.txt" \
    "wc -l logs/app.log > results/wc_lines.txt" \
    "wc -l logs/app.log > results/wc_lines.txt" \
    check_wc_lines
}

# 13) diff -u
check_diff_u() {
  file_exists "results/patch.diff" || return 1
  contains "results/patch.diff" "^--- " || return 1
  contains "results/patch.diff" "^\\+\\+\\+ " || return 1
  contains "results/patch.diff" "^@@ " || return 1
  return 0
}

ex_diff() {
  exercise_loop \
    "diff ｜ -u（统一格式补丁）" \
    "比较 docs/v1.txt 和 docs/v2.txt，生成 unified diff 到 results/patch.diff" \
    "diff -u docs/v1.txt docs/v2.txt > results/patch.diff" \
    "diff -u docs/v1.txt docs/v2.txt > results/patch.diff" \
    check_diff_u
}

# 14) which
check_which() {
  file_exists "results/which_grep.txt" || return 1
  contains "results/which_grep.txt" "grep" || return 1
  return 0
}

ex_which() {
  if ! has which; then say "⏭️ which 不存在，跳过"; return 2; fi
  exercise_loop \
    "which ｜ locate command（定位命令路径）" \
    "输出 grep 的路径到 results/which_grep.txt" \
    "which grep > results/which_grep.txt" \
    "which grep > results/which_grep.txt" \
    check_which
}

# 15) file
check_file_cmd() {
  file_exists "results/file_fake.txt" || return 1
  ! contains "results/file_fake.txt" "ASCII text"
}

ex_file() {
  if ! has file; then say "⏭️ file 不存在，跳过"; return 2; fi
  exercise_loop \
    "file ｜ determine file type（判断文件类型）" \
    "判断 data/fake.txt（其实是 PNG）类型，输出到 results/file_fake.txt" \
    "file data/fake.txt > results/file_fake.txt" \
    "file data/fake.txt > results/file_fake.txt" \
    check_file_cmd
}

# 16) whatis
check_whatis() { nonempty "results/whatis_grep.txt"; }

ex_whatis() {
  if ! has whatis; then say "⏭️ whatis 不存在，跳过"; return 2; fi
  exercise_loop \
    "whatis ｜ short manual（简短用途说明）" \
    "查询 grep 的简短说明，写入 results/whatis_grep.txt（若提示 nothing appropriate 也算完成）" \
    "whatis grep > results/whatis_grep.txt" \
    "whatis grep > results/whatis_grep.txt" \
    check_whatis
}

# 17) apropos
check_apropos() { nonempty "results/apropos_compress.txt"; }

ex_apropos() {
  if ! has apropos; then say "⏭️ apropos 不存在，跳过"; return 2; fi
  exercise_loop \
    "apropos ｜ man -k（模糊搜索手册关键词）" \
    "搜索 compress 相关条目（取前 10 行即可），写入 results/apropos_compress.txt" \
    "apropos compress | head > results/apropos_compress.txt" \
    "apropos compress | head > results/apropos_compress.txt" \
    check_apropos
}

# 18) gzip compress with -c
check_gzip_c() {
  file_exists "results/big.txt.gz" || return 1
  file_exists "data/big.txt" || return 1
  if has gzip; then gzip -t "$WORKDIR/results/big.txt.gz" >/dev/null 2>&1; else return 1; fi
}

ex_gzip_c() {
  if ! has gzip; then say "⏭️ gzip 不存在，跳过"; return 2; fi
  exercise_loop \
    "gzip ｜ -c（输出到 stdout，不删原文件）" \
    "把 data/big.txt 压缩到 results/big.txt.gz，且保留原文件" \
    "gzip -c data/big.txt > results/big.txt.gz" \
    "gzip -c data/big.txt > results/big.txt.gz" \
    check_gzip_c
}

# 19) gzip -dc decompress
check_gzip_dc() {
  file_exists "results/big.unzipped.txt" || return 1
  content_equals "data/big.txt" "results/big.unzipped.txt"
}

ex_gzip_dc() {
  if ! has gzip; then say "⏭️ gzip 不存在，跳过"; return 2; fi
  exercise_loop \
    "gzip ｜ -d + -c（解压到 stdout）" \
    "把 results/big.txt.gz 解压到 results/big.unzipped.txt，并确保与原文件一致" \
    "gzip -dc results/big.txt.gz > results/big.unzipped.txt" \
    "gzip -dc results/big.txt.gz > results/big.unzipped.txt" \
    check_gzip_dc
}

# 20) bzip2 -c
check_bzip2_c() {
  file_exists "results/big.txt.bz2" || return 1
  file_exists "data/big.txt" || return 1
  return 0
}

ex_bzip2_c() {
  if ! has bzip2; then say "⏭️ bzip2 不存在，跳过"; return 2; fi
  exercise_loop \
    "bzip2 ｜ -c（输出到 stdout）" \
    "把 data/big.txt 压缩到 results/big.txt.bz2（保留原文件）" \
    "bzip2 -c data/big.txt > results/big.txt.bz2" \
    "bzip2 -c data/big.txt > results/big.txt.bz2" \
    check_bzip2_c
}

# 21) bunzip2 -c
check_bunzip2_c() {
  file_exists "results/big.bz2.unzipped.txt" || return 1
  content_equals "data/big.txt" "results/big.bz2.unzipped.txt"
}

ex_bunzip2_c() {
  if ! has bunzip2; then say "⏭️ bunzip2 不存在，跳过"; return 2; fi
  exercise_loop \
    "bunzip2 ｜ -c（解压到 stdout）" \
    "把 results/big.txt.bz2 解压到 results/big.bz2.unzipped.txt，并确保与原文件一致" \
    "bunzip2 -c results/big.txt.bz2 > results/big.bz2.unzipped.txt" \
    "bunzip2 -c results/big.txt.bz2 > results/big.bz2.unzipped.txt" \
    check_bunzip2_c
}

# 22) compress/uncompress (optional)
check_compress_c() {
  file_exists "results/big.txt.Z" || return 1
  file_exists "data/big.txt" || return 1
  return 0
}
ex_compress_c() {
  if ! has compress; then say "⏭️ compress 不存在，跳过"; return 2; fi
  exercise_loop \
    "compress ｜ -c（生成 .Z）" \
    "把 data/big.txt 压缩到 results/big.txt.Z（保留原文件）" \
    "compress -c data/big.txt > results/big.txt.Z" \
    "compress -c data/big.txt > results/big.txt.Z" \
    check_compress_c
}
check_uncompress_c() {
  file_exists "results/big.Z.unzipped.txt" || return 1
  content_equals "data/big.txt" "results/big.Z.unzipped.txt"
}
ex_uncompress_c() {
  if ! has uncompress; then say "⏭️ uncompress 不存在，跳过"; return 2; fi
  exercise_loop \
    "uncompress ｜ -c（解压 .Z 到 stdout）" \
    "把 results/big.txt.Z 解压到 results/big.Z.unzipped.txt，并确保与原文件一致" \
    "uncompress -c results/big.txt.Z > results/big.Z.unzipped.txt" \
    "uncompress -c results/big.txt.Z > results/big.Z.unzipped.txt" \
    check_uncompress_c
}

# 23) man + info (manual)
ex_man_info() {
  hr
  say "📖 man vs info ｜ 手册练习（人工完成）"
  if has man; then
    say "1) 将打开：man find（练习 /pattern 搜索，q 退出）"
    pause_any
    ( cd "$WORKDIR" && man find )
  else
    say "⏭️ man 不存在，跳过"
  fi

  if has info; then
    say "2) 将打开：info find（练习节点跳转，q 退出）"
    pause_any
    ( cd "$WORKDIR" && info find )
  else
    say "⏭️ info 不存在，跳过"
  fi
  say "✅ 本步骤不做自动验收（你自己看完退出即可）"
  return 0
}

# 24) apt-get (dry-run)
check_apt_sim() { nonempty "results/apt_sim.txt"; }

ex_apt_get() {
  if ! has apt-get; then say "⏭️ apt-get 不存在（非 Debian/Ubuntu），跳过"; return 2; fi
  exercise_loop \
    "apt-get ｜ -s（模拟安装/卸载，不改系统）" \
    "用模拟模式查看安装 tree 的动作，把输出写入 results/apt_sim.txt（不需要 sudo）" \
    "apt-get -s install tree > results/apt_sim.txt" \
    "apt-get -s install tree > results/apt_sim.txt" \
    check_apt_sim
}

# ---------- runner ----------
run_all() {
  local passed=0 skipped=0 failed=0
  local steps=(
    ex_ln_hard
    ex_ln_symlink
    ex_unlink
    ex_find_name_type
    ex_find_size_bool
    ex_find_exec
    ex_cut_fields
    ex_cut_chars
    ex_expand
    ex_grep
    ex_sort
    ex_wc
    ex_diff
    ex_which
    ex_file
    ex_whatis
    ex_apropos
    ex_gzip_c
    ex_gzip_dc
    ex_bzip2_c
    ex_bunzip2_c
    ex_compress_c
    ex_uncompress_c
    ex_man_info
    ex_apt_get
  )

  for fn in "${steps[@]}"; do
    set +e
    "$fn"
    rc=$?
    set -e
    case "$rc" in
      0) passed=$((passed+1)) ;;
      2) skipped=$((skipped+1)) ;;
      *) failed=$((failed+1)) ;;
    esac
  done

  hr
  say "📊 今日结果 ｜ Summary"
  say "✅ 通过: $passed"
  say "⏭️ 跳过: $skipped"
  say "❌ 失败: $failed"
  say "📁 练习目录: $WORKDIR"
  if [[ "$KEEP" -eq 0 ]]; then
    say "（未使用 --keep，将在退出后自动清理）"
  fi
}

run_quick() {
  local passed=0 skipped=0 failed=0
  local steps=(
    ex_ln_hard
    ex_ln_symlink
    ex_find_name_type
    ex_cut_fields
    ex_grep
    ex_sort
    ex_gzip_c
    ex_diff
  )
  for fn in "${steps[@]}"; do
    set +e
    "$fn"
    rc=$?
    set -e
    case "$rc" in
      0) passed=$((passed+1)) ;;
      2) skipped=$((skipped+1)) ;;
      *) failed=$((failed+1)) ;;
    esac
  done
  hr
  say "📊 Quick 结果"
  say "✅ 通过: $passed  ⏭️ 跳过: $skipped  ❌ 失败: $failed"
  say "📁 练习目录: $WORKDIR"
}

main_menu() {
  hr
  say "🧠 CLI Drill ｜ 每日练习"
  say "练习目录: $WORKDIR"
  say ""
  say "1) 全量（覆盖你列的所有主题，环境不支持的会自动跳过）"
  say "2) Quick（更短）"
  say "3) 只建沙盒后退出（你自己玩）"
  say ""
  read -r -p "选择 1/2/3: " choice </dev/tty
  case "$choice" in
    1) run_all ;;
    2) run_quick ;;
    3) say "已创建沙盒：$WORKDIR"; KEEP=1 ;;
    *) say "默认走 Quick"; run_quick ;;
  esac
}

# ---------- go ----------
set -e
setup_sandbox

case "$MODE" in
  all) run_all ;;
  quick) run_quick ;;
  menu|*) main_menu ;;
esac
