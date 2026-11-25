#!/usr/bin/env bash
# action.yml 的每一支：釘的 commit 旁邊的 tag、傳給它的 version、兩份 README 的表與安裝指令，都要一樣。
# Dependabot 只會改 uses 那一行，version 沒跟著改就會用新的 Action 跑舊的工具。
# --online：再去 GitHub 看那個 tag 是不是真的指到那個 commit（CI 用）。
set -eu
cd "$(dirname "$0")/.."
bad=0
no() { echo "x $1"; bad=1; }
for t in XamlContrast XamlKeys XamlFit XamlA11y; do
  low=$(tr 'A-Z' 'a-z' <<< "$t")
  line=$(grep -E "uses: HSU-YU-MING/cornhsu-$low@" action.yml) || { no "$t is not in action.yml"; continue; }
  sha=$(sed -E 's/.*@([0-9a-f]{40}) # v.*/\1/' <<< "$line")
  tag=$(sed -E 's/.*# (v[0-9.]+)[[:space:]]*$/\1/' <<< "$line")
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { no "$t is not pinned to a commit: $line"; continue; }
  ver=$(grep -A 3 -F "$line" action.yml | sed -nE 's/^ +version: ([0-9.]+)[[:space:]]*$/\1/p' | head -n 1)
  [ "v$ver" = "$tag" ] || no "$t: the action is $tag, version is ${ver:-missing}"
  for f in README.md README.zh-Hant.md; do
    grep -qE "^\| \[$t\]\(.*\| $ver \|" "$f" || no "$f does not say $t $ver"
    # 寫 baseline 的安裝指令（XamlFit 沒有）
    for v in $(sed -nE "s/.*Cornhsu\.$t --version ([0-9.]+).*/\1/p" "$f"); do
      [ "$v" = "$ver" ] || no "$f installs $t $v, action.yml runs $ver"
    done
  done
  if [ "${1:-}" = --online ]; then
    real=$(gh api "repos/HSU-YU-MING/cornhsu-$low/commits/$tag" -q .sha)
    [ "$real" = "$sha" ] || no "$t: $tag is $real, action.yml pins $sha"
  fi
  echo "$t $tag ${sha:0:8}"
done
# GitHub 市集：說明要少於 125 個字（字元），太長就不能上架，而且要到按發佈那一頁才看得到
desc=$(sed -nE "s/^description: '(.*)'[[:space:]]*\$/\1/p" action.yml)
[ -n "$desc" ] && [ "${#desc}" -lt 125 ] || no "the description in action.yml is ${#desc} characters, the Marketplace takes fewer than 125"
# README 的範例釘的是 CHANGELOG 最新的版本
latest=$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\].*/\1/p' CHANGELOG.md | head -n 1)
for f in README.md README.zh-Hant.md; do
  for v in $(sed -nE 's/.*cornhsu-xaml-audit@v([0-9.]+).*/\1/p' "$f" | sort -u); do
    [ "$v" = "$latest" ] || no "$f pins v$v, CHANGELOG is at $latest"
  done
done
[ "$bad" -eq 0 ] && echo ok
exit "$bad"
