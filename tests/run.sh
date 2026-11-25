#!/usr/bin/env bash
# plan.sh、report.sh 與 bump.sh 的測試：不用網路、不用裝工具。bash tests/run.sh
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export RUNNER_TEMP="$tmp/rt"
pass=0 fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); printf 'x %s\n   expected: %s\n   got:      %s\n' "$1" "$2" "$3"; fi; }
has() { case "$3" in *"$2"*) pass=$((pass + 1)) ;; *) fail=$((fail + 1)); printf 'x %s: no "%s" in\n%s\n' "$1" "$2" "$3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail + 1)); printf 'x %s: "%s" is in\n%s\n' "$1" "$2" "$3" ;; *) pass=$((pass + 1)) ;; esac; }

# plan NAME=value… → 印「結束碼 contrast keys fit a11y」
plan() {
  rm -rf "$RUNNER_TEMP"; mkdir -p "$RUNNER_TEMP"; : > "$tmp/out"
  ( cd "$tmp/ws" && env XU_ROOT=src XU_WORKDIR=. XU_TOOLS=auto XU_FAIL_ON= XU_CONTRAST_BASELINE= XU_KEYS_BASELINE= XU_FIT_BASELINE= \
      XU_A11Y_BASELINE= XU_FIT_RESX= XU_FIT_METRICS= XU_FIT_EXPORT_FONTS= XU_COMMENT=true XU_UPLOAD_REPORT=true XU_SARIF=false \
      XU_SHARE_STATS=true XU_PREFIX= GITHUB_OUTPUT="$tmp/out" "$@" bash "$here/scripts/plan.sh" > "$tmp/log" 2>&1 )
  local code=$? o=''
  for t in contrast keys fit a11y; do o+=" $(sed -n "s/^$t=//p" "$tmp/out")"; done
  echo "$code$o"
}

mkdir -p "$tmp/ws/src" "$tmp/ws/with" "$tmp/ws/cfg" "$tmp/ws/sub/src"
: > "$tmp/ws/with/xamlfit.fonts.json.gz"; : > "$tmp/ws/cfg/xamlfit.config.json"; : > "$tmp/ws/sub/xamlfit.fonts.json"
all='0 true true true true' three='0 true true false true'
ok 'auto, no metrics' "$three" "$(plan)"
has 'auto says XamlFit was left out' '::warning title=XAML audit::XamlFit was not run' "$(cat "$tmp/log")"
has 'and tells the report' 'fit-note=no font metrics' "$(cat "$tmp/out")"
ok 'auto, metrics in root' "$all" "$(plan XU_ROOT=with)"
hasnt 'auto says nothing then' '::warning' "$(cat "$tmp/log")"
ok 'auto, metrics named in the config' "$all" "$(plan XU_ROOT=cfg)"
ok 'auto, metrics in the working directory' "$all" "$(plan XU_WORKDIR=sub)"
ok 'auto, root elsewhere does not count' "$three" "$(plan XU_WORKDIR=sub/src XU_ROOT=.)"
ok 'auto, absolute root' "$all" "$(plan "XU_ROOT=$tmp/ws/with")"
ok 'auto, metrics input' "$all" "$(plan XU_FIT_METRICS=m.gz)"
ok 'auto, exported fonts' "$all" "$(plan 'XU_FIT_EXPORT_FONTS=Segoe UI')"
ok 'a list' '0 true false false true' "$(plan 'XU_TOOLS=contrast, a11y')"
ok 'a list without spaces' '0 false true true false' "$(plan XU_TOOLS=keys,fit)"
ok 'asking for fit runs it without metrics' '0 false false true false' "$(plan XU_TOOLS=fit)"
ok 'fail-on warn' "$three" "$(plan XU_FAIL_ON=warn)"
ok 'a prefix' "$three" "$(plan XU_PREFIX=web.1_a-b)"
for bad in XU_TOOLS= XU_TOOLS=, XU_TOOLS=Contrast XU_TOOLS=contrast,all XU_ROOT= XU_ROOT=--version XU_A11Y_BASELINE=-x XU_CONTRAST_BASELINE=-x \
  XU_KEYS_BASELINE=-x XU_FIT_BASELINE=-x XU_FIT_RESX=-x XU_FIT_METRICS=-x XU_FAIL_ON=Warn XU_FAIL_ON=info XU_COMMENT=yes XU_COMMENT= \
  XU_UPLOAD_REPORT=True XU_SARIF=1 XU_SHARE_STATS=no XU_PREFIX=-x XU_PREFIX=.. 'XU_PREFIX=a b' 'XU_PREFIX=a"b' "XU_PREFIX=$(printf 'a%.0s' {1..61})"; do
  ok "refused: $bad" '2    ' "$(plan "$bad")"
