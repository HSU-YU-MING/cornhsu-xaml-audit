#!/usr/bin/env bash
# 把四支的 Markdown 報告合成一份：上面一張表，下面一支一段。寫進 $RUNNER_TEMP/xaml-audit.md。
# 輸入：XU_CONTRAST／XU_KEYS／XU_FIT／XU_A11Y = 各步驟的 outcome（success／failure／skipped／cancelled／空），XU_FIT_NOTE。
# 結束碼：0 = 選到的都過；1 = 有一支沒過，或一支都沒跑。
set -u

out="$RUNNER_TEMP/xaml-audit.md"
limit=${XU_LIMIT:-14000}   # 一支最多這麼多位元組：四支加起來不超過 GitHub 留言的上限（約 65536 字）
failed=0 ran=0
table='' body=''

section() { # 名稱 報告檔 outcome 沒跑的原因
  local name=$1 file="$RUNNER_TEMP/$2-report.md" outcome=$3 note=$4 status text open='' opened
  case "$outcome" in
    success | failure) ran=$((ran + 1)) ;;
    '' | skipped) table+="| $name | not run${note:+: $note} |"$'\n'; return ;;
    *) failed=1; table+="| $name | :warning: $outcome |"$'\n'; return ;;
  esac
  [ "$outcome" = success ] || { failed=1; open=' open'; }
  if [ ! -s "$file" ]; then
    # 沒有報告：輸入錯、裝不起來、或自己壞了。成功卻沒有報告也不能算看過
    failed=1
    table+="| $name | :warning: stopped before its report (see the log of this step) |"$'\n'
    return
  fi
  # 每一份的第 3 行是結論（❌ **FAIL** · …）。放進表格，直線要跳脫
  status=$(sed -n '3{s/\r$//;s/|/\\|/g;p;}' "$file")
  table+="| $name | ${status:-$outcome} |"$'\n'
  if [ "$(wc -c < "$file")" -gt "$limit" ]; then
    # 截在整行上：切在 code span 中間的話，收尾的反引號沒了，裡面的 [文字](網址)、@帳號 就會生效
    text=$(head -c "$limit" "$file" | sed '$d' | tr -d '\r')
    opened=$(( $(grep -c '^<details' <<< "$text") - $(grep -c '</details>$' <<< "$text") ))
    while [ "$opened" -gt 0 ]; do text+=$'\n\n</details>'; opened=$((opened - 1)); done
    text+=$'\n\n<sub>:warning: Report truncated here; the whole report is in the artifact.</sub>'
  else
    text=$(tr -d '\r' < "$file")
  fi
  body+=$'\n'"<details$open><summary>$name</summary>"$'\n\n'"$text"$'\n\n</details>\n'
}

section XamlContrast xamlcontrast "$XU_CONTRAST" ''
section XamlKeys xamlkeys "$XU_KEYS" ''
section XamlFit xamlfit "$XU_FIT" "$XU_FIT_NOTE"
section XamlA11y xamla11y "$XU_A11Y" ''
[ "$ran" -gt 0 ] || failed=1

{
  printf '## XAML audit\n\n| Tool | Result |\n|---|---|\n%s%s' "$table" "$body"
} > "$out"
exit "$failed"
