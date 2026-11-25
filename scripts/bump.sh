#!/usr/bin/env bash
# 把四支裡的一支換成新版，並準備這個 Action 的下一版：
#   bash scripts/bump.sh XamlContrast 1.12.0            # 版號加第三位
#   bash scripts/bump.sh XamlContrast 1.12.0 --minor    # 判定變了（那一支的 CHANGELOG 有 Upgrading）：加第二位
# 改 action.yml（commit、tag 註解、version）、兩份 README（表、安裝指令、範例）、CHANGELOG，再跑 verify-pins.sh。
# 這一版還沒推 tag 就再換一支：併進同一版，不會再加一次版號。只改檔案，不 commit、不推 tag。
# 測試用：BUMP_SHA 給 commit 的話不連網路。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

usage() { echo "usage: bash scripts/bump.sh XamlContrast|XamlKeys|XamlFit|XamlA11y <x.y.z> [--minor]" >&2; exit 2; }
{ [ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$3" = --minor ]; }; } || usage
tool=$1 ver=$2 minor=${3:-}
case "$tool" in XamlContrast | XamlKeys | XamlFit | XamlA11y) ;; *) usage ;; esac
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
low=$(tr 'A-Z' 'a-z' <<< "$tool")
repo="HSU-YU-MING/cornhsu-$low"

old=$(sed -nE "s|.*uses: $repo@[0-9a-f]{40} # v([0-9.]+)[[:space:]]*\$|\\1|p" action.yml)
[ -n "$old" ] || { echo "bump: $tool is not pinned in action.yml" >&2; exit 1; }
[ "$old" != "$ver" ] || { echo "bump: $tool is already $ver" >&2; exit 1; }

# 先確認那一版真的在：commit 對得到、nuget.org 裝得到。沒有就什麼都不改
sha=${BUMP_SHA:-}
if [ -z "$sha" ]; then
  sha=$(gh api "repos/$repo/commits/v$ver" -q .sha 2>/dev/null) || { echo "bump: $repo has no tag v$ver" >&2; exit 1; }
  curl -fsS "https://api.nuget.org/v3-flatcontainer/cornhsu.$low/index.json" | grep -qF "\"$ver\"" ||
    { echo "bump: Cornhsu.$tool $ver is not on nuget.org yet (it takes a few minutes after the release)" >&2; exit 1; }
fi
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "bump: not a commit: $sha" >&2; exit 1; }

rewrite() { cat "$1.tmp" > "$1"; rm -f "$1.tmp"; }

# action.yml：uses 那一行，和它後面的第一個 version
awk -v repo="$repo" -v sha="$sha" -v ver="$ver" '
  /uses:/ { on = 0 }
  index($0, "uses: " repo "@") { sub(/@[0-9a-f]+ # v[0-9.]+/, "@" sha " # v" ver); on = 1 }
  on && /^ +version: / { sub(/version: [0-9.]+/, "version: " ver); on = 0 }
  { print }
' action.yml > action.yml.tmp && rewrite action.yml

# 這個 Action 自己的版號：CHANGELOG 最上面那一版已經有 tag 才往上加
latest=$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -n 1)
IFS=. read -r a b c <<< "$latest"
next=$latest
if git rev-parse -q --verify "refs/tags/v$latest" > /dev/null; then
  if [ -n "$minor" ]; then next="$a.$((b + 1)).0"; else next="$a.$b.$((c + 1))"; fi
fi
line="- [$tool $ver](https://github.com/$repo/releases/tag/v$ver)."
awk -v old="$latest" -v next_="$next" -v day="$(date +%F)" -v line="$line" '
  !done && index($0, "## [" old "]") == 1 {
    print "## [" next_ "] - " day; print ""; print line
    done = 1
    if (next_ == old) next          # 併進還沒發的那一版：原本的標題不要
    print ""
  }
  { print }
' CHANGELOG.md > CHANGELOG.md.tmp && rewrite CHANGELOG.md
# 併進同一版時，新的一行和原本的清單中間不要空行
if [ "$next" = "$latest" ]; then
  awk -v line="$line" 'prev == line && $0 == "" { prev = ""; next } { print; prev = $0 }' CHANGELOG.md > CHANGELOG.md.tmp && rewrite CHANGELOG.md
fi

for f in README.md README.zh-Hant.md; do
  sed -E -e "s/^(\\| \\[$tool\\]\\(.*\\| )[0-9.]+ \\|\$/\\1$ver |/" \
         -e "s/(Cornhsu\\.$tool --version )[0-9]+\\.[0-9]+\\.[0-9]+/\\1$ver/" \
         -e "s/(cornhsu-xaml-audit@v)[0-9]+\\.[0-9]+\\.[0-9]+/\\1$next/" "$f" > "$f.tmp" && rewrite "$f"
done

if [ -n "${BUMP_SHA:-}" ]; then bash scripts/verify-pins.sh; else bash scripts/verify-pins.sh --online; fi
echo
echo "$tool $old -> $ver; this action: v$next"
echo "read https://github.com/$repo/releases/tag/v$ver and say in CHANGELOG.md what changes for the user"
[ -n "$minor" ] || echo "if it finds different things now (Upgrading), this is a minor version: git checkout . and run again with --minor"
echo "then: branch, PR, merge, git tag v$next"
