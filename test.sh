#!/usr/bin/env bash
# unix_drill.sh — interactive Unix/Linux command memorization drill
# - English-only UI in the shell
# - Sandbox-safe (creates a temp practice directory)
# - Spaced repetition (simple Leitner-style scheduling)
# - Coverage check: ensures EVERY command/key mentioned in the slides is covered by at least one question

set -euo pipefail

APP_NAME="unix-drill"
APP_DIR="${HOME}/.${APP_NAME}"
PROGRESS_FILE="${APP_DIR}/progress.tsv"
mkdir -p "${APP_DIR}"

# ----------------------------
# Required coverage (from slides)
# ----------------------------
# Commands and “control keys” that must appear in tags at least once.
REQUIRED_TAGS=(
  # login/logout/exit
  "login" "logout" "exit"
  # control keys
  "^H" "Backspace" "^U" "^S" "^Q" "^C" "^D" "^V"
  # useful info
  "uname" "passwd" "date" "who" "who am i" "whoami" "ps" "stty" "env"
  # alias/help
  "alias" "man" "xman" "info" "whatis" "apropos"
  # directory commands
  "pwd" "cd" "mkdir" "rmdir" "tree" "ls"
  # permissions
  "chmod" "umask" "chgrp" "chown"
  # display commands
  "echo" "cat" "head" "tail" "more" "less"
  # file manipulation
  "cp" "mv" "rm" "ln" "unlink" "find"
  # compression
  "compress" "uncompress" "gzip" "gunzip" "bzip2" "bunzip2"
  # utilities
  "wc" "diff" "tkdiff" "windiff" "grep" "egrep" "fgrep" "which" "file" "sort" "apt-get"
)

