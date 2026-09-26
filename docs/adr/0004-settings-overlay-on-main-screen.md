# 设置面板弹在主屏，写入全走 Engine CLI

960×400 触屏太小，打字也不方便；只显示不设置又得手改 JSON。PUB 的设置知识原本在 GNOME 的 `pub-ui.js` 里，抄进 QML 会两边漂移。

决定：Settings Overlay 是 Omarchy overlay，出现在当前聚焦的主屏。入口有两个：副屏上的设置按钮；`~/.config/omarchy/extensions/omarchy-menu.jsonc` 里的「PUB 设置」（`omarchy-shell shell summon noirbright.pub-am01s`）。v1 包含 Enabled、Remaining 读法、官方 CLI 浏览器登录（含 Claude 授权码粘贴）、粘贴 API key。Pinned 在副屏上没有意义，不出现；Primary Window 用默认值。Provider 目录、设置、凭据全部通过 PUB Engine 的 `catalog` / `settings set` / `credentials set`（PUB ADR 0011），本仓库不写 `settings.json` 或 `credentials.json`。
