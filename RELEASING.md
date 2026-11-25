# Releasing

**推 tag 就是發版**：沒有套件、沒有 workflow，使用者直接 `uses: …@v0.1.0`。tag 推出去之後不要移動它。

1. 任何一支出新版：`action.yml` 改 commit、tag 註解、`version`，兩份 README 的表與 baseline 指令也改。
   `bash scripts/verify-pins.sh --online` 會說哪裡沒改到（CI 也會擋）。Dependabot 開的 PR 只改 `uses`，要自己補 `version`。
2. 那一支的 CHANGELOG 看一遍：改了判定就是這裡的 minor，CHANGELOG 寫 **Upgrading**。
3. `CHANGELOG.md` 填版本與日期，README 的範例釘新版。
4. CI 綠了、合併之後：`git tag v0.1.0`、`git push origin v0.1.0`。
