#!/usr/bin/env bash
# 驗輸入、決定跑哪幾支。壞值 exit 2，在裝任何東西之前。訊息只點名 input，不印值（值可能來自 PR 作者）。
# 輸入都從 XU_* 環境變數來；結果寫進 $GITHUB_OUTPUT：contrast／keys／fit／a11y = true|false，fit-note = 為什麼沒跑。
set -u

bad=0
refuse() { echo "::error title=XAML audit action::$1"; bad=1; }

# 帶換行的值一律拒絕：下游的錯誤訊息會原樣印出，換行後的內容落在行首就成了 workflow command
case "$XU_ROOT$XU_WORKDIR$XU_TOOLS$XU_CONTRAST_BASELINE$XU_KEYS_BASELINE$XU_FIT_BASELINE$XU_A11Y_BASELINE$XU_FIT_RESX$XU_FIT_METRICS$XU_FIT_EXPORT_FONTS$XU_PREFIX" in
  *$'\n'* | *$'\r'*) refuse "inputs must not contain a line break" ;;
esac
case "$XU_ROOT" in -*) refuse "root must not start with '-' (write ./-name for such a directory)" ;; esac
[ -n "$XU_ROOT" ] || refuse "root must not be empty (write . for the repository root)"
for pair in "contrast-baseline=$XU_CONTRAST_BASELINE" "keys-baseline=$XU_KEYS_BASELINE" "fit-baseline=$XU_FIT_BASELINE" "a11y-baseline=$XU_A11Y_BASELINE" "fit-resx=$XU_FIT_RESX" "fit-metrics=$XU_FIT_METRICS"; do
  case "${pair#*=}" in -*) refuse "${pair%%=*} must not start with '-' (write ./-name for such a path)" ;; esac
done
case "$XU_FAIL_ON" in
  '' | warn | fail) ;;
  *) refuse "fail-on must be 'fail', 'warn' or empty (each tool's own default)" ;;
esac
for pair in "comment=$XU_COMMENT" "upload-report=$XU_UPLOAD_REPORT" "sarif=$XU_SARIF" "share-stats=$XU_SHARE_STATS"; do
  case "${pair#*=}" in
    true | false) ;;
    *) refuse "${pair%%=*} must be 'true' or 'false'" ;;
  esac
done
# artifact-prefix 會成為 artifact 名稱與 PR 留言標記的一部分（標記又拼進 jq 字串），只收安全的字元
if [ -n "$XU_PREFIX" ] && { ! [[ "$XU_PREFIX" =~ ^[A-Za-z0-9._-]{1,60}$ ]] || [[ "$XU_PREFIX" =~ ^-|^\.+$ ]]; }; then
  refuse "artifact-prefix must be 1-60 characters of A-Z, a-z, 0-9, '.', '_' or '-', not starting with '-' and not only dots"
fi

contrast=false keys=false fit=false a11y=false note=''
if [ "$XU_TOOLS" = auto ]; then
  contrast=true keys=true a11y=true
  # XamlFit 沒有字型寬度表就量不了（exit 2 或 3）。第一天就因為這個紅燈，整套會被關掉；
  # 默默跳過又會變成「沒看就說沒問題」。所以：找得到才跑，找不到就在報告與註記上說沒跑。
  case "$XU_ROOT" in
    /* | [A-Za-z]:*) dir=$XU_ROOT ;;
    *) dir="$XU_WORKDIR/$XU_ROOT" ;;
  esac
  if [ -n "$XU_FIT_METRICS$XU_FIT_EXPORT_FONTS" ]; then
    fit=true
  else
    for f in "$dir"/xamlfit.fonts.json.gz "$dir"/xamlfit.fonts.json "$dir"/xamlfit.config.json "$XU_WORKDIR"/xamlfit.fonts.json.gz "$XU_WORKDIR"/xamlfit.fonts.json; do
      [ -f "$f" ] && fit=true
    done
  fi
  [ "$fit" = true ] || note="no font metrics: run 'xamlfit fonts export' once and commit the file, or set fit-export-fonts on a Windows runner"
else
  IFS=', ' read -ra names <<< "$XU_TOOLS"
  n=0
  for t in "${names[@]}"; do
    case "$t" in
      '') continue ;;
      contrast) contrast=true ;;
      keys) keys=true ;;
      fit) fit=true ;;
      a11y) a11y=true ;;
      *) refuse "tools must be 'auto' or a list of contrast, keys, fit and a11y" ;;
    esac
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || refuse "tools is empty: nothing would be checked"
fi
[ "$bad" -eq 0 ] || exit 2

# 同一個 job 前一次呼叫留下的報告不能被這一次的留言撿去
for t in xamlcontrast xamlkeys xamlfit xamla11y; do rm -f -- "$RUNNER_TEMP/$t-report.md"; done
rm -f -- "$RUNNER_TEMP/xaml-audit.md"

{
  echo "contrast=$contrast"
  echo "keys=$keys"
  echo "fit=$fit"
  echo "a11y=$a11y"
  echo "fit-note=$note"
} >> "$GITHUB_OUTPUT"
[ -z "$note" ] || echo "::warning title=XAML audit::XamlFit was not run ($note)"
