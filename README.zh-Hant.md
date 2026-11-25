# XAML audit

**一個 GitHub Action 跑四種 WPF XAML 靜態檢查。不開 App，PR 上只有一則留言。**

[English](README.md)

```yaml
permissions:
  contents: read
  pull-requests: write      # PR 留言
  # security-events: write  # sarif: true 才要

steps:
  - uses: actions/checkout@v7
  - uses: HSU-YU-MING/cornhsu-xaml-audit@v0.1.1
    with:
      root: src
```

| 工具 | 問的問題 | 版本 |
|---|---|---|
| [XamlContrast](https://github.com/HSU-YU-MING/cornhsu-xamlcontrast) | 看不看得清楚（顏色對比） | 1.11.1 |
| [XamlKeys](https://github.com/HSU-YU-MING/cornhsu-xamlkeys) | 找不找得到（資源鍵） | 0.4.1 |
| [XamlFit](https://github.com/HSU-YU-MING/cornhsu-xamlfit) | 裝不裝得下（翻譯的字） | 0.13.1 |
| [XamlA11y](https://github.com/HSU-YU-MING/cornhsu-xamla11y) | 按不按得到、念不念得出來 | 0.1.0 |

這個 repo 自己不檢查任何東西：依序跑四支自己的 Action（版本就是上面那些），把報告合成一則留言。
釘這個 Action 的一個 tag，就等於釘住四支。每一支照樣把問題標在那一行；前一支紅了，後面的照跑；最後只要有一支沒過就擋。

## 既有的專案

第一次跑，每一支都會有東西要報。各記一份 baseline 放進 repo，之後只擋新增的：

```bash
dotnet tool install -g Cornhsu.XamlContrast --version 1.11.1 && xamlcontrast src --write-baseline contrast-baseline.json
dotnet tool install -g Cornhsu.XamlKeys --version 0.4.1      && xamlkeys src --write-baseline keys-baseline.json
dotnet tool install -g Cornhsu.XamlA11y --version 0.1.0      && xamla11y audit src --write-baseline a11y-baseline.json
```

```yaml
    with:
      root: src
      contrast-baseline: contrast-baseline.json
      keys-baseline: keys-baseline.json
      a11y-baseline: a11y-baseline.json
```

## XamlFit 要有字型寬度表

它用你的字型寬度量字。還沒有的時候**不會跑，報告會寫沒跑**：
跑一次 `xamlfit fonts export` 把檔案放進 repo（[什麼可以放](https://github.com/HSU-YU-MING/cornhsu-xamlfit/blob/main/README.zh-Hant.md)），
或用 Windows 的 runner 加 `fit-export-fonts: "Segoe UI"`。寫 `tools: contrast, keys, fit, a11y` 就一定會跑。

## 輸入

| 輸入 | 預設 | |
|---|---|---|
| `root` | `.` | 要掃的資料夾 |
| `working-directory` | `.` | 路徑相對於它 |
| `tools` | `auto` | `auto`，或 `contrast`、`keys`、`fit`、`a11y` 的清單 |
| `fail-on` | 各支自己的 | `fail` 或 `warn`，四支一起 |
| `contrast-baseline`、`keys-baseline`、`fit-baseline`、`a11y-baseline` | | 進 repo 的 baseline |
| `fit-resx`、`fit-metrics`、`fit-export-fonts` | 它的設定檔 | XamlFit 的譯文與字型 |
| `comment` | `true` | 一則 PR 留言，原地更新 |
| `upload-report` | `true` | 一支一個 artifact |
| `sarif` | `false` | 上傳 code scanning |
| `share-stats` | `true` | XamlContrast 的匿名統計（[傳了什麼](https://stats.cornhsu.com/)）；另外三支什麼都不傳 |
| `artifact-prefix` | | 同一次 workflow 跑不只一次時要設 |

其他的寫在各支自己的設定檔，並排放在 `root`：`xamlcontrast.config.json`、`xamlkeys.config.json`、
`xamlfit.config.json`、`xamla11y.config.json`。

會擋的情況：有一支找到問題、有一支看得太少不能信（它的退出碼 3）、有一支沒跑完、一支都沒跑。留言的表會寫是哪一支。

只要用其中一支、或想自己選版本：直接用各自的 Action（上面的表有連結）。
原本四個 Action 都有接的，換過來之後那四則舊留言不會再更新；workflow 與 job 名稱沒變的話，code scanning 的警示照舊。

## 授權

MIT