# ----------------------------
# Spaced repetition schedule (seconds) by level
# level 0 -> immediate; level 1 -> 2 min; 2 -> 10 min; 3 -> 1h; 4 -> 6h; 5 -> 1d; 6 -> 3d
# ----------------------------
SRS_DELAYS=(0 120 600 3600 21600 86400 259200)
MAX_LEVEL=$(( ${#SRS_DELAYS[@]} - 1 ))

# ----------------------------
# Question bank format (pipe-separated):
# id | tags(comma-separated) | type | prompt | answers(separated by ';;') | hint
#
# type:
# - type: user must type the command/key
# - fact: short factual recall (still typed as answer)
# ----------------------------
read -r -d '' QUESTION_BANK <<'EOF' || true
Q001|login|type|Type the command listed for starting a login session (as shown in the slides).|login|Use a single word command.
Q002|logout|type|Type the command listed for logging out (as shown in the slides).|logout|Use a single word command.
Q003|exit|type|Type the command listed for leaving the current shell session.|exit|Use a single word command.

Q010|^H,Backspace|fact|Which control key (or key name) erases a character? Type exactly as in slides (e.g., ^H or Backspace).|^H;;Backspace|Two acceptable answers.
Q011|^U|fact|Which control key cancels the current line? Type it like ^U.|^U|Caret notation.
Q012|^S|fact|Which control key pauses the display? Type it like ^S.|^S|Caret notation.
Q013|^Q|fact|Which control key restarts the display after a pause? Type it like ^Q.|^Q|Caret notation.
Q014|^C|fact|Which control key cancels/interrupts the current operation? Type it like ^C.|^C|Caret notation.
Q015|^D|fact|Which control key signals end-of-file (EOF) / may log a user off? Type it like ^D.|^D|Caret notation.
Q016|^V|fact|Which control key makes the following control character treated as a normal character? Type it like ^V.|^V|Caret notation.

Q020|uname|type|Show Unix/Linux version (all info) as shown in slides.|uname -a|Use the option in the example.
Q021|passwd|type|Type the command to change your password (only the command).|passwd|Admin permission policies may apply.
Q022|date|type|Type the command to display system date and time.|date|Single word command.
Q023|who|type|Type the command to list logged-in users.|who|Single word command.
Q024|who am i|type|Type the command that shows who you are in the form shown in slides.|who am i;;who\ am\ i|Include spaces between words.
Q025|whoami|type|Type the command to print effective username.|whoami|Single word command.
Q026|ps|type|Type the command that lists your current processes (basic).|ps|Single word command.
Q027|stty|type|Type the command to show terminal control settings (basic).|stty|Single word command.
Q028|stty|type|Set erase key to ^X (as shown). Type the full command.|stty erase ^X|Include 'erase' and caret notation.
Q029|stty|type|Set kill key to ^Y (as shown). Type the full command.|stty kill ^Y|Include 'kill' and caret notation.
Q030|env|type|Type the command to show environment variable values.|env|Single word command.

Q040|alias|type|List currently defined shell aliases. Type the command.|alias|Single word command.
Q041|alias,ls|type|Create an alias named ll for 'ls -alF' (use the syntax shown).|alias ll='ls -alF';;alias ll="ls -alF"|Quotes can be single or double.
Q042|alias|fact|What is the general alias syntax shown in slides? Type exactly the pattern.|alias aname='pname'|Use the pattern (not a real alias).

Q050|man|type|Open the manual page for 'man' itself (as shown).|man man|Two words.
Q051|man|type|Use man to search one-line summaries by keyword (as shown).|man -k keyword|Keyword placeholder is literal.
Q052|man|type|Use man to show one-line summary for a file (as shown).|man -f file|File placeholder is literal.
Q053|xman|type|Type the command that launches the GUI man browser.|xman|Single word command.
Q054|info|type|Type the command that shows hypertext help pages (generic).|info|Single word command.
Q055|whatis|type|Type the command that searches the whatis database for a word.|whatis|Single word command.
Q056|apropos|type|Type the command that searches the whatis database for a string.|apropos|Single word command.

Q070|pwd|type|Print working directory. Type the command.|pwd|Single word command.
Q071|cd|type|Change to your home directory using the simplest form shown.|cd|No argument means home in many shells.
Q072|cd|type|Change to your home using tilde form.|cd ~|Include the tilde.
Q073|cd,env|type|Change to your home using environment variable form shown.|cd $HOME|Include $HOME.
Q074|mkdir|type|Create two directories: ./personal and ./manage (as shown).|mkdir ./personal ./manage;;mkdir personal manage|Both are acceptable.
Q075|mkdir|type|Create nested directories a/b/c using -p.|mkdir -p a/b/c|Include -p.
Q076|rmdir|type|Remove two empty directories: personal and manage (as shown).|rmdir personal manage|Directory must be empty.
Q077|tree|type|Type the command that displays a directory tree.|tree|May require installation on some systems.

Q080|ls|type|List directory contents in long format.|ls -l|Include -l.
Q081|ls|type|List including hidden files in long format.|ls -al;;ls -la|Order may vary.
Q082|ls|type|List in long format, include hidden, sort by time.|ls -alt|Include -a -l -t.
Q083|ls|type|List in long format, include hidden, time sort, add suffix (-F).|ls -altF;;ls -alFt|Include -F too.
Q084|ls|type|List in long format, include hidden, time sort, suffix, recursive.|ls -altFR;;ls -alFtR|Include -R too.
Q085|ls|type|Compare: show long listing of /dev (not just directory entry). Type the first command.|ls -l /dev|Include path /dev.
Q086|ls|type|Compare: show long listing of the directory entry /dev itself. Type the second command.|ls -ld /dev|Include -d.
Q087|ls|type|Show file type suffix with -F (basic).|ls -F|Include -F.
Q088|ls,alias|type|Show colored listing via ls option shown (as part of alias idea).|ls --color=auto|Include the long option.

Q100|chmod|type|Give owner write permission using symbolic mode (as shown).|chmod u+w file|Use 'file' placeholder literally.
Q101|chmod|type|Give group read/write permission using symbolic mode (as shown).|chmod g+rw file|Use 'file' placeholder literally.
Q102|chmod|type|Remove execute permission for group and others (as shown).|chmod go-x file|Use 'file' placeholder literally.
Q103|chmod|type|Give rwx to user/group/others using numeric form (as shown).|chmod 777 filename;;chmod 7 7 7 filename|Either compact or spaced.
Q104|chmod|type|Set permissions to 750 (as shown).|chmod 750 filename|Use 'filename' placeholder literally.
Q105|chmod|type|Set permissions to 640 (as shown).|chmod 640 filename|Use 'filename' placeholder literally.
Q106|umask|type|Set umask to 022 (as shown).|umask 022|Include the mask.
Q107|umask|type|Show current umask value (basic).|umask|Single word command.

Q110|chgrp|type|Change group of a file (generic). Type the command name only.|chgrp|Command name only.
Q111|chown|type|Change owner of a file (generic). Type the command name only.|chown|Command name only.

Q120|echo|type|Echo a text string to stdout (type the command name only).|echo|Command name only.
Q121|cat|type|Concatenate / display a file (type the command name only).|cat|Command name only.
Q122|head|type|Display first 10 lines of a file (type the command name only).|head|Command name only.
Q123|tail|type|Display last 10 lines of a file (type the command name only).|tail|Command name only.
Q124|more|type|Browse a file page by page (type the command name only).|more|Command name only.
Q125|less|type|Browse a file with less (type the command name only).|less|Command name only.
Q126|more,less,ls|type|Pipe long ls output into more (as shown).|ls -l | more;;ls -l\|\ more;;ls -l|more|Any equivalent pipe spacing is fine.
Q127|less,ls|type|Pipe long ls output into less (as shown).|ls -l | less;;ls -l\|\ less;;ls -l|less|Any equivalent pipe spacing is fine.

Q140|cp|type|Copy file a.txt to b.txt.|cp a.txt b.txt|Two arguments.
Q141|cp|type|Recursively copy directory srcdir to dstdir (use -R or -r).|cp -R srcdir dstdir;;cp -r srcdir dstdir|Either -R or -r.
Q142|mv|type|Rename oldname to newname.|mv oldname newname|Two arguments.
Q143|rm|type|Remove a file named t.txt.|rm t.txt|Simple remove.
Q144|rm|type|Recursively remove a directory named dir (as shown with -rR).|rm -rR dir;;rm -R dir;;rm -r dir|Use a recursive option.

Q150|ln|type|Create a symbolic link to /usr/bin/firefox in current directory (as shown).|ln -s /usr/bin/firefox .|Dot means current directory.
Q151|ln|type|Create a symbolic link named f to /usr/bin/firefox (as shown).|ln -s /usr/bin/firefox ./f;;ln -s /usr/bin/firefox f|Name the link target f.
Q152|unlink|type|Remove a link named filename (as shown).|unlink filename|Use placeholder literally.

Q160|find|type|Find files matching Net*.jpeg under current dir and print (as shown).|find . -name 'Net*.jpeg' -print;;find . -name Net\*.jpeg -print;;find . -name "Net*.jpeg" -print|Quote/escape variations accepted.
Q161|find|type|Find files newer than init.c and print (as shown).|find . -newer init.c -print|Use -newer.
Q162|find|type|Find directories under /usr/local and print (as shown).|find /usr/local -type d -print|Use -type d.
Q163|find,rm|type|Complex example (as shown): find with (user Bill OR size +10000c), print, then exec rm. Type it.|find . \( -user Bill -o -size +10000c \) -print -exec rm { } \;|Include escaped parentheses and -exec ... \;
Q164|find,rm|type|Another example (as shown): use -ok rm with -size +1000 and -atime 30 (use placeholders).|find denis -size +1000 -atime 30 -ok rm { } \;|This is a memorization pattern question.

Q170|compress|type|Type the compression command name mentioned (classic .Z).|compress|Command name only.
Q171|uncompress|type|Type the decompression command name mentioned for .Z.|uncompress|Command name only.
Q172|gzip|type|Compress a file named filename (as shown).|gzip filename|Command + file.
Q173|gzip|type|Decompress using gzip -d (as shown).|gzip -d filename|Command + -d.
Q174|gzip|type|Show help for gzip (as shown).|gzip -h|Include -h.
Q175|gunzip|type|Type the command name gunzip (as shown).|gunzip|Command name only.
Q176|bzip2|type|Type the command name bzip2 (as shown).|bzip2|Command name only.
Q177|bunzip2|type|Type the command name bunzip2 (as shown).|bunzip2|Command name only.

Q180|wc|type|Count lines/words/chars in a file: type the command name only.|wc|Command name only.
Q181|wc|type|Option to count characters (as shown). Type 'wc' with that option and a file placeholder f.|wc -c f|Use placeholder f.
Q182|wc|type|Option to count lines (as shown). Type 'wc' with that option and placeholder f.|wc -l f|Use placeholder f.
Q183|wc|type|Option to count words (as shown). Type 'wc' with that option and placeholder f.|wc -w f|Use placeholder f.
Q184|wc,ls|type|Count number of entries in current directory (as shown).|ls | wc -l;;ls\|\ wc\ -l;;ls|wc -l|Pipe okay.

Q190|diff|type|Compare two files file1 and file2 (as shown).|diff file1 file2|Two arguments.
Q191|tkdiff|type|Type the GUI diff tool name mentioned.|tkdiff|Command name only.
Q192|windiff|type|Type the Windows diff tool name mentioned.|windiff|Command name only.

Q200|grep|type|Basic grep form: search regexp in file (as shown pattern).|grep regexp file|Placeholders are literal.
Q201|grep|type|Example: search 'static' in all .c files under current dir (as shown).|grep static ./*.c;;grep static *.c|Glob variations accepted.
Q202|grep|type|Example: find lines starting with # in *.cpp (as shown).|grep ^# *.cpp|Include ^#.
Q203|grep,man,find|type|Example: count 'perm' occurrences in man find output, case-insensitive (as shown).|man find | grep -ci perm;;man find|grep -ci perm|Pipe spacing variations accepted.
Q204|grep|type|Example: grep Event with -n and -i in main.c (as shown).|grep -ni Event main.c;;grep -in Event main.c|Option order may vary.
Q205|grep|fact|Which grep option counts matching lines? Type the option only.|-c|Just the option.
Q206|grep|fact|Which grep option ignores case? Type the option only.|-i|Just the option.
Q207|grep|fact|Which grep option prints line numbers? Type the option only.|-n|Just the option.
Q208|grep|fact|Which grep option searches recursively? Type the option only.|-r|Just the option.
Q209|egrep|fact|Which variant uses extended regular expressions? Type its command name.|egrep|Command name only.
Q210|fgrep|fact|Which variant searches for exact strings (no pattern)? Type its command name.|fgrep|Command name only.

Q220|which|type|Locate a command (show its pathname or alias). Type the command name only.|which|Command name only.
Q221|file|type|Determine file type. Type the command name only.|file|Command name only.
Q222|sort|type|Sort text files. Type the command name only.|sort|Command name only.
Q223|apt-get|type|Linux package handling tool name mentioned. Type the command name only.|apt-get|Command name only.
EOF

# ----------------------------
# CLI args
# ----------------------------
FILTER_TAG=""
NO_SRS=0
SEED=""
SANDBOX_PATH=""
SHOW_ANSWERS_ON_WRONG=1

usage() {
  cat <<'USAGE'
unix_drill.sh — interactive Unix/Linux command memorization drill

Usage:
  ./unix_drill.sh [options]

Options:
  --tag TAG        Practice only questions that include TAG (e.g., ls, find, grep)
  --no-srs         Disable spaced repetition scheduling (pure random)
  --seed N         Deterministic random seed (integer)
  --sandbox PATH   Use an existing directory as sandbox (will create files inside)
  --no-show        Do not show the answer automatically when wrong
  -h, --help       Show this help

In-session commands:
  /help            Show help
  /hint            Show hint (if any)
  /show            Show the answer for the current question
  /skip            Skip this question (due soon)
  /tag TAG         Switch tag filter on the fly
  /all             Clear tag filter (practice everything)
  /stats           Show your stats
  /missing         Show missing required tags (should be none)
  /quit            Exit

Notes:
  - This tool creates a sandbox directory to avoid harming real files.
  - Some commands are "theoretical" (e.g., login/logout/passwd/apt-get) and are practiced as typing recall.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) FILTER_TAG="${2:-}"; shift 2;;
    --no-srs) NO_SRS=1; shift;;
    --seed) SEED="${2:-}"; shift 2;;
    --sandbox) SANDBOX_PATH="${2:-}"; shift 2;;
    --no-show) SHOW_ANSWERS_ON_WRONG=0; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

# ----------------------------
# Utilities
# ----------------------------
now_epoch() { date +%s; }

trim() {
  local s="$*"
  # shellcheck disable=SC2001
  echo "$s" | sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//'
}

collapse_spaces() {
  # collapse multiple spaces/tabs to single spaces
  echo "$*" | tr '\t' ' ' | sed -e 's/[[:space:]]\+/ /g'
}

normalize_answer() {
  local s
  s="$(trim "$*")"
  s="$(collapse_spaces "$s")"
  # allow user to type pipe with or without spaces around it
  s="${s// | /|}"
  s="${s//| /|}"
  s="${s// |/|}"
  echo "$s"
}

# compare user input to acceptable answers
is_correct() {
  local user="$1"; shift
  local ua
  ua="$(normalize_answer "$user")"
  local ans
  for ans in "$@"; do
    if [[ "$ua" == "$(normalize_answer "$ans")" ]]; then
      return 0
    fi
  done
  return 1
}

# ----------------------------
# Parse question bank into arrays
# ----------------------------
declare -a Q_ID Q_TAGS Q_TYPE Q_PROMPT Q_ANS_LIST Q_HINT
while IFS='|' read -r id tags qtype prompt answers hint; do
  # skip blanks and comments
  [[ -z "${id// }" ]] && continue
  [[ "${id:0:1}" == "#" ]] && continue

  Q_ID+=("$id")
  Q_TAGS+=("$tags")
  Q_TYPE+=("$qtype")
  Q_PROMPT+=("$prompt")
  Q_ANS_LIST+=("$answers")
  Q_HINT+=("$hint")
done <<<"$QUESTION_BANK"

Q_COUNT=${#Q_ID[@]}

# ----------------------------
# Coverage check
# ----------------------------
coverage_check() {
  local covered=()
  local i tags t
  for ((i=0; i<Q_COUNT; i++)); do
    tags="${Q_TAGS[$i]}"
    IFS=',' read -r -a tarr <<<"$tags"
    for t in "${tarr[@]}"; do
      t="$(trim "$t")"
      [[ -n "$t" ]] && covered+=("$t")
    done
  done

  local missing=()
  local req c ok
  for req in "${REQUIRED_TAGS[@]}"; do
    ok=0
    for c in "${covered[@]}"; do
      if [[ "$c" == "$req" ]]; then ok=1; break; fi
    done
    [[ $ok -eq 0 ]] && missing+=("$req")
  done

  if ((${#missing[@]})); then
    echo "ERROR: Question bank is missing coverage for these required tags:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    echo "Fix the question bank before using the drill." >&2
    exit 1
  fi
}

missing_report() {
  local covered=()
  local i tags t
  for ((i=0; i<Q_COUNT; i++)); do
    tags="${Q_TAGS[$i]}"
    IFS=',' read -r -a tarr <<<"$tags"
    for t in "${tarr[@]}"; do
      t="$(trim "$t")"
      [[ -n "$t" ]] && covered+=("$t")
    done
  done

  local missing=()
  local req c ok
  for req in "${REQUIRED_TAGS[@]}"; do
    ok=0
    for c in "${covered[@]}"; do
      if [[ "$c" == "$req" ]]; then ok=1; break; fi
    done
    [[ $ok -eq 0 ]] && missing+=("$req")
  done

  if ((${#missing[@]})); then
    echo "Missing tags:"
    printf '  - %s\n' "${missing[@]}"
  else
    echo "No missing tags. Coverage is complete."
  fi
}

coverage_check

# ----------------------------
# Sandbox setup (safe practice workspace)
# ----------------------------
SANDBOX=""
cleanup() {
  if [[ -n "${SANDBOX}" && -d "${SANDBOX}" && -z "${SANDBOX_PATH}" ]]; then
    rm -rf "${SANDBOX}"
  fi
}
trap cleanup EXIT INT TERM

sandbox_init() {
  if [[ -n "${SANDBOX_PATH}" ]]; then
    mkdir -p "${SANDBOX_PATH}"
    SANDBOX="${SANDBOX_PATH}"
  else
    SANDBOX="$(mktemp -d)"
  fi

  # Create sample files/dirs for realistic prompts (still safe)
  mkdir -p "${SANDBOX}/personal" "${SANDBOX}/manage" "${SANDBOX}/dir" "${SANDBOX}/a/b"
  printf "hello\nEvent line\nSTATIC thing\n" > "${SANDBOX}/main.c"
  printf "init\n" > "${SANDBOX}/init.c"
  printf "#include <stdio.h>\n" > "${SANDBOX}/test.cpp"
  printf "one two three\nfour five\n" > "${SANDBOX}/words.txt"
  touch "${SANDBOX}/Net1.jpeg" "${SANDBOX}/Net2.jpeg"

  # For ln/unlink practice: create a harmless symlink target
  mkdir -p "${SANDBOX}/bin"
  printf '#!/usr/bin/env bash\necho "fake firefox"\n' > "${SANDBOX}/bin/firefox"
  chmod +x "${SANDBOX}/bin/firefox"

  cd "${SANDBOX}"
}

# ----------------------------
# Progress storage
# TSV columns:
# id \t level \t next_due_epoch \t correct \t wrong
# ----------------------------
declare -A P_LEVEL P_DUE P_CORRECT P_WRONG

load_progress() {
  if [[ -f "${PROGRESS_FILE}" ]]; then
    while IFS=$'\t' read -r pid lvl due cor wr; do
      [[ -z "${pid:-}" ]] && continue
      P_LEVEL["$pid"]="${lvl:-0}"
      P_DUE["$pid"]="${due:-0}"
      P_CORRECT["$pid"]="${cor:-0}"
      P_WRONG["$pid"]="${wr:-0}"
    done < "${PROGRESS_FILE}"
  fi

  # Initialize missing IDs
  local i id
  for ((i=0; i<Q_COUNT; i++)); do
    id="${Q_ID[$i]}"
    : "${P_LEVEL[$id]:=0}"
    : "${P_DUE[$id]:=0}"
    : "${P_CORRECT[$id]:=0}"
    : "${P_WRONG[$id]:=0}"
  done
}

save_progress() {
  : > "${PROGRESS_FILE}"
  local i id
  for ((i=0; i<Q_COUNT; i++)); do
    id="${Q_ID[$i]}"
    printf "%s\t%s\t%s\t%s\t%s\n" \
      "$id" "${P_LEVEL[$id]}" "${P_DUE[$id]}" "${P_CORRECT[$id]}" "${P_WRONG[$id]}" \
      >> "${PROGRESS_FILE}"
  done
}

# ----------------------------
# Question selection
# ----------------------------
matches_tag_filter() {
  local tags="$1"
  [[ -z "${FILTER_TAG}" ]] && return 0
  # exact tag match within comma-separated list
  IFS=',' read -r -a arr <<<"$tags"
  local t
  for t in "${arr[@]}"; do
    t="$(trim "$t")"
    if [[ "$t" == "$FILTER_TAG" ]]; then
      return 0
    fi
  done
  return 1
}

pick_question_index() {
  local now
  now="$(now_epoch)"

  # build candidate indices
  local -a due_idxs=()
  local -a any_idxs=()
  local i id

  for ((i=0; i<Q_COUNT; i++)); do
    id="${Q_ID[$i]}"
    matches_tag_filter "${Q_TAGS[$i]}" || continue
    any_idxs+=("$i")
    if [[ "${NO_SRS}" -eq 0 ]]; then
      if (( now >= ${P_DUE[$id]} )); then
        due_idxs+=("$i")
      fi
    fi
  done

  if ((${#any_idxs[@]} == 0)); then
    echo "No questions match the current tag filter: '${FILTER_TAG}'" >&2
    return 1
  fi

  local pick_from_count
  local -a pick_from
  if [[ "${NO_SRS}" -eq 0 && ${#due_idxs[@]} -gt 0 ]]; then
    pick_from=("${due_idxs[@]}")
  else
    pick_from=("${any_idxs[@]}")
  fi
  pick_from_count=${#pick_from[@]}

  # random pick
  local r=$(( RANDOM % pick_from_count ))
  echo "${pick_from[$r]}"
}

# ----------------------------
# Session UI
# ----------------------------
print_banner() {
  cat <<EOF
${APP_NAME} — Unix/Linux command drill
Sandbox: ${SANDBOX}
Tag filter: ${FILTER_TAG:-<none>}
Spaced repetition: $( [[ "${NO_SRS}" -eq 1 ]] && echo "OFF" || echo "ON" )

Type /help for commands.
EOF
}

show_help_in_session() {
  cat <<'EOF'
Commands:
  /help            Show this help
  /hint            Show hint for current question (if any)
  /show            Show the answer for the current question
  /skip            Skip current question
  /tag TAG         Practice only TAG (e.g., ls, find, grep)
  /all             Clear tag filter
  /stats           Show stats
  /missing         Show missing required tags (should be none)
  /quit            Exit
EOF
}

show_stats() {
  local total=0 correct=0 wrong=0
  local i id
  for ((i=0; i<Q_COUNT; i++)); do
    id="${Q_ID[$i]}"
    (( total += 1 ))
    (( correct += P_CORRECT[$id] ))
    (( wrong += P_WRONG[$id] ))
  done
  echo "Stats:"
  echo "  Questions: ${total}"
  echo "  Total correct: ${correct}"
  echo "  Total wrong:   ${wrong}"
  if [[ -n "${FILTER_TAG}" ]]; then
    echo "  (Note: tag filter active: ${FILTER_TAG})"
  fi
}

update_srs_on_result() {
  local qid="$1"
  local ok="$2"  # 1=correct,0=wrong
  local now
  now="$(now_epoch)"

  if [[ "${NO_SRS}" -eq 1 ]]; then
    # still keep counters
    if [[ "$ok" -eq 1 ]]; then
      P_CORRECT["$qid"]=$(( P_CORRECT["$qid"] + 1 ))
    else
      P_WRONG["$qid"]=$(( P_WRONG["$qid"] + 1 ))
    fi
    P_DUE["$qid"]=0
    return
  fi

  if [[ "$ok" -eq 1 ]]; then
    P_CORRECT["$qid"]=$(( P_CORRECT["$qid"] + 1 ))
    local lvl=${P_LEVEL[$qid]}
    if (( lvl < MAX_LEVEL )); then lvl=$(( lvl + 1 )); fi
    P_LEVEL["$qid"]=$lvl
    P_DUE["$qid"]=$(( now + SRS_DELAYS[$lvl] ))
  else
    P_WRONG["$qid"]=$(( P_WRONG["$qid"] + 1 ))
    P_LEVEL["$qid"]=0
    P_DUE["$qid"]=$(( now + 60 )) # retry soon
  fi
}

# ----------------------------
# Main quiz loop
# ----------------------------
sandbox_init
load_progress

# deterministic seed if requested
if [[ -n "${SEED}" ]]; then
  RANDOM="${SEED}"
fi

print_banner

CURRENT_INDEX=-1
CURRENT_ID=""
CURRENT_HINT=""
CURRENT_ANS=()

while true; do
  idx="$(pick_question_index)" || exit 1
  CURRENT_INDEX="$idx"
  CURRENT_ID="${Q_ID[$idx]}"
  CURRENT_HINT="${Q_HINT[$idx]}"

  IFS=';;' read -r -a CURRENT_ANS <<<"${Q_ANS_LIST[$idx]}"

  echo
  echo "------------------------------------------------------------"
  echo "[$CURRENT_ID] Tags: ${Q_TAGS[$idx]}"
  echo "Q: ${Q_PROMPT[$idx]}"
  echo -n "> "
  IFS= read -r user_input || true
  user_input="$(trim "$user_input")"

  # in-session commands
  case "$user_input" in
    "/quit") save_progress; echo "Bye."; exit 0;;
    "/help") show_help_in_session; continue;;
    "/hint") echo "Hint: ${CURRENT_HINT:-<none>}"; continue;;
    "/show") echo "Answer: ${CURRENT_ANS[0]}"; continue;;
    "/skip")
      # push due a little later to reduce immediate repetition
      if [[ "${NO_SRS}" -eq 0 ]]; then
        P_DUE["$CURRENT_ID"]=$(( $(now_epoch) + 120 ))
      fi
      echo "Skipped."
      continue
      ;;
    "/stats") show_stats; continue;;
    "/missing") missing_report; continue;;
    "/all")
      FILTER_TAG=""
      echo "Tag filter cleared."
      continue
      ;;
    /tag\ *)
      FILTER_TAG="$(trim "${user_input#/tag }")"
      echo "Tag filter set to: ${FILTER_TAG}"
      continue
      ;;
  esac

  if is_correct "$user_input" "${CURRENT_ANS[@]}"; then
    echo "✅ Correct."
    update_srs_on_result "$CURRENT_ID" 1
  else
    echo "❌ Wrong."
    update_srs_on_result "$CURRENT_ID" 0
    if [[ "${SHOW_ANSWERS_ON_WRONG}" -eq 1 ]]; then
      echo "Answer: ${CURRENT_ANS[0]}"
    fi
  fi

  save_progress
done