done
for v in ROOT WORKDIR TOOLS CONTRAST_BASELINE KEYS_BASELINE FIT_BASELINE A11Y_BASELINE FIT_RESX FIT_METRICS FIT_EXPORT_FONTS PREFIX; do
  ok "refused: a line break in $v" '2    ' "$(plan "XU_$v"=$'a\n::error::x')"
  hasnt "the value is not printed ($v)" '::error::x' "$(cat "$tmp/log")"
done
plan > /dev/null
mkdir -p "$RUNNER_TEMP"; for t in xamlcontrast xamlkeys xamlfit xamla11y; do echo old > "$RUNNER_TEMP/$t-report.md"; done
( cd "$tmp/ws" && env XU_ROOT=. XU_WORKDIR=. XU_TOOLS=keys XU_FAIL_ON= XU_CONTRAST_BASELINE= XU_KEYS_BASELINE= XU_FIT_BASELINE= XU_A11Y_BASELINE= \
    XU_FIT_RESX= XU_FIT_METRICS= XU_FIT_EXPORT_FONTS= XU_COMMENT=true XU_UPLOAD_REPORT=true XU_SARIF=false XU_SHARE_STATS=true XU_PREFIX= \
    GITHUB_OUTPUT="$tmp/out" bash "$here/scripts/plan.sh" )
ok 'reports of an earlier call are gone' '' "$(ls "$RUNNER_TEMP")"

# report：報告檔是 <工具>=<內容>，outcome 用 XU_*
start() { rm -rf "$RUNNER_TEMP"; mkdir -p "$RUNNER_TEMP"; }
md() { printf '## %s\n\n%s\n\nbody of %s\n' "$2" "$3" "$2" > "$RUNNER_TEMP/$1-report.md"; }
report() { env XU_CONTRAST= XU_KEYS= XU_FIT= XU_A11Y= XU_FIT_NOTE= "$@" bash "$here/scripts/report.sh"; echo $?; }
text() { cat "$RUNNER_TEMP/xaml-audit.md"; }
four() { md xamlcontrast XamlContrast "PASS c"; md xamlkeys XamlKeys "PASS k"; md xamlfit XamlFit "PASS f"; md xamla11y XamlA11y "PASS a"; }

start; four
ok 'all pass' 0 "$(report XU_CONTRAST=success XU_KEYS=success XU_FIT=success XU_A11Y=success)"
for n in XamlContrast:c XamlKeys:k XamlFit:f XamlA11y:a; do has "row of ${n%%:*}" "| ${n%%:*} | PASS ${n##*:} |" "$(text)"; has "body of ${n%%:*}" "body of ${n%%:*}" "$(text)"; done
hasnt 'closed when it passed' '<details open>' "$(text)"
for one in CONTRAST KEYS FIT A11Y; do
  start; four
  args=(XU_CONTRAST=success XU_KEYS=success XU_FIT=success XU_A11Y=success "XU_$one=failure")
  ok "$one failing fails" 1 "$(report "${args[@]}")"
  ok "$one is the open one" 1 "$(text | grep -c '<details open>')"
done
start; four
ok 'one left out' 0 "$(report XU_CONTRAST=success XU_KEYS=success XU_FIT=skipped XU_A11Y=success 'XU_FIT_NOTE=no font metrics')"
has 'says so and why' '| XamlFit | not run: no font metrics |' "$(text)"
hasnt 'without its old report' 'body of XamlFit' "$(text)"
start; four
ok 'not chosen' 0 "$(report XU_KEYS=success)"
has 'not chosen: says not run' '| XamlContrast | not run |' "$(text)"
start
ok 'failed before its report' 1 "$(report XU_KEYS=failure)"
has 'failed before its report: says so' '| XamlKeys | :warning: stopped before its report' "$(text)"
start
ok 'success without a report is not a pass' 1 "$(report XU_KEYS=success)"
start; four
ok 'cancelled is not a pass' 1 "$(report XU_KEYS=success XU_A11Y=cancelled)"
start
ok 'nothing ran is not a pass' 1 "$(report)"
start; md xamlkeys XamlKeys 'a | b'
ok 'a bar in the result' 0 "$(report XU_KEYS=success)"
has 'a bar in the result is escaped' '| XamlKeys | a \| b |' "$(text)"
start; printf '## XamlKeys\r\n\r\nPASS k\r\n\r\n<details><summary>x</summary>\r\n\r\ny\r\n\r\n</details>\r\n' > "$RUNNER_TEMP/xamlkeys-report.md"
ok 'CRLF' 0 "$(report XU_KEYS=success)"
hasnt 'CRLF: gone' $'\r' "$(text)"
# 太長：截在整行、收好 details、其他支不受影響
start; four
{ printf '## XamlKeys\n\nFAIL k\n\n<details><summary>x</summary>\n\n'; for i in $(seq 400); do printf '| `row %s` | `[a](http://x) @user 中文字` |\n' "$i"; done; printf '\n</details>\n'; } > "$RUNNER_TEMP/xamlkeys-report.md"
ok 'long' 1 "$(report XU_CONTRAST=success XU_KEYS=failure XU_FIT=success XU_A11Y=success XU_LIMIT=3000)"
t=$(text)
has 'long: says it was cut' 'Report truncated here' "$t"
has 'long: the rest is still there' 'body of XamlA11y' "$t"
ok 'long: details are balanced' "$(grep -c '<details' <<< "$t")" "$(grep -c '</details>' <<< "$t")"
ok 'long: no half row' 0 "$(grep '^| `row' <<< "$t" | grep -vc '` |$')"
start; four
for t in xamlcontrast xamlkeys xamlfit xamla11y; do { printf '## t\n\nFAIL\n\n'; for i in $(seq 4000); do echo "| \`row $i\` |"; done; } > "$RUNNER_TEMP/$t-report.md"; done
report XU_CONTRAST=failure XU_KEYS=failure XU_FIT=failure XU_A11Y=failure > /dev/null
size=$(wc -c < "$RUNNER_TEMP/xaml-audit.md")
ok 'four long ones fit in a comment' yes "$([ "$size" -lt 65000 ] && echo yes || echo "$size")"

