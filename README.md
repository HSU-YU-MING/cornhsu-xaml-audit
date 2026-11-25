# XAML audit

**Four static checks for WPF XAML in one GitHub Action. Nothing is launched, one PR comment.**

[繁體中文](README.zh-Hant.md)

```yaml
permissions:
  contents: read
  pull-requests: write      # the PR comment
  # security-events: write  # only for sarif: true

steps:
  - uses: actions/checkout@v7
  - uses: HSU-YU-MING/cornhsu-xaml-audit@v0.1.2
    with:
      root: src
```

| Tool | Asks | Version |
|---|---|---|
| [XamlContrast](https://github.com/HSU-YU-MING/cornhsu-xamlcontrast) | can you **see** it (color contrast) | 1.11.1 |
| [XamlKeys](https://github.com/HSU-YU-MING/cornhsu-xamlkeys) | can it be **found** (resource keys) | 0.4.1 |
| [XamlFit](https://github.com/HSU-YU-MING/cornhsu-xamlfit) | does it **fit** (translated text) | 0.13.1 |
| [XamlA11y](https://github.com/HSU-YU-MING/cornhsu-xamla11y) | can you **reach** it (keyboard, screen reader) | 0.1.0 |

This repository checks nothing itself: it runs the four tools' own actions, at the versions above, and puts their reports
into one comment. Pinning a tag of this action pins all four. Each tool marks its findings on the lines, and every one of them
runs even when an earlier one failed. The job fails at the end when any of them did.

## An existing project

Every tool has problems to report on its first run. Write a baseline for each, commit the files, and only new problems fail:

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

## XamlFit needs font metrics

It measures text with the widths of your fonts. Until they are there it is **left out, and the report says so**:
run `xamlfit fonts export` once and commit the file ([what may be committed](https://github.com/HSU-YU-MING/cornhsu-xamlfit#readme)),
or use a Windows runner and `fit-export-fonts: "Segoe UI"`. With `tools: contrast, keys, fit, a11y` it always runs.

## Inputs

| Input | Default | |
|---|---|---|
| `root` | `.` | folder to scan |
| `working-directory` | `.` | the paths are relative to it |
| `tools` | `auto` | `auto`, or a list of `contrast`, `keys`, `fit`, `a11y` |
| `fail-on` | each tool's own | `fail` or `warn`, for all of them |
| `contrast-baseline`, `keys-baseline`, `fit-baseline`, `a11y-baseline` | | committed baseline files |
| `fit-resx`, `fit-metrics`, `fit-export-fonts` | its config file | XamlFit's translations and fonts |
| `comment` | `true` | one PR comment, updated in place |
| `upload-report` | `true` | one artifact per tool |
| `sarif` | `false` | upload to code scanning |
| `share-stats` | `true` | XamlContrast's anonymous statistics ([what is sent](https://stats.cornhsu.com/)); the others send nothing |
| `artifact-prefix` | | set it when the action runs more than once in a workflow run |

Everything else is set in each tool's own config file, side by side in `root`: `xamlcontrast.config.json`,
`xamlkeys.config.json`, `xamlfit.config.json`, `xamla11y.config.json`.

The job fails when a tool found problems, when one saw too little to be trusted (its exit code 3), when one stopped
before its report, and when none ran. The table in the comment says which.

Using one tool alone, or different versions of them: call their own actions
(linked in the table above) directly. Moving from four actions to this one: the four old PR comments are not updated any more; code scanning alerts carry on if the workflow and job keep their names.

## License

MIT
