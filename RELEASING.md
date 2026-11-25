# Releasing

**推 tag 就是發版**：沒有套件、沒有 workflow，使用者直接 `uses: …@v0.1.0`。tag 推出去之後不要移動它。

1. 任何一支出新版：`bash scripts/bump.sh XamlContrast 1.12.0`（判定變了加 `--minor`）。它查 GitHub 的 tag 與 nuget.org、
   改 `action.yml`、兩份 README、CHANGELOG，並準備下一個版號；這一版還沒推 tag 就再換一支，會併進同一版。
   Dependabot 開的 PR 只改 `uses`，`verify-pins.sh` 會擋：關掉它、改跑腳本。
2. 那一支的 CHANGELOG 看一遍，把使用者會看到的改變寫進這裡的 CHANGELOG；判定變了就寫 **Upgrading**。
3. CI 綠了、合併之後：`git tag v0.1.0`、`git push origin v0.1.0`。