# bump：在複製品裡跑，不連網路
bumped() { # 有沒有 tag 的版本
  rm -rf "$tmp/b"; mkdir -p "$tmp/b"
  cp -r "$here/action.yml" "$here/README.md" "$here/README.zh-Hant.md" "$here/CHANGELOG.md" "$here/scripts" "$tmp/b/"
  latest=$(sed -nE 's/^## \[([0-9.]+)\].*/\1/p' "$tmp/b/CHANGELOG.md" | head -n 1)
  ( cd "$tmp/b" && git init -q . && git config user.email t@t && git config user.name t && git config core.autocrlf false && git add -A && git commit -qm x )
  [ "${1:-}" = untagged ] || git -C "$tmp/b" tag "v$latest"
}
bump() { ( cd "$tmp/b" && BUMP_SHA=$(printf 'a%.0s' {1..40}) bash scripts/bump.sh "$@" > "$tmp/blog" 2>&1 ); echo $?; }
top() { sed -nE 's/^## \[([0-9.]+)\] - (.*)/\1/p' "$tmp/b/CHANGELOG.md" | head -n "${1:-1}" | tr '\n' ' '; }
files() { git -C "$tmp/b" diff --name-only | tr '\n' ' '; }
for t in XamlContrast XamlKeys XamlFit XamlA11y; do
  bumped
  ok "bump $t" 0 "$(bump "$t" 77.1.2)"
  has "bump $t: verify-pins is content" ok "$(cat "$tmp/blog")"
  ok "bump $t: every file" 'CHANGELOG.md README.md README.zh-Hant.md action.yml ' "$(files)"
  ok "bump $t: only its own pin" 4 "$(git -C "$tmp/b" diff -U0 -- action.yml | grep -cE '^[-+] ')"
  has "bump $t: the CHANGELOG says so" "- [$t 77.1.2](https://github.com/HSU-YU-MING/cornhsu-$(tr 'A-Z' 'a-z' <<< "$t")/releases/tag/v77.1.2)." "$(head -n 12 "$tmp/b/CHANGELOG.md")"
  ok "bump $t: no old example left" 0 "$(grep -c "xaml-audit@v$latest" "$tmp/b/README.md")"
done
bumped
IFS=. read -r a b c <<< "$latest"
bump XamlKeys 77.1.2 > /dev/null
ok 'the next patch' "$a.$b.$((c + 1)) $latest " "$(top 2)"
ok 'a second one joins the version that is not out yet' 0 "$(bump XamlFit 77.3.4)"
ok 'and does not bump again' "$a.$b.$((c + 1)) $latest " "$(top 2)"
ok 'both are listed, next to each other' 2 "$(sed -n '/^## /,/^## /p' "$tmp/b/CHANGELOG.md" | sed -n '3,4p' | grep -c '77\.')"
bumped; bump XamlKeys 77.1.2 --minor > /dev/null
ok 'the next minor' "$a.$((b + 1)).0 $latest " "$(top 2)"
bumped untagged; bump XamlKeys 77.1.2 > /dev/null
ok 'the version at the top is not out yet' "$latest" "$(top | tr -d ' ')"
for bad in '' 'XamlKeys' 'xamlkeys 1.0.0' 'XamlAudit 1.0.0' 'XamlKeys v1.0.0' 'XamlKeys 1.0' 'XamlKeys 1.0.0 --major' 'XamlKeys 1.0.0 --minor x'; do
  bumped
  # shellcheck disable=SC2086
  ok "refused: bump $bad" 2 "$(bump $bad)"
  ok "nothing changed: bump $bad" '' "$(files)"
done
bumped
now=$(sed -nE 's/.*cornhsu-xamlkeys@[0-9a-f]+ # v([0-9.]+).*/\1/p' "$tmp/b/action.yml")
ok 'already there' 1 "$(bump XamlKeys "$now")"
ok 'already there: nothing changed' '' "$(files)"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
